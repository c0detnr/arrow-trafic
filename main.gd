extends Node2D

const Logic = preload("res://logic.gd")
const COLORS := {"red": Color("e74c3c"), "blue": Color("3498db"), "green": Color("2ecc71"),
	"yellow": Color("f1c40f"), "purple": Color("9b59b6"), "orange": Color("e67e22")}
const SAVE_PATH := "user://save.json"
const BOX := 56.0
const QUEUE_Y := 70.0
const POCKET_Y := 160.0

var levels: Array = []
var idx := 0
var s: Dictionary = {}
var nodes := {}  # arrow id -> Node2D
var cell := 64.0
var origin := Vector2.ZERO
var info: Label
var panel: PanelContainer
var panel_label: Label
var next_btn: Button


func _ready() -> void:
	levels = _load_levels()
	if levels.is_empty():
		push_error("No levels found in res://levels/")
		return
	_build_ui()
	start(clampi(_load_save(), 0, levels.size() - 1))


func _load_levels() -> Array:
	for p in ["res://levels/proto.json", "res://levels/dev_sample.json"]:
		if FileAccess.file_exists(p):
			var data = JSON.parse_string(FileAccess.get_file_as_string(p))
			if data is Array and not data.is_empty():
				return data
	return []


func _load_save() -> int:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)) if FileAccess.file_exists(SAVE_PATH) else null
	return int(data.get("level", 0)) if data is Dictionary else 0


func start(i: int) -> void:
	idx = i
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"level": idx}))
	for n in nodes.values():
		n.queue_free()
	nodes.clear()
	s = Logic.new_state(levels[idx])
	var vs := get_viewport_rect().size
	# shortcut: layout computed once per level start, recompute on resize if needed later
	var area := Rect2(16, POCKET_Y + BOX + 30, vs.x - 32, vs.y - (POCKET_Y + BOX + 30) - 120)
	cell = floorf(minf(area.size.x / s.w, area.size.y / s.h))
	origin = area.position + (area.size - Vector2(s.w, s.h) * cell) / 2
	for a in s.arrows:
		_make_arrow(a)
	panel.visible = false
	_refresh()


func _make_arrow(a: Dictionary) -> void:
	var n := Node2D.new()
	var h := Logic.head(a)
	n.position = origin + Vector2(h) * cell
	n.set_meta("base", n.position)
	n.draw.connect(func():
		var col: Color = COLORS.get(a.color, Color.WHITE)
		for c in Logic.cells(a):
			n.draw_rect(Rect2(Vector2(c - h) * cell + Vector2(4, 4), Vector2(cell - 8, cell - 8)), col)
		var d := Vector2(Logic.DIRS[a.dir])
		var side := Vector2(-d.y, d.x)
		var m := Vector2(cell, cell) / 2
		n.draw_colored_polygon(PackedVector2Array([m + d * cell * 0.35,
			m - d * cell * 0.15 + side * cell * 0.28, m - d * cell * 0.15 - side * cell * 0.28]), Color.WHITE))
	add_child(n)
	nodes[a.id] = n


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed:
		_tap(e.position)
	# touch also emits emulated mouse events (device -1); skip those to avoid double taps
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT \
			and e.device != InputEvent.DEVICE_ID_EMULATION:
		_tap(e.position)


func _tap(pos: Vector2) -> void:
	if s.is_empty() or s.status != "playing":
		return
	var i := Logic.arrow_at(s, Vector2i(((pos - origin) / cell).floor()))
	if i < 0:
		return
	var a: Dictionary = s.arrows[i]
	var n: Node2D = nodes[a.id]
	var r := Logic.tap(s, i)
	var d := Vector2(Logic.DIRS[a.dir])
	if r == "blocked":
		var base: Vector2 = n.get_meta("base")
		var t := n.create_tween()
		for off in [d * 8, -d * 6, d * 4, Vector2.ZERO]:
			t.tween_property(n, "position", base + off, 0.05)
	else:
		nodes.erase(a.id)
		var t := n.create_tween().set_parallel()
		t.tween_property(n, "position", n.position + d * cell * (maxi(s.w, s.h) + 2), 0.3)
		t.tween_property(n, "modulate:a", 0.0, 0.3)
		t.chain().tween_callback(n.queue_free)
		if r == "won" or r == "lost":
			panel_label.text = "KAZANDIN!" if r == "won" else "KAYBETTİN"
			next_btn.visible = r == "won"
			panel.visible = true
	_refresh()


func _refresh() -> void:
	info.text = "Bölüm %d / %d     Hata: %d" % [idx + 1, levels.size(), s.mistakes]
	queue_redraw()


func _draw() -> void:
	if s.is_empty():
		return
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(16, QUEUE_Y - 6), "Kuyruk", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, Vector2(16, POCKET_Y - 6), "Cep", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var q: Array = s.queue.slice(0, 8)
	for k in q.size():
		var r := Rect2(24 + k * (BOX + 16), QUEUE_Y, BOX, BOX)
		if k == 0:
			draw_rect(r.grow(6), Color.WHITE, false, 4)
		draw_rect(r, COLORS.get(q[k], Color.WHITE))
	if s.queue.size() > 8:
		draw_string(font, Vector2(24 + 8 * (BOX + 16), QUEUE_Y + 38), "+%d" % (s.queue.size() - 8), HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	for k in s.cap:
		var r := Rect2(24 + k * (BOX + 16), POCKET_Y, BOX, BOX)
		draw_rect(r, Color(1, 1, 1, 0.12))
		if k < s.pocket.size():
			draw_rect(r.grow(-6), COLORS.get(s.pocket[k], Color.WHITE))
	for y in s.h:
		for x in s.w:
			draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), Color(1, 1, 1, 0.08), false, 2)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 80)
	b.add_theme_font_size_override("font_size", 32)
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	var vs := get_viewport_rect().size
	info = Label.new()
	info.position = Vector2(16, 8)
	info.add_theme_font_size_override("font_size", 28)
	add_child(info)
	var retry := _button("Tekrar", func(): start(idx))
	retry.position = Vector2(vs.x / 2 - 120, vs.y - 100)
	add_child(retry)

	panel = PanelContainer.new()
	panel.z_index = 10
	panel.custom_minimum_size = Vector2(420, 320)
	panel.position = vs / 2 - Vector2(210, 160)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel_label = Label.new()
	panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_label.add_theme_font_size_override("font_size", 44)
	next_btn = _button("Sonraki", func(): start((idx + 1) % levels.size()))
	box.add_child(panel_label)
	box.add_child(next_btn)
	box.add_child(_button("Tekrar", func(): start(idx)))
	panel.add_child(box)
	add_child(panel)
