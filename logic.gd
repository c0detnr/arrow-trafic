extends RefCounted
## Pure game rules from SPEC.md. State is a plain Dictionary; no drawing here.

const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}


static func new_state(level: Dictionary) -> Dictionary:
	var arrows := []
	for i in level.arrows.size():
		var a: Dictionary = level.arrows[i].duplicate()
		a.id = i  # stable id for the view, survives removals
		arrows.append(a)
	return {"w": int(level.w), "h": int(level.h), "cap": int(level.pocket), "arrows": arrows,
		"queue": level.queue.duplicate(), "pocket": [], "mistakes": 0, "status": "playing"}


static func head(a: Dictionary) -> Vector2i:
	return Vector2i(int(a.x), int(a.y))


static func cells(a: Dictionary) -> Array:
	var out := []
	for k in int(a.len):
		out.append(head(a) - DIRS[a.dir] * k)
	return out


## Index into s.arrows of the arrow covering `cell`, or -1.
static func arrow_at(s: Dictionary, cell: Vector2i) -> int:
	for i in s.arrows.size():
		if cell in cells(s.arrows[i]):
			return i
	return -1


static func can_exit(s: Dictionary, i: int) -> bool:
	var d: Vector2i = DIRS[s.arrows[i].dir]
	var c := head(s.arrows[i]) + d
	while c.x >= 0 and c.y >= 0 and c.x < s.w and c.y < s.h:
		if arrow_at(s, c) != -1:
			return false
		c += d
	return true


## Mutates s. Returns "blocked" | "gate" | "pocket" | "lost" | "won", or "" if game is over.
static func tap(s: Dictionary, i: int) -> String:
	if s.status != "playing":
		return ""
	if not can_exit(s, i):
		s.mistakes += 1
		return "blocked"
	var a: Dictionary = s.arrows.pop_at(i)
	var result := "gate"
	if not s.queue.is_empty() and s.queue[0] == a.color:
		s.queue.pop_front()
	elif s.pocket.size() >= s.cap:
		s.status = "lost"
		return "lost"
	else:
		s.pocket.append(a.color)
		result = "pocket"
	while not s.queue.is_empty() and s.queue[0] in s.pocket:
		s.pocket.erase(s.queue.pop_front())
	if s.arrows.is_empty():
		s.status = "won"
		return "won"
	return result
