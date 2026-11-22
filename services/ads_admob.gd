extends RefCounted
## Ads backend for the Poing Studios AdMob plugin (godot-admob-plugin v5.1.0, Android).
## Implements the backend contract documented at the top of services/ads.gd.
##
## The plugin is OPTIONAL: this file never names a plugin class_name, so the game parses, runs
## and exports without it. Plugin classes are load()ed by path into `api` at runtime; tests
## replace `api` with fakes. ads.gd only creates this adapter when is_plugin_available().
##
## Flow: initialize() → UMP consent (form only when required) → MobileAds.initialize() only when
## consent is NOT_REQUIRED/OBTAINED (else retry with backoff / on app resume, no ads meanwhile) →
## preload one rewarded + one interstitial. Failed loads retry with backoff. Every ad object is
## single use and destroy()ed after it closes or fails to show.

const AdsConfig := preload("res://services/ads_config.gd")

## Engine singleton registered by the plugin's Android AAR (see its AndroidManifest.xml).
const SINGLETON := "PoingGodotAdMob"
const ADDON_SRC := "res://addons/admob/gdscript/src/"
## Plugin GDScript wrappers used here, relative to ADDON_SRC (paths from the v5.1.0 source).
const SCRIPTS := {
	"MobileAds": "api/MobileAds.gd",
	"RewardedAdLoader": "api/RewardedAdLoader.gd",
	"InterstitialAdLoader": "api/InterstitialAdLoader.gd",
	"AdRequest": "api/core/AdRequest.gd",
	"RequestConfiguration": "api/core/RequestConfiguration.gd",
	"RewardedAdLoadCallback": "api/listeners/RewardedAdLoadCallback.gd",
	"InterstitialAdLoadCallback": "api/listeners/InterstitialAdLoadCallback.gd",
	"FullScreenContentCallback": "api/listeners/FullScreenContentCallback.gd",
	"OnUserEarnedRewardListener": "api/listeners/OnUserEarnedRewardListener.gd",
	"OnInitializationCompleteListener": "api/listeners/OnInitializationCompleteListener.gd",
	"UserMessagingPlatform": "ump/api/UserMessagingPlatform.gd",
	"ConsentRequestParameters": "ump/core/ConsentRequestParameters.gd",
	"ConsentDebugSettings": "ump/core/ConsentDebugSettings.gd",
}

# Plugin enum values (ConsentInformation.gd / DebugGeography.gd, v5.1.0).
# ConsentStatus {UNKNOWN, NOT_REQUIRED, REQUIRED, OBTAINED} (ump/api/ConsentInformation.gd, v5.1.0)
const CONSENT_STATUS_NOT_REQUIRED := 1
const CONSENT_STATUS_REQUIRED := 2
const CONSENT_STATUS_OBTAINED := 3
const PRIVACY_OPTIONS_REQUIRED := 2         # PrivacyOptionsRequirementStatus {UNKNOWN, NOT_REQUIRED, REQUIRED}
const DEBUG_GEOGRAPHY_EEA := 1              # DebugGeography.Values {DISABLED, EEA, NOT_EEA}

## Seconds to wait before retrying the n-th consecutive failed load (last value repeats).
const RETRY_DELAYS := [10.0, 30.0, 60.0, 120.0, 300.0]
## If MobileAds never reports initialization complete, start loading anyway after this long.
const INIT_FALLBACK_SEC := 10.0
## Loaded ads expire after one hour on Google's side; drop and reload slightly before that.
const AD_MAX_AGE_SEC := 55.0 * 60.0
## The SDK reports "reward earned" before "dismissed", but both hop threads; give a late reward
## this long to arrive before telling Ads that the rewarded ad closed.
const REWARD_GRACE_SEC := 0.3
## If neither "dismissed" nor "failed to show" arrives this long after show(), treat the ad as
## closed so ads are not disabled for the rest of the session. Counts game time, which normally
## stands still while the ad's own activity covers the game.
const SHOW_WATCHDOG_SEC := 60.0

## Plugin "classes": name → GDScript (static calls / .new()) or, in tests, a fake object for
## the static ones (MobileAds, UserMessagingPlatform) and a Callable factory for the others.
var api := {}
## (seconds: float, callback: Callable) -> void. Tests replace it to fire timers by hand.
var schedule: Callable
## Returns seconds as float; tests replace it.
var clock: Callable
## Debug builds always use test ad unit ids.
var debug_build := OS.is_debug_build()

var listener: Object
var _consent_running := false
var _consent_failures := 0
var _consent_retry_pending := false
var _sdk_started := false
var _sdk_ready := false

var _rewarded_ad: Object
var _rewarded_loaded_at := 0.0
var _rewarded_loading := false
var _rewarded_failures := 0
var _rewarded_retry_pending := false
var _showing_rewarded: Object
## The showing rewarded ad already reported dismissed / failed (closing after the grace period).
var _rewarded_dismissed := false
var _reward_listener: Object

var _interstitial_ad: Object
var _interstitial_loaded_at := 0.0
var _interstitial_loading := false
var _interstitial_failures := 0
var _interstitial_retry_pending := false
var _showing_interstitial: Object


## True when the native plugin is in the build AND its GDScript wrappers are in the project.
static func is_plugin_available() -> bool:
	if not Engine.has_singleton(SINGLETON):
		return false
	for key in SCRIPTS:
		if not ResourceLoader.exists(ADDON_SRC + SCRIPTS[key]):
			return false
	return true


func _init() -> void:
	schedule = _default_schedule
	clock = func() -> float: return Time.get_ticks_msec() / 1000.0


## Loads the plugin wrappers by path. Returns false (and leaves `api` empty) if any is missing.
func load_plugin_api() -> bool:
	var loaded := {}
	for key in SCRIPTS:
		var path: String = ADDON_SRC + SCRIPTS[key]
		var script: Script = load(path) if ResourceLoader.exists(path) else null
		if script == null:
			push_warning("AdsAdMob: missing plugin script " + SCRIPTS[key])
			return false
		loaded[key] = script
	api = loaded
	return true


func _default_schedule(seconds: float, callback: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if seconds <= 0.0 or tree == null:
		callback.call_deferred()
	else:
		tree.create_timer(seconds, true).timeout.connect(callback)


func _new(key: String) -> Object:
	var factory = api.get(key)
	if factory is Callable:
		return factory.call()
	return factory.new() if factory != null else null


func _ump() -> Object:
	return api.get("UserMessagingPlatform")


func _now() -> float:
	return clock.call()


# --- Contract: setup / consent ---

func initialize(target: Object) -> void:
	listener = target
	if api.is_empty() and not load_plugin_api():
		return
	request_consent()


## Refreshes UMP consent info and shows the consent form when required, then starts the SDK.
func request_consent() -> void:
	if _consent_running or _ump() == null:
		return
	_consent_running = true
	var params := _new("ConsentRequestParameters")
	params.tag_for_under_age_of_consent = false
	if debug_build and not AdsConfig.UMP_TEST_DEVICE_HASHED_IDS.is_empty():
		var debug_settings := _new("ConsentDebugSettings")
		debug_settings.debug_geography = DEBUG_GEOGRAPHY_EEA
		for hashed_id in AdsConfig.UMP_TEST_DEVICE_HASHED_IDS:
			debug_settings.test_device_hashed_ids.append(hashed_id)
		params.consent_debug_settings = debug_settings
	_ump().consent_information.update(params, _on_consent_info_updated, _on_consent_failed)


func _on_consent_info_updated() -> void:
	var info: Object = _ump().consent_information
	if info.get_is_consent_form_available() and info.get_consent_status() == CONSENT_STATUS_REQUIRED:
		_ump().load_consent_form(_on_consent_form_loaded, _on_consent_failed)
	else:
		_consent_finished()


func _on_consent_form_loaded(form: Object) -> void:
	form.show(func(_form_error) -> void: _consent_finished())


func _on_consent_failed(form_error) -> void:
	# Still start the SDK: consent from an earlier session (or none needed) may apply; the SDK
	# itself only serves what the stored consent allows.
	if form_error != null and "message" in form_error:
		push_warning("AdsAdMob: consent error: " + str(form_error.message))
	_consent_finished()


## Starts the SDK only when Google allows requesting ads (consent NOT_REQUIRED or OBTAINED, which
## may also come from an earlier session after a failed refresh). Otherwise no ads are loaded and
## the consent flow is retried with backoff and on app resume (on_app_resumed()).
func _consent_finished() -> void:
	_consent_running = false
	if _can_request_ads():
		_consent_failures = 0
		_start_sdk()
	elif not _sdk_started:
		push_warning("AdsAdMob: no usable consent yet; ads stay off, retrying later")
		_schedule_consent_retry()


func _can_request_ads() -> bool:
	if _ump() == null:
		return false
	var status := int(_ump().consent_information.get_consent_status())
	return status == CONSENT_STATUS_NOT_REQUIRED or status == CONSENT_STATUS_OBTAINED


func _schedule_consent_retry() -> void:
	if _consent_retry_pending:
		return
	_consent_retry_pending = true
	schedule.call(_retry_delay(_consent_failures), _retry_consent)
	_consent_failures += 1


func _retry_consent() -> void:
	_consent_retry_pending = false
	if not _sdk_started:
		request_consent()


## Optional contract hook, called by ads.gd on NOTIFICATION_APPLICATION_RESUMED.
func on_app_resumed() -> void:
	if not _sdk_started:
		request_consent()


func _start_sdk() -> void:
	if _sdk_started:
		return
	_sdk_started = true
	var config := _new("RequestConfiguration")
	if config != null:
		config.max_ad_content_rating = AdsConfig.MAX_AD_CONTENT_RATING
		api.MobileAds.set_request_configuration(config)
	var init_listener := _new("OnInitializationCompleteListener")
	init_listener.on_initialization_complete = func(_status) -> void: _on_sdk_ready()
	api.MobileAds.initialize(init_listener)
	schedule.call(INIT_FALLBACK_SEC, _on_sdk_ready)


func _on_sdk_ready() -> void:
	if _sdk_ready:
		return
	_sdk_ready = true
	# Preload one of each (ads.gd's early load_*() calls were no-ops before this point).
	load_rewarded()
	load_interstitial()


func can_show_privacy_options() -> bool:
	if _ump() == null:
		return false
	return _ump().consent_information.get_privacy_options_requirement_status() \
		== PRIVACY_OPTIONS_REQUIRED


func show_privacy_options() -> void:
	if _ump() != null:
		_ump().show_privacy_options_form(func(_form_error) -> void: pass)


# --- Contract: rewarded ---

func is_rewarded_loaded() -> bool:
	if _rewarded_ad != null and _now() - _rewarded_loaded_at > AD_MAX_AGE_SEC:
		_rewarded_ad.destroy()
		_release(_rewarded_ad)
		_rewarded_ad = null
		load_rewarded()
	return _rewarded_ad != null


func load_rewarded() -> void:
	if not _sdk_ready:
		return
	if _rewarded_ad != null:
		listener._backend_rewarded_loaded(true)
		return
	if _rewarded_loading or _rewarded_retry_pending:
		return
	_rewarded_loading = true
	var callback := _new("RewardedAdLoadCallback")
	callback.on_ad_loaded = _on_rewarded_loaded
	callback.on_ad_failed_to_load = _on_rewarded_failed_to_load
	var loader := _new("RewardedAdLoader")
	loader.load(AdsConfig.rewarded_unit_id(debug_build), _new("AdRequest"), callback)


func _on_rewarded_loaded(ad: Object) -> void:
	_rewarded_loading = false
	_rewarded_failures = 0
	var callbacks := _new("FullScreenContentCallback")
	callbacks.on_ad_dismissed_full_screen_content = _on_rewarded_done.bind(ad)
	callbacks.on_ad_failed_to_show_full_screen_content = _on_rewarded_show_failed.bind(ad)
	ad.full_screen_content_callback = callbacks
	_rewarded_ad = ad
	_rewarded_loaded_at = _now()
	listener._backend_rewarded_loaded(true)


func _on_rewarded_failed_to_load(error) -> void:
	_rewarded_loading = false
	_log_error("rewarded load", error)
	listener._backend_rewarded_loaded(false)
	_rewarded_retry_pending = true
	schedule.call(_retry_delay(_rewarded_failures), _retry_rewarded)
	_rewarded_failures += 1


func _retry_rewarded() -> void:
	_rewarded_retry_pending = false
	load_rewarded()


func show_rewarded(_placement: String) -> void:
	var ad := _rewarded_ad if is_rewarded_loaded() else null
	if ad == null or _showing_rewarded != null:
		# Nothing to show: still close, as the contract demands.
		schedule.call(0.0, Callable(listener, "_backend_rewarded_closed"))
		return
	_rewarded_ad = null
	_showing_rewarded = ad
	_rewarded_dismissed = false
	_reward_listener = _new("OnUserEarnedRewardListener")
	_reward_listener.on_user_earned_reward = _on_reward_earned.bind(ad)
	schedule.call(SHOW_WATCHDOG_SEC, _rewarded_watchdog.bind(ad))
	ad.show(_reward_listener)


## No dismiss / show failure in time: close it like a dismiss (reward only if already earned).
func _rewarded_watchdog(ad: Object) -> void:
	if ad == _showing_rewarded and not _rewarded_dismissed:
		push_warning("AdsAdMob: rewarded ad never reported closing; closing it")
		_on_rewarded_done(ad)


func _on_reward_earned(_item, ad: Object) -> void:
	if ad == _showing_rewarded:
		listener._backend_reward_earned()


func _on_rewarded_show_failed(error, ad: Object) -> void:
	_log_error("rewarded show", error)
	_on_rewarded_done(ad)


func _on_rewarded_done(ad: Object) -> void:
	if ad != _showing_rewarded or _rewarded_dismissed:
		return
	_rewarded_dismissed = true
	ad.destroy()
	_release(ad)
	# Keep _showing_rewarded until the grace period ends so a late reward still counts.
	schedule.call(REWARD_GRACE_SEC, _finish_rewarded.bind(ad))


func _finish_rewarded(ad: Object) -> void:
	if ad != _showing_rewarded:
		return
	_showing_rewarded = null
	if _reward_listener != null:
		_reward_listener.on_user_earned_reward = _ignore   # drop the Callable bound to the ad
	_reward_listener = null
	listener._backend_rewarded_closed()   # ads.gd then calls load_rewarded() for the next one


# --- Contract: interstitial ---

func is_interstitial_loaded() -> bool:
	if _interstitial_ad != null and _now() - _interstitial_loaded_at > AD_MAX_AGE_SEC:
		_interstitial_ad.destroy()
		_release(_interstitial_ad)
		_interstitial_ad = null
		load_interstitial()
	return _interstitial_ad != null


func load_interstitial() -> void:
	if not _sdk_ready or not _listener_wants_interstitial():
		return
	if _interstitial_ad != null or _interstitial_loading or _interstitial_retry_pending:
		return
	_interstitial_loading = true
	var callback := _new("InterstitialAdLoadCallback")
	callback.on_ad_loaded = _on_interstitial_loaded
	callback.on_ad_failed_to_load = _on_interstitial_failed_to_load
	var loader := _new("InterstitialAdLoader")
	loader.load(AdsConfig.interstitial_unit_id(debug_build), _new("AdRequest"), callback)


func _on_interstitial_loaded(ad: Object) -> void:
	_interstitial_loading = false
	_interstitial_failures = 0
	var callbacks := _new("FullScreenContentCallback")
	callbacks.on_ad_dismissed_full_screen_content = _on_interstitial_done.bind(ad)
	callbacks.on_ad_failed_to_show_full_screen_content = _on_interstitial_show_failed.bind(ad)
	ad.full_screen_content_callback = callbacks
	_interstitial_ad = ad
	_interstitial_loaded_at = _now()


func _on_interstitial_failed_to_load(error) -> void:
	_interstitial_loading = false
	_log_error("interstitial load", error)
	_interstitial_retry_pending = true
	schedule.call(_retry_delay(_interstitial_failures), _retry_interstitial)
	_interstitial_failures += 1


func _retry_interstitial() -> void:
	_interstitial_retry_pending = false
	load_interstitial()


func show_interstitial() -> void:
	var ad := _interstitial_ad if is_interstitial_loaded() else null
	if ad == null or _showing_interstitial != null:
		schedule.call(0.0, Callable(listener, "_backend_interstitial_closed"))
		return
	_interstitial_ad = null
	_showing_interstitial = ad
	schedule.call(SHOW_WATCHDOG_SEC, _interstitial_watchdog.bind(ad))
	ad.show()


func _interstitial_watchdog(ad: Object) -> void:
	if ad == _showing_interstitial:
		push_warning("AdsAdMob: interstitial never reported closing; closing it")
		_on_interstitial_done(ad)


func _on_interstitial_show_failed(error, ad: Object) -> void:
	_log_error("interstitial show", error)
	_on_interstitial_done(ad)


func _on_interstitial_done(ad: Object) -> void:
	if ad != _showing_interstitial:
		return
	_showing_interstitial = null
	ad.destroy()
	_release(ad)
	listener._backend_interstitial_closed()   # ads.gd then calls load_interstitial()


# --- Helpers ---

## Optional listener hook (ads.gd: false once "remove ads" is owned). Missing → true.
func _listener_wants_interstitial() -> bool:
	if listener == null or not listener.has_method("_backend_wants_interstitial"):
		return true
	return listener._backend_wants_interstitial()


## Replaces the ad's callbacks (which hold Callables bound to the ad itself) with no-ops, so the
## destroyed wrapper object is not kept alive by a reference cycle.
func _release(ad: Object) -> void:
	var callbacks: Object = ad.full_screen_content_callback
	if callbacks != null:
		callbacks.on_ad_dismissed_full_screen_content = _ignore
		callbacks.on_ad_failed_to_show_full_screen_content = _ignore


func _ignore(_arg = null) -> void:
	pass

static func _retry_delay(failures: int) -> float:
	return RETRY_DELAYS[mini(failures, RETRY_DELAYS.size() - 1)]


static func _log_error(what: String, error) -> void:
	var text := ""
	if error is Object and "message" in error:
		text = "%s (code %s)" % [error.message, error.code if "code" in error else "?"]
	push_warning("AdsAdMob: %s failed: %s" % [what, text])
