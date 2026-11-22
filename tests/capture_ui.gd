extends SceneTree

# XDG_DATA_HOME=$(mktemp -d) godot --path . --script tests/capture_ui.gd -- <output.png> <width> <height> <level> <state>
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
	var viewport := SubViewport.new()
	viewport.size = Vector2i(width, height)
	viewport.size_2d_override = Vector2i(maxi(720, roundi(width * 1280.0 / height)), maxi(1280, roundi(height * 720.0 / width)))
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://main.tscn").instantiate()
	viewport.add_child(game)
	game.start(int(args[3]) if args.size() > 3 else 0)
	if args.size() > 4 and args[4] == "won":
		while game.s.status == "playing":
			var moved := false
			for i in game.s.arrows.size():
				if game.Logic.can_exit(game.s, i):
					game._tap(game.origin + (Vector2(game.Logic.head(game.s.arrows[i])) + Vector2.ONE * 0.5) * game.cell)
					moved = true
					break
			assert(moved)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(args[0])
	assert(error == OK)
	quit()
