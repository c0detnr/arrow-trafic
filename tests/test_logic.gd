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

	print("test_logic: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures else 0)
