extends Node
## IAP autoload: store products, purchases and restore. All grants go through _grant().
##
## Backend contract (what a real adapter such as services/iap_play_billing.gd must implement):
##   initialize(listener: Object) -> void   # connect to the store; keep listener for callbacks
##   query_products(ids: Array) -> void     # fetch localized titles/prices
##   purchase(product_id: String) -> void   # launch the store purchase flow
##   restore_purchases() -> void            # query owned purchases (incl. unconsumed consumables)
##   finish_purchase(product_id: String, token: String, consumable: bool) -> void
##                                          # consume (consumable) or acknowledge (non-consumable)
## The backend reports back by calling these listener methods on the main thread:
##   _backend_availability(available: bool)
##   _backend_products(details: Dictionary) # id -> {"price": String, "title": String}
##   _backend_purchase_succeeded(product_id: String, token: String)
##   _backend_purchase_failed(product_id: String, message: String)  # "cancelled" or store text
##   _backend_restored(purchases: Array)    # [{"product_id": String, "token": String}, ...]
## Failure messages emitted by IAP itself: "unavailable", "unknown_product", "already_owned", "busy".

signal products_updated()
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, message: String)
signal availability_changed(available: bool)

## Fallback prices/titles are placeholders only; real localized values come from the store.
const PRODUCTS := {
	"remove_ads": {"type": "non_consumable", "hints": 5, "removes_ads": true,
		"fallback_price_try": "₺49,99", "fallback_title": "Remove Ads"},
	"hints_10": {"type": "consumable", "hints": 10, "removes_ads": false,
		"fallback_price_try": "₺19,99", "fallback_title": "10 Hints"},
	"hints_30": {"type": "consumable", "hints": 30, "removes_ads": false,
		"fallback_price_try": "₺44,99", "fallback_title": "30 Hints"},
	"supporter_pack": {"type": "non_consumable", "hints": 40, "removes_ads": true,
		"fallback_price_try": "₺99,99", "fallback_title": "Supporter Pack"},
}

## Platform singleton the Play Billing plugin registers; fill in with the real adapter.
const BILLING_SINGLETON := ""

## Active backend (see contract above). Never null after _ready().
var backend: Object
var _available := false
var _details := {}
var _pending := ""


func _ready() -> void:
	backend = _make_native_backend()
	if backend == null:
		backend = MockBillingBackend.new() if OS.is_debug_build() else NoBillingBackend.new()
	backend.initialize(self)


func _make_native_backend() -> Object:
	# TODO(billing adapter): when the Google Play Billing plugin is added, load it here, e.g.
	#   if BILLING_SINGLETON != "" and Engine.has_singleton(BILLING_SINGLETON):
	#       return load("res://services/iap_play_billing.gd").new()
	# The adapter wraps the singleton and implements the backend contract at the top of this file.
	return null


func _economy() -> Node:
	return get_node_or_null("/root/Economy")


func is_available() -> bool:
	return _available


## Store-localized price if known, else the placeholder.
func get_price(id: String) -> String:
	var price := str(_details.get(id, {}).get("price", ""))
	return price if not price.is_empty() else str(PRODUCTS.get(id, {}).get("fallback_price_try", ""))


func get_title(id: String) -> String:
	var title := str(_details.get(id, {}).get("title", ""))
	return title if not title.is_empty() else str(PRODUCTS.get(id, {}).get("fallback_title", id))


func owns(id: String) -> bool:
	var economy := _economy()
	return economy != null and economy.owns(id)


func purchase(id: String) -> void:
	if not PRODUCTS.has(id):
		purchase_failed.emit(id, "unknown_product")
	elif not _available:
		purchase_failed.emit(id, "unavailable")
	elif PRODUCTS[id].type == "non_consumable" and owns(id):
		purchase_failed.emit(id, "already_owned")
	elif not _pending.is_empty():
		purchase_failed.emit(id, "busy")
	else:
		_pending = id
		backend.purchase(id)


func restore_purchases() -> void:
	if _available:
		backend.restore_purchases()


## Single grant path. Returns true if anything new was granted for this token.
## A seen token never re-grants hints, but non-consumable ownership is always (re)applied.
func _grant(product_id: String, token: String) -> bool:
	var product: Dictionary = PRODUCTS.get(product_id, {})
	var economy := _economy()
	if product.is_empty() or economy == null:
		return false
	if product.type == "non_consumable":
		economy.own(product_id)
		if product.removes_ads:
			economy.set_ads_removed(true)
	if token.is_empty() or economy.token_seen(token):
		return false
	economy.mark_token(token)
	economy.add_hints(int(product.hints))
	return true


func _backend_availability(available: bool) -> void:
	if available == _available:
		return
	_available = available
	availability_changed.emit(available)
	if available:
		backend.query_products(PRODUCTS.keys())


func _backend_products(details: Dictionary) -> void:
	for id in details:
		if PRODUCTS.has(id) and details[id] is Dictionary:
			_details[id] = details[id]
	products_updated.emit()


func _backend_purchase_succeeded(product_id: String, token: String) -> void:
	if _pending == product_id:
		_pending = ""
	if not PRODUCTS.has(product_id):
		return
	var granted := _grant(product_id, token)
	backend.finish_purchase(product_id, token, PRODUCTS[product_id].type == "consumable")
	if granted:
		purchase_completed.emit(product_id)


func _backend_purchase_failed(product_id: String, message: String) -> void:
	if _pending == product_id:
		_pending = ""
	purchase_failed.emit(product_id, message)


func _backend_restored(purchases: Array) -> void:
	for entry in purchases:
		if entry is Dictionary and PRODUCTS.has(entry.get("product_id", "")):
			var id: String = entry.product_id
			var token := str(entry.get("token", ""))
			_grant(id, token)
			backend.finish_purchase(id, token, PRODUCTS[id].type == "consumable")
	products_updated.emit()


## Debug-build stand-in: available; purchases succeed on the next idle frame.
class MockBillingBackend:
	extends RefCounted
	## Next purchase fails with "mock_failure".
	var mock_fail_next := false
	var listener: Object
	## Simulated store account: non-consumable id -> token (survives Economy resets).
	var store_owned := {}
	var _serial := 0

	func initialize(target: Object) -> void:
		listener = target
		listener._backend_availability(true)

	func query_products(_ids: Array) -> void:
		listener._backend_products.call_deferred({})

	func purchase(product_id: String) -> void:
		if mock_fail_next:
			mock_fail_next = false
			listener._backend_purchase_failed.call_deferred(product_id, "mock_failure")
			return
		_serial += 1
		var token := "mock-%s-%d-%d" % [product_id, Time.get_ticks_usec(), _serial]
		if listener.PRODUCTS[product_id].type == "non_consumable":
			store_owned[product_id] = token
		listener._backend_purchase_succeeded.call_deferred(product_id, token)

	func restore_purchases() -> void:
		var owned := []
		for id in store_owned:
			owned.append({"product_id": id, "token": store_owned[id]})
		listener._backend_restored.call_deferred(owned)

	func finish_purchase(_product_id: String, _token: String, _consumable: bool) -> void:
		pass


## Release build without a plugin: unavailable, so the UI hides the shop.
class NoBillingBackend:
	extends RefCounted

	func initialize(_target: Object) -> void:
		pass

	func query_products(_ids: Array) -> void:
		pass

	func purchase(_product_id: String) -> void:
		pass

	func restore_purchases() -> void:
		pass

	func finish_purchase(_product_id: String, _token: String, _consumable: bool) -> void:
		pass
