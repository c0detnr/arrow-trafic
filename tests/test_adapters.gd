extends SceneTree
## Plugin adapters (AdMob, Play Billing) against fakes that mimic the plugin wrappers.
## Run: XDG_DATA_HOME=$(mktemp -d) godot --headless --script tests/test_adapters.gd

const TEST_SAVE := "user://test_adapters_economy.json"
const AdsConfig := preload("res://services/ads_config.gd")

var failures := 0
var timers: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	# Godot 4.7 adds project autoloads in --script mode; add them by hand if a version does not.
	for entry in [["Economy", "res://services/economy.gd"], ["Ads", "res://services/ads.gd"],
			["IAP", "res://services/iap.gd"]]:
		if root.get_node_or_null(entry[0]) == null:
			var node: Node = load(entry[1]).new()
			node.name = entry[0]
			root.add_child(node)
	var economy: Node = root.get_node("Economy")
	economy.save_path = TEST_SAVE
	economy.reset_for_tests()
	call_deferred("run")


func frames(n := 2) -> void:
	for i in n:
		await process_frame


## Fake for the adapters' `schedule` seam: timers fire only when the test says so.
func fake_schedule(seconds: float, callback: Callable) -> void:
	timers.append([seconds, callback])


func fire_timers() -> Array:
	var fired := timers.map(func(t: Array) -> float: return t[0])
	var due := timers
	timers = []
	for t in due:
		t[1].call()
	return fired


func run() -> void:
	test_without_plugin()
	test_ads_config()
	test_admob()
	test_admob_through_ads()
	test_admob_consent_gating()
	test_admob_regressions()
	test_release_config()
	await test_billing()
	root.get_node("Economy").reset_for_tests()
	print("test_adapters: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)


# --- No plugin (desktop / plugin not installed) ---

func test_without_plugin() -> void:
	for path in ["res://services/ads_admob.gd", "res://services/iap_play_billing.gd",
			"res://services/ads_config.gd"]:
		var script: Script = load(path)
		check(script != null and script.can_instantiate(), "%s loads without the plugin" % path)
	check(not load("res://services/ads_admob.gd").is_plugin_available(), "no AdMob plugin on desktop")
	check(not load("res://services/iap_play_billing.gd").is_plugin_available(), "no Billing plugin on desktop")
	var ads_node: Node = load("res://services/ads.gd").new()
	var iap_node: Node = load("res://services/iap.gd").new()
	check(ads_node._make_native_backend() == null, "ads: no native backend on desktop")
	check(iap_node._make_native_backend() == null, "iap: no native backend on desktop")
	ads_node.free()
	iap_node.free()
	check(root.get_node("Ads").backend.get_script() != load("res://services/ads_admob.gd"),
		"Ads autoload fell back to a non-AdMob backend")
	# An adapter created anyway stays inert instead of crashing.
	var admob: RefCounted = load("res://services/ads_admob.gd").new()
	var listener := FakeAdsListener.new()
	admob.initialize(listener)
	check(admob.api.is_empty() and not admob.is_rewarded_loaded() and not admob.can_show_privacy_options(),
		"AdMob adapter inert without plugin scripts")


func test_ads_config() -> void:
	check(AdsConfig.rewarded_unit_id(true) == "ca-app-pub-3940256099942544/5224354917", "debug rewarded = test id")
	check(AdsConfig.interstitial_unit_id(true) == "ca-app-pub-3940256099942544/1033173712", "debug interstitial = test id")
	if AdsConfig.REAL_REWARDED_ID.is_empty():
		check(AdsConfig.rewarded_unit_id(false) == AdsConfig.TEST_REWARDED_ID, "release falls back to test id while real is empty")
	else:
		check(AdsConfig.rewarded_unit_id(false) == AdsConfig.REAL_REWARDED_ID, "release uses real id")


# --- AdMob ---

func make_admob(fakes: AdMobFakes) -> RefCounted:
	var admob: RefCounted = load("res://services/ads_admob.gd").new()
	admob.api = fakes.api()
	admob.schedule = fake_schedule
	admob.debug_build = true
	return admob


func test_admob() -> void:
	timers.clear()
	var fakes := AdMobFakes.new()
	var listener := FakeAdsListener.new()
	var admob := make_admob(fakes)

	# Consent first: form required → shown → dismissed → SDK init → preload.
	fakes.consent.form_available = true
	fakes.consent.status = 2  # REQUIRED
	admob.initialize(listener)
	check(fakes.consent.update_calls == 1 and fakes.mobile_ads.init_listener == null, "consent update before SDK init")
	check(fakes.consent.last_params.tag_for_under_age_of_consent == false, "consent params")
	fakes.consent.on_success.call()
	check(fakes.ump.load_success.is_valid(), "consent form loaded when required")
	var form := FakeConsentForm.new()
	fakes.ump.load_success.call(form)
	check(form.on_dismissed.is_valid() and fakes.mobile_ads.init_listener == null, "form shown, SDK waits")
	admob.load_rewarded()
	check(fakes.loads.is_empty(), "no loads before SDK init")
	fakes.consent.status = 3  # OBTAINED once the user answered the form
	form.on_dismissed.call(null)
	check(fakes.mobile_ads.init_listener != null, "MobileAds.initialize after consent")
	check(fakes.mobile_ads.request_config != null and fakes.mobile_ads.request_config.max_ad_content_rating == AdsConfig.MAX_AD_CONTENT_RATING,
		"request configuration applied")
	fakes.mobile_ads.init_listener.on_initialization_complete.call(null)
	check(fakes.loads.size() == 2, "preloads one rewarded + one interstitial")
	check(fakes.loads[0].kind == "rewarded" and fakes.loads[0].unit == AdsConfig.TEST_REWARDED_ID, "rewarded uses test id in debug")
	check(fakes.loads[1].kind == "interstitial" and fakes.loads[1].unit == AdsConfig.TEST_INTERSTITIAL_ID, "interstitial uses test id in debug")
	timers.clear()  # drop the init fallback timer (it is a no-op once ready)

	# Rewarded: load → show → reward → dismissed → closed.
	var ad1 := FakeAd.new()
	fakes.loads[0].callback.on_ad_loaded.call(ad1)
	check(listener.events == ["loaded:true"] and admob.is_rewarded_loaded(), "rewarded loaded reported")
	admob.show_rewarded("hint")
	check(ad1.shown == 1 and not admob.is_rewarded_loaded(), "rewarded shown once, slot emptied")
	ad1.reward_listener.on_user_earned_reward.call(Bag.new())
	ad1.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	check(ad1.destroyed, "rewarded destroyed after dismiss")
	check(listener.events == ["loaded:true", "earned"], "closed waits for the reward grace period")
	fire_timers()
	check(listener.events == ["loaded:true", "earned", "closed"], "reward then closed")

	# Dismiss arriving before the reward still pays out within the grace period.
	listener.events.clear()
	admob.load_rewarded()
	var ad_late := FakeAd.new()
	fakes.loads.back().callback.on_ad_loaded.call(ad_late)
	admob.show_rewarded("hint")
	ad_late.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	ad_late.reward_listener.on_user_earned_reward.call(Bag.new())
	fire_timers()
	check(listener.events == ["loaded:true", "earned", "closed"], "late reward still counted")

	# Show failure → closed, no reward, ad destroyed.
	listener.events.clear()
	admob.load_rewarded()
	var ad2 := FakeAd.new()
	fakes.loads.back().callback.on_ad_loaded.call(ad2)
	admob.show_rewarded("revive")
	ad2.full_screen_content_callback.on_ad_failed_to_show_full_screen_content.call(Bag.new())
	fire_timers()
	check(listener.events == ["loaded:true", "closed"] and ad2.destroyed, "show failure still closes")
	# A second dismiss for the same ad is ignored.
	ad2.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	fire_timers()
	check(listener.events.count("closed") == 1, "closed only once per show")

	# Nothing loaded → closed anyway.
	listener.events.clear()
	admob.show_rewarded("hint")
	fire_timers()
	check(listener.events == ["closed"], "show without ad closes")

	# Load failures retry with growing backoff.
	listener.events.clear()
	var before := fakes.loads.size()
	admob.load_rewarded()
	fakes.loads.back().callback.on_ad_failed_to_load.call(Bag.new())
	check(listener.events == ["loaded:false"], "load failure reported")
	admob.load_rewarded()
	check(fakes.loads.size() == before + 1, "no reload while a retry is pending")
	check(fire_timers() == [10.0] and fakes.loads.size() == before + 2, "retry after 10s")
	fakes.loads.back().callback.on_ad_failed_to_load.call(Bag.new())
	check(fire_timers() == [30.0] and fakes.loads.size() == before + 3, "then 30s")
	fakes.loads.back().callback.on_ad_loaded.call(FakeAd.new())
	check(admob.is_rewarded_loaded(), "retry success")

	# Expired ads are dropped and reloaded.
	var now := [0.0]
	admob.clock = func() -> float: return now[0]
	admob._rewarded_loaded_at = 0.0
	now[0] = 56.0 * 60.0
	var loads_before := fakes.loads.size()
	check(not admob.is_rewarded_loaded() and fakes.loads.size() == loads_before + 1, "expired rewarded reloaded")

	# Interstitial: load → show → dismissed → closed + destroyed.
	var inter := FakeAd.new()
	fakes.loads[1].callback.on_ad_loaded.call(inter)
	check(admob.is_interstitial_loaded(), "interstitial loaded")
	listener.events.clear()
	admob.show_interstitial()
	check(inter.shown == 1, "interstitial shown")
	inter.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	check(listener.events == ["interstitial_closed"] and inter.destroyed, "interstitial closed + destroyed")
	listener.events.clear()
	admob.show_interstitial()
	fire_timers()
	check(listener.events == ["interstitial_closed"], "interstitial show without ad closes")

	# Privacy options.
	fakes.consent.privacy_status = 1
	check(not admob.can_show_privacy_options(), "privacy options not required")
	fakes.consent.privacy_status = 2
	check(admob.can_show_privacy_options(), "privacy options required")
	admob.show_privacy_options()
	check(fakes.ump.privacy_shown == 1, "privacy options form shown")

	# Consent not required → straight to SDK init; consent failure also starts the SDK.
	var fakes2 := AdMobFakes.new()
	var admob2 := make_admob(fakes2)
	admob2.initialize(FakeAdsListener.new())
	fakes2.consent.on_success.call()
	check(not fakes2.ump.load_success.is_valid() and fakes2.mobile_ads.init_listener != null, "no form when not required")
	var fakes3 := AdMobFakes.new()
	var admob3 := make_admob(fakes3)
	admob3.initialize(FakeAdsListener.new())
	fakes3.consent.on_failure.call(Bag.new())
	check(fakes3.mobile_ads.init_listener != null, "consent refresh failure with earlier NOT_REQUIRED status starts SDK")
	timers.clear()


## The adapter driven by the real Ads node (not in the tree, so its _ready does not run).
func test_admob_through_ads() -> void:
	timers.clear()
	var fakes := AdMobFakes.new()
	var admob := make_admob(fakes)
	var ads: Node = load("res://services/ads.gd").new()
	ads.backend = admob
	ads._ads_supported = true
	admob.initialize(ads)
	fakes.consent.on_success.call()
	fakes.mobile_ads.init_listener.on_initialization_complete.call(null)
	timers.clear()
	var ad := FakeAd.new()
	fakes.loads[0].callback.on_ad_loaded.call(ad)
	check(ads.is_rewarded_ready(), "Ads sees rewarded ready")
	var got := []
	ads.rewarded_finished.connect(func(placement: String, rewarded: bool) -> void: got.append([placement, rewarded]))
	var rewards := [0]
	check(ads.show_rewarded("hint", func() -> void: rewards[0] += 1), "Ads.show_rewarded starts")
	ad.reward_listener.on_user_earned_reward.call(Bag.new())
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	fire_timers()
	check(rewards[0] == 1 and got == [["hint", true]], "Ads: reward granted once, finished(hint, true)")
	check(fakes.loads.size() == 3 and fakes.loads[2].kind == "rewarded", "Ads asked for the next rewarded")
	ads.free()


## A started adapter (consent not required → SDK initialized), timers cleared.
func started_admob(fakes: AdMobFakes, listener: Object) -> RefCounted:
	var admob := make_admob(fakes)
	admob.initialize(listener)
	fakes.consent.on_success.call()
	fakes.mobile_ads.init_listener.on_initialization_complete.call(null)
	timers.clear()
	return admob


## Regression (admob_consent_gating): no SDK / ads without usable consent; retried later.
func test_admob_consent_gating() -> void:
	timers.clear()
	var fakes := AdMobFakes.new()
	var listener := FakeAdsListener.new()
	var admob := make_admob(fakes)
	fakes.consent.form_available = true
	fakes.consent.status = 2  # REQUIRED
	admob.initialize(listener)
	fakes.consent.on_success.call()
	var form := FakeConsentForm.new()
	fakes.ump.load_success.call(form)
	form.on_dismissed.call(null)   # closed without an answer: still REQUIRED
	check(fakes.mobile_ads.init_listener == null, "admob_consent_gating: REQUIRED after form -> SDK not started")
	admob.load_rewarded()
	admob.load_interstitial()
	check(fakes.loads.is_empty() and not admob.is_rewarded_loaded(), "admob_consent_gating: no ads loaded, rewarded unavailable")
	check(fire_timers() == [10.0] and fakes.consent.update_calls == 2, "admob_consent_gating: consent retried after backoff")
	fakes.consent.status = 0  # UNKNOWN: refresh failed on a first launch
	fakes.consent.on_failure.call(Bag.new())
	check(fakes.mobile_ads.init_listener == null, "admob_consent_gating: update failure with UNKNOWN -> SDK not started")
	check(timers.map(func(t: Array) -> float: return t[0]) == [30.0], "admob_consent_gating: backoff grows")
	timers.clear()
	admob.on_app_resumed()
	check(fakes.consent.update_calls == 3, "admob_consent_gating: retried on app resume")
	fakes.consent.status = 3  # OBTAINED
	fakes.consent.on_success.call()
	check(fakes.mobile_ads.init_listener != null, "admob_consent_gating: OBTAINED -> SDK starts")
	fakes.mobile_ads.init_listener.on_initialization_complete.call(null)
	check(fakes.loads.size() == 2, "admob_consent_gating: ads load once consent is usable")
	admob.on_app_resumed()
	check(fakes.consent.update_calls == 3, "admob_consent_gating: no consent refresh on resume once started")
	timers.clear()

	# Ads forwards app resume to the backend.
	var ads: Node = load("res://services/ads.gd").new()
	var fakes2 := AdMobFakes.new()
	fakes2.consent.status = 0
	var admob2 := make_admob(fakes2)
	ads.backend = admob2
	admob2.initialize(ads)
	fakes2.consent.on_failure.call(Bag.new())
	ads.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(fakes2.consent.update_calls == 2 and not ads.is_rewarded_ready(), "admob_consent_gating: Ads resume -> consent retry")
	ads.free()
	timers.clear()


func test_admob_regressions() -> void:
	timers.clear()
	var fakes := AdMobFakes.new()
	var listener := FakeAdsListener.new()
	var admob := started_admob(fakes, listener)
	var now := [0.0]
	admob.clock = func() -> float: return now[0]

	# admob_expired_released: expired ads are destroyed AND their callbacks released.
	var old_rewarded := FakeAd.new()
	fakes.loads[0].callback.on_ad_loaded.call(old_rewarded)
	var old_inter := FakeAd.new()
	fakes.loads[1].callback.on_ad_loaded.call(old_inter)
	now[0] = 56.0 * 60.0
	check(not admob.is_rewarded_loaded() and not admob.is_interstitial_loaded(), "admob_expired_released: expired ads dropped")
	for ad in [old_rewarded, old_inter]:
		var cb: Object = ad.full_screen_content_callback
		check(ad.destroyed and cb.on_ad_dismissed_full_screen_content.get_method() == "_ignore"
			and cb.on_ad_failed_to_show_full_screen_content.get_method() == "_ignore",
			"admob_expired_released: callbacks cleared")
	check(fakes.loads.size() == 4, "admob_expired_released: both reloaded")

	# admob_show_watchdog: no dismiss / show failure → closed after 60 s, reward only if earned.
	listener.events.clear()
	var ad := FakeAd.new()
	fakes.loads[2].callback.on_ad_loaded.call(ad)
	listener.events.clear()
	admob.show_rewarded("hint")
	ad.reward_listener.on_user_earned_reward.call(Bag.new())
	check(fire_timers() == [admob.SHOW_WATCHDOG_SEC], "admob_show_watchdog: watchdog armed on show")
	check(ad.destroyed, "admob_show_watchdog: stuck rewarded destroyed")
	fire_timers()   # grace period
	check(listener.events == ["earned", "closed"], "admob_show_watchdog: earned reward kept, closed once: %s" % [listener.events])
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	fire_timers()
	check(listener.events.count("closed") == 1, "admob_show_watchdog: late dismiss ignored")

	listener.events.clear()
	admob.load_rewarded()
	var ad2 := FakeAd.new()
	fakes.loads.back().callback.on_ad_loaded.call(ad2)
	listener.events.clear()
	admob.show_rewarded("revive")
	fire_timers()
	fire_timers()
	check(listener.events == ["closed"], "admob_show_watchdog: no reward when not earned")
	check(admob._showing_rewarded == null, "admob_show_watchdog: rewarded slot free again")

	# Watchdog after a normal dismiss does nothing.
	admob.load_rewarded()
	var ad3 := FakeAd.new()
	fakes.loads.back().callback.on_ad_loaded.call(ad3)
	listener.events.clear()
	admob.show_rewarded("hint")
	ad3.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	fire_timers()
	fire_timers()
	check(listener.events == ["closed"], "admob_show_watchdog: normal dismiss closes once")

	var inter := FakeAd.new()
	fakes.loads[3].callback.on_ad_loaded.call(inter)
	listener.events.clear()
	admob.show_interstitial()
	fire_timers()
	check(listener.events == ["interstitial_closed"] and inter.destroyed and admob._showing_interstitial == null,
		"admob_show_watchdog: stuck interstitial closed")
	inter.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	check(listener.events.count("interstitial_closed") == 1, "admob_show_watchdog: late interstitial dismiss ignored")

	# admob_no_interstitial_when_removed: the listener says no → nothing loaded, incl. at SDK start.
	var fakes2 := AdMobFakes.new()
	var listener2 := FakeAdsListener.new()
	listener2.wants_interstitial = false
	var admob2 := started_admob(fakes2, listener2)
	check(fakes2.loads.size() == 1 and fakes2.loads[0].kind == "rewarded", "admob_no_interstitial_when_removed: only rewarded preloaded")
	admob2.load_interstitial()
	check(fakes2.loads.size() == 1, "admob_no_interstitial_when_removed: load_interstitial is a no-op")
	listener2.wants_interstitial = true
	admob2.load_interstitial()
	check(fakes2.loads.size() == 2 and fakes2.loads[1].kind == "interstitial", "admob_no_interstitial_when_removed: loads again when wanted")
	timers.clear()


## Regression (release_config_check): release misconfiguration is detected and reported once.
func test_release_config() -> void:
	var expected := int(AdsConfig.REAL_REWARDED_ID.is_empty()) + int(AdsConfig.REAL_INTERSTITIAL_ID.is_empty())
	check(AdsConfig.release_config_problems("ca-app-pub-1234567890123456~1234567890").size() == expected,
		"release_config_check: real app id → only unit-id problems")
	check(AdsConfig.release_config_problems(AdsConfig.TEST_APP_ID).size() == expected + 1, "release_config_check: test app id flagged")
	check(AdsConfig.release_config_problems("").size() == expected + 1, "release_config_check: empty app id flagged")
	var project_app_id := str(ProjectSettings.get_setting(AdsConfig.APP_ID_SETTING, ""))
	AdsConfig._release_problems_reported = true   # as after the first report: never twice
	check(not AdsConfig.report_release_problems(project_app_id), "release_config_check: reported at most once")
	check(AdsConfig.rewarded_unit_id(false) != "" and AdsConfig.interstitial_unit_id(false) != "", "release_config_check: ids still usable")


# --- Play Billing ---

func test_billing() -> void:
	timers.clear()
	var economy: Node = root.get_node("Economy")
	var iap: Node = root.get_node("IAP")
	economy.reset_for_tests()
	var client := FakeBillingClient.new()
	var billing: RefCounted = load("res://services/iap_play_billing.gd").new()
	billing.make_client = func() -> Object: return client
	billing.schedule = fake_schedule
	# Swap the debug mock out for the adapter.
	iap.backend = billing
	iap._available = false
	iap._details = {}
	iap._pending = ""
	var completed := []
	var failed := []
	iap.purchase_completed.connect(func(id: String) -> void: completed.append(id))
	iap.purchase_failed.connect(func(id: String, message: String) -> void: failed.append([id, message]))

	billing.initialize(iap)
	check(client.calls.count("start_connection") == 1, "connects on initialize")
	check(billing.consumables == {"remove_ads": false, "hints_10": true, "hints_30": true, "supporter_pack": false},
		"product types from IAP.PRODUCTS")

	# Connection error → unavailable, reconnect with backoff.
	client.connect_error.emit(3, "billing unavailable")
	await frames()
	check(not iap.is_available() and fire_timers() == [2.0], "connect error schedules reconnect")
	check(client.calls.count("start_connection") == 2, "reconnected")

	# Connected → available, product details + owned purchases queried.
	client.connected.emit()
	await frames()
	check(iap.is_available(), "available after connect")
	check(client.detail_queries.size() == 1 and Array(client.detail_queries[0][0]) == iap.PRODUCTS.keys()
		and client.detail_queries[0][1] == 0, "queried INAPP details for all products")
	check(client.calls.count("query_purchases") == 1, "owned purchases queried on startup")
	client.query_purchases_response.emit({"response_code": 0, "debug_message": "", "purchases": []})
	client.query_product_details_response.emit({"response_code": 0, "debug_message": "",
		"product_details": [{"product_id": "hints_10", "title": "10 Hints (Arrow Traffic)", "name": "10 Hints",
			"one_time_purchase_offer_details_list": [
				{"formatted_price": "₺9,99", "offer_id": "launch-sale"},
				{"formatted_price": "₺19,99", "offer_id": null}]}],
		"unfetched_products": []})
	await frames()
	check(iap.get_price("hints_10") == "₺19,99" and iap.get_title("hints_10") == "10 Hints", "store price/title from base offer")

	# Consumable purchase → granted → consumed.
	var hints: int = economy.get_hints()
	iap.purchase("hints_10")
	check(client.purchased == ["hints_10"], "purchase flow launched")
	client.on_purchase_updated.emit(purchase_update([purchase_dict("hints_10", "tok-h10", 1, false)]))
	await frames()
	check(economy.get_hints() == hints + 10 and completed == ["hints_10"], "consumable granted")
	check(client.consumed == ["tok-h10"] and client.acknowledged.is_empty(), "consumable consumed, not acknowledged")
	client.consume_purchase_response.emit({"response_code": 0, "debug_message": "", "token": "tok-h10"})
	await frames()

	# Non-consumable purchase → owned + ads removed → acknowledged (not consumed).
	hints = economy.get_hints()
	iap.purchase("remove_ads")
	client.on_purchase_updated.emit(purchase_update([purchase_dict("remove_ads", "tok-ra", 1, false)]))
	await frames()
	check(iap.owns("remove_ads") and economy.is_ads_removed() and economy.get_hints() == hints + 5, "remove_ads granted")
	check(client.acknowledged == ["tok-ra"] and client.consumed == ["tok-h10"], "non-consumable acknowledged")
	client.acknowledge_purchase_response.emit({"response_code": 0, "debug_message": "", "token": "tok-ra"})
	await frames()

	# User cancels → failed("canceled"), IAP no longer busy.
	iap.purchase("hints_30")
	client.on_purchase_updated.emit({"response_code": 1, "debug_message": "User canceled"})
	await frames()
	check(failed.back() == ["hints_30", "canceled"] and iap._pending.is_empty(), "USER_CANCELED → canceled")

	# Pending payment → not granted until PURCHASED.
	hints = economy.get_hints()
	iap.purchase("hints_30")
	client.on_purchase_updated.emit(purchase_update([purchase_dict("hints_30", "tok-h30", 2, false)]))
	await frames()
	check(failed.back() == ["hints_30", "pending"] and economy.get_hints() == hints, "pending is not granted")
	check(billing._purchasing.is_empty() and iap._pending.is_empty(), "billing_pending_clears_busy")
	check(not client.consumed.has("tok-h30"), "pending is not consumed")
	client.on_purchase_updated.emit(purchase_update([purchase_dict("hints_30", "tok-h30", 1, false)]))
	await frames()
	check(economy.get_hints() == hints + 30 and client.consumed.has("tok-h30"), "pending → purchased grants + consumes")

	# Regression (billing_unknown_state_not_stuck): an OK update that does not settle our purchase
	# (UNSPECIFIED state, another product only, or empty) reports failure instead of staying busy.
	hints = economy.get_hints()
	for update in [[purchase_dict("hints_10", "tok-unspec", 0, false)], [purchase_dict("remove_ads", "tok-ra", 1, true)], []]:
		iap.purchase("hints_10")
		client.on_purchase_updated.emit(purchase_update(update))
		await frames()
		check(failed.back() == ["hints_10", "unknown_state"] and iap._pending.is_empty() and billing._purchasing.is_empty(),
			"billing_unknown_state_not_stuck: %s" % [update])
	check(economy.get_hints() == hints and not client.consumed.has("tok-unspec"), "billing_unknown_state_not_stuck: nothing granted")
	iap.purchase("hints_10")
	check(failed.back() != ["hints_10", "busy"], "billing_unknown_state_not_stuck: next purchase not busy")
	client.on_purchase_updated.emit({"response_code": 1, "debug_message": "User canceled"})
	await frames()

	# Regression (billing_resume_restores): app resume re-queries owned purchases.
	var resume_queries: int = client.calls.count("query_purchases")
	iap.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(client.calls.count("query_purchases") == resume_queries + 1, "billing_resume_restores")
	client.query_purchases_response.emit({"response_code": 0, "debug_message": "", "purchases": []})
	await frames()

	# Launch failure: already owned → failed + owned purchases re-queried.
	var queries: int = client.calls.count("query_purchases")
	client.next_purchase_result = {"response_code": 7, "debug_message": "Item already owned"}
	iap.purchase("supporter_pack")
	check(failed.back() == ["supporter_pack", "already_owned"], "ITEM_ALREADY_OWNED → already_owned")
	check(client.calls.count("query_purchases") == queries + 1, "already owned triggers restore query")
	client.next_purchase_result = {"response_code": 0, "debug_message": ""}

	# Reinstall: restore re-applies non-consumables; unfinished purchases go through success path.
	economy.reset_for_tests()
	completed.clear()
	var acks: int = client.acknowledged.size()
	iap.restore_purchases()
	check(client.calls.count("query_purchases") == queries + 2, "restore queries purchases")
	client.query_purchases_response.emit({"response_code": 0, "debug_message": "", "purchases": [
		purchase_dict("remove_ads", "tok-ra", 1, true),
		purchase_dict("hints_30", "tok-h30-old", 1, false),
		purchase_dict("supporter_pack", "tok-sp", 1, false),
		purchase_dict("hints_10", "tok-pend", 2, false)]})
	await frames()
	check(iap.owns("remove_ads") and economy.is_ads_removed(), "restore delivers owned remove_ads")
	check(iap.owns("supporter_pack"), "unacknowledged supporter_pack granted on restore")
	check(client.acknowledged.size() == acks + 1 and client.acknowledged.back() == "tok-sp",
		"only the unacknowledged purchase is acknowledged")
	check(client.consumed.has("tok-h30-old"), "unconsumed consumable consumed after restore")
	check(completed.has("hints_30") and completed.has("supporter_pack"), "unfinished purchases reported as completed")
	check(not client.consumed.has("tok-pend"), "pending purchase ignored by restore")
	# 3 (start) + 5 (remove_ads) + 30 (hints_30) + 40 (supporter_pack)
	check(economy.get_hints() == 78, "restore grants each token once (got %d)" % economy.get_hints())
	# Same query again (e.g. next startup) grants nothing twice.
	client.query_purchases_response.emit({"response_code": 0, "debug_message": "", "purchases": [
		purchase_dict("remove_ads", "tok-ra", 1, true)]})
	await frames()
	check(economy.get_hints() == 78, "repeat restore grants nothing")

	# Failed acknowledge → retried through a later purchases query.
	timers.clear()
	client.acknowledge_purchase_response.emit({"response_code": 6, "debug_message": "error", "token": "tok-sp"})
	await frames()
	queries = client.calls.count("query_purchases")
	check(fire_timers().size() == 1 and client.calls.count("query_purchases") == queries + 1, "failed ack retried")

	# Disconnect → unavailable, reconnect scheduled. A purchase in flight is released.
	timers.clear()
	iap.purchase("hints_10")
	client.disconnected.emit()
	await frames()
	check(failed.back() == ["hints_10", "unavailable"] and iap._pending.is_empty(), "billing_disconnect_clears_pending")
	var starts: int = client.calls.count("start_connection")
	check(not iap.is_available() and fire_timers().size() == 1, "disconnect schedules reconnect")
	check(client.calls.count("start_connection") == starts + 1, "reconnects after disconnect")
	client.connected.emit()
	await frames()
	check(iap.is_available() and client.detail_queries.size() == 2, "reconnect re-queries products")
	economy.reset_for_tests()


func purchase_dict(id: String, token: String, state: int, acknowledged: bool) -> Dictionary:
	return {"order_id": "GPA.%s" % token, "purchase_token": token, "purchase_state": state,
		"is_acknowledged": acknowledged, "product_ids": PackedStringArray([id]), "quantity": 1}


func purchase_update(purchases: Array) -> Dictionary:
	return {"response_code": 0, "debug_message": "", "purchases": purchases}


# --- Fakes mimicking the Poing AdMob wrappers ---

## Stand-in for every plugin data/callback class (only the fields the adapter touches).
class Bag:
	extends RefCounted
	var message := "fake error"
	var code := 3
	var tag_for_under_age_of_consent := true
	var consent_debug_settings: Object
	var debug_geography := 0
	var test_device_hashed_ids: Array[String] = []
	var max_ad_content_rating := ""
	var on_initialization_complete: Callable
	var on_ad_loaded: Callable
	var on_ad_failed_to_load: Callable
	var on_ad_dismissed_full_screen_content: Callable
	var on_ad_failed_to_show_full_screen_content: Callable
	var on_user_earned_reward: Callable


class FakeMobileAds:
	extends RefCounted
	var init_listener: Object
	var request_config: Object

	func initialize(listener: Object = null) -> void:
		init_listener = listener

	func set_request_configuration(config: Object) -> void:
		request_config = config


class FakeConsentInfo:
	extends RefCounted
	var form_available := false
	var status := 1
	var privacy_status := 0
	var update_calls := 0
	var last_params: Object
	var on_success: Callable
	var on_failure: Callable

	func update(params: Object, success: Callable, failure: Callable) -> void:
		update_calls += 1
		last_params = params
		on_success = success
		on_failure = failure

	func get_is_consent_form_available() -> bool:
		return form_available

	func get_consent_status() -> int:
		return status

	func get_privacy_options_requirement_status() -> int:
		return privacy_status


class FakeUMP:
	extends RefCounted
	var consent_information := FakeConsentInfo.new()
	var load_success: Callable
	var load_failure: Callable
	var privacy_shown := 0

	func load_consent_form(success: Callable, failure: Callable) -> void:
		load_success = success
		load_failure = failure

	func show_privacy_options_form(_on_dismissed: Callable) -> void:
		privacy_shown += 1


class FakeConsentForm:
	extends RefCounted
	var on_dismissed: Callable

	func show(dismissed: Callable) -> void:
		on_dismissed = dismissed


class FakeAd:
	extends RefCounted
	var full_screen_content_callback: Object
	var reward_listener: Object
	var shown := 0
	var destroyed := false

	func show(listener: Object = null) -> void:
		shown += 1
		reward_listener = listener

	func destroy() -> void:
		destroyed = true


class FakeLoader:
	extends RefCounted
	var kind := ""
	var unit := ""
	var callback: Object
	var sink: Array

	func _init(p_kind: String, p_sink: Array) -> void:
		kind = p_kind
		sink = p_sink

	func load(unit_id: String, _request: Object, load_callback: Object) -> void:
		unit = unit_id
		callback = load_callback
		sink.append(self)


class AdMobFakes:
	extends RefCounted
	var mobile_ads := FakeMobileAds.new()
	var ump := FakeUMP.new()
	var consent: FakeConsentInfo = ump.consent_information
	var loads: Array = []

	func api() -> Dictionary:
		var bag := func() -> Object: return Bag.new()
		return {
			"MobileAds": mobile_ads,
			"UserMessagingPlatform": ump,
			"RewardedAdLoader": func() -> Object: return FakeLoader.new("rewarded", loads),
			"InterstitialAdLoader": func() -> Object: return FakeLoader.new("interstitial", loads),
			"AdRequest": bag,
			"RequestConfiguration": bag,
			"RewardedAdLoadCallback": bag,
			"InterstitialAdLoadCallback": bag,
			"FullScreenContentCallback": bag,
			"OnUserEarnedRewardListener": bag,
			"OnInitializationCompleteListener": bag,
			"ConsentRequestParameters": bag,
			"ConsentDebugSettings": bag,
		}


class FakeAdsListener:
	extends RefCounted
	var events: Array = []
	var wants_interstitial := true

	func _backend_wants_interstitial() -> bool:
		return wants_interstitial

	func _backend_rewarded_loaded(ok: bool) -> void:
		events.append("loaded:%s" % ok)

	func _backend_reward_earned() -> void:
		events.append("earned")

	func _backend_rewarded_closed() -> void:
		events.append("closed")

	func _backend_interstitial_closed() -> void:
		events.append("interstitial_closed")


# --- Fake mimicking the Play Billing BillingClient wrapper (3.3.0 signals and methods) ---

class FakeBillingClient:
	extends RefCounted
	signal connected
	signal disconnected
	signal connect_error(response_code: int, debug_message: String)
	signal query_product_details_response(response: Dictionary)
	signal query_purchases_response(response: Dictionary)
	signal on_purchase_updated(response: Dictionary)
	signal consume_purchase_response(response: Dictionary)
	signal acknowledge_purchase_response(response: Dictionary)

	var calls: Array = []
	var detail_queries: Array = []
	var purchased: Array = []
	var consumed: Array = []
	var acknowledged: Array = []
	var next_purchase_result := {"response_code": 0, "debug_message": ""}

	func start_connection() -> void:
		calls.append("start_connection")

	func query_product_details(product_list: PackedStringArray, product_type: int) -> void:
		detail_queries.append([product_list, product_type])

	func query_purchases(product_type: int, _include_suspended_subs := false) -> void:
		assert(product_type == 0)
		calls.append("query_purchases")

	func purchase(product_id: String, _option := "", _offer := "", _personalized := false) -> Dictionary:
		purchased.append(product_id)
		return next_purchase_result

	func consume_purchase(token: String) -> void:
		consumed.append(token)

	func acknowledge_purchase(token: String) -> void:
		acknowledged.append(token)
