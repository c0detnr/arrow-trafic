extends Node2D

const Logic = preload("res://logic.gd")
const COLORS := {"red": Color("#ed8078"), "blue": Color("#80b9ed"), "green": Color("#a9d8ad"),
	"yellow": Color("#edcd76"), "purple": Color("#dfacbd"), "orange": Color("#eba176")}
const INK := Color("#ffffff")
const MUTED := Color("#a3a6a0")
const CREAM := Color("#0f0f0f")
const SURFACE := Color("#1a1a1a")
const ACCENT := Color("#dafa9c")
const DISPLAY_FONT = preload("res://assets/fonts/Sora[wght].ttf")
const BODY_FONT = preload("res://assets/fonts/Figtree[wght].ttf")
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
var veil: ColorRect


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
	veil.visible = false
	retry.disabled = false
	queue_redraw()


func _layout() -> void:
	if s.is_empty():
		return
	var vs := get_viewport_rect().size
	var width := minf(vs.x - 72, 680)
	left = (vs.x - width) * 0.5
	pocket_y = vs.y - 206
	var area := Rect2(left + 24, 401, width - 48, pocket_y - 509)
	cell = minf(area.size.x / s.w, area.size.y / s.h)
	var board := Vector2(s.w, s.h) * cell
	origin = area.get_center() - board * 0.5
	tray = Rect2(origin, board).grow(24)
	retry.position = Vector2(vs.x - left - retry.size.x, 48)
	veil.size = vs
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
		n.draw_line(tail, head, col, cell * 0.34, true)
		n.draw_circle(tail, cell * 0.17, col, true, -1, true)
		n.draw_colored_polygon(PackedVector2Array([tip, neck + side * cell * 0.32, neck - side * cell * 0.32]), col)
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
			veil.visible = true
			retry.disabled = true
	queue_redraw()



func _surface(rect: Rect2, tint: Color, radius: int) -> void:
	draw_style_box(_style(tint, radius), rect)


func _style(tint: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(radius)
	return style


func _text(pos: Vector2, text: String, size: int, color := INK, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, display := false) -> void:
	draw_string(DISPLAY_FONT if display else BODY_FONT, pos, text, align, width, size, color)


func _draw() -> void:
	if s.is_empty():
		return
	var vs := get_viewport_rect().size
	var width := vs.x - 2 * left
	_text(Vector2(left, 112), "Bölüm %02d" % (idx + 1), 50, INK, -1, HORIZONTAL_ALIGNMENT_LEFT, true)

	# The queue's first item gets a fixed slot; the preview fits the remaining width.
	_text(Vector2(left, 203), "Sıradaki", 26, ACCENT)
	var count := mini(s.queue.size(), 6)
	var step := (width - 184) / 5.0
	for k in count:
		var pos := Vector2(left + 36 if k == 0 else left + 134 + (k - 1) * step, 259)
		if k == 0:
			draw_arc(pos, 34, 0, TAU, 48, ACCENT, 2, true)
		draw_circle(pos, 26 if k == 0 else 18, COLORS[s.queue[k]], true, -1, true)
		_mark(self, pos, 9 if k == 0 else 7, s.queue[k])
	if s.queue.size() > count:
		_text(Vector2(vs.x - left - 64, 267), "+%d" % (s.queue.size() - count), 26, MUTED, 44, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(left, 353), "%d ok kaldı" % s.arrows.size(), 26, MUTED)
	_text(Vector2(left, 353), "Hata  %d" % s.mistakes, 26, MUTED, width, HORIZONTAL_ALIGNMENT_RIGHT)

	_surface(tray, SURFACE, 24)
	for y in s.h:
		for x in s.w:
			draw_circle(origin + (Vector2(x, y) + Vector2.ONE * 0.5) * cell, 2.5, Color("#383b36"), true, -1, true)

	_text(Vector2(left, pocket_y - 28), "Geçici cep", 26, INK)
	_text(Vector2(left, pocket_y - 28), "%d / %d dolu" % [s.pocket.size(), s.cap], 26, ACCENT if s.pocket.size() == s.cap else MUTED, width, HORIZONTAL_ALIGNMENT_RIGHT)
	for k in s.cap:
		var pos := Vector2(left + width * (k + 0.5) / s.cap, pocket_y + 47)
		draw_arc(pos, 29, 0, TAU, 48, MUTED, 2, true)
		if k < s.pocket.size():
			if k == s.pocket.size() - 1:
				pos.y -= 18 * (1.0 - landing)
			draw_circle(pos, 25, COLORS[s.pocket[k]], true, -1, true)
			_mark(self, pos, 9, s.pocket[k])

	if idx == 0:
		_text(Vector2(left, vs.y - 62), "Çıkışı açık bir oka dokun.", 26, MUTED, width, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(left, vs.y - 30), "Sırası gelmeyen renkler cepte bekler.", 24, MUTED, width, HORIZONTAL_ALIGNMENT_CENTER)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(204, 84)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_font_override("font", BODY_FONT)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_stylebox_override("normal", _style(ACCENT, 18))
	b.add_theme_stylebox_override("hover", _style(ACCENT.lightened(0.14), 18))
	b.add_theme_stylebox_override("pressed", _style(ACCENT.darkened(0.14), 18))
	var focus := _style(Color.TRANSPARENT, 18)
	focus.set_border_width_all(3)
	focus.border_color = INK
	focus.expand_margin_left = 5
	focus.expand_margin_right = 5
	focus.expand_margin_top = 5
	focus.expand_margin_bottom = 5
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	veil = ColorRect.new()
	veil.color = Color(0, 0, 0, 0.72)
	veil.z_index = 9
	add_child(veil)
	retry = _button("", func(): start(idx))
	retry.icon = preload("res://assets/restart.svg")
	retry.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retry.flat = true
	retry.custom_minimum_size = Vector2(88, 88)
	retry.tooltip_text = "Yeniden başlat"
	retry.accessibility_name = retry.tooltip_text
	retry.add_theme_color_override("icon_hover_color", CREAM)
	retry.add_theme_color_override("icon_pressed_color", CREAM)
	add_child(retry)

	panel = PanelContainer.new()
	panel.z_index = 10
	var modal := _style(SURFACE, 28)
	modal.content_margin_left = 30
	modal.content_margin_right = 30
	modal.content_margin_top = 36
	modal.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", modal)
	panel.custom_minimum_size = Vector2(540, 360)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	panel_label = Label.new()
	panel_label.add_theme_font_override("font", DISPLAY_FONT)
	panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_label.add_theme_font_size_override("font_size", 34)
	panel_label.add_theme_color_override("font_color", INK)
	next_btn = _button("Sonraki bölüm", func(): start((idx + 1) % levels.size()))
	box.add_child(panel_label)
	box.add_child(next_btn)
	box.add_child(_button("Bölümü tekrar oyna", func(): start(idx)))
	panel.add_child(box)
	add_child(panel)
