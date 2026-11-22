extends SceneTree

# Run with XDG_DATA_HOME=$(mktemp -d) godot --headless --script tests/test_ui.gd
func _initialize():
	if FileAccess.file_exists("user://save.json"):
		printerr("Use an empty XDG_DATA_HOME for this UI test.")
		quit(1)
		return
	call_deferred("check")

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
		assert(pick != -1)
		game._tap(center_of(game, pick))

func check():
	var economy: Node = root.get_node("Economy")
	var ads: Node = root.get_node("Ads")
	var iap: Node = root.get_node("IAP")
	economy.today_provider = func() -> String: return "2026-03-01"
	economy.reset_for_tests()
	# A frozen clock keeps every interstitial inside the "first minute" guard.
	ads.clock = func() -> float: return 0.0
	ads.reset_for_tests()
	var legacy_save := FileAccess.open("user://save.json", FileAccess.WRITE)
	assert(legacy_save)
	legacy_save.store_string('{"level":0}')
	legacy_save.close()
	var game = load("res://main.tscn").instantiate()
	assert(game.language == OS.get_locale_language())
	game.language = "tr"
	root.add_child(game)
	assert(game.theme_name == "dark")
	assert(game.home_screen.visible and not game.settings_veil.visible)
	assert(game.home_level.text == "Bölüm 01" and game.home_screen.color == game.palette.cream)
	assert(game.mascot.position == game.home_art.position)
	assert(game.mascot.scale.x > 1.5 and game.mascot.z_index > game.home_screen.z_index)
	for native_size in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(768, 1024)]:
		var logical_size := Vector2i(maxi(720, roundi(native_size.x * 1280.0 / native_size.y)), maxi(1280, roundi(native_size.y * 720.0 / native_size.x)))
		root.size = logical_size
		await process_frame
		game._layout()
		var screen := Rect2(Vector2.ZERO, Vector2(logical_size))
		var scale_factor := float(native_size.x) / logical_size.x
		for control in [game.home_title, game.home_level, game.play_button, game.settings_button, game.shop_button, game.daily_button, game.hint_button]:
			assert(screen.encloses(control.get_rect()))
		for button in [game.play_button, game.settings_button, game.theme_button, game.settings_close, game.shop_button,
				game.daily_button, game.hint_button, game.restore_button, game.privacy_button, game.shop_close, game.revive_ad_button,
				game.revive_hint_button, game.panel_retry]:
			assert(button.get_combined_minimum_size().x * scale_factor >= 44 and button.get_combined_minimum_size().y * scale_factor >= 44)
		assert(game.hint_button.size.x * scale_factor >= 44 and game.hint_button.size.y * scale_factor >= 44)
		assert(game.daily_button.visible and game.daily_button.text == "Günlük hediye: +1 ipucu")
		assert(game.home_title.get_rect().end.y < game.home_art.position.y - 220 * game.home_art.scale.y)
		assert(game.home_art.position.y + 220 * game.home_art.scale.y < game.daily_button.position.y)
		assert(game.daily_button.get_rect().end.y < game.home_level.position.y)
		assert(game.shop_button.get_rect().end.x < game.settings_button.position.x)
		# HUD: hint | home | restart, with the longest title still clear of the hint button.
		assert(game.hint_button.get_rect().end.x < game.home_button.position.x)
		var badge_end: float = game.hint_button.position.x + game.hint_badge.position.x + game.hint_badge.size.x
		assert(badge_end < game.home_button.position.x)
		for title in ["Bölüm 1000", "Level 1000"]:
			var title_width: float = game.DISPLAY_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, game._title_font_size(title)).x
			assert(game.left + title_width < game.hint_button.position.x + game.HINT_INSET)
		game.shop_button.pressed.emit()
		await process_frame
		assert(game.shop_veil.visible and screen.encloses(game.shop_panel.get_global_rect()))
		assert(game.shop_scroll.get_rect().size.y >= game.shop_list.get_combined_minimum_size().y)
		assert(game.play_button.focus_mode == Control.FOCUS_NONE)
		var close_shop := InputEventAction.new()
		close_shop.action = "ui_cancel"
		close_shop.pressed = true
		game._unhandled_input(close_shop)
		assert(not game.shop_veil.visible and game.get_viewport().gui_get_focus_owner() == game.shop_button)
		assert(game.play_button.size.x == minf(logical_size.x - 108, 780))
		game.settings_button.pressed.emit()
		await process_frame
		assert(screen.encloses(game.settings_panel.get_global_rect()))
		assert(game.get_viewport().gui_get_focus_owner() == game.theme_button)
		assert(game.play_button.focus_mode == Control.FOCUS_NONE)
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		game._unhandled_input(cancel)
		assert(not game.settings_veil.visible)
		assert(game.get_viewport().gui_get_focus_owner() == game.settings_button)
	root.size = Vector2i(720, 1280)
	game.play_button.pressed.emit()
	assert(not game.home_screen.visible)
	game.start(0)
	assert(game.retry.icon and game.retry.accessibility_name == "Yeniden başlat")
	assert(game.home_button.text.is_empty() and game.home_button.icon == preload("res://assets/home.svg"))
	assert(game.home_button.accessibility_name == "Ana ekran")
	assert(game.get_node_or_null("Mascot") == game.mascot and game.mascot.is_visible_in_tree())
	assert(game.mascot_state == "idle")
	await process_frame
	assert(game.tray.has_point(game.origin))
	# Native logical viewports cover portrait phones, tablets and a wide desktop.
	for viewport_size in [Vector2i(720, 1280), Vector2i(720, 1559), Vector2i(960, 1280), Vector2i(2048, 1280)]:
		root.size = viewport_size
		for level in game.levels.size():
			game.start(level)
			await process_frame
			game._layout()
			assert(game.cell > 0)
			assert(game.tray.position.y >= 375)
			assert(game.tray.end.y < game.pocket_y - 54)
			assert(game.retry.position.x >= game.left + 290)
			for title in ["Bölüm %02d" % (level + 1), "Bölüm 1000"]:
				var title_width: float = game.DISPLAY_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, game._title_font_size(title)).x
				assert(game.left + title_width < game.hint_button.position.x + game.HINT_INSET)
			assert(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(game.hint_button.get_rect()))
			assert(game.hint_button.get_rect().end.x < game.home_button.position.x)
			assert(game.mascot.position == Vector2(viewport_size.x * 0.5, game.pocket_y - 28))
			assert(game.mascot.scale == Vector2.ONE * 1.5)
			# Win expansion and next-board entry are separate animation phases.
			var board_bottom: float = maxf(game.tray.get_center().y + game.tray.size.y * 0.52, game.tray.end.y + 18)
			assert(game.mascot.position.y - (17 + 4) * 1.5 > board_bottom)
			# 28px covers breathing/wobble; a landing circle reaches pocket_y + 4.
			assert(game.mascot.position.y + 28 < game.pocket_y + 4)
			var pocket_heading_width: float = game.BODY_FONT.get_string_size("Geçici cep", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			assert(game.left + 40 + pocket_heading_width < game.mascot.position.x - 40)
			var capacity_width: float = game.BODY_FONT.get_string_size("%d / %d" % [game.s.cap, game.s.cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			assert(viewport_size.x - game.left - capacity_width > game.mascot.position.x + 40)
			assert(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(game.panel.get_rect()))
	root.size = Vector2i(720, 1280)
	# Keep the scripted win and loss independent of the generated level pack.
	game.levels = JSON.parse_string(FileAccess.get_file_as_string("res://levels/proto.json"))
	game.start(1)
	var blocked = game.s.arrows[1]
	assert(not game.Logic.can_exit(game.s, 1))
	game._tap(game.origin + (Vector2(game.Logic.head(blocked)) + Vector2.ONE * 0.5) * game.cell)
	assert(game.mascot_state == "blocked")
	await game.mascot_tween.finished
	assert(game.mascot_state == "idle" and is_zero_approx(game.mascot.rotation))
	game.start(0)
	game.s.cap = 2
	var a = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(a)) + Vector2.ONE * 0.5) * game.cell)
	assert(game.s.pocket == ["purple"] and game.mascot_state == "worried")
	var dark_background: Color = game.palette.cream
	var current_state: Dictionary = game.s.duplicate(true)
	var current_nodes: Dictionary = game.nodes.duplicate()
	game.home_button.pressed.emit()
	assert(game.home_screen.visible)
	a = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(a)) + Vector2.ONE * 0.5) * game.cell)
	assert(game.s == current_state and game.nodes == current_nodes)
	game.settings_button.pressed.emit()
	assert(game.settings_panel.is_visible_in_tree() and game.theme_button.text == "Açık tema")
	game.theme_button.pressed.emit()
	assert(game.theme_name == "light" and game.palette.cream != dark_background)
	assert(game.theme_button.text == "Koyu tema" and game.home_screen.color == game.palette.cream)
	assert(game.play_button.get_theme_color("font_focus_color") == game.palette.cream)
	assert(game.settings_button.get_theme_color("icon_focus_color") == game.palette.ink)
	assert(game.settings_close.get_theme_color("font_focus_color") == game.palette.ink)
	assert(game.settings_veil.color == game.palette.veil)
	assert(game.settings_panel.get_theme_stylebox("panel").bg_color == game.palette.surface)
	assert(game.s == current_state and game.nodes == current_nodes)
	var save: Dictionary = game._load_save()
	assert(save.level == 0 and save.theme == "light")
	game.settings_close.pressed.emit()
	assert(not game.settings_panel.is_visible_in_tree() and game.home_screen.visible)
	game.play_button.pressed.emit()
	assert(not game.home_screen.visible and game.s == current_state and game.nodes == current_nodes)
	a = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(a)) + Vector2.ONE * 0.5) * game.cell)
	assert(game.s.pocket.is_empty() and game.mascot_state == "idle")
	while game.s.status == "playing":
		var moved := false
		for i in game.s.arrows.size():
			if game.Logic.can_exit(game.s, i):
				game._tap(game.origin + (Vector2(game.Logic.head(game.s.arrows[i])) + Vector2.ONE * 0.5) * game.cell)
				moved = true
				break
		assert(moved)
	assert(game.s.status == "won" and game.input_locked and game.retry.disabled)
	assert(economy.get_stars(0) == economy.stars_for(game.s.mistakes) and game.win_stars == economy.get_stars(0))
	assert(economy.levels_cleared == 1 and game.hint_button.disabled)
	assert(game.mascot_state == "win")
	assert(not game.panel.visible and not game.veil.visible and game.celebration == 0.0)
	while game.idx == 0:
		await process_frame
		assert(not game.panel.visible and not game.veil.visible and game.input_locked)
	assert(game.idx == 1 and game.input_locked and game.retry.disabled)
	assert(game.mascot_state == "idle")
	var next_arrow = game.s.arrows[0]
	var next_tap = game.origin + (Vector2(game.Logic.head(next_arrow)) + Vector2.ONE * 0.5) * game.cell
	var next_state = game.s.duplicate(true)
	game._tap(next_tap)
	assert(game.s == next_state)
	await game.win_tween.finished
	assert(game.idx == 1 and not game.panel.visible and not game.veil.visible)
	assert(not game.input_locked and not game.retry.disabled and not game.hint_button.disabled)
	assert(ads.backend.shown_interstitials == 0)
	save = game._load_save()
	assert(save.level == 1 and save.theme == "light")
	var restored = load("res://main.tscn").instantiate()
	restored.language = "tr"
	root.add_child(restored)
	assert(restored.idx == 1 and restored.palette.cream == game.palette.cream)
	assert(restored.home_screen.visible and restored.home_level.text == "Bölüm 02 · ★ %d" % economy.total_stars())
	restored.queue_free()
	game.retry.pressed.emit()
	assert(game.idx == 1 and game.s.mistakes == 0 and game.s.pocket.is_empty())
	# Force a full pocket with a real mismatch to cover the loss panel and retry.
	game.start(0)
	game.s.cap = 0
	var wrong = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(wrong)) + Vector2.ONE * 0.5) * game.cell)
	assert(game.s.status == "lost" and game.panel.visible and game.veil.visible)
	game.retry.pressed.emit()
	assert(game.s.status == "playing" and not game.veil.visible)
	await monetization(game, economy, ads)
	game.queue_free()
	await process_frame
	var english = load("res://main.tscn").instantiate()
	english.language = "en"
	root.add_child(english)
	assert(english.home_level.text == "Level 01 · ★ %d" % economy.total_stars() and english.play_button.text == "Play")
	assert(english.shop_title.text == "Shop" and english.revive_ad_button.accessibility_name == "Watch ad · Undo")
	for key in english.ENGLISH_TEXT:
		assert(english._localized(key) == english.ENGLISH_TEXT[key])
	assert(not ProjectSettings.get_setting("application/config/quit_on_go_back"))
	english.settings_button.pressed.emit()
	assert(english.settings_veil.visible and english.settings_title.text == "Settings")
	english.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(english.home_screen.visible and not english.settings_veil.visible)
	english.play_button.pressed.emit()
	assert(not english.home_screen.visible and english.home_button.accessibility_name == "Home")
	english.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(english.home_screen.visible)
	print("test_ui: OK (all levels, four viewports, win/loss/retry, theme, save, mascot, locale, back, hints, revive, shop, daily)")
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
	assert(hints > 0 and game.hint_button.visible and not game.hint_button.disabled)
	assert(game.hint_badge_label.visible and game.hint_badge_label.text == str(hints))
	game.hint_button.pressed.emit()
	assert(economy.get_hints() == hints - 1 and game.hinted_id != -1)
	assert(game.hint_badge_label.text == str(hints - 1))
	game.hint_button.pressed.emit()
	assert(economy.get_hints() == hints - 1)
	var hinted := -1
	for i in game.s.arrows.size():
		if int(game.s.arrows[i].id) == game.hinted_id:
			hinted = i
	assert(hinted != -1 and game.Logic.can_exit(game.s, hinted))
	var count: int = game.s.arrows.size()
	var mistakes: int = game.s.mistakes
	game._tap(center_of(game, hinted))
	assert(game.s.arrows.size() == count - 1 and game.s.mistakes == mistakes and game.hinted_id == -1)
	assert(game.history.size() == 1)
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
	assert(game.Logic.hint(game.s) == -1)
	hints = economy.get_hints()
	game.hint_button.pressed.emit()
	assert(economy.get_hints() == hints and game.hinted_id == -1)
	assert(game.toast.visible and game.toast_label.text == "Buradan çıkış yok — geri al veya yeniden başlat")
	assert(screen.encloses(game.toast.get_rect()))
	# Stuck nudge after three blocked taps.
	game.start(1)
	var blocked := -1
	for i in game.s.arrows.size():
		if not game.Logic.can_exit(game.s, i):
			blocked = i
	assert(blocked != -1)
	for k in 3:
		game._tap(center_of(game, blocked))
	assert(game.hint_nudge and game.hint_nudge.is_running() and game.blocked_streak == 0)
	await game.hint_nudge.finished
	assert(game.hint_button.scale == Vector2.ONE)
	# Loss -> revive with a (mock) rewarded ad restores the state before the losing move.
	game.start(0)
	lose(game)
	assert(game.s.status == "lost" and game.panel.visible and game.veil.visible)
	assert(game.revive_ad_button.visible and game.revive_hint_button.visible and game.panel_retry.visible)
	assert(game.hint_button.disabled)
	await process_frame
	assert(screen.encloses(game.panel.get_rect()))
	assert(game.panel.size.y >= game.panel.get_combined_minimum_size().y)
	var before: Dictionary = game.history.back().duplicate(true)
	count = game.s.arrows.size()
	hints = economy.get_hints()
	game.revive_ad_button.pressed.emit()
	await frames()
	assert(game.s.status == "playing" and game.s.arrows.size() == count + 1 and game.s == before)
	assert(not game.panel.visible and not game.veil.visible and not game.retry.disabled)
	assert(economy.get_hints() == hints and not game.hint_button.disabled)
	assert(game.nodes.size() == game.s.arrows.size())
	for a in game.s.arrows:
		assert(game.nodes.has(a.id) and game.nodes[a.id].is_visible_in_tree())
	# Revive with a hint spends exactly one.
	lose(game)
	assert(game.s.status == "lost")
	count = game.s.arrows.size()
	game.revive_hint_button.pressed.emit()
	assert(economy.get_hints() == hints - 1 and game.s.status == "playing" and game.s.arrows.size() == count + 1)
	assert(not game.panel.visible)
	# No hints: the badge offers an ad, the button opens the shop.
	while economy.spend_hint():
		pass
	assert(game.hint_badge_icon.visible and not game.hint_badge_label.visible)
	lose(game)
	assert(not game.revive_hint_button.visible and game.revive_ad_button.visible)
	game.panel_retry.pressed.emit()
	assert(game.s.status == "playing")
	game.hint_button.pressed.emit()
	assert(game.shop_veil.visible and game.shop_ad_button.visible and game.shop_hints_label.text == "İpuçların: 0")
	for id in game.SHOP_PRODUCTS:
		assert(game.shop_rows[id].visible and not game.shop_rows[id].disabled)
	var tap_while_shop: Dictionary = game.s.duplicate(true)
	game._tap(center_of(game, 0))
	assert(game.s == tap_while_shop)
	game.shop_rows["hints_10"].pressed.emit()
	await frames()
	assert(economy.get_hints() == 10 and game.toast_label.text == "Teşekkürler!")
	assert(game.shop_hints_label.text == "İpuçların: 10" and game.hint_badge_label.text == "10")
	game.shop_ad_button.pressed.emit()
	await frames()
	assert(economy.get_hints() == 11 and ads.backend.shown_rewarded.back() == "hint")
	game.shop_rows["remove_ads"].pressed.emit()
	await frames()
	assert(economy.get_hints() == 16 and economy.is_ads_removed())
	assert(game.shop_rows["remove_ads"].disabled and game.shop_rows["remove_ads"].get_meta("price").text == "Satın alındı ✓")
	ads.backend.mock_fail_next = false
	var iap: Node = root.get_node("IAP")
	iap.backend.mock_fail_next = true
	game.shop_rows["hints_30"].pressed.emit()
	await frames()
	assert(economy.get_hints() == 16 and game.toast_label.text == "Satın alma tamamlanmadı")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(not game.shop_veil.visible and not game.home_screen.visible)
	assert(game.get_viewport().gui_get_focus_owner() == game.hint_button)
	# Settings: restore purchases and privacy options.
	game.home_button.pressed.emit()
	game.settings_button.pressed.emit()
	assert(game.restore_button.visible and game.privacy_button.visible)
	game.restore_button.pressed.emit()
	assert(game.toast_label.text == "Satın alımlar kontrol ediliyor")
	game.settings_close.pressed.emit()
	# Daily gift: promises +3 on day 7, claims once.
	assert(game.daily_button.visible and game.daily_button.text == "Günlük hediye: +1 ipucu")
	economy.streak = 6
	economy.last_daily = "2026-02-28"
	game._layout_home(Vector2(root.size))
	assert(game.daily_button.text == "Günlük hediye: +3 ipucu")
	hints = economy.get_hints()
	game.daily_button.pressed.emit()
	assert(economy.get_hints() == hints + 3 and economy.streak == 7 and not game.daily_button.visible)
	assert(game.toast_label.text == "+3 ipucu · Seri 7 gün")
	game.daily_button.pressed.emit()
	assert(economy.get_hints() == hints + 3)
	await frames(1)
