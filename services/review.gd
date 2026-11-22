extends Node
## Review autoload: asks for a Google Play in-app review at most once ever, at a good moment.
##
## Call maybe_request(total_cleared, last_stars) after a win. It requests the review flow only when
## all rules pass (see constants) and remembers that it did in its own file (never save.json).
##
## Plugin: godot-sdk-integrations/godot-inapp-review v5.3 (Android). Its GDScript wrapper is a Node
## (`class_name InappReview`, res://addons/InappReviewPlugin/InappReview.gd) that talks to the
## engine singleton "InappReviewPlugin":
##   generate_review_info() → signal review_info_generated | review_info_generation_failed
##   launch_review_flow()   → signal review_flow_launched  | review_flow_launch_failed
## This file never names the plugin's class_name: the wrapper is load()ed by path only when the
## singleton AND the addon scripts exist, so the game parses and runs without the plugin.
## Tests inject a fake with the same methods/signals via set_plugin().
##
## Google enforces a quota: the review card may silently not appear (review_flow_launched still
## fires). That is expected; we never retry or tell the player anything.

## Minimum distinct levels cleared before asking.
const MIN_CLEARS := 20
## Only right after a perfect (3-star) clear: the player just had a great moment.
const REQUIRED_STARS := 3
## Never ask within this many seconds of an interstitial (measured with Ads.clock).
const MIN_SECONDS_AFTER_INTERSTITIAL := 60.0

const SINGLETON := "InappReviewPlugin"
## Wrapper node script and the shared logger it depends on (paths from the v5.3 addon layout).
const WRAPPER_SCRIPT := "res://addons/InappReviewPlugin/InappReview.gd"
const ADDON_SCRIPTS := [WRAPPER_SCRIPT, "res://addons/GMPShared/GmpLogger.gd"]

var save_path := "user://review.json"
## Without a plugin, debug builds still "request" (debug print) so the once-ever logic is
## testable on desktop; release builds without a plugin stay inert and persist nothing.
var debug_build := OS.is_debug_build()
## InappReview wrapper node, a test fake, or null (no plugin).
var plugin: Object

var requested := false
var _flow_pending := false
## The plugin reported a failure this session: try again only in a later session.
var _failed_this_session := false


func _ready() -> void:
	load_data()
	var native := _make_native_plugin()
	if native != null:
		add_child(native)   # the wrapper binds to its singleton in _ready()
		set_plugin(native)


## True when the native singleton exists and the addon's GDScript files are in the project.
static func is_plugin_available() -> bool:
	if not Engine.has_singleton(SINGLETON):
		return false
	for path in ADDON_SCRIPTS:
		if not ResourceLoader.exists(path):
			return false
	return true


## A new wrapper node (not yet in the tree), or null when the plugin is unavailable.
func _make_native_plugin() -> Node:
	if not is_plugin_available():
		return null
	var script: Script = load(WRAPPER_SCRIPT)
	return script.new() if script != null and script.can_instantiate() else null


## Uses `p` as the plugin (wrapper node or fake). Pass null to detach.
func set_plugin(p: Object) -> void:
	if plugin != null:
		for pair in _signal_handlers():
			if plugin.has_signal(pair[0]) and plugin.is_connected(pair[0], pair[1]):
				plugin.disconnect(pair[0], pair[1])
	plugin = p
	_flow_pending = false
	if plugin != null:
		for pair in _signal_handlers():
			if plugin.has_signal(pair[0]):
				plugin.connect(pair[0], pair[1])


func _signal_handlers() -> Array:
	return [["review_info_generated", _on_review_info_generated],
		["review_info_generation_failed", _on_review_info_generation_failed],
		["review_flow_launched", _on_review_flow_launched],
		["review_flow_launch_failed", _on_review_flow_launch_failed]]


func _ads() -> Node:
	return get_node_or_null("/root/Ads")


# --- Persistence ---

func load_data() -> void:
	requested = false
	if not FileAccess.file_exists(save_path):
		return
	var json := JSON.new()
	var data = json.data if json.parse(FileAccess.get_file_as_string(save_path)) == OK else null
	if not data is Dictionary:
		push_warning("Review: unreadable %s, using defaults" % save_path)
		return
	requested = data.get("requested") is bool and data.get("requested")


func save_data() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"requested": requested}))
	else:
		push_error("Review: cannot write %s" % save_path)


## Wipes memory and the save file.
func reset_for_tests() -> void:
	requested = false
	_flow_pending = false
	_failed_this_session = false
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


# --- Public API ---

func is_requested() -> bool:
	return requested


## Call after a win. Asks Google Play for the in-app review flow when every rule passes;
## returns whether it did. At most once ever: persisted only when the plugin reports
## review_flow_launched; a failure allows one more try in a later session (not this one).
func maybe_request(total_cleared: int, last_stars: int) -> bool:
	if requested or _flow_pending or _failed_this_session:
		return false
	if total_cleared < MIN_CLEARS or last_stars < REQUIRED_STARS:
		return false
	if _interstitial_too_recent():
		return false
	if plugin == null and not debug_build:
		return false   # release without plugin: inert, keep the one chance for a build that has it
	if plugin == null:
		_mark_requested()
		print("Review (debug): in-app review would be requested now (no plugin)")
		return true
	_flow_pending = true
	plugin.generate_review_info()
	return true


func _mark_requested() -> void:
	requested = true
	save_data()


func _interstitial_too_recent() -> bool:
	var ads := _ads()
	if ads == null or not ("last_interstitial_time" in ads) or not ("clock" in ads):
		return false
	var now: float = ads.clock.call()
	return now - float(ads.last_interstitial_time) < MIN_SECONDS_AFTER_INTERSTITIAL


# --- Plugin callbacks ---

func _on_review_info_generated() -> void:
	if not _flow_pending:
		return
	plugin.launch_review_flow()


func _on_review_info_generation_failed() -> void:
	_flow_pending = false
	_failed_this_session = true
	push_warning("Review: review info generation failed")


func _on_review_flow_launched() -> void:
	# Finished; the card may not have been shown at all (Google quota), which is fine.
	if _flow_pending:
		_flow_pending = false
		_mark_requested()


func _on_review_flow_launch_failed() -> void:
	_flow_pending = false
	_failed_this_session = true
	push_warning("Review: review flow launch failed")
