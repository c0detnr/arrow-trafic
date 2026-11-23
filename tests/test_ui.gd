extends SceneTree

# Run with XDG_DATA_HOME=$(mktemp -d) godot --headless --script tests/test_ui.gd
# A failed assert does not change the exit code of a --script run, so every check goes through
# check(), which counts failures; the run exits 1 when any failed (or when it hangs).

var failures := 0


func _initialize():
	if FileAccess.file_exists("user://save.json"):
		printerr("Use an empty XDG_DATA_HOME for this UI test.")
		quit(1)
		return
	create_timer(900.0).timeout.connect(func():
		printerr("test_ui: timed out (a check probably aborted the coroutine)")
		quit(1))
	call_deferred("run")


func check(cond, msg := "") -> void:
	if cond:
		return
	failures += 1
	var stack := get_stack()
	var where: String = "line %d" % stack[1].line if stack.size() > 1 else "?"
	printerr("FAIL test_ui (%s)%s" % [where, (": " + msg) if msg else ""])

func frames(n := 3) -> void:
	for i in n:
		await process_frame

func center_of(game, i: int) -> Vector2:
	return game.origin + (Vector2(game.Logic.head(game.s.arrows[i])) + Vector2.ONE * 0.5) * game.cell

## Taps exitable arrows (mismatching the queue first) until the pocket overflows.
func lose(game) -> void:
	game.s.cap = 0
	while game.s.status == "playing":
		var pick := -1
		for i in game.s.arrows.size():
			if game.Logic.can_exit(game.s, i) and (pick == -1 or game.s.queue.is_empty() or game.s.arrows[i].color != game.s.queue[0]):
				pick = i
		check(pick != -1)
		game._tap(center_of(game, pick))

func run():
	var economy: Node = root.get_node("Economy")
	var ads: Node = root.get_node("Ads")
	var iap: Node = root.get_node("IAP")
	economy.today_provider = func() -> String: return "2026-03-01"
	economy.reset_for_tests()
	# A frozen clock keeps every interstitial inside the "first minute" guard.
	ads.clock = func() -> float: return 0.0
	ads.reset_for_tests()
	var legacy_save := FileAccess.open("user://save.json", FileAccess.WRITE)
	check(legacy_save)
	legacy_save.store_string('{"level":0}')
	legacy_save.close()
	var game = load("res://main.tscn").instantiate()
	check(game.language == OS.get_locale_language())
	game.language = "tr"
	root.add_child(game)
	check(game.theme_name == "dark")
	check(game.vibration_on and game.sound_on, "a save without toggle keys means vibration and sound on")
	check(game.home_screen.visible and not game.settings_veil.visible)
	check(game.home_level.text == "Bölüm 01" and game.home_screen.color == game.palette.cream)
	check(game.mascot.position == game.home_art.position)
	check(game.mascot.scale.x > 1.5 and game.mascot.z_index > game.home_screen.z_index)
	for native_size in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(768, 1024)]:
		var logical_size := Vector2i(maxi(720, roundi(native_size.x * 1280.0 / native_size.y)), maxi(1280, roundi(native_size.y * 720.0 / native_size.x)))
		root.size = logical_size
		await process_frame
		game._layout()
		var screen := Rect2(Vector2.ZERO, Vector2(logical_size))
		var scale_factor := float(native_size.x) / logical_size.x
		for control in [game.home_title, game.home_level, game.play_button, game.settings_button, game.shop_button, game.daily_button,
				game.hint_button, game.levels_button, game.daily_puzzle_button]:
			check(screen.encloses(control.get_rect()))
		for button in [game.play_button, game.settings_button, game.theme_button, game.settings_close, game.shop_button,
				game.daily_button, game.hint_button, game.restore_button, game.privacy_button, game.shop_close, game.revive_ad_button,
				game.revive_hint_button, game.panel_retry, game.levels_button, game.vibration_button, game.sound_button,
				game.levels_close, game.levels_prev, game.levels_next, game.level_tiles[0], game.daily_puzzle_button]:
			check(button.get_combined_minimum_size().x * scale_factor >= 44 and button.get_combined_minimum_size().y * scale_factor >= 44,
				"%s too small at %s" % [button.accessibility_name, native_size])
		check(game.hint_button.size.x * scale_factor >= 44 and game.hint_button.size.y * scale_factor >= 44)
		check(game.daily_button.visible and game.daily_button.text == "Günlük hediye: +1 ipucu")
		check(game.home_title.get_rect().end.y < game.home_art.position.y - 220 * game.home_art.scale.y)
		check(game.home_art.position.y + 220 * game.home_art.scale.y < game.daily_button.position.y)
		check(game.daily_button.get_rect().end.y < game.home_level.position.y)
		# Daily puzzle entry: between the gift row and the level label, its own row, never clipped.
		check(game.daily_puzzle_button.visible and game.daily_puzzle_button.text == "Günün bulmacası")
		check(game.daily_puzzle_button.size.y * scale_factor >= 44, "daily puzzle entry too short at %s" % native_size)
		check(game.daily_button.get_rect().end.y < game.daily_puzzle_button.position.y)
		check(game.daily_puzzle_button.get_rect().end.y < game.home_level.position.y)
		check(game.home_art.position.y + 220 * game.home_art.scale.y < game.daily_puzzle_button.position.y)
		check(game.daily_puzzle_button.size.x >= game.daily_puzzle_button.get_combined_minimum_size().x, "daily puzzle label fits")
		check(game.shop_button.get_rect().end.x < game.settings_button.position.x)
		check(game.levels_button.get_rect().end.x < game.shop_button.position.x)
		check(game.levels_button.get_rect().end.y < game.home_title.position.y)
		# HUD: hint | home | restart, with the longest title still clear of the hint button.
		check(game.hint_button.get_rect().end.x < game.home_button.position.x)
		var badge_end: float = game.hint_button.position.x + game.hint_badge.position.x + game.hint_badge.size.x
		check(badge_end < game.home_button.position.x)
		for title in ["Bölüm 1000", "Level 1000"]:
			var title_width: float = game.DISPLAY_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, game._title_font_size(title)).x
			check(game.left + title_width < game.hint_button.position.x + game.HINT_INSET)
		game.shop_button.pressed.emit()
		await process_frame
		check(game.shop_veil.visible and screen.encloses(game.shop_panel.get_global_rect()))
		check(game.shop_scroll.get_rect().size.y >= game.shop_list.get_combined_minimum_size().y)
		check(game.play_button.focus_mode == Control.FOCUS_NONE)
		var close_shop := InputEventAction.new()
		close_shop.action = "ui_cancel"
		close_shop.pressed = true
		game._unhandled_input(close_shop)
		check(not game.shop_veil.visible and game.get_viewport().gui_get_focus_owner() == game.shop_button)
		check(game.play_button.size.x == minf(logical_size.x - 108, 780))
		game.settings_button.pressed.emit()
		await process_frame
		check(screen.encloses(game.settings_panel.get_global_rect()))
		check(game.get_viewport().gui_get_focus_owner() == game.theme_button)
		check(game.play_button.focus_mode == Control.FOCUS_NONE)
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		game._unhandled_input(cancel)
		check(not game.settings_veil.visible)
		check(game.get_viewport().gui_get_focus_owner() == game.settings_button)
		game.levels_button.pressed.emit()
		await process_frame
		check(game.levels_veil.visible and screen.encloses(game.levels_panel.get_global_rect()), "level select fits %s" % native_size)
		var last_tile: Button = game.level_tiles.back()
		check(game.levels_panel.get_global_rect().encloses(last_tile.get_global_rect()))
		check(game.levels_panel.get_global_rect().encloses(game.levels_next.get_global_rect()))
		check(game.get_viewport().gui_get_focus_owner() == game.level_tiles[game.idx % game.LEVELS_PER_PAGE])
		check(game.play_button.focus_mode == Control.FOCUS_NONE)
		game._unhandled_input(cancel)
		check(not game.levels_veil.visible and game.get_viewport().gui_get_focus_owner() == game.levels_button)
		check(game.play_button.focus_mode == Control.FOCUS_ALL)
	root.size = Vector2i(720, 1280)
	game.play_button.pressed.emit()
	check(not game.home_screen.visible)
	game.start(0)
	check(game.retry.icon and game.retry.accessibility_name == "Yeniden başlat")
	check(game.home_button.text.is_empty() and game.home_button.icon == preload("res://assets/home.svg"))
	check(game.home_button.accessibility_name == "Ana ekran")
	check(game.get_node_or_null("Mascot") == game.mascot and game.mascot.is_visible_in_tree())
	check(game.mascot_state == "idle")
	await process_frame
	check(game.tray.has_point(game.origin))
	# Native logical viewports cover portrait phones, tablets and a wide desktop.
	for viewport_size in [Vector2i(720, 1280), Vector2i(720, 1559), Vector2i(960, 1280), Vector2i(2048, 1280)]:
		root.size = viewport_size
		for level in game.levels.size():
			game.start(level)
			await process_frame
			game._layout()
			check(game.cell > 0)
			check(game.tray.position.y >= 375)
			check(game.tray.end.y < game.pocket_y - 54)
			check(game.retry.position.x >= game.left + 290)
			for title in ["Bölüm %02d" % (level + 1), "Bölüm 1000"]:
				var title_width: float = game.DISPLAY_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, game._title_font_size(title)).x
				check(game.left + title_width < game.hint_button.position.x + game.HINT_INSET)
			check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(game.hint_button.get_rect()))
			check(game.hint_button.get_rect().end.x < game.home_button.position.x)
			check(game.mascot.position == Vector2(viewport_size.x * 0.5, game.pocket_y - 28))
			check(game.mascot.scale == Vector2.ONE * 1.5)
			# Win expansion and next-board entry are separate animation phases.
			var board_bottom: float = maxf(game.tray.get_center().y + game.tray.size.y * 0.52, game.tray.end.y + 18)
			check(game.mascot.position.y - (17 + 4) * 1.5 > board_bottom)
			# 28px covers breathing/wobble; a landing circle reaches pocket_y + 4.
			check(game.mascot.position.y + 28 < game.pocket_y + 4)
			var pocket_heading_width: float = game.BODY_FONT.get_string_size("Geçici cep", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			check(game.left + 40 + pocket_heading_width < game.mascot.position.x - 40)
			var capacity_width: float = game.BODY_FONT.get_string_size("%d / %d" % [game.s.cap, game.s.cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			check(viewport_size.x - game.left - capacity_width > game.mascot.position.x + 40)
			check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(game.panel.get_rect()))
	root.size = Vector2i(720, 1280)
	# Keep the scripted win and loss independent of the generated level pack.
	game.levels = JSON.parse_string(FileAccess.get_file_as_string("res://levels/proto.json"))
	game.start(1)
	var blocked = game.s.arrows[1]
	check(not game.Logic.can_exit(game.s, 1))
	game._tap(game.origin + (Vector2(game.Logic.head(blocked)) + Vector2.ONE * 0.5) * game.cell)
	check(game.mascot_state == "blocked")
	await game.mascot_tween.finished
	check(game.mascot_state == "idle" and is_zero_approx(game.mascot.rotation))
	game.start(0)
	game.s.cap = 2
	var a = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(a)) + Vector2.ONE * 0.5) * game.cell)
	check(game.s.pocket == ["purple"] and game.mascot_state == "worried")
	var dark_background: Color = game.palette.cream
	var current_state: Dictionary = game.s.duplicate(true)
	var current_nodes: Dictionary = game.nodes.duplicate()
	game.home_button.pressed.emit()
	check(game.home_screen.visible)
	a = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(a)) + Vector2.ONE * 0.5) * game.cell)
	check(game.s == current_state and game.nodes == current_nodes)
	game.settings_button.pressed.emit()
	check(game.settings_panel.is_visible_in_tree() and game.theme_button.text == "Açık tema")
	# Focus rings: hidden after a tap (phones), back on a key press; a restyle keeps the mode.
	var focused: Control = game.get_viewport().gui_get_focus_owner()
	check(focused == game.theme_button and not game.touch_mode, "desktop runs start in keyboard mode")
	check(focused.get_theme_stylebox("focus") is StyleBoxFlat)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(-10, -10)
	game._input(touch)
	check(game.touch_mode and focused.get_theme_stylebox("focus") is StyleBoxEmpty, "no focus ring after a tap")
	for button in [game.play_button, game.home_button, game.shop_button, game.level_tiles[0]]:
		check(button.get_theme_stylebox("focus") is StyleBoxEmpty)
	game.theme_button.pressed.emit()
	check(game.theme_name == "light" and game.palette.cream != dark_background)
	check(game.get_viewport().gui_get_focus_owner() == game.theme_button)
	check(game.theme_button.get_theme_stylebox("focus") is StyleBoxEmpty, "a theme change keeps rings hidden in touch mode")
	var arrow_key := InputEventKey.new()
	arrow_key.keycode = KEY_DOWN
	arrow_key.pressed = true
	game._input(arrow_key)
	var ring := game.theme_button.get_theme_stylebox("focus") as StyleBoxFlat
	check(not game.touch_mode and ring and ring.border_width_top == 3 and ring.border_color == game.palette.ink, "ring back after a key")
	check(game.shop_button.get_theme_stylebox("focus") is StyleBoxFlat)
	check(game.theme_button.text == "Koyu tema" and game.home_screen.color == game.palette.cream)
	check(game.play_button.get_theme_color("font_focus_color") == game.palette.cream)
	check(game.settings_button.get_theme_color("icon_focus_color") == game.palette.ink)
	check(game.settings_close.get_theme_color("font_focus_color") == game.palette.ink)
	check(game.settings_veil.color == game.palette.veil)
	check(game.settings_panel.get_theme_stylebox("panel").bg_color == game.palette.surface)
	check(game.s == current_state and game.nodes == current_nodes)
	var save: Dictionary = game._load_save()
	check(save.level == 0 and save.theme == "light")
	game.settings_close.pressed.emit()
	check(not game.settings_panel.is_visible_in_tree() and game.home_screen.visible)
	game.play_button.pressed.emit()
	check(not game.home_screen.visible and game.s == current_state and game.nodes == current_nodes)
	a = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(a)) + Vector2.ONE * 0.5) * game.cell)
	check(game.s.pocket.is_empty() and game.mascot_state == "idle")
	# Review hook: a spy stands in for the Review autoload (if any) during this win.
	var real_review: Node = root.get_node_or_null("Review")
	if real_review:
		root.remove_child(real_review)
	var review_spy := Node.new()
	review_spy.name = "Review"
	review_spy.set_script(_review_spy_script())
	root.add_child(review_spy)
	while game.s.status == "playing":
		var moved := false
		for i in game.s.arrows.size():
			if game.Logic.can_exit(game.s, i):
				game._tap(game.origin + (Vector2(game.Logic.head(game.s.arrows[i])) + Vector2.ONE * 0.5) * game.cell)
				moved = true
				break
		check(moved)
	check(game.s.status == "won" and game.input_locked and game.retry.disabled)
	check(economy.get_stars(0) == economy.stars_for(game.s.mistakes) and game.win_stars == economy.get_stars(0))
	check(economy.levels_cleared == 1 and game.hint_button.disabled)
	check(game.mascot_state == "win")
	check(not game.panel.visible and not game.veil.visible and game.celebration == 0.0)
	while game.idx == 0:
		await process_frame
		check(not game.panel.visible and not game.veil.visible and game.input_locked)
	check(game.idx == 1 and game.input_locked and game.retry.disabled)
	check(game.mascot_state == "idle")
	var next_arrow = game.s.arrows[0]
	var next_tap = game.origin + (Vector2(game.Logic.head(next_arrow)) + Vector2.ONE * 0.5) * game.cell
	var next_state = game.s.duplicate(true)
	game._tap(next_tap)
	check(game.s == next_state)
	await game.win_tween.finished
	check(review_spy.calls == [[economy.levels_cleared, economy.get_stars(0)]], "review hook after a win: %s" % [review_spy.calls])
	root.remove_child(review_spy)
	review_spy.free()
	game._maybe_request_review(3)  # no Review node at all: nothing happens
	if real_review:
		root.add_child(real_review)
		game._maybe_request_review(1)  # the real service applies its own rules
	check(game.idx == 1 and not game.panel.visible and not game.veil.visible)
	check(not game.input_locked and not game.retry.disabled and not game.hint_button.disabled)
	check(ads.backend.shown_interstitials == 0)
	save = game._load_save()
	check(save.level == 1 and save.theme == "light")
	var restored = load("res://main.tscn").instantiate()
	restored.language = "tr"
	root.add_child(restored)
	check(restored.idx == 1 and restored.palette.cream == game.palette.cream)
	check(restored.home_screen.visible and restored.home_level.text == "Bölüm 02 · ★ %d" % economy.total_stars())
	restored.queue_free()
	game.retry.pressed.emit()
	check(game.idx == 1 and game.s.mistakes == 0 and game.s.pocket.is_empty())
	# Force a full pocket with a real mismatch to cover the loss panel and retry.
	game.start(0)
	game.s.cap = 0
	var wrong = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(wrong)) + Vector2.ONE * 0.5) * game.cell)
	check(game.s.status == "lost" and game.panel.visible and game.veil.visible)
	game.retry.pressed.emit()
	check(game.s.status == "playing" and not game.veil.visible)
	await monetization(game, economy, ads)
	await level_select(game, economy)
	await settings_toggles(game)
	await interstitial_timing(game, economy, ads)
	await revive_to_winnable(game)
	await daily_puzzle(game, economy, ads)
	purchase_messages(game)
	game.queue_free()
	await process_frame
	var english = load("res://main.tscn").instantiate()
	english.language = "en"
	root.add_child(english)
	check(english.home_level.text == "Level 01 · ★ %d" % economy.total_stars() and english.play_button.text == "Play")
	check(english.shop_title.text == "Shop" and english.revive_ad_button.accessibility_name == "Watch ad · Undo")
	check(english.daily_puzzle_button.text.begins_with("Daily puzzle"), english.daily_puzzle_button.text)
	for key in english.ENGLISH_TEXT:
		check(english._localized(key) == english.ENGLISH_TEXT[key])
	check(not ProjectSettings.get_setting("application/config/quit_on_go_back"))
	english.settings_button.pressed.emit()
	check(english.settings_veil.visible and english.settings_title.text == "Settings")
	english.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(english.home_screen.visible and not english.settings_veil.visible)
	english.play_button.pressed.emit()
	check(not english.home_screen.visible and english.home_button.accessibility_name == "Home")
	english.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(english.home_screen.visible)
	if failures > 0:
		printerr("test_ui: %d check(s) failed" % failures)
		quit(1)
		return
	print("test_ui: OK (all levels, four viewports, win/loss/retry, theme, save, mascot, locale, back, hints, revive, shop, daily, level select, toggles, review hook, interstitial timing, winnable revive, pending purchase)")
	create_timer(1.0).timeout.connect(func():
		printerr("Android back on Home did not quit.")
		quit(1))
	english.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


func monetization(game, economy: Node, ads: Node) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	# Hint: spends one, highlights an exitable arrow, never charges twice for the same hint.
	game.start(0)
	await process_frame
	var hints: int = economy.get_hints()
	check(hints > 0 and game.hint_button.visible and not game.hint_button.disabled)
	check(game.hint_badge_label.visible and game.hint_badge_label.text == str(hints))
	game.hint_button.pressed.emit()
	check(economy.get_hints() == hints - 1 and game.hinted_id != -1)
	check(game.hint_badge_label.text == str(hints - 1))
	game.hint_button.pressed.emit()
	check(economy.get_hints() == hints - 1)
	var hinted := -1
	for i in game.s.arrows.size():
		if int(game.s.arrows[i].id) == game.hinted_id:
			hinted = i
	check(hinted != -1 and game.Logic.can_exit(game.s, hinted))
	var count: int = game.s.arrows.size()
	var mistakes: int = game.s.mistakes
	game._tap(center_of(game, hinted))
	check(game.s.arrows.size() == count - 1 and game.s.mistakes == mistakes and game.hinted_id == -1)
	check(game.history.size() == 1)
	# Dead state: no spend, a toast instead.
	game.start(0)
	var used := {}
	for a in game.s.arrows:
		used[a.color] = true
	var absent := ""
	for colour in game.palette.arrows:
		if not used.has(colour):
			absent = colour
	game.s.cap = 0
	game.s.queue.push_front(absent)
	check(game.Logic.hint(game.s) == -1)
	hints = economy.get_hints()
	game.hint_button.pressed.emit()
	check(economy.get_hints() == hints and game.hinted_id == -1)
	check(game.toast.visible and game.toast_label.text == "Buradan çıkış yok — geri al veya yeniden başlat")
	check(screen.encloses(game.toast.get_rect()))
	# Stuck nudge after three blocked taps.
	game.start(1)
	var blocked := -1
	for i in game.s.arrows.size():
		if not game.Logic.can_exit(game.s, i):
			blocked = i
	check(blocked != -1)
	for k in 3:
		game._tap(center_of(game, blocked))
	check(game.hint_nudge and game.hint_nudge.is_running() and game.blocked_streak == 0)
	await game.hint_nudge.finished
	check(game.hint_button.scale == Vector2.ONE)
	# Loss -> revive with a (mock) rewarded ad restores the state before the losing move.
	game.start(0)
	lose(game)
	check(game.s.status == "lost" and game.panel.visible and game.veil.visible)
	check(game.revive_ad_button.visible and game.revive_hint_button.visible and game.panel_retry.visible)
	check(game.hint_button.disabled)
	await process_frame
	check(screen.encloses(game.panel.get_rect()))
	check(game.panel.size.y >= game.panel.get_combined_minimum_size().y)
	var before: Dictionary = game.history.back().duplicate(true)
	count = game.s.arrows.size()
	hints = economy.get_hints()
	game.revive_ad_button.pressed.emit()
	await frames()
	check(game.s.status == "playing" and game.s.arrows.size() == count + 1 and game.s == before)
	check(not game.panel.visible and not game.veil.visible and not game.retry.disabled)
	check(economy.get_hints() == hints and not game.hint_button.disabled)
	check(game.nodes.size() == game.s.arrows.size())
	for a in game.s.arrows:
		check(game.nodes.has(a.id) and game.nodes[a.id].is_visible_in_tree())
	# Revive with a hint spends exactly one.
	lose(game)
	check(game.s.status == "lost")
	count = game.s.arrows.size()
	game.revive_hint_button.pressed.emit()
	check(economy.get_hints() == hints - 1 and game.s.status == "playing" and game.s.arrows.size() == count + 1)
	check(not game.panel.visible)
	# No hints: the badge offers an ad, the button opens the shop.
	while economy.spend_hint():
		pass
	check(game.hint_badge_icon.visible and not game.hint_badge_label.visible)
	lose(game)
	check(not game.revive_hint_button.visible and game.revive_ad_button.visible)
	game.panel_retry.pressed.emit()
	check(game.s.status == "playing")
	game.hint_button.pressed.emit()
	check(game.shop_veil.visible and game.shop_ad_button.visible and game.shop_hints_label.text == "İpuçların: 0")
	for id in game.SHOP_PRODUCTS:
		check(game.shop_rows[id].visible and not game.shop_rows[id].disabled)
	var tap_while_shop: Dictionary = game.s.duplicate(true)
	game._tap(center_of(game, 0))
	check(game.s == tap_while_shop)
	game.shop_rows["hints_10"].pressed.emit()
	await frames()
	check(economy.get_hints() == 10 and game.toast_label.text == "Teşekkürler!")
	check(game.shop_hints_label.text == "İpuçların: 10" and game.hint_badge_label.text == "10")
	game.shop_ad_button.pressed.emit()
	await frames()
	check(economy.get_hints() == 11 and ads.backend.shown_rewarded.back() == "hint")
	game.shop_rows["remove_ads"].pressed.emit()
	await frames()
	check(economy.get_hints() == 16 and economy.is_ads_removed())
	check(game.shop_rows["remove_ads"].disabled and game.shop_rows["remove_ads"].get_meta("price").text == "Satın alındı ✓")
	ads.backend.mock_fail_next = false
	var iap: Node = root.get_node("IAP")
	iap.backend.mock_fail_next = true
	game.shop_rows["hints_30"].pressed.emit()
	await frames()
	check(economy.get_hints() == 16 and game.toast_label.text == "Satın alma tamamlanmadı")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not game.shop_veil.visible and not game.home_screen.visible)
	check(game.get_viewport().gui_get_focus_owner() == game.hint_button)
	# Settings: restore purchases and privacy options.
	game.home_button.pressed.emit()
	game.settings_button.pressed.emit()
	check(game.restore_button.visible and game.privacy_button.visible)
	game.restore_button.pressed.emit()
	check(game.toast_label.text == "Satın alımlar kontrol ediliyor")
	game.settings_close.pressed.emit()
	# Daily gift: promises +3 on day 7, claims once.
	check(game.daily_button.visible and game.daily_button.text == "Günlük hediye: +1 ipucu")
	economy.streak = 6
	economy.last_daily = "2026-02-28"
	game._layout_home(Vector2(root.size))
	check(game.daily_button.text == "Günlük hediye: +3 ipucu")
	hints = economy.get_hints()
	game.daily_button.pressed.emit()
	check(economy.get_hints() == hints + 3 and economy.streak == 7 and not game.daily_button.visible)
	check(game.toast_label.text == "+3 ipucu · Seri 7 gün")
	game.daily_button.pressed.emit()
	check(economy.get_hints() == hints + 3)
	await frames(1)


func _review_spy_script() -> GDScript:
	var spy := GDScript.new()
	spy.source_code = "extends Node\nvar calls := []\nfunc maybe_request(total_cleared: int, last_stars: int) -> bool:\n\tcalls.append([total_cleared, last_stars])\n\treturn false\n"
	spy.reload()
	return spy


func level_select(game, economy: Node) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	game.levels = game._load_levels()
	check(game.levels.size() > 90, "level select tests need the full level pack")
	for i in 45:
		economy.record_clear(i, i % 4)
	game.start(40)
	game._show_home(true)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	# Opens on the page holding the current level, with that tile focused and ringed.
	game.levels_button.pressed.emit()
	await process_frame
	check(game.levels_veil.visible and game.levels_page == 1)
	check(game.levels_page_label.text == "31–60 / %d" % game.levels.size(), game.levels_page_label.text)
	check(game.levels_stars_label.text == str(economy.total_stars()))
	var current: Button = game.level_tiles[10]
	check(current.get_meta("number").text == "41" and game.get_viewport().gui_get_focus_owner() == current)
	check(current.get_theme_stylebox("normal").border_color == game.palette.accent)
	check(game.level_tiles[11].get_theme_stylebox("normal").border_width_top == 0)
	check(screen.encloses(game.levels_panel.get_global_rect()))
	# Stars: level 31 (index 30) was cleared with 2 mistakes -> 2 stars.
	var stars: Array = game.level_tiles[0].get_meta("stars")
	check(game.level_tiles[0].get_meta("star_row").visible)
	check(stars[0].self_modulate == game.palette.accent and stars[1].self_modulate == game.palette.accent and stars[2].self_modulate == game.palette.grid)
	# Index 45 is one past the last starred level (unlocked, no stars yet); 46 is locked.
	var next_open: Button = game.level_tiles[15]
	var locked: Button = game.level_tiles[16]
	check(not next_open.disabled and next_open.get_meta("star_row").visible)
	check(locked.disabled and not locked.get_meta("star_row").visible and locked.focus_mode == Control.FOCUS_NONE)
	check(locked.accessibility_name == "Bölüm 47, kilitli")
	locked.pressed.emit()
	check(game.idx == 40 and game.levels_veil.visible and game.home_screen.visible, "a locked tile does nothing")
	# Pagination.
	game.levels_next.pressed.emit()
	check(game.levels_page == 2 and game.levels_page_label.text == "61–90 / %d" % game.levels.size())
	check(game.level_tiles.all(func(tile: Button) -> bool: return tile.disabled))
	game.levels_prev.pressed.emit()
	game.levels_prev.pressed.emit()
	check(game.levels_page == 0 and game.levels_prev.disabled and not game.levels_next.disabled)
	game.levels_prev.pressed.emit()
	check(game.levels_page == 0)
	var pages: int = ceili(game.levels.size() / float(game.LEVELS_PER_PAGE))
	for k in pages + 2:
		game.levels_next.pressed.emit()
	check(game.levels_page == pages - 1 and game.levels_next.disabled)
	var last_first: int = (pages - 1) * game.LEVELS_PER_PAGE
	check(game.levels_page_label.text == "%d–%d / %d" % [last_first + 1, game.levels.size(), game.levels.size()])
	var shown: int = game.levels.size() - last_first
	if shown < game.LEVELS_PER_PAGE:
		check(game.level_tiles[shown].modulate.a == 0.0 and game.level_tiles[shown - 1].modulate.a == 1.0)
	# Back (Android) and ui_cancel close the sheet without leaving Home.
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not game.levels_veil.visible and game.home_screen.visible)
	game.levels_button.pressed.emit()
	check(game.levels_page == 1, "reopens on the current level's page")
	game._unhandled_input(cancel)
	check(not game.levels_veil.visible and game.get_viewport().gui_get_focus_owner() == game.levels_button)
	# An unlocked tile starts that level and goes to the game.
	game.levels_button.pressed.emit()
	game.level_tiles[3].pressed.emit()
	check(game.idx == 33 and not game.levels_veil.visible and not game.home_screen.visible)
	check(game.s.status == "playing" and game.s.arrows.size() == game.levels[33].arrows.size() and not game.input_locked)
	check(game._load_save().level == 33)
	check(game.get_viewport().gui_get_focus_owner() == game.home_button)
	# Never lock the player out of their saved level, even far past their stars.
	game.start(500)
	game._show_home(true)
	game.levels_button.pressed.emit()
	check(game.levels_page == 16 and not game.level_tiles[20].disabled and game.level_tiles[21].disabled)
	check(not game.level_tiles[19].disabled, "levels below the saved one stay playable")
	game._unhandled_input(cancel)
	# Works after a theme switch too.
	game._toggle_theme()
	game.levels_button.pressed.emit()
	check(game.level_tiles[20].get_theme_stylebox("normal").border_color == game.palette.accent)
	check(game.levels_panel.get_theme_stylebox("panel").bg_color == game.palette.surface)
	game._unhandled_input(cancel)
	game._toggle_theme()
	# Leave the game on level 1 for the locale checks that follow.
	game.start(0)
	game._show_home(true)


func settings_toggles(game) -> void:
	game.settings_button.pressed.emit()
	check(game.vibration_button.text == "Titreşim: Açık" and game.sound_button.text == "Ses: Açık")
	check(game.theme_button.focus_neighbor_bottom == game.theme_button.get_path_to(game.vibration_button))
	check(game.vibration_button.focus_neighbor_bottom == game.vibration_button.get_path_to(game.sound_button))
	check(game.sound_button.focus_neighbor_bottom == game.sound_button.get_path_to(game.restore_button))
	check(game.vibration_button.get_theme_stylebox("normal").bg_color == game.palette.cream)
	game.vibration_button.pressed.emit()
	game.sound_button.pressed.emit()
	check(game.vibration_button.text == "Titreşim: Kapalı" and game.sound_button.text == "Ses: Kapalı")
	var save: Dictionary = game._load_save()
	check(save.vibration == false and save.sound == false and save.level == 0)
	# Vibration off: taps request no pulse. Sound off: the win chime stays silent.
	game.settings_close.pressed.emit()
	game.play_button.pressed.emit()
	var pulses: int = game.haptic_count
	game._tap(game.origin + Vector2(-500, -500))  # off the board: nothing at all
	var blocked := -1
	for i in game.s.arrows.size():
		if not game.Logic.can_exit(game.s, i):
			blocked = i
	if blocked == -1:
		game.start(1)
		for i in game.s.arrows.size():
			if not game.Logic.can_exit(game.s, i):
				blocked = i
	check(blocked != -1)
	game._tap(center_of(game, blocked))
	check(game.haptic_count == pulses, "no vibration while it is off")
	game._play_win_chime()
	check(not game.win_sound.playing, "no chime while sound is off")
	# Persists across a reload.
	var restored = load("res://main.tscn").instantiate()
	restored.language = "tr"
	root.add_child(restored)
	check(not restored.vibration_on and not restored.sound_on)
	check(restored.vibration_button.text == "Titreşim: Kapalı" and restored.sound_button.text == "Ses: Kapalı")
	restored.queue_free()
	# Back on: pulses (25 ms blocked, 15 ms exit) and the chime play again.
	game._show_home(true)
	game.settings_button.pressed.emit()
	game.vibration_button.pressed.emit()
	game.sound_button.pressed.emit()
	check(game.vibration_on and game.sound_on and game._load_save().vibration == true and game._load_save().sound == true)
	game.settings_close.pressed.emit()
	game.play_button.pressed.emit()
	pulses = game.haptic_count
	game._tap(center_of(game, blocked))
	check(game.haptic_count == pulses + 1)
	game._play_win_chime()
	check(game.win_sound.playing, "chime plays when sound is on")
	game.win_sound.stop()
	game.start(0)
	game._show_home(true)
	await frames(1)


## Puts a review spy at /root/Review; returns [spy, real Review or null] for _remove_review_spy.
func _install_review_spy() -> Array:
	var real: Node = root.get_node_or_null("Review")
	if real:
		root.remove_child(real)
	var spy := Node.new()
	spy.name = "Review"
	spy.set_script(_review_spy_script())
	root.add_child(spy)
	return [spy, real]


func _remove_review_spy(pair: Array) -> void:
	root.remove_child(pair[0])
	pair[0].free()
	if pair[1]:
		root.add_child(pair[1])


## Ads backend whose interstitial stays open until the test closes it.
func _held_interstitial_backend() -> Object:
	var script := GDScript.new()
	script.source_code = """extends RefCounted
var shown_interstitials := 0
func initialize(_target: Object) -> void: pass
func is_rewarded_loaded() -> bool: return true
func load_rewarded() -> void: pass
func show_rewarded(_placement: String) -> void: pass
func is_interstitial_loaded() -> bool: return true
func load_interstitial() -> void: pass
func show_interstitial() -> void: shown_interstitials += 1
func request_consent() -> void: pass
func can_show_privacy_options() -> bool: return false
func show_privacy_options() -> void: pass
"""
	script.reload()
	return script.new()


func _win_current(game) -> void:
	while game.s.status == "playing":
		var moved := false
		for i in game.s.arrows.size():
			if game.Logic.can_exit(game.s, i):
				game._tap(center_of(game, i))
				moved = true
				break
		if not moved:
			break


## Makes the next on_level_cleared() pass Ads' pacing rules (public API only).
func _arm_interstitial(ads: Node, economy: Node, now: Dictionary) -> void:
	now.t += 1000.0
	for k in ads.INTERSTITIAL_EVERY_CLEARS - 1:
		ads.on_level_cleared(0)  # below the first-clears threshold: only counts the win
	var k := 500
	while economy.levels_cleared < ads.FIRST_INTERSTITIAL_AFTER_CLEARS:
		economy.record_clear(k, 0)
		k += 1


func interstitial_timing(game, economy: Node, ads: Node) -> void:
	var proto = JSON.parse_string(FileAccess.get_file_as_string("res://levels/proto.json"))
	game.levels = proto
	var real_backend: Object = ads.backend
	var fake := _held_interstitial_backend()
	var now := {"t": 0.0}
	ads.clock = func() -> float: return now.t
	ads.reset_for_tests()
	ads.backend = fake
	var ads_removed: bool = economy.is_ads_removed()
	economy.set_ads_removed(false)  # the shop test bought "remove ads"
	var review := _install_review_spy()
	# The interstitial opens only after the board has faded out, before the next level starts.
	_arm_interstitial(ads, economy, now)
	game.start(0)
	game._show_home(false)
	_win_current(game)
	check(game.s.status == "won")
	var tween: Tween = game.win_tween
	var guard := 0
	while fake.shown_interstitials == 0 and game.idx == 0 and guard < 600:
		await process_frame
		guard += 1
	check(fake.shown_interstitials == 1, "interstitial shown")
	check(game.idx == 0 and game.input_locked and game.retry.disabled, "next level waits for the ad")
	check(is_zero_approx(game.board_layer.modulate.a), "board is faded out under the ad")
	check(tween.is_valid() and not tween.is_running(), "transition paused")
	await create_timer(0.3).timeout
	check(game.idx == 0 and game.input_locked, "still waiting while the ad is open")
	ads._backend_interstitial_closed()
	await tween.finished
	check(game.idx == 1 and not game.input_locked and not game.retry.disabled)
	check(review[0].calls.is_empty(), "no review prompt after an interstitial")
	# Safety timeout: a close that never arrives cannot keep the game locked.
	game.interstitial_timeout = 0.25
	_arm_interstitial(ads, economy, now)
	game.start(0)
	_win_current(game)
	tween = game.win_tween
	guard = 0
	while fake.shown_interstitials == 1 and game.idx == 0 and guard < 600:
		await process_frame
		guard += 1
	check(fake.shown_interstitials == 2 and game.idx == 0 and game.input_locked)
	await tween.finished
	check(game.idx == 1 and not game.input_locked, "timeout released the transition")
	check(review[0].calls.is_empty())
	ads._backend_interstitial_closed()  # the late close changes nothing
	await process_frame
	check(game.idx == 1 and not game.input_locked)
	_remove_review_spy(review)
	ads.backend = real_backend
	economy.set_ads_removed(ads_removed)
	ads.clock = func() -> float: return 0.0
	ads.reset_for_tests()
	game.interstitial_timeout = 90.0
	game.start(0)
	game._show_home(true)


func revive_to_winnable(game) -> void:
	game.levels = JSON.parse_string(FileAccess.get_file_as_string("res://levels/proto.json"))
	game.start(0)
	game._show_home(false)
	var winnable: Dictionary = game.Logic.snapshot(game.s)
	var dead: Dictionary = game.Logic.snapshot(game.s)
	var used := {}
	for a in dead.arrows:
		used[a.color] = true
	for colour in game.palette.arrows:
		if not used.has(colour):
			dead.queue.push_front(colour)
			break
	dead.cap = 0
	check(game.Logic.hint(dead.duplicate(true)) == -1, "dead snapshot is unwinnable")
	# Newest snapshot is a dead end: revive skips it and drops it.
	game.history = [winnable.duplicate(true), dead.duplicate(true)]
	game.s.status = "lost"
	game._show_loss_panel()
	check(game.revive_target == 0 and game.revive_ad_button.visible)
	check(game.history[0] == winnable and game.history[1] == dead, "solver works on copies")
	game.revive_ad_button.pressed.emit()
	await frames()
	check(game.s == winnable and game.history.is_empty() and not game.panel.visible)
	# Nothing winnable: only replay is offered, and a stray revive does nothing.
	game.history = [dead.duplicate(true), dead.duplicate(true)]
	game.s.status = "lost"
	game._show_loss_panel()
	check(game.revive_target == -1 and not game.revive_ad_button.visible and not game.revive_hint_button.visible)
	check(game.panel_retry.visible)
	game.revive_ad_button.pressed.emit()
	game.revive_hint_button.pressed.emit()
	await frames()
	check(game.s.status == "lost" and game.panel.visible)
	game.panel_retry.pressed.emit()
	check(game.s.status == "playing" and not game.panel.visible)
	game.start(0)
	game._show_home(true)


## Wins the board on the board's solver path (the daily levels are too hard for _win_current).
func _solve_current(game) -> void:
	while game.s.status == "playing":
		var pick: int = game.Logic.hint(game.s)
		check(pick >= 0, "solver found a move")
		if pick < 0:
			return
		game._tap(center_of(game, pick))


## Plays today's puzzle to a win (the transition included) and returns once Home is back.
func _win_daily(game) -> void:
	_solve_current(game)
	check(game.s.status == "won")
	var tween: Tween = game.win_tween
	check(tween != null and game.input_locked)
	if tween and tween.is_valid() and tween.is_running():
		await tween.finished
	await process_frame


func daily_puzzle(game, economy: Node, ads: Node) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	game.levels = game._load_levels()
	economy.today_provider = func() -> String: return "2026-03-05"
	economy.daily_puzzle_last = ""
	economy.daily_puzzle_streak = 0
	var review := _install_review_spy()
	# A campaign board left mid-play on level 3.
	game.start(2)
	game._show_home(false)
	for i in game.s.arrows.size():
		if game.Logic.can_exit(game.s, i):
			game._tap(center_of(game, i))
			break
	var campaign_state: Dictionary = game.s.duplicate(true)
	var campaign_history: int = game.history.size()
	check(campaign_history == 1)
	game._show_home(true)
	check(game.daily_puzzle_button.is_visible_in_tree() and game.daily_puzzle_button.text == "Günün bulmacası")
	check(game.daily_puzzle_button.get_theme_color("icon_normal_color") == game.palette.accent)
	var target: int = economy.daily_puzzle_index(game.levels.size())
	check(target >= 150 and target < game.levels.size())
	# Starting it: the daily board, its title, and the saved campaign level untouched.
	game.daily_puzzle_button.pressed.emit()
	check(game.daily_mode and not game.home_screen.visible and game.idx == target)
	check(game.s.arrows.size() == game.levels[target].arrows.size() and game.history.is_empty())
	check(game._board_title() == "Günün bulmacası" and game._load_save().level == 2)
	check(game.retry.visible and game.home_button.visible and game.hint_button.visible and not game.hint_button.disabled)
	# Restart keeps the daily puzzle; hints work as usual.
	for i in game.s.arrows.size():
		if game.Logic.can_exit(game.s, i):
			game._tap(center_of(game, i))
			break
	game.retry.pressed.emit()
	check(game.daily_mode and game.idx == target and game.s.arrows.size() == game.levels[target].arrows.size())
	check(game._load_save().level == 2, "restarting the daily puzzle does not save it as the campaign level")
	var hints: int = economy.get_hints()
	game.hint_button.pressed.emit()
	check(economy.get_hints() == hints - 1 and game.hinted_id != -1)
	# Home from the daily puzzle: the campaign board is back exactly as it was.
	game.home_button.pressed.emit()
	check(game.home_screen.visible and not game.daily_mode and game.idx == 2)
	check(game.s == campaign_state and game.history.size() == campaign_history)
	check(game.home_level.text.begins_with("Bölüm 03") and game._load_save().level == 2)
	check(not economy.is_daily_puzzle_done() and game.daily_puzzle_button.text == "Günün bulmacası")
	# Android back from the daily puzzle does the same.
	game.daily_puzzle_button.pressed.emit()
	check(game.daily_mode)
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.home_screen.visible and not game.daily_mode and game.idx == 2 and game.s == campaign_state)
	# Win: +2 hints once, celebration, back Home; no stars, clears, ad pacing or review.
	var cleared: int = economy.levels_cleared
	var starred: int = economy.best_stars.size()
	var ad_wins: int = ads._wins_since_interstitial
	var shown_ads: int = ads.backend.shown_interstitials
	hints = economy.get_hints()
	game.daily_puzzle_button.pressed.emit()
	var hud_title: String = game._board_title()
	_solve_current(game)
	check(game.s.status == "won" and game.input_locked and game.mascot_state == "win" and game.win_stars == 0)
	check(economy.get_hints() == hints + 2 and economy.is_daily_puzzle_done())
	check(game.toast.visible and game.toast_label.text == "+2 ipucu · Günün bulmacası")
	check(hud_title == "Günün bulmacası")
	var tween: Tween = game.win_tween
	var celebrated := false
	var guard := 0
	while game.daily_mode and guard < 600:
		guard += 1
		celebrated = celebrated or game.celebration > 0.0
		await process_frame
	check(celebrated, "the win celebration plays for the daily puzzle")
	if tween and tween.is_valid() and tween.is_running():
		await tween.finished
	await process_frame
	check(game.home_screen.visible and not game.input_locked and not game.retry.disabled and game.win_tween == null)
	check(game.idx == 2 and game.s == campaign_state and game.history.size() == campaign_history, "campaign resumes")
	check(economy.levels_cleared == cleared and economy.best_stars.size() == starred and economy.get_stars(target) == 0,
		"no record_clear for the daily puzzle")
	check(ads._wins_since_interstitial == ad_wins and ads.backend.shown_interstitials == shown_ads,
		"daily puzzle win skips Ads.on_level_cleared")
	check(review[0].calls.is_empty(), "no review prompt after the daily puzzle")
	check(game._load_save().level == 2)
	check(game.daily_puzzle_button.text == "Günün bulmacası ✓")
	check(game.daily_puzzle_button.get_theme_color("icon_normal_color") == game.palette.muted)
	check(screen.encloses(game.toast.get_rect()) and not game.toast.get_rect().intersects(game.daily_puzzle_button.get_rect()),
		"reward toast on Home leaves the daily puzzle entry readable")
	# Replay is allowed but grants nothing.
	hints = economy.get_hints()
	game.daily_puzzle_button.pressed.emit()
	check(game.daily_mode and game.idx == target)
	await _win_daily(game)
	check(economy.get_hints() == hints and game.home_screen.visible and not game.daily_mode and game.idx == 2)
	# Next day: a new puzzle, and the streak shows once it is longer than one day.
	economy.today_provider = func() -> String: return "2026-03-06"
	game._layout_home(Vector2(root.size))
	check(game.daily_puzzle_button.text == "Günün bulmacası")
	var tomorrow: int = economy.daily_puzzle_index(game.levels.size())
	check(tomorrow != target and tomorrow >= 150)
	game.daily_puzzle_button.pressed.emit()
	check(game.idx == tomorrow)
	await _win_daily(game)
	check(economy.get_hints() == hints + 2 and game.daily_puzzle_button.text == "Günün bulmacası ✓ · 2 gün")
	check(screen.encloses(game.daily_puzzle_button.get_rect()))
	# The campaign continues afterwards: Play resumes level 3 and a win advances to level 4.
	game.play_button.pressed.emit()
	check(not game.home_screen.visible and game.idx == 2 and game.s == campaign_state and not game.daily_mode)
	_solve_current(game)
	check(game.s.status == "won" and game.win_stars > 0 and economy.get_stars(2) > 0, "campaign wins still record stars")
	# Leaving mid-transition for the daily puzzle still moves the campaign on to level 4.
	game._show_home(true)
	game.daily_puzzle_button.pressed.emit()
	check(game.daily_mode and game.win_tween == null and game._load_save().level == 3)
	game.home_button.pressed.emit()
	check(game.idx == 3 and game.s.status == "playing" and not game.input_locked and game._load_save().level == 3)
	check(game.s.arrows.size() == game.levels[3].arrows.size())
	_remove_review_spy(review)
	economy.today_provider = func() -> String: return "2026-03-01"
	game.start(0)
	game._show_home(true)


func purchase_messages(game) -> void:
	var iap: Node = root.get_node("IAP")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	iap.purchase_failed.emit("hints_10", "pending")
	check(game.toast_label.text == "Ödeme bekleniyor — onaylanınca ipuçların eklenecek")
	check(screen.encloses(game.toast.get_rect()))
	iap.purchase_failed.emit("hints_10", "unavailable")
	check(game.toast_label.text == "Mağaza şu an kullanılamıyor")
	game.toast_label.text = ""
	iap.purchase_failed.emit("hints_10", "canceled")
	check(game.toast_label.text == "")
	iap.purchase_failed.emit("hints_10", "BILLING_ERROR")
	check(game.toast_label.text == "Satın alma tamamlanmadı")
