extends SceneTree
## Run: godot --headless --script tests/test_logic.gd

const Logic = preload("res://logic.gd")

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)


func arrow(x, y, dir, len, color) -> Dictionary:
	return {"x": x, "y": y, "dir": dir, "len": len, "color": color}


func _init() -> void:
	# Level A: blue (1,1)-up blocks red (2,1)-left.
	var s := Logic.new_state({"w": 4, "h": 4, "pocket": 3, "queue": ["blue", "red"],
		"arrows": [arrow(2, 1, "left", 2, "red"), arrow(1, 1, "up", 2, "blue")]})
	check(Logic.tap(s, 0) == "blocked", "red is blocked")
	check(s.mistakes == 1 and s.arrows.size() == 2, "blocked: mistake counted, arrow stays")
	check(Logic.tap(s, 1) == "gate", "blue passes gate")
	check(s.queue == ["red"] and s.pocket.is_empty(), "gate pops queue front")
	check(Logic.tap(s, 0) == "won", "last arrow wins")
	check(s.status == "won" and s.queue.is_empty(), "won with empty queue")
	check(Logic.tap(s, 0) == "", "no moves after game over")

	# Level B: pocket then chained release.
	s = Logic.new_state({"w": 5, "h": 6, "pocket": 3, "queue": ["blue", "green", "red", "yellow", "red"],
		"arrows": [arrow(2, 0, "right", 3, "green"), arrow(4, 2, "down", 2, "red"),
			arrow(0, 5, "left", 1, "yellow"), arrow(2, 3, "up", 2, "blue"), arrow(3, 5, "right", 2, "red")]})
	check(Logic.tap(s, 3) == "blocked", "blue blocked by green")
	check(Logic.tap(s, 0) == "pocket", "green goes to pocket")
	check(s.pocket == ["green"], "pocket holds green")
	check(Logic.tap(s, 2) == "gate", "blue passes gate")
	check(s.pocket.is_empty() and s.queue == ["red", "yellow", "red"], "green chained out of pocket")
	check(Logic.tap(s, 1) == "pocket", "yellow to pocket")
	check(Logic.tap(s, 0) == "gate" and s.pocket.is_empty(), "red passes, yellow chains out")
	check(Logic.tap(s, 0) == "won", "level B won")

	# Pocket overflow -> lost.
	s = Logic.new_state({"w": 3, "h": 3, "pocket": 1, "queue": ["green", "red", "blue"],
		"arrows": [arrow(0, 0, "up", 1, "red"), arrow(1, 0, "up", 1, "blue"), arrow(2, 0, "up", 1, "green")]})
	check(Logic.tap(s, 0) == "pocket", "red to pocket")
	check(Logic.tap(s, 0) == "lost" and s.status == "lost", "full pocket loses")

	# Snapshot / restore round trip.
	s = Logic.new_state({"w": 5, "h": 6, "pocket": 3, "queue": ["blue", "green", "red", "yellow", "red"],
		"arrows": [arrow(2, 0, "right", 3, "green"), arrow(4, 2, "down", 2, "red"),
			arrow(0, 5, "left", 1, "yellow"), arrow(2, 3, "up", 2, "blue"), arrow(3, 5, "right", 2, "red")]})
	Logic.tap(s, 3)
	Logic.tap(s, 0)
	var snap := Logic.snapshot(s)
	var ref := s.duplicate(true)
	Logic.tap(s, 2)
	Logic.tap(s, 0)
	check(s != ref, "state changed after snapshot")
	Logic.restore(s, snap)
	check(s == ref, "restore equals snapshot (ids, mistakes, pocket, queue, status)")
	check(s.mistakes == 1 and s.pocket == ["green"] and s.arrows.size() == 4, "restored fields")
	Logic.tap(s, 2)
	Logic.restore(s, snap)
	check(s == ref, "snapshot reusable twice")
	var ids := []
	for a in s.arrows:
		ids.append(a.id)
	check(ids == [1, 2, 3, 4], "arrow ids preserved")
	for k in 10:  # play to the end, then restore
		if s.status == "playing":
			Logic.tap(s, Logic.hint(s))
	check(s.status == "won", "played to the end")
	Logic.restore(s, snap)
	check(s.status == "playing" and s == ref, "restore after game over")

	# Hint on level A: blue first (red is blocked).
	s = Logic.new_state({"w": 4, "h": 4, "pocket": 3, "queue": ["blue", "red"],
		"arrows": [arrow(2, 1, "left", 2, "red"), arrow(1, 1, "up", 2, "blue")]})
	check(Logic.hint(s) == 1, "hint picks blue")
	check(Logic.solve(s) == [1, 0], "solve returns ids in order")
	Logic.tap(s, 1)
	check(Logic.hint(s) == 0 and Logic.solve(s) == [0], "hint after a move")
	Logic.tap(s, 0)
	check(Logic.hint(s) == -1 and Logic.solve(s) == [], "won: no hint, empty solve")

	# Hint prefers the gate colour when the pocket is tight.
	s = Logic.new_state({"w": 3, "h": 3, "pocket": 1, "queue": ["green", "red", "blue"],
		"arrows": [arrow(0, 0, "up", 1, "red"), arrow(1, 0, "up", 1, "blue"), arrow(2, 0, "up", 1, "green")]})
	check(Logic.hint(s) == 2, "hint picks green for the gate")
	Logic.tap(s, 0)
	check(Logic.hint(s) == 1, "red pocketed: green still wins")
	Logic.tap(s, 0)
	check(s.status == "lost" and Logic.hint(s) == -1 and Logic.solve(s) == [-1], "lost: no hint")

	# Dead state: pocket 1, gate wants green but green is last behind red and blue.
	s = Logic.new_state({"w": 1, "h": 4, "pocket": 1, "queue": ["green", "red", "blue"],
		"arrows": [arrow(0, 0, "up", 1, "red"), arrow(0, 1, "up", 1, "blue"), arrow(0, 2, "up", 1, "green")]})
	check(Logic.hint(s) == -1 and Logic.solve(s) == [-1], "unavoidable overflow: no hint")

	# Integration: follow hints on shipped levels.
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	for id in [1, 2, 50, 200, 500, 999, 1000]:
		s = Logic.new_state(levels[id - 1])
		check(int(levels[id - 1].id) == id, "level index %d" % id)
		var n := 0
		while s.status == "playing" and n < 100:
			var h := Logic.hint(s)
			if h == -1:
				break
			Logic.tap(s, h)
			n += 1
		check(s.status == "won" and s.mistakes == 0, "hint wins level %d" % id)

	# Random legal moves first: hint is -1 or still wins.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for id in [10, 120, 333, 640, 777, 900, 1000]:
		for rep in 5:
			s = Logic.new_state(levels[id - 1])
			for k in rng.randi_range(1, 8):
				var mv := []
				for i in s.arrows.size():
					if Logic.can_exit(s, i):
						mv.append(i)
				if s.status != "playing" or mv.is_empty():
					break
				Logic.tap(s, mv[rng.randi() % mv.size()])
			if s.status != "playing" or Logic.hint(s) == -1:
				continue
			while s.status == "playing" and Logic.hint(s) != -1:
				Logic.tap(s, Logic.hint(s))
			check(s.status == "won" and s.mistakes == 0, "mid-game hint wins level %d" % id)

	print("test_logic: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)
