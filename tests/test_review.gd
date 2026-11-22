extends SceneTree
## In-App Review service (services/review.gd) with a fake InappReview plugin.
## Run: XDG_DATA_HOME=$(mktemp -d) godot --headless --script tests/test_review.gd

const TEST_SAVE := "user://test_review.json"
const TEST_ECONOMY := "user://test_review_economy.json"
const ReviewScript := preload("res://services/review.gd")

var failures := 0
var ads: Node
var fake_now := 0.0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	# Godot 4.7 adds project autoloads in --script mode; add them by hand if a version does not.
	for entry in [["Economy", "res://services/economy.gd"], ["Ads", "res://services/ads.gd"],
			["IAP", "res://services/iap.gd"], ["Review", "res://services/review.gd"]]:
		if root.get_node_or_null(entry[0]) == null:
			var node: Node = load(entry[1]).new()
			node.name = entry[0]
			root.add_child(node)
	var economy: Node = root.get_node("Economy")
	economy.save_path = TEST_ECONOMY
	economy.reset_for_tests()
	ads = root.get_node("Ads")
	ads.clock = func() -> float: return fake_now
	call_deferred("run")


func frames(n := 2) -> void:
	for i in n:
		await process_frame


## A fresh Review node in the tree (so /root/Ads is reachable), with its own save file.
func make_review(debug := true) -> Node:
	var review: Node = ReviewScript.new()
	review.save_path = TEST_SAVE
	review.debug_build = debug
	root.add_child(review)   # _ready(): load_data(), no native plugin on desktop
	return review


func run() -> void:
	test_without_plugin()
	test_thresholds()
	test_once_ever()
	test_interstitial_cooldown()
	await test_cooldown_with_real_interstitial()
	await test_fake_plugin_flow()
	test_fake_plugin_failures()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	root.get_node("Economy").reset_for_tests()
	print("test_review: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)


func reset_ads_clock() -> void:
	fake_now = 10000.0
	ads.reset_for_tests()   # last_interstitial_time = -INF


func test_without_plugin() -> void:
	check(not ReviewScript.is_plugin_available(), "no InappReviewPlugin singleton on desktop")
	var autoload: Node = root.get_node_or_null("Review")
	check(autoload != null and autoload.get_script() == ReviewScript, "Review autoload registered")
	check(autoload.plugin == null and autoload.get_child_count() == 0, "autoload has no plugin node on desktop")
	var review := make_review()
	check(review._make_native_plugin() == null, "no wrapper created without the plugin")
	review.reset_for_tests()
	review.free()

	# Release build without the plugin: inert, nothing persisted (a later build with it may ask).
	reset_ads_clock()
	review = make_review(false)
	review.reset_for_tests()
	check(not review.maybe_request(50, 3), "release without plugin never requests")
	check(not review.is_requested() and not FileAccess.file_exists(TEST_SAVE), "release without plugin persists nothing")
	review.free()


func test_thresholds() -> void:
	reset_ads_clock()
	var review := make_review()
	review.reset_for_tests()
	check(not review.maybe_request(ReviewScript.MIN_CLEARS - 1, 3), "below 20 clears: no request")
	for stars in [0, 1, 2]:
		check(not review.maybe_request(ReviewScript.MIN_CLEARS, stars), "%d stars: no request" % stars)
	check(not review.is_requested() and not FileAccess.file_exists(TEST_SAVE), "nothing persisted while rules fail")
	check(review.maybe_request(ReviewScript.MIN_CLEARS, 3), "20 clears + 3 stars requests (debug, no plugin)")
	check(review.is_requested() and FileAccess.file_exists(TEST_SAVE), "request persisted")
	review.reset_for_tests()
	review.free()


func test_once_ever() -> void:
	reset_ads_clock()
	var review := make_review()
	review.reset_for_tests()
	check(review.maybe_request(30, 3), "first request")
	check(not review.maybe_request(31, 3) and not review.maybe_request(100, 3), "never twice in a session")
	review.free()

	# New session (fresh node) reads the file and stays silent.
	review = make_review()
	check(review.is_requested() and not review.maybe_request(200, 3), "never again after restart")
	review.free()

	# Corrupt or foreign data falls back to "not requested".
	for text in ["{not json", "[1, 2]", '{"requested": "yes"}']:
		var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		review = make_review()
		check(not review.is_requested(), "bad file %s -> not requested" % text)
		review.free()
	review = make_review()
	review.reset_for_tests()
	check(not FileAccess.file_exists(TEST_SAVE) and not review.is_requested(), "reset_for_tests wipes file")
	check(not FileAccess.file_exists("user://save.json"), "review never writes save.json")
	review.free()


func test_interstitial_cooldown() -> void:
	reset_ads_clock()
	var review := make_review()
	review.reset_for_tests()
	ads.last_interstitial_time = fake_now - 10.0
	check(not review.maybe_request(40, 3), "10 s after interstitial: no request")
	ads.last_interstitial_time = fake_now - 59.9
	check(not review.maybe_request(40, 3), "59.9 s after interstitial: no request")
	check(not review.is_requested(), "cooldown does not burn the one request")
	ads.last_interstitial_time = fake_now - 60.0
	check(review.maybe_request(40, 3), "60 s after interstitial: request")
	review.reset_for_tests()
	review.free()


## Same rule driven through the real Ads pacing (mock backend shows the interstitial).
func test_cooldown_with_real_interstitial() -> void:
	reset_ads_clock()
	root.get_node("Economy").set_ads_removed(false)
	fake_now += 1000.0
	var shown := false
	for i in ads.INTERSTITIAL_EVERY_CLEARS:
		shown = ads.on_level_cleared(50 + i)
	check(shown and ads.last_interstitial_time == fake_now, "Ads showed an interstitial")
	await frames()
	var review := make_review()
	review.reset_for_tests()
	fake_now += 30.0
	check(not review.maybe_request(60, 3), "no review 30 s after a real interstitial")
	fake_now += 31.0
	check(review.maybe_request(60, 3), "review allowed 61 s after it")
	review.reset_for_tests()
	review.free()


func test_fake_plugin_flow() -> void:
	reset_ads_clock()
	var review := make_review()
	review.reset_for_tests()
	var fake := FakeInappReview.new()
	review.set_plugin(fake)
	check(not review.maybe_request(10, 3), "plugin: thresholds still apply")
	check(fake.calls.is_empty(), "no plugin calls while rules fail")
	check(review.maybe_request(25, 3), "plugin: request made")
	check(fake.calls == ["generate_review_info"], "generate_review_info called first")
	check(review.is_requested() and FileAccess.file_exists(TEST_SAVE), "plugin request persisted immediately")
	check(not review.maybe_request(26, 3), "no second request while flow pending")
	await frames()
	check(fake.calls == ["generate_review_info", "launch_review_flow"], "review_info_generated -> launch_review_flow: %s" % [fake.calls])
	await frames()
	check(not review._flow_pending, "flow finished after review_flow_launched")
	check(not review.maybe_request(100, 3) and fake.calls.size() == 2, "once ever with plugin too")

	# A stray review_info_generated (not ours) does not launch anything.
	fake.review_info_generated.emit()
	check(fake.calls.size() == 2, "stray signal ignored")
	review.set_plugin(null)
	check(not fake.review_info_generated.is_connected(review._on_review_info_generated), "set_plugin(null) disconnects")
	review.reset_for_tests()
	review.free()
	fake.free()


func test_fake_plugin_failures() -> void:
	reset_ads_clock()
	var review := make_review()
	review.reset_for_tests()
	var fake := FakeInappReview.new()
	fake.auto_respond = false
	review.set_plugin(fake)
	check(review.maybe_request(25, 3), "request with silent fake")
	fake.review_info_generation_failed.emit()
	check(fake.calls == ["generate_review_info"] and not review._flow_pending, "generation failure: no launch")
	check(review.is_requested() and not review.maybe_request(25, 3), "failure still counts as the one request")

	review.reset_for_tests()
	fake.calls.clear()
	check(review.maybe_request(25, 3), "request again after reset")
	fake.review_info_generated.emit()
	check(fake.calls == ["generate_review_info", "launch_review_flow"], "launch after generated")
	fake.review_flow_launch_failed.emit()
	check(not review._flow_pending, "launch failure ends the flow quietly")
	review.reset_for_tests()
	review.free()
	fake.free()


## Mimics the InappReview wrapper node (godot-inapp-review v5.3): same methods and signals.
## Responds on the next frame, like the native plugin's async tasks.
class FakeInappReview:
	extends Node
	signal review_info_generated
	signal review_info_generation_failed
	signal review_flow_launched
	signal review_flow_launch_failed

	var calls: Array = []
	var auto_respond := true

	func generate_review_info() -> void:
		calls.append("generate_review_info")
		if auto_respond:
			review_info_generated.emit.call_deferred()

	func launch_review_flow() -> void:
		calls.append("launch_review_flow")
		if auto_respond:
			review_flow_launched.emit.call_deferred()
