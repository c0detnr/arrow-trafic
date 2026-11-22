extends SceneTree

# XDG_DATA_HOME=$(mktemp -d) godot --path . --script tests/capture_ui.gd -- <output.png> <width> <height> <level> <state> <theme> [taps]
# States: playing, mid, won, home, settings, shop, daily (gift claimed + toast), hint (highlighted hint), lost (revive panel),
# levels (level select; every level before <level> is cleared with 0-3 mistakes so tiles show stars).
# hint is captured near the top of the halo pulse so the highlighted arrow reads clearly.
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
	if state == "levels":
		for i in level:
			root.get_node("Economy").record_clear(i, i % 4)
	game.start(level)
	if state not in ["home", "settings", "shop", "daily", "levels"]:
		game.play_button.pressed.emit()
	elif state == "settings":
		game.settings_button.pressed.emit()
	elif state == "shop":
		game.shop_button.pressed.emit()
	elif state == "daily":  # claim the gift so the toast shows
		game.daily_button.pressed.emit()
	elif state == "levels":
		game.levels_button.pressed.emit()
	if game.theme_name != selected_theme:
		game._toggle_theme()
	var win: Tween
	if state in ["hint", "lost"]:  # a couple of real moves so the queue and pocket are in use
		for _k in int(args[6]) if args.size() > 6 else 2:
			var pick: int = game.Logic.hint(game.s)
			if pick >= 0:
				game._tap(game.origin + (Vector2(game.Logic.head(game.s.arrows[pick])) + Vector2.ONE * 0.5) * game.cell)
	if state == "hint":
		game.hint_button.pressed.emit()
	elif state == "lost":
		var guard := 0
		while game.s.status == "playing":
			guard += 1
			if guard > 6:  # force the overflow if the level keeps letting colours through
				game.s.cap = game.s.pocket.size()
			var pick := -1
			for i in game.s.arrows.size():
				if game.Logic.can_exit(game.s, i) and (pick == -1 or game.s.queue.is_empty() or game.s.arrows[i].color != game.s.queue[0]):
					pick = i
			game._tap(game.origin + (Vector2(game.Logic.head(game.s.arrows[pick])) + Vector2.ONE * 0.5) * game.cell)
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
	if state == "hint":  # catch the halo near the top of its pulse (main.gd: sin(ticks * 0.005))
		while sin(Time.get_ticks_msec() * 0.005) < 0.85:
			await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(args[0])
	assert(error == OK)
	if win and win.is_running():
		await win.finished
	quit()
