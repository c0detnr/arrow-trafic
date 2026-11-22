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


## Deep copy of state for undo/revive. Arrow ids are kept.
static func snapshot(s: Dictionary) -> Dictionary:
	return s.duplicate(true)


## Mutates s in place so every key equals `snap`. Copies, so one snap can be restored twice.
static func restore(s: Dictionary, snap: Dictionary) -> void:
	s.clear()
	s.merge(snap.duplicate(true))


## Winning order of arrow ids from the current state. [] if no arrows remain,
## [-1] if no win exists from here (dead / lost) or more than `limit` states were explored.
static func solve(s: Dictionary, limit := 60000) -> Array:
	var order := _solve_idx(s, limit)
	if order.is_empty() or order[0] == -1:
		return order
	var ids := []
	for i in order:
		ids.append(int(s.arrows[i].get("id", i)))
	return ids


## Index into s.arrows of the next arrow on a winning line, or -1 (not playing / dead state).
static func hint(s: Dictionary) -> int:
	if s.status != "playing":
		return -1
	var order := _solve_idx(s)
	return -1 if order.is_empty() else order[0]


## Like solve() but returns indices into the current s.arrows (not re-indexed after removals).
static func _solve_idx(s: Dictionary, limit := 60000) -> Array:
	if s.status == "lost":
		return [-1]
	if s.arrows.is_empty():
		return []
	var sv := _Solver.new(s, limit)
	if not sv.ok:
		return [-1]
	if not sv.rec(sv.full, 0, sv.pk0, s.pocket.size()):
		return [-1]
	var out := []
	for k in range(sv.order.size() - 1, -1, -1):
		out.append(sv.order[k])
	return out


## Memoized DFS over (mask of remaining arrows, queue index, pocket colour counts);
## same model as tools/arrowlib.py Level.solve. Only dead states are memoized.
class _Solver:
	var ok := true
	var n: int
	var cap: int
	var qlen: int
	var nc: int  # distinct colours
	var cb: int  # bits per colour count in the pocket code
	var cm: int  # mask for one colour count
	var full: int
	var pk0 := 0
	var color := PackedInt32Array()
	var block := PackedInt64Array()
	var q := PackedInt32Array()
	var nxt := PackedInt32Array()  # nxt[qi * nc + c] = distance from qi to next c in queue
	var qshift: int
	var pshift: int
	var int_key := true
	var dead := {}
	var limit: int
	var hit := false
	var order := PackedInt32Array()

	func _init(s: Dictionary, lim: int) -> void:
		limit = lim
		n = s.arrows.size()
		if n > 62:
			ok = false  # masks are 64-bit ints; no hint for such boards
			return
		cap = int(s.cap)
		var ids := {}
		for a in s.arrows:
			if not ids.has(a.color):
				ids[a.color] = ids.size()
		for c in s.queue:
			if not ids.has(c):
				ids[c] = ids.size()
		for c in s.pocket:
			if not ids.has(c):
				ids[c] = ids.size()
		nc = ids.size()
		qlen = s.queue.size()
		for c in s.queue:
			q.append(ids[c])
		cb = _bits(maxi(cap, s.pocket.size()))
		cm = (1 << cb) - 1
		for c in s.pocket:
			pk0 += 1 << (cb * int(ids[c]))
		nxt.resize((qlen + 1) * nc)
		for c in nc:
			nxt[qlen * nc + c] = qlen + 1
		for qi in range(qlen - 1, -1, -1):
			for c in nc:
				nxt[qi * nc + c] = 0 if q[qi] == c else nxt[(qi + 1) * nc + c] + 1
		var w := int(s.w)
		var h := int(s.h)
		var owner := PackedInt32Array()
		owner.resize(w * h)
		owner.fill(-1)
		for i in n:
			var a: Dictionary = s.arrows[i]
			color.append(ids[a.color])
			var d: Vector2i = DIRS[a.dir]
			for k in int(a.len):
				var p := Vector2i(int(a.x), int(a.y)) - d * k
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
					owner[p.y * w + p.x] = i
		for i in n:
			var a: Dictionary = s.arrows[i]
			var d: Vector2i = DIRS[a.dir]
			var c := Vector2i(int(a.x), int(a.y)) + d
			var m := 0
			while c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
				var o := owner[c.y * w + c.x]
				if o != -1 and o != i:
					m |= 1 << o
				c += d
			block.append(m)
		full = (1 << n) - 1
		qshift = n
		pshift = n + _bits(qlen)
		int_key = pshift + cb * nc <= 63

	static func _bits(v: int) -> int:
		var b := 1
		while (1 << b) <= v:
			b += 1
		return b

	func rec(mask: int, qi: int, pk: int, ps: int) -> bool:
		if mask == 0:
			return true
		var key: Variant = mask | (qi << qshift) | (pk << pshift) if int_key else "%d,%d,%d" % [mask, qi, pk]
		if dead.has(key):
			return false
		if dead.size() >= limit:
			hit = true
			return false
		var mv := PackedInt32Array()
		var base := qi * nc
		for i in n:
			if (mask >> i) & 1 and block[i] & mask == 0:
				mv.append(nxt[base + color[i]] * 64 + i)
		mv.sort()
		for v in mv:
			var i := v & 63
			var c := color[i]
			var nqi := qi
			var npk := pk
			var nps := ps
			if nqi < qlen and q[nqi] == c:
				nqi += 1
			elif ps >= cap:
				continue  # pocket overflow = loss
			else:
				npk += 1 << (cb * c)
				nps += 1
			while nqi < qlen and (npk >> (cb * q[nqi])) & cm:
				npk -= 1 << (cb * q[nqi])
				nps -= 1
				nqi += 1
			if rec(mask & ~(1 << i), nqi, npk, nps):
				order.append(i)
				return true
			if hit:
				return false
		dead[key] = true
		return false
