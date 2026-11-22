extends SceneTree

# XDG_DATA_HOME=$(mktemp -d) godot --path . --script tests/capture_ui.gd -- <output.png> <width> <height> <level> <state> <theme>
func _initialize() -> void:
	if FileAccess.file_exists("user://save.json"):
		printerr("Use an empty XDG_DATA_HOME for captures.")
		quit(1)
		return
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var width := int(args[1]) if args.size() > 1 else 720
	var height := int(args[2]) if args.size() > 2 else 1280
	var level := int(args[3]) if args.size() > 3 else 0
	var selected_theme := args[5] if args.size() > 5 else "dark"
	if selected_theme not in ["dark", "light"]:
		printerr("Theme must be dark or light.")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(width, height)
	viewport.size_2d_override = Vector2i(maxi(720, roundi(width * 1280.0 / height)), maxi(1280, roundi(height * 720.0 / width)))
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://main.tscn").instantiate()
	viewport.add_child(game)
	var state := args[4] if args.size() > 4 else "playing"
	game.start(level)
	if state not in ["home", "settings"]:
		game.play_button.pressed.emit()
	elif state == "settings":
		game.settings_button.pressed.emit()
	if game.theme_name != selected_theme:
		game._toggle_theme()
	var win: Tween
	if state == "mid":  # play N exitable arrows so the queue and pocket look lived-in
		for _k in int(args[6]) if args.size() > 6 else 4:
			for i in game.s.arrows.size():
				if game.Logic.can_exit(game.s, i) and game.s.status == "playing":
					game._tap(game.origin + (Vector2(game.Logic.head(game.s.arrows[i])) + Vector2.ONE * 0.5) * game.cell)
					break
	if args.size() > 4 and args[4] == "won":
		while game.s.status == "playing":
			var moved := false
			for i in game.s.arrows.size():
				if game.Logic.can_exit(game.s, i):
					game._tap(game.origin + (Vector2(game.Logic.head(game.s.arrows[i])) + Vector2.ONE * 0.5) * game.cell)
					moved = true
					break
			assert(moved)
		assert(game.s.status == "won")
		win = game.win_tween
		while win.is_running() and game.idx == level and game.celebration < 0.33:
			await process_frame
		assert(game.celebration >= 0.33 and game.celebration < 1.0)
	else:
		await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(args[0])
	assert(error == OK)
	if win and win.is_running():
		await win.finished
	quit()
