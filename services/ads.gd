extends Node
## Ads autoload: rewarded ("hint", "revive") and interstitial ("level_end") placements.
##
## Backend contract (what a real adapter such as services/ads_admob.gd must implement):
##   initialize(listener: Object) -> void   # keep listener (this node) for callbacks
##   is_rewarded_loaded() -> bool
##   load_rewarded() -> void
##   show_rewarded(placement: String) -> void
##   is_interstitial_loaded() -> bool
##   load_interstitial() -> void
##   show_interstitial() -> void
##   request_consent() -> void              # GDPR / UMP consent form when required
##   can_show_privacy_options() -> bool     # UMP "privacy options required" status
##   show_privacy_options() -> void
## The backend reports back by calling these listener methods (any thread-safe deferral is the
## adapter's job; call them on the main thread):
##   _backend_rewarded_loaded(ok: bool)     # after load_rewarded() finishes
##   _backend_reward_earned()               # user watched enough to earn the reward
##   _backend_rewarded_closed()             # rewarded ad dismissed (always, earned or not)
##   _backend_interstitial_closed()         # interstitial dismissed or failed to show

signal rewarded_ready_changed(ready: bool)
signal rewarded_finished(placement: String, rewarded: bool)
signal interstitial_closed()

const PLACEMENT_HINT := "hint"
const PLACEMENT_REVIVE := "revive"
const PLACEMENT_LEVEL_END := "level_end"

# Interstitial pacing. The player should rarely see one; all rules must pass.
## No interstitial until the player has cleared this many levels in total.
const FIRST_INTERSTITIAL_AFTER_CLEARS := 8
## At most one interstitial per this many wins (counted per session, replays included).
const INTERSTITIAL_EVERY_CLEARS := 4
## Minimum seconds between two interstitials.
const MIN_SECONDS_BETWEEN_INTERSTITIALS := 180.0
## A player who just watched a rewarded ad has "paid"; skip interstitials for this long.
const MIN_SECONDS_AFTER_REWARDED := 120.0
## Never interrupt the first minute of a session.
const MIN_SECONDS_AFTER_APP_START := 60.0

## Platform singleton the AdMob plugin registers; fill in with the real adapter.
const ADMOB_SINGLETON := ""

## Active backend (see contract above). Never null after _ready().
var backend: Object
## Returns seconds as float; tests replace it.
var clock: Callable
var last_rewarded_time := -INF
var last_interstitial_time := -INF
var _start_time := 0.0
var _wins_since_interstitial := 0
var _ads_supported := false
var _rewarded_showing := false
var _interstitial_showing := false
var _placement := ""
var _earned := false
var _on_reward: Callable


func _init() -> void:
	clock = func() -> float: return Time.get_ticks_msec() / 1000.0


func _ready() -> void:
	_start_time = clock.call()
	backend = _make_native_backend()
	_ads_supported = backend != null
	if backend == null:
		if OS.is_debug_build():
			backend = MockAdsBackend.new()
			_ads_supported = true
		else:
			backend = NoAdsBackend.new()
	backend.initialize(self)
	backend.load_rewarded()
	backend.load_interstitial()


func _make_native_backend() -> Object:
	# TODO(ads adapter): when the AdMob Android plugin is added, load it here, e.g.
	#   if ADMOB_SINGLETON != "" and Engine.has_singleton(ADMOB_SINGLETON):
	#       return load("res://services/ads_admob.gd").new()
	# The adapter wraps the singleton and implements the backend contract at the top of this file.
	return null


func _economy() -> Node:
	return get_node_or_null("/root/Economy")


## Resets pacing state against the current clock.
func reset_for_tests() -> void:
	_start_time = clock.call()
	last_rewarded_time = -INF
	last_interstitial_time = -INF
	_wins_since_interstitial = 0
	_rewarded_showing = false
	_interstitial_showing = false


# --- Rewarded ---

## Whether rewarded placements exist at all (false only with the release "no ads" backend).
## Deliberately ignores Economy.is_ads_removed(): rewarded ads are opt-in and give value,
## so buying "remove ads" only removes interstitials.
func rewarded_ads_enabled() -> bool:
	return _ads_supported


func is_rewarded_ready() -> bool:
	return _ads_supported and not _rewarded_showing and not _interstitial_showing \
		and backend.is_rewarded_loaded()


## Shows a rewarded ad. on_reward is called exactly once, only if the reward was earned.
## rewarded_finished is always emitted afterwards. Returns false if no ad is ready.
func show_rewarded(placement: String, on_reward: Callable) -> bool:
	if not is_rewarded_ready():
		return false
	_rewarded_showing = true
	_placement = placement
	_earned = false
	_on_reward = on_reward
	rewarded_ready_changed.emit(false)
	backend.show_rewarded(placement)
	return true


func _backend_rewarded_loaded(ok: bool) -> void:
	rewarded_ready_changed.emit(ok and is_rewarded_ready())


func _backend_reward_earned() -> void:
	if not _rewarded_showing or _earned:
		return
	_earned = true
	var callback := _on_reward
	_on_reward = Callable()
	if callback.is_valid():
		callback.call()


func _backend_rewarded_closed() -> void:
	if not _rewarded_showing:
		return
	_rewarded_showing = false
	_on_reward = Callable()
	last_rewarded_time = clock.call()
	rewarded_finished.emit(_placement, _earned)
	backend.load_rewarded()


# --- Interstitial ---

## Call ONLY after a win (never on a loss or retry). Applies the pacing rules above and
## shows an interstitial if they all pass. Returns whether one is being shown.
func on_level_cleared(total_cleared: int) -> bool:
	_wins_since_interstitial += 1
	if not _ads_supported or _interstitial_showing or _rewarded_showing:
		return false
	var economy := _economy()
	if economy and economy.is_ads_removed():
		return false
	if total_cleared < FIRST_INTERSTITIAL_AFTER_CLEARS:
		return false
	if _wins_since_interstitial < INTERSTITIAL_EVERY_CLEARS:
		return false
	var now: float = clock.call()
	if now - _start_time < MIN_SECONDS_AFTER_APP_START:
		return false
	if now - last_interstitial_time < MIN_SECONDS_BETWEEN_INTERSTITIALS:
		return false
	if now - last_rewarded_time < MIN_SECONDS_AFTER_REWARDED:
		return false
	if not backend.is_interstitial_loaded():
		backend.load_interstitial()
		return false
	_interstitial_showing = true
	_wins_since_interstitial = 0
	last_interstitial_time = now
	backend.show_interstitial()
	return true


func _backend_interstitial_closed() -> void:
	if not _interstitial_showing:
		return
	_interstitial_showing = false
	interstitial_closed.emit()
	backend.load_interstitial()


# --- Consent / privacy ---

func request_consent() -> void:
	backend.request_consent()


## Show a "Privacy options" button in Settings when true (required for UMP in the EEA).
func can_show_privacy_options() -> bool:
	return backend.can_show_privacy_options()


func show_privacy_options() -> void:
	backend.show_privacy_options()


## Debug-build stand-in: always loaded; results arrive on the next idle frame.
class MockAdsBackend:
	extends RefCounted
	## Next rewarded closes without a reward (simulates skip/failure).
	var mock_fail_next := false
	var listener: Object
	var shown_rewarded: Array = []
	var shown_interstitials := 0

	func initialize(target: Object) -> void:
		listener = target

	func is_rewarded_loaded() -> bool:
		return true

	func load_rewarded() -> void:
		listener._backend_rewarded_loaded.call_deferred(true)

	func show_rewarded(placement: String) -> void:
		shown_rewarded.append(placement)
		if mock_fail_next:
			mock_fail_next = false
		else:
			listener._backend_reward_earned.call_deferred()
		listener._backend_rewarded_closed.call_deferred()

	func is_interstitial_loaded() -> bool:
		return true

	func load_interstitial() -> void:
		pass

	func show_interstitial() -> void:
		shown_interstitials += 1
		listener._backend_interstitial_closed.call_deferred()

	func request_consent() -> void:
		pass

	func can_show_privacy_options() -> bool:
		return true

	func show_privacy_options() -> void:
		print("Ads (mock): privacy options")


## Release build without a plugin: never ready, so the UI hides ad buttons.
class NoAdsBackend:
	extends RefCounted

	func initialize(_target: Object) -> void:
		pass

	func is_rewarded_loaded() -> bool:
		return false

	func load_rewarded() -> void:
		pass

	func show_rewarded(_placement: String) -> void:
		pass

	func is_interstitial_loaded() -> bool:
		return false

	func load_interstitial() -> void:
		pass

	func show_interstitial() -> void:
		pass

	func request_consent() -> void:
		pass

	func can_show_privacy_options() -> bool:
		return false

	func show_privacy_options() -> void:
		pass
