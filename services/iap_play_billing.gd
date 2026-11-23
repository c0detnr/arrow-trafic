extends RefCounted
## IAP backend for godot-sdk-integrations/godot-google-play-billing 3.3.0 (Billing Library 9.1.0).
## Implements the backend contract documented at the top of services/iap.gd.
##
## The plugin is OPTIONAL: this file never names the plugin's `BillingClient` class_name; the
## wrapper script is load()ed by path at runtime (tests inject a fake through `make_client`).
## iap.gd only creates this adapter when is_plugin_available().
##
## Flow: connect (retry with backoff, reconnect after a disconnect) → report availability →
## iap.gd queries product details → query owned purchases (catches purchases finished while the
## app was closed and ones never consumed/acknowledged) → deliver them through iap.gd's grant
## path → iap.gd calls finish_purchase() → consume (consumable) / acknowledge (non-consumable).

## Engine singleton registered by the plugin's AAR.
const SINGLETON := "GodotGooglePlayBilling"
## Wrapper script installed by the plugin (export_scripts/BillingClient.gd in the repo).
const CLIENT_SCRIPT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"

# Values of the wrapper's enums (BillingClient.gd, 3.3.0).
const RESPONSE_OK := 0
const RESPONSE_USER_CANCELED := 1
const RESPONSE_DEVELOPER_ERROR := 5
const RESPONSE_ITEM_ALREADY_OWNED := 7
const RESPONSE_ITEM_NOT_OWNED := 8
const PRODUCT_TYPE_INAPP := 0                # ProductType {INAPP, SUBS}
const PURCHASE_STATE_PURCHASED := 1          # PurchaseState {UNSPECIFIED_STATE, PURCHASED, PENDING}
const PURCHASE_STATE_PENDING := 2

## Seconds before the n-th consecutive retry (last value repeats).
const RETRY_DELAYS := [2.0, 5.0, 15.0, 30.0, 60.0, 120.0]

## () -> Object with BillingClient's methods and signals. Tests replace it.
var make_client: Callable
## (seconds: float, callback: Callable) -> void. Tests replace it to fire timers by hand.
var schedule: Callable

var listener: Object
var client: Object
## Product id → true if consumable (from listener.PRODUCTS).
var consumables := {}
var _connect_failures := 0
var _reconnect_pending := false
var _query_failures := 0
var _query_retry_pending := false
var _product_ids: Array = []
var _purchasing := ""
## Purchase token → is_acknowledged, as last reported by the store.
var _acknowledged := {}
## Tokens with a consume/acknowledge request in flight.
var _finishing := {}


## True when the native plugin is in the build AND its GDScript wrapper is in the project.
static func is_plugin_available() -> bool:
	return Engine.has_singleton(SINGLETON) and ResourceLoader.exists(CLIENT_SCRIPT)


func _init() -> void:
	make_client = func() -> Object:
		var script: Script = load(CLIENT_SCRIPT)
		return script.new() if script != null else null
	schedule = _default_schedule


func _default_schedule(seconds: float, callback: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if seconds <= 0.0 or tree == null:
		callback.call_deferred()
	else:
		tree.create_timer(seconds, true).timeout.connect(callback)


static func _retry_delay(failures: int) -> float:
	return RETRY_DELAYS[mini(failures, RETRY_DELAYS.size() - 1)]


# --- Contract ---

func initialize(target: Object) -> void:
	listener = target
	if "PRODUCTS" in listener:
		var products: Dictionary = listener.PRODUCTS
		for id in products:
			consumables[id] = products[id].get("type", "") == "consumable"
	client = make_client.call()
	if client == null:
		listener._backend_availability(false)
		return
	# Native signals may arrive off the main thread; CONNECT_DEFERRED hops back to it.
	var deferred := CONNECT_DEFERRED
	client.connected.connect(_on_connected, deferred)
	client.disconnected.connect(_on_disconnected, deferred)
	client.connect_error.connect(_on_connect_error, deferred)
	client.query_product_details_response.connect(_on_product_details, deferred)
	client.query_purchases_response.connect(_on_query_purchases, deferred)
	client.on_purchase_updated.connect(_on_purchase_updated, deferred)
	client.consume_purchase_response.connect(_on_consume_response, deferred)
	client.acknowledge_purchase_response.connect(_on_acknowledge_response, deferred)
	# BillingClient is a Node: parent it to the IAP autoload so it is freed with the tree.
	if client is Node and listener is Node and client.get_parent() == null:
		(listener as Node).add_child.call_deferred(client)
	client.start_connection()


func query_products(ids: Array) -> void:
	_product_ids = ids.duplicate()
	if client != null and not ids.is_empty():
		client.query_product_details(PackedStringArray(ids), PRODUCT_TYPE_INAPP)


func purchase(product_id: String) -> void:
	_purchasing = product_id
	var result = client.purchase(product_id)
	var code := int(result.get("response_code", -999)) if result is Dictionary else -999
	if code != RESPONSE_OK:
		_purchasing = ""
		_fail(product_id, code, str(result.get("debug_message", "")) if result is Dictionary else "")
		if code == RESPONSE_DEVELOPER_ERROR and not _product_ids.is_empty():
			query_products(_product_ids)   # DEVELOPER_ERROR: details not loaded yet; refetch


func restore_purchases() -> void:
	_query_owned()


func finish_purchase(_product_id: String, token: String, consumable: bool) -> void:
	if client == null or token.is_empty() or _finishing.has(token):
		return
	if consumable:
		_finishing[token] = true
		client.consume_purchase(token)
	elif not _acknowledged.get(token, false):
		_finishing[token] = true
		client.acknowledge_purchase(token)


# --- Connection ---

func _on_connected() -> void:
	_connect_failures = 0
	_reconnect_pending = false
	listener._backend_availability(true)   # iap.gd then calls query_products()
	_query_owned()


func _on_disconnected() -> void:
	listener._backend_availability(false)
	_schedule_reconnect()


func _on_connect_error(code: int, message: String) -> void:
	push_warning("IapPlayBilling: connect error %d: %s" % [code, message])
	listener._backend_availability(false)
	_schedule_reconnect()


func _schedule_reconnect() -> void:
	if _reconnect_pending:
		return
	_reconnect_pending = true
	schedule.call(_retry_delay(_connect_failures), _reconnect)
	_connect_failures += 1


func _reconnect() -> void:
	_reconnect_pending = false
	if client != null:
		client.start_connection()


# --- Store responses ---

func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		push_warning("IapPlayBilling: product query failed: " + str(response.get("debug_message", "")))
		return
	var details := {}
	for product in response.get("product_details", []):
		if not product is Dictionary:
			continue
		var offers = product.get("one_time_purchase_offer_details_list")
		var price := ""
		if offers is Array and not offers.is_empty():
			var chosen: Dictionary = offers[0]
			for offer in offers:   # prefer the base purchase option over a discount offer
				if offer is Dictionary and (offer.get("offer_id") == null or str(offer.get("offer_id")).is_empty()):
					chosen = offer
					break
			price = str(chosen.get("formatted_price", ""))
		# "title" is "Name (App name)"; "name" is the bare product name.
		var title := str(product.get("name", ""))
		if title.is_empty():
			title = str(product.get("title", ""))
		details[str(product.get("product_id", ""))] = {"price": price, "title": title}
	listener._backend_products(details)


func _query_owned() -> void:
	if client != null:
		client.query_purchases(PRODUCT_TYPE_INAPP)


func _on_query_purchases(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		push_warning("IapPlayBilling: purchase query failed: " + str(response.get("debug_message", "")))
		_schedule_query_retry()
		return
	_query_failures = 0
	var restored := []
	for purchase in response.get("purchases", []):
		if not purchase is Dictionary or int(purchase.get("purchase_state", 0)) != PURCHASE_STATE_PURCHASED:
			continue   # PENDING: not paid yet; it shows up here as PURCHASED once it is
		var token := str(purchase.get("purchase_token", ""))
		var acknowledged := bool(purchase.get("is_acknowledged", false))
		_acknowledged[token] = acknowledged
		for id in purchase.get("product_ids", []):
			var product_id := str(id)
			if consumables.get(product_id, false) or not acknowledged:
				# Paid but never finished (app closed / crash / pending completed): run it through
				# the normal success path so it is granted, then consumed or acknowledged.
				listener._backend_purchase_succeeded(product_id, token)
			else:
				restored.append({"product_id": product_id, "token": token})
	listener._backend_restored(restored)


func _schedule_query_retry() -> void:
	if _query_retry_pending:
		return
	_query_retry_pending = true
	schedule.call(_retry_delay(_query_failures), func() -> void:
		_query_retry_pending = false
		_query_owned())
	_query_failures += 1


func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code != RESPONSE_OK:
		var id := _purchasing
		_purchasing = ""
		if not id.is_empty():
			_fail(id, code, str(response.get("debug_message", "")))
		return
	for purchase in response.get("purchases", []):
		if not purchase is Dictionary:
			continue
		var state := int(purchase.get("purchase_state", 0))
		var token := str(purchase.get("purchase_token", ""))
		for id in purchase.get("product_ids", []):
			var product_id := str(id)
			if state == PURCHASE_STATE_PURCHASED:
				if product_id == _purchasing:
					_purchasing = ""
				_acknowledged[token] = bool(purchase.get("is_acknowledged", false))
				listener._backend_purchase_succeeded(product_id, token)
			elif state == PURCHASE_STATE_PENDING:
				# Not paid yet (e.g. cash payment). Do not grant; report "pending" (the UI shows a
				# "payment pending" note) and free the purchase slot. Play sends another update, or
				# the owned-purchases query (startup / app resume) returns it as PURCHASED, later.
				if product_id == _purchasing:
					_purchasing = ""
				listener._backend_purchase_failed(product_id, "pending")
	if not _purchasing.is_empty():
		# OK update without our product in a known state (UNSPECIFIED, or only other purchases):
		# never leave IAP waiting forever.
		var stuck := _purchasing
		_purchasing = ""
		listener._backend_purchase_failed(stuck, "unknown_state")


func _fail(product_id: String, code: int, debug_message: String) -> void:
	var message := debug_message if not debug_message.is_empty() else "billing_error_%d" % code
	if code == RESPONSE_USER_CANCELED:
		message = "canceled"
	elif code == RESPONSE_ITEM_ALREADY_OWNED:
		message = "already_owned"
		_query_owned()   # it is owned but this install does not know: restore it
	listener._backend_purchase_failed(product_id, message)


func _on_consume_response(response: Dictionary) -> void:
	_on_finished(response, false)


func _on_acknowledge_response(response: Dictionary) -> void:
	_on_finished(response, true)


func _on_finished(response: Dictionary, acknowledge: bool) -> void:
	var token := str(response.get("token", ""))
	_finishing.erase(token)
	var code := int(response.get("response_code", -1))
	if code == RESPONSE_OK:
		if acknowledge:
			_acknowledged[token] = true
	elif code != RESPONSE_ITEM_NOT_OWNED:
		# Unacknowledged purchases are refunded after 3 days: retry via the owned-purchases query,
		# which re-delivers the purchase (the grant is de-duplicated by token) and finishes again.
		push_warning("IapPlayBilling: %s failed (%d): %s" % [
			"acknowledge" if acknowledge else "consume", code, response.get("debug_message", "")])
		_schedule_query_retry()
