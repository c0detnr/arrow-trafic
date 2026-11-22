extends Node2D

const Logic = preload("res://logic.gd")
const COLORS := {"red": Color("#bc5456"), "blue": Color("#487da2"), "green": Color("#43836b"),
	"yellow": Color("#ab791f"), "purple": Color("#87689a"), "orange": Color("#bc6940")}
const INK := Color("#273e39")
const MUTED := Color("#536760")
const CREAM := Color("#fffcf4")
const SAVE_PATH := "user://save.json"

var levels: Array = []
var idx := 0
var s: Dictionary = {}
var nodes := {}  # arrow id -> Node2D
var cell := 64.0
var origin := Vector2.ZERO
var tray: Rect2
var left: float
var pocket_y: float
var landing := 1.0
var landing_tween: Tween
var retry: Button
var panel: PanelContainer
var panel_label: Label
var next_btn: Button


func _ready() -> void:
	levels = _load_levels()
	if levels.is_empty():
		push_error("No levels found in res://levels/")
		return
	_build_ui()
	get_viewport().size_changed.connect(_layout)
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
	if landing_tween:
		landing_tween.kill()
	landing = 1.0
	s = Logic.new_state(levels[idx])
	_layout()
	for a in s.arrows:
		_make_arrow(a)
	panel.visible = false
	queue_redraw()


func _layout() -> void:
	if s.is_empty():
		return
	var vs := get_viewport_rect().size
	var width := minf(vs.x - 72, 680)
	left = (vs.x - width) * 0.5
	pocket_y = vs.y - 116
	var area := Rect2(left + 24, 306, width - 48, pocket_y - 402)
	cell = minf(area.size.x / s.w, area.size.y / s.h)
	var board := Vector2(s.w, s.h) * cell
	origin = area.get_center() - board * 0.5
	tray = Rect2(origin, board).grow(18)
	retry.position = Vector2(vs.x - left - retry.size.x, 46)
	panel.position = (vs - panel.size) * 0.5
	for a in s.arrows:
		if nodes.has(a.id):
			var n: Node2D = nodes[a.id]
			n.position = origin + Vector2(Logic.head(a)) * cell
			n.set_meta("base", n.position)
			n.queue_redraw()
	queue_redraw()


func _mark(canvas: CanvasItem, pos: Vector2, radius: float, color_name: String) -> void:
	var width := radius * 0.42
	match color_name:
		"green":
			canvas.draw_arc(pos, radius * 0.8, 0, TAU, 28, CREAM, width, true)
		"purple":
			for x in [-0.6, 0.6]:
				canvas.draw_line(pos + Vector2(x, -0.8) * radius, pos + Vector2(x, 0.8) * radius, CREAM, width, true)
		"blue":
			canvas.draw_circle(pos, radius * 0.78, CREAM, true, -1, true)
		"orange":
			canvas.draw_line(pos - Vector2.ONE * radius * 0.8, pos + Vector2.ONE * radius * 0.8, CREAM, width, true)
		"yellow":
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2.UP * radius, pos + Vector2(1, 0.8) * radius, pos + Vector2(-1, 0.8) * radius]), CREAM)
		"red":
			canvas.draw_line(pos - Vector2.RIGHT * radius, pos + Vector2.RIGHT * radius, CREAM, width, true)
			canvas.draw_line(pos - Vector2.DOWN * radius, pos + Vector2.DOWN * radius, CREAM, width, true)


func _make_arrow(a: Dictionary) -> void:
	var n := Node2D.new()
	n.position = origin + Vector2(Logic.head(a)) * cell
	n.set_meta("base", n.position)
	n.draw.connect(func():
		var d := Vector2(Logic.DIRS[a.dir])
		var side := d.orthogonal()
		var head := Vector2.ONE * cell * 0.5
		var tail := head - d * cell * (int(a.len) - 1)
		var col: Color = COLORS[a.color]
		var tip := head + d * cell * 0.34
		var neck := head - d * cell * 0.14
		for offset in [Vector2.DOWN * 3, Vector2.ZERO]:
			var tint := col if offset == Vector2.ZERO else col.darkened(0.22)
			n.draw_line(tail + offset, head + offset, tint, cell * 0.34, true)
			n.draw_circle(tail + offset, cell * 0.17, tint, true, -1, true)
			n.draw_colored_polygon(PackedVector2Array([tip + offset, neck + side * cell * 0.32 + offset, neck - side * cell * 0.32 + offset]), tint)
		_mark(n, tail, cell * 0.087, a.color))
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
	if r != "blocked" and landing_tween:
		landing_tween.kill()
		landing = 1.0
	if r == "pocket":
		landing = 0.0
		landing_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		landing_tween.tween_method(func(progress: float):
			landing = progress
			queue_redraw(), 0.0, 1.0, 0.22)
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
			panel_label.text = "Bölüm tamamlandı" if r == "won" else "Cep doldu"
			next_btn.visible = r == "won"
			panel.visible = true
	queue_redraw()



func _surface(rect: Rect2, tint: Color, radius: int, shadow := false) -> void:
	var style := _style(tint, radius)
	if shadow:
		style.shadow_color = Color("#75634727")
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 5)
	draw_style_box(style, rect)


func _style(tint: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(radius)
	return style


func _draw() -> void:
	if s.is_empty():
		return
	var vs := get_viewport_rect().size
	var width := vs.x - 2 * left
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(left, 98), "Bölüm %02d" % (idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, INK)
	draw_string(font, Vector2(left, 166), "Renk sırası", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, MUTED)
	_surface(Rect2(left, 182, width, 76), Color("#e9e5d7"), 38)
	var q: Array = s.queue.slice(0, 8)
	for k in q.size():
		var pos := Vector2(left + 44 + k * 66, 220)
		if k == 0:
			draw_circle(pos, 33, INK, true, -1, true)
			draw_circle(pos, 29, CREAM, true, -1, true)
		draw_circle(pos, 25 if k == 0 else 19, COLORS[q[k]], true, -1, true)
		_mark(self, pos, 9 if k == 0 else 7, q[k])
	if s.queue.size() > 8:
		draw_string(font, Vector2(vs.x - left - 90, 229), "+%d" % (s.queue.size() - 8), HORIZONTAL_ALIGNMENT_CENTER, 78, 24, MUTED)
	_surface(tray, CREAM, 28, true)
	for y in s.h:
		for x in s.w:
			draw_circle(origin + (Vector2(x, y) + Vector2.ONE * 0.5) * cell, 3.5, Color("#d4d4c4"), true, -1, true)
	draw_string(font, Vector2(left, pocket_y - 24), "Cep", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	draw_string(font, Vector2(left, pocket_y - 24), "%d / %d" % [s.pocket.size(), s.cap], HORIZONTAL_ALIGNMENT_RIGHT, width, 24, MUTED)
	_surface(Rect2(left, pocket_y, width, 82), Color("#e9e5d7"), 30)
	for k in s.cap:
		var pos := Vector2(left + width * (k + 0.5) / s.cap, pocket_y + 41)
		draw_circle(pos, 28, Color("#d4cfc0"), true, -1, true)
		draw_arc(pos, 28, PI, TAU, 32, Color("#c4bead"), 2, true)
		if k < s.pocket.size():
			if k == s.pocket.size() - 1:
				pos.y -= 18 * (1.0 - landing)
			draw_circle(pos, 24, COLORS[s.pocket[k]], true, -1, true)
			_mark(self, pos, 9, s.pocket[k])
	draw_string(font, Vector2(left, 166), "Hata  %d" % s.mistakes, HORIZONTAL_ALIGNMENT_RIGHT, width, 22, MUTED)

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(224, 76)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _style(INK, 24))
	b.add_theme_stylebox_override("hover", _style(MUTED, 24))
	b.add_theme_stylebox_override("pressed", _style(INK.darkened(0.2), 24))
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	var vs := get_viewport_rect().size
	retry = _button("Yeniden başlat", func(): start(idx))
	add_child(retry)

	panel = PanelContainer.new()
	panel.z_index = 10
	var modal := _style(CREAM, 32)
	modal.content_margin_left = 30
	modal.content_margin_right = 30
	modal.shadow_size = 18
	modal.shadow_color = Color("#384a4140")
	panel.add_theme_stylebox_override("panel", modal)
	panel.custom_minimum_size = Vector2(420, 320)
	panel.position = vs / 2 - Vector2(210, 160)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel_label = Label.new()
	panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_label.add_theme_font_size_override("font_size", 34)
	panel_label.add_theme_color_override("font_color", INK)
	next_btn = _button("Sonraki bölüm", func(): start((idx + 1) % levels.size()))
	box.add_child(panel_label)
	box.add_child(next_btn)
	box.add_child(_button("Tekrar", func(): start(idx)))
	panel.add_child(box)
	add_child(panel)
