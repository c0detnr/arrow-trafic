extends SceneTree

# Run with XDG_DATA_HOME=$(mktemp -d) godot --headless --script tests/test_ui.gd
func _initialize():
	if FileAccess.file_exists("user://save.json"):
		printerr("Use an empty XDG_DATA_HOME for this UI test.")
		quit(1)
		return
	call_deferred("check")

func check():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start(0)
	await process_frame
	assert(game.tray.has_point(game.origin))
	var a = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(a)) + Vector2.ONE * 0.5) * game.cell)
	assert(game.s.pocket == ["purple"])
	while game.s.status == "playing":
		var moved := false
		for i in game.s.arrows.size():
			if game.Logic.can_exit(game.s, i):
				game._tap(game.origin + (Vector2(game.Logic.head(game.s.arrows[i])) + Vector2.ONE * 0.5) * game.cell)
				moved = true
				break
		assert(moved)
	assert(game.panel.visible and game.s.status == "won")
	game.next_btn.pressed.emit()
	assert(game.idx == 1 and not game.panel.visible)
	quit()
