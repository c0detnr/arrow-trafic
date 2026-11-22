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
	# Native logical viewports cover portrait phones, tablets and a wide desktop.
	for viewport_size in [Vector2i(720, 1280), Vector2i(720, 1559), Vector2i(960, 1280), Vector2i(2048, 1280)]:
		root.size = viewport_size
		for level in game.levels.size():
			game.start(level)
			await process_frame
			game._layout()
			assert(game.cell > 0)
			assert(game.tray.position.y >= 430)
			assert(game.tray.end.y < game.pocket_y - 54)
			assert(game.retry.position.x >= game.left + 290)
			assert(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(game.panel.get_rect()))
	root.size = Vector2i(720, 1280)
	game.start(0)
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
	assert(game.panel.visible and game.veil.visible and game.retry.disabled and game.s.status == "won")
	game.next_btn.pressed.emit()
	assert(game.idx == 1 and not game.panel.visible and not game.veil.visible and not game.retry.disabled)
	game.retry.pressed.emit()
	assert(game.idx == 1 and game.s.mistakes == 0 and game.s.pocket.is_empty())
	# Force a full pocket with a real mismatch to cover the loss panel and retry.
	game.start(0)
	game.s.cap = 0
	var wrong = game.s.arrows[0]
	game._tap(game.origin + (Vector2(game.Logic.head(wrong)) + Vector2.ONE * 0.5) * game.cell)
	assert(game.s.status == "lost" and game.veil.visible and not game.next_btn.visible)
	game.retry.pressed.emit()
	assert(game.s.status == "playing" and not game.veil.visible)
	print("test_ui: OK (all levels, four viewports, win/loss/retry)")
	quit()
