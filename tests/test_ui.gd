extends SceneTree

# Run with XDG_DATA_HOME=$(mktemp -d) godot --headless --script tests/test_ui.gd
func _initialize():
	if FileAccess.file_exists("user://save.json"):
		printerr("Use an empty XDG_DATA_HOME for this UI test.")
		quit(1)
		return
	call_deferred("check")

func check():
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
		for control in [game.home_title, game.home_level, game.play_button, game.settings_button]:
			assert(screen.encloses(control.get_rect()))
		for button in [game.play_button, game.settings_button, game.theme_button, game.settings_close]:
			assert(button.size.x * scale_factor >= 44 and button.size.y * scale_factor >= 44)
		assert(game.home_title.get_rect().end.y < game.home_art.position.y - 220 * game.home_art.scale.y)
		assert(game.home_art.position.y + 220 * game.home_art.scale.y < game.home_level.position.y)
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
			var title := "Bölüm %02d" % (level + 1)
			var title_width: float = game.DISPLAY_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 50).x
			assert(game.left + title_width < game.home_button.position.x)
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
	assert(not game.input_locked and not game.retry.disabled)
	save = game._load_save()
	assert(save.level == 1 and save.theme == "light")
	var restored = load("res://main.tscn").instantiate()
	restored.language = "tr"
	root.add_child(restored)
	assert(restored.idx == 1 and restored.palette.cream == game.palette.cream)
	assert(restored.home_screen.visible and restored.home_level.text == "Bölüm 02")
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
	game.queue_free()
	await process_frame
	var english = load("res://main.tscn").instantiate()
	english.language = "en"
	root.add_child(english)
	assert(english.home_level.text == "Level 01" and english.play_button.text == "Play")
	assert(not ProjectSettings.get_setting("application/config/quit_on_go_back"))
	english.settings_button.pressed.emit()
	assert(english.settings_veil.visible and english.settings_title.text == "Settings")
	english.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(english.home_screen.visible and not english.settings_veil.visible)
	english.play_button.pressed.emit()
	assert(not english.home_screen.visible and english.home_button.accessibility_name == "Home")
	english.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(english.home_screen.visible)
	print("test_ui: OK (all levels, four viewports, win/loss/retry, theme, save, mascot, locale and back)")
	create_timer(1.0).timeout.connect(func():
		printerr("Android back on Home did not quit.")
		quit(1))
	english.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
