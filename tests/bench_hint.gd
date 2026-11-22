extends SceneTree
## Run: godot --headless --script tests/bench_hint.gd

const Logic = preload("res://logic.gd")


func _init() -> void:
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	var worst := 0.0
	var worst_id := 0
	var total := 0.0
	var fails := 0
	for lv in levels:
		var s := Logic.new_state(lv)
		var t := Time.get_ticks_usec()
		var h := Logic.hint(s)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		total += ms
		if ms > worst:
			worst = ms
			worst_id = int(lv.id)
		if h == -1:
			fails += 1
	print("bench_hint: %d levels, max %.2f ms (id %d), avg %.3f ms, -1 results: %d"
		% [levels.size(), worst, worst_id, total / levels.size(), fails])
	# Mid-game: random legal exits, then hint (may be dead).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mworst := 0.0
	var mtotal := 0.0
	var runs := 0
	var deads := 0
	for lv in levels:
		var s := Logic.new_state(lv)
		var steps := rng.randi_range(1, s.arrows.size())
		for k in steps:
			var mv := []
			for i in s.arrows.size():
				if Logic.can_exit(s, i):
					mv.append(i)
			if mv.is_empty() or s.status != "playing":
				break
			Logic.tap(s, mv[rng.randi() % mv.size()])
		if s.status != "playing":
			continue
		var t := Time.get_ticks_usec()
		if Logic.hint(s) == -1:
			deads += 1
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		mworst = maxf(mworst, ms)
		mtotal += ms
		runs += 1
	print("bench_hint mid-game: %d states, max %.2f ms, avg %.3f ms, dead: %d" % [runs, mworst, mtotal / maxi(runs, 1), deads])
	quit()
