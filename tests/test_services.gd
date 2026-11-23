extends SceneTree
## Run: XDG_DATA_HOME=$(mktemp -d) godot --headless --script tests/test_services.gd

const TEST_SAVE := "user://test_economy.json"

var failures := 0
var economy: Node
var ads: Node
var iap: Node
var fake_now := 0.0
var fake_today := "2026-03-01"
var hint_events: Array = []
var daily_events: Array = []
var reward_calls := 0
var rewarded_events: Array = []
var interstitial_closes := 0
var completed: Array = []
var failed: Array = []


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
	economy = root.get_node("Economy")
	ads = root.get_node("Ads")
	iap = root.get_node("IAP")
	economy.save_path = TEST_SAVE
	economy.today_provider = func() -> String: return fake_today
	ads.clock = func() -> float: return fake_now
	economy.reset_for_tests()
	call_deferred("run")


func frames(n := 2) -> void:
	for i in n:
		await process_frame


func run() -> void:
	test_economy()
	test_daily_puzzle()
	await test_ads()
	await test_ads_ready_signal()
	await test_iap()
	await test_ads_removed_no_interstitial_loads()
	await test_iap_regressions()
	economy.reset_for_tests()
	print("test_services: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)


func test_economy() -> void:
	economy.hints_changed.connect(func(count: int) -> void: hint_events.append(count))
	economy.daily_claimed.connect(func(amount: int, streak: int) -> void: daily_events.append([amount, streak]))
	check(economy.get_hints() == 3, "new players start with 3 hints")
	check(not economy.is_ads_removed() and economy.total_stars() == 0, "defaults")
	check(economy.spend_hint() and economy.get_hints() == 2, "spend hint")
	check(hint_events == [2], "hints_changed on spend")
	economy.add_hints(4)
	check(economy.get_hints() == 6 and hint_events.back() == 6, "add hints + signal")
	economy.reset_for_tests()
	for i in 3:
		economy.spend_hint()
	check(not economy.spend_hint() and economy.get_hints() == 0, "cannot spend at 0")

	# Daily reward and streaks.
	check(economy.can_claim_daily(), "daily claimable for new player")
	check(economy.next_daily_amount() == 1, "next daily for new player is 1")
	check(economy.claim_daily() == 1 and economy.streak == 1, "first daily")
	check(not economy.can_claim_daily() and economy.claim_daily() == 0, "same day gives 0")
	check(economy.next_daily_amount() == 0 and economy.streak == 1, "next daily is 0 after claiming, no state change")
	check(daily_events == [[1, 1]], "daily_claimed emitted once")
	fake_today = "2026-03-02"
	check(economy.claim_daily() == 1 and economy.streak == 2, "next day continues streak")
	fake_today = "2026-03-04"
	check(economy.claim_daily() == 1 and economy.streak == 1, "gap resets streak")
	# Month/year boundaries count as consecutive days.
	var days := ["2026-12-27", "2026-12-28", "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03"]
	economy.last_daily = ""
	var amounts := []
	var hinted := []
	for day in days:
		fake_today = day
		hinted.append(economy.next_daily_amount())
		amounts.append(economy.claim_daily())
	check(amounts == [1, 1, 1, 1, 1, 1, 3, 1], "day 7 of each cycle gives 3: %s" % [amounts])
	check(hinted == amounts, "next_daily_amount predicts claim_daily: %s" % [hinted])
	check(economy.streak == 8, "streak across new year")
	# Streak at 6 → tomorrow's claim is the 7th (3 hints); a missed day resets it to 1.
	economy.streak = 6
	economy.last_daily = "2027-02-10"
	fake_today = "2027-02-11"
	check(economy.next_daily_amount() == 3, "next daily is 3 on day 7 of the cycle")
	fake_today = "2027-02-12"
	check(economy.next_daily_amount() == 1 and economy.streak == 6, "gap: next daily falls back to 1")
	# Regression: moving the device clock back and forth must not farm the daily gift.
	economy.last_daily = ""
	fake_today = "2027-03-10"
	check(economy.claim_daily() == 1, "clock test: first claim")
	var before_back: int = economy.get_hints()
	for day in ["2027-03-09", "2026-01-01", "2027-03-10"]:
		fake_today = day
		check(not economy.can_claim_daily() and economy.next_daily_amount() == 0 and economy.claim_daily() == 0,
			"daily_clock_back: %s after 2027-03-10 counts as claimed" % day)
	check(economy.get_hints() == before_back and economy.last_daily == "2027-03-10" and economy.streak == 1,
		"daily_clock_back: nothing granted, state unchanged")
	fake_today = "2027-03-11"
	check(economy.claim_daily() == 1 and economy.streak == 2, "daily_clock_back: next real day still claimable, streak kept")

	# Stars and clears.
	check(economy.stars_for(0) == 3 and economy.stars_for(1) == 2 and economy.stars_for(2) == 2 and economy.stars_for(3) == 1, "stars_for")
	economy.reset_for_tests()
	var r: Dictionary = economy.record_clear(0, 2)
	check(r == {"stars": 2, "first_clear": true, "bonus_hints": 0}, "first clear: %s" % r)
	r = economy.record_clear(0, 0)
	check(r.stars == 3 and not r.first_clear and economy.levels_cleared == 1, "replay is not a first clear")
	economy.record_clear(0, 5)
	check(economy.get_stars(0) == 3, "best stars kept")
	var bonus := 0
	for level in range(1, 20):
		r = economy.record_clear(level, 4)
		bonus += r.bonus_hints
		if level == 9 or level == 19:
			check(r.bonus_hints == 1, "bonus hint on clear #%d" % (level + 1))
	check(bonus == 2 and economy.levels_cleared == 20 and economy.get_hints() == 5, "bonus every 10th clear")
	check(economy.total_stars() == 3 + 19, "total stars")
	check(economy.get_stars(99) == 0, "uncleared level has 0 stars")

	# Persistence round-trip.
	economy.set_ads_removed(true)
	economy.own("remove_ads")
	economy.mark_token("tok-a")
	fake_today = "2026-05-05"
	economy.claim_daily()
	var copy: Node = load("res://services/economy.gd").new()
	copy.save_path = TEST_SAVE
	copy.load_data()
	check(copy.get_hints() == economy.get_hints() and copy.is_ads_removed(), "reload hints/ads_removed")
	check(copy.owns("remove_ads") and copy.token_seen("tok-a") and not copy.token_seen("tok-b"), "reload purchases/tokens")
	check(copy.last_daily == "2026-05-05" and copy.streak == 1 and copy.levels_cleared == 20, "reload daily/clears")
	check(copy.get_stars(0) == 3 and copy.total_stars() == economy.total_stars(), "reload stars")
	for i in 60:
		copy.mark_token("t%d" % i)
	check(copy.consumed_tokens.size() == 50 and copy.token_seen("t59") and not copy.token_seen("t9"), "keep last 50 tokens")
	copy.free()

	# Corrupt file falls back to defaults.
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	economy.load_data()
	check(economy.get_hints() == 3 and not economy.is_ads_removed() and economy.levels_cleared == 0, "corrupt file -> defaults")
	f = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string('{"hints": "lots", "ads_removed": "yes", "best_stars": {"x": 3, "2": 9}, "purchased": [1, "remove_ads"]}')
	f.close()
	economy.load_data()
	check(economy.get_hints() == 3 and economy.get_stars(2) == 3 and economy.best_stars.size() == 1, "bad fields sanitized")
	check(not economy.is_ads_removed(), "non-bool ads_removed -> false")
	check(economy.purchased == ["remove_ads"], "non-string ids dropped")
	economy.reset_for_tests()
	check(not FileAccess.file_exists(TEST_SAVE) and not FileAccess.file_exists("user://save.json"), "economy never writes save.json")


func test_daily_puzzle() -> void:
	economy.reset_for_tests()
	fake_today = "2026-11-22"
	# Deterministic per date, inside levels 151..1000, and different on other days.
	var today_index: int = economy.daily_puzzle_index(1000)
	check(today_index == economy.daily_puzzle_index(1000), "daily puzzle: same index for the same date")
	var copy: Node = load("res://services/economy.gd").new()
	copy.today_provider = func() -> String: return "2026-11-22"
	check(copy.daily_puzzle_index(1000) == today_index, "daily puzzle: a fresh Economy (restart) picks the same level")
	copy.free()
	var seen := {}
	for day in 850:
		fake_today = Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string("2026-01-01") + day * 86400)
		var index: int = economy.daily_puzzle_index(1000)
		check(index >= 150 and index <= 999, "daily puzzle: %d in levels 151..1000 on %s" % [index, fake_today])
		seen[index] = true
	check(seen.size() == 850, "daily puzzle: 850 consecutive days never repeat a level (%d distinct)" % seen.size())
	fake_today = "2026-11-22"
	var small: int = economy.daily_puzzle_index(10)
	check(small >= 0 and small < 10, "daily puzzle: a small pack uses its whole range")
	check(economy.daily_puzzle_index(0) == 0, "daily puzzle: empty pack does not crash")
	# Completion: once per day, +2 hints, streak.
	check(not economy.is_daily_puzzle_done() and economy.daily_puzzle_streak_count() == 0, "daily puzzle: fresh state")
	var hints: int = economy.get_hints()
	check(economy.complete_daily_puzzle() == 2 and economy.get_hints() == hints + 2, "daily puzzle: first win grants 2")
	check(economy.is_daily_puzzle_done() and economy.daily_puzzle_streak_count() == 1, "daily puzzle: done, streak 1")
	check(economy.complete_daily_puzzle() == 0 and economy.get_hints() == hints + 2, "daily puzzle: replay grants nothing")
	check(economy.can_claim_daily(), "daily puzzle does not claim the daily gift")
	fake_today = "2026-11-23"
	check(not economy.is_daily_puzzle_done() and economy.daily_puzzle_streak_count() == 1, "daily puzzle: next day open, streak kept")
	check(economy.complete_daily_puzzle() == 2 and economy.daily_puzzle_streak_count() == 2, "daily puzzle: streak continues")
	fake_today = "2026-11-24"
	check(economy.complete_daily_puzzle() == 2 and economy.daily_puzzle_streak == 3, "daily puzzle: third day")
	# Month and year boundaries are consecutive days.
	economy.daily_puzzle_last = "2026-12-31"
	fake_today = "2027-01-01"
	check(economy.complete_daily_puzzle() == 2 and economy.daily_puzzle_streak == 4, "daily puzzle: streak across new year")
	# A missed day: the shown streak drops to 0 and the next solve starts over at 1.
	fake_today = "2027-01-03"
	check(economy.daily_puzzle_streak_count() == 0, "daily puzzle: gap hides the old streak")
	check(economy.complete_daily_puzzle() == 2 and economy.daily_puzzle_streak_count() == 1, "daily puzzle: gap resets streak")
	# Backward dates (clock moved back) count as done and grant nothing.
	hints = economy.get_hints()
	for day in ["2027-01-02", "2026-06-01"]:
		fake_today = day
		check(economy.is_daily_puzzle_done() and economy.complete_daily_puzzle() == 0,
			"daily puzzle: %s before the last solve grants nothing" % day)
	check(economy.get_hints() == hints and economy.daily_puzzle_last == "2027-01-03" and economy.daily_puzzle_streak == 1,
		"daily puzzle: backward dates leave state unchanged")
	fake_today = "2027-01-04"
	check(economy.complete_daily_puzzle() == 2 and economy.daily_puzzle_streak == 2, "daily puzzle: next real day continues")
	# Persisted with the rest of economy.json.
	copy = load("res://services/economy.gd").new()
	copy.save_path = TEST_SAVE
	copy.today_provider = func() -> String: return "2027-01-04"
	copy.load_data()
	check(copy.daily_puzzle_last == "2027-01-04" and copy.daily_puzzle_streak == 2 and copy.is_daily_puzzle_done(),
		"daily puzzle: reload keeps last date and streak")
	copy.free()
	var file := FileAccess.open(TEST_SAVE, FileAccess.READ)
	var saved = JSON.parse_string(file.get_as_text())
	file.close()
	check(saved.daily_puzzle_last == "2027-01-04" and int(saved.daily_puzzle_streak) == 2, "daily puzzle: keys in economy.json")
	# Older saves without the keys (or with bad values) load as never solved.
	for text in ['{"hints": 4, "streak": 2}', '{"daily_puzzle_last": 5, "daily_puzzle_streak": "x"}', '{"daily_puzzle_last": "x", "last_daily": "zzz"}']:
		file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		economy.load_data()
		check(economy.daily_puzzle_last == "" and economy.daily_puzzle_streak == 0 and not economy.is_daily_puzzle_done(),
			"daily puzzle: backward compatible load of %s" % text)
		check(economy.get_hints() == int(JSON.parse_string(text).get("hints", 3)), "daily puzzle: other fields load from %s" % text)
		check(economy.last_daily == "" and economy.can_claim_daily(), "junk dates are dropped on load: %s" % text)
	economy.reset_for_tests()
	fake_today = "2026-03-01"


func test_ads() -> void:
	ads.rewarded_finished.connect(func(placement: String, rewarded: bool) -> void: rewarded_events.append([placement, rewarded]))
	ads.interstitial_closed.connect(func() -> void: interstitial_closes += 1)
	check(ads.rewarded_ads_enabled() and ads.is_rewarded_ready(), "mock rewarded ready in debug")
	fake_now = 0.0
	ads.reset_for_tests()
	fake_now = 1000.0
	var shown := []
	for total in range(1, 13):
		fake_now += 1000.0
		if ads.on_level_cleared(total):
			shown.append(total)
		await frames(1)
	check(shown == [8, 12], "first interstitial at 8 clears, then every 4: %s" % [shown])
	await frames()
	check(interstitial_closes == 2, "interstitial_closed emitted")
	# 180 s between interstitials.
	for total in range(13, 17):
		fake_now += 10.0
		check(not ads.on_level_cleared(total), "too soon after interstitial (%d)" % total)
	fake_now += 140.0
	check(ads.on_level_cleared(17), "allowed after 180 s")
	await frames()

	# Rewarded: on_reward once, finish signal, then 120 s interstitial cool-down.
	fake_now += 1000.0
	check(ads.show_rewarded("hint", func() -> void: reward_calls += 1), "show rewarded")
	check(not ads.is_rewarded_ready() and not ads.show_rewarded("hint", func() -> void: reward_calls += 100), "no second show while showing")
	await frames()
	check(reward_calls == 1, "on_reward called exactly once")
	check(rewarded_events == [["hint", true]], "rewarded_finished(hint, true)")
	check(ads.last_rewarded_time == fake_now and ads.is_rewarded_ready(), "rewarded time recorded and reloaded")
	for total in range(18, 22):
		fake_now += 15.0
		check(not ads.on_level_cleared(total), "no interstitial within 120 s of rewarded (%d)" % total)
	fake_now += 61.0
	check(ads.on_level_cleared(22), "interstitial after rewarded cool-down")
	await frames()
	ads.backend.mock_fail_next = true
	check(ads.show_rewarded("revive", func() -> void: reward_calls += 1), "show failing rewarded")
	await frames()
	check(reward_calls == 1 and rewarded_events.back() == ["revive", false], "skipped rewarded gives nothing")

	# 60 s after app start.
	fake_now = 5000.0
	ads.reset_for_tests()
	fake_now += 30.0
	for total in range(30, 40):
		check(not ads.on_level_cleared(total), "no interstitial in first minute")
	fake_now += 31.0
	check(ads.on_level_cleared(40), "interstitial after first minute")
	await frames()

	# Remove-ads blocks interstitials but keeps opt-in rewarded.
	economy.set_ads_removed(true)
	fake_now += 10000.0
	for total in range(41, 60):
		check(not ads.on_level_cleared(total), "ads_removed blocks interstitial")
	check(ads.rewarded_ads_enabled() and ads.is_rewarded_ready(), "rewarded stays available with ads removed")
	check(ads.show_rewarded("hint", func() -> void: reward_calls += 1), "rewarded shows with ads removed")
	await frames()
	check(reward_calls == 2, "reward granted with ads removed")
	check(ads.can_show_privacy_options(), "mock exposes privacy options")
	ads.request_consent()
	economy.reset_for_tests()


## rewarded_ready_changed follows every change of is_rewarded_ready() (mock backend).
func test_ads_ready_signal() -> void:
	var ready_events: Array = []
	var record := func(ready: bool) -> void: ready_events.append(ready)
	ads.rewarded_ready_changed.connect(record)
	economy.set_ads_removed(false)
	fake_now += 100000.0
	ads.reset_for_tests()
	fake_now += 1000.0
	var shown := false
	for i in 4:
		shown = ads.on_level_cleared(100 + i)
	check(shown, "interstitial shown for ready-signal test")
	check(ready_events == [false] and not ads.is_rewarded_ready(), "interstitial start emits ready=false: %s" % [ready_events])
	await frames()
	check(ready_events.back() == true and ads.is_rewarded_ready(), "interstitial close emits ready=true: %s" % [ready_events])

	ready_events.clear()
	check(ads.show_rewarded("hint", func() -> void: pass), "rewarded shows")
	check(ready_events == [false], "rewarded start emits ready=false")
	await frames()
	check(ready_events.back() == true and ads.is_rewarded_ready(), "rewarded close emits ready=true: %s" % [ready_events])

	# A rewarded load result arriving under an interstitial must not report ready.
	ready_events.clear()
	fake_now += 1000.0
	for i in 4:
		ads.on_level_cleared(200 + i)
	ads._backend_rewarded_loaded(true)
	check(ready_events == [false, false], "load during interstitial reports not ready: %s" % [ready_events])
	await frames()
	check(ready_events.back() == true, "ready again after interstitial")
	ads.rewarded_ready_changed.disconnect(record)
	economy.reset_for_tests()


func test_iap() -> void:
	iap.purchase_completed.connect(func(id: String) -> void: completed.append(id))
	iap.purchase_failed.connect(func(id: String, message: String) -> void: failed.append([id, message]))
	await frames()
	check(iap.is_available(), "mock billing available in debug")
	check(iap.get_price("hints_10") == "₺19,99" and iap.get_title("remove_ads") == "Remove Ads", "fallback price/title")
	iap._backend_products({"hints_10": {"price": "$0.99", "title": "10 Hints (Store)"}, "bogus": {}})
	check(iap.get_price("hints_10") == "$0.99" and iap.get_title("hints_10") == "10 Hints (Store)", "store price wins")
	check(iap.get_price("hints_30") == "₺44,99", "fallback when store has none")

	iap.purchase("hints_10")
	iap.purchase("hints_30")
	check(failed.back() == ["hints_30", "busy"], "concurrent purchase rejected")
	await frames()
	check(economy.get_hints() == 13 and completed == ["hints_10"], "hints_10 adds 10")
	iap.purchase("remove_ads")
	await frames()
	check(economy.is_ads_removed() and iap.owns("remove_ads") and economy.get_hints() == 18, "remove_ads owned, ads removed, +5")
	iap.purchase("remove_ads")
	check(failed.back() == ["remove_ads", "already_owned"], "non-consumable cannot be bought twice")

	# Duplicate delivery of the same token is granted once.
	iap._backend_purchase_succeeded("hints_30", "dup-token")
	iap._backend_purchase_succeeded("hints_30", "dup-token")
	check(economy.get_hints() == 48 and completed.count("hints_30") == 1, "duplicate token not double-granted")

	# Restore without data loss: ownership kept, no hint re-grant.
	iap.restore_purchases()
	await frames()
	check(iap.owns("remove_ads") and economy.get_hints() == 48, "restore keeps ownership, no re-grant")
	# Reinstall: local data wiped, store still has remove_ads.
	economy.reset_for_tests()
	iap.restore_purchases()
	await frames()
	check(iap.owns("remove_ads") and economy.is_ads_removed(), "restore re-applies ownership after reinstall")
	check(not iap.owns("hints_10"), "consumables are never owned")

	var before: int = economy.get_hints()
	iap.backend.mock_fail_next = true
	iap.purchase("hints_30")
	await frames()
	check(failed.back() == ["hints_30", "mock_failure"] and economy.get_hints() == before, "failure emits purchase_failed")
	iap.purchase("nope")
	check(failed.back() == ["nope", "unknown_product"], "unknown product")
	iap.purchase("supporter_pack")
	await frames()
	check(iap.owns("supporter_pack") and economy.get_hints() == before + 40, "supporter pack")


## Regression: no interstitial is loaded once "remove ads" is owned; un-removing reloads.
func test_ads_removed_no_interstitial_loads() -> void:
	economy.reset_for_tests()
	economy.set_ads_removed(false)
	var mock: Object = ads.backend
	fake_now += 100000.0
	ads.reset_for_tests()
	fake_now += 1000.0
	for i in ads.INTERSTITIAL_EVERY_CLEARS:
		ads.on_level_cleared(300 + i)
	check(ads._interstitial_showing, "ads_removed_no_loads: interstitial showing")
	economy.set_ads_removed(true)   # bought while the ad is up
	var loads: int = mock.interstitial_loads
	await frames()   # mock closes it
	check(mock.interstitial_loads == loads, "ads_removed_no_loads: no reload after close once ads removed")
	check(not ads._backend_wants_interstitial(), "ads_removed_no_loads: backend told not to load")
	fake_now += 10000.0
	for i in 8:
		ads.on_level_cleared(400 + i)
	check(mock.interstitial_loads == loads, "ads_removed_no_loads: wins do not load interstitials")
	# A fresh Ads node starting with ads already removed never preloads one.
	var fresh: Node = load("res://services/ads.gd").new()
	root.add_child(fresh)
	check(fresh.backend.interstitial_loads == 0, "ads_removed_no_loads: no preload at startup")
	fresh.free()
	economy.set_ads_removed(false)
	check(mock.interstitial_loads == loads + 1, "ads_removed_no_loads: ads back -> interstitial reloaded")
	economy.reset_for_tests()


func test_iap_regressions() -> void:
	economy.reset_for_tests()
	await frames()

	# _grant saves the hints BEFORE marking the token (a crash in between must not lose the pack).
	var seen_at_hint_save := []
	var probe := func(_count: int) -> void:
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
		seen_at_hint_save.append([economy.token_seen("order-tok"), int(saved.hints)])
	economy.hints_changed.connect(probe)
	var before: int = economy.get_hints()
	iap._backend_purchase_succeeded("hints_10", "order-tok")
	economy.hints_changed.disconnect(probe)
	check(seen_at_hint_save == [[false, before + 10]], "grant_hints_before_token: hints saved before token marked: %s" % [seen_at_hint_save])
	check(economy.token_seen("order-tok") and economy.get_hints() == before + 10, "grant_hints_before_token: both applied")

	# Store going away mid-purchase releases "busy".
	failed.clear()
	iap._pending = "hints_30"
	iap._backend_availability(false)
	check(iap._pending.is_empty() and failed.back() == ["hints_30", "unavailable"], "iap_unavailable_clears_pending")
	iap._backend_availability(true)
	iap.purchase("hints_10")
	check(failed.back() != ["hints_10", "busy"], "iap_unavailable_clears_pending: next purchase not busy")
	await frames()

	# Pending payment clears busy.
	iap._pending = "hints_30"
	iap._backend_purchase_failed("hints_30", "pending")
	check(iap._pending.is_empty() and failed.back() == ["hints_30", "pending"], "iap_pending_clears_busy")

	# App resume re-queries owned purchases (background / promo-code purchases).
	var restored := [0]
	var count_restore := func() -> void: restored[0] += 1
	iap.products_updated.connect(count_restore)
	iap.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await frames()
	check(restored[0] == 1, "iap_resume_restores: restore on resume")
	iap._available = false
	iap.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await frames()
	check(restored[0] == 1, "iap_resume_restores: not while unavailable")
	iap._available = true
	iap.products_updated.disconnect(count_restore)
