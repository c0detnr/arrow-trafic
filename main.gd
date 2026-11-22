extends Node2D

const Logic = preload("res://logic.gd")
const THEMES := {
	"dark": {
		"ink": Color("#ffffff"),
		"muted": Color("#a3a6a0"),
		"cream": Color("#0f0f0f"),
		"surface": Color("#1a1a1a"),
		"accent": Color("#dafa9c"),
		"grid": Color("#383b36"),
		"veil": Color(0, 0, 0, 0.72),
		"arrows": {"red": Color("#ed8078"), "blue": Color("#80b9ed"), "green": Color("#a9d8ad"),
			"yellow": Color("#edcd76"), "purple": Color("#dfacbd"), "orange": Color("#eba176")},
	},
	"light": {
		"ink": Color("#2b2a26"),
		"muted": Color("#6f6a60"),
		"cream": Color("#f6f1e7"),
		"surface": Color("#fffdf8"),
		"accent": Color("#40561e"),
		"grid": Color("#ded3bd"),
		"veil": Color(0.17, 0.16, 0.15, 0.52),
		"arrows": {"red": Color("#ac4c43"), "blue": Color("#356d9d"), "green": Color("#507b51"),
			"yellow": Color("#8a691a"), "purple": Color("#9d5278"), "orange": Color("#a5522d")},
	},
}
const DISPLAY_FONT = preload("res://assets/fonts/Sora[wght].ttf")
const BODY_FONT = preload("res://assets/fonts/Figtree[wght].ttf")
const SAVE_PATH := "user://save.json"
const ENGLISH_TEXT := {
	"Bölüm %02d": "Level %02d",
	"Sıradaki": "Next",
	"Geçici cep": "Pocket",
	"Tamamlandı": "Complete",
	"Cep doldu": "Pocket full",
	"Bölümü tekrar oyna": "Replay level",
	"Oyna": "Play",
	"Ayarlar": "Settings",
	"Açık tema": "Light theme",
	"Koyu tema": "Dark theme",
	"Kapat": "Close",
	"Yeniden başlat": "Restart",
	"Ana ekran": "Home",
	"Çıkışı açık bir oka dokun.": "Tap an arrow with a clear path.",
	"Sırası gelmeyen renkler cepte bekler.": "Colors not yet called wait in the pocket.",
}
const HUD_ICONS := {
	"remaining": preload("res://assets/remaining.svg"),
	"mistakes": preload("res://assets/mistakes.svg"),
	"queue": preload("res://assets/queue.svg"),
	"pocket": preload("res://assets/pocket.svg"),
}

var levels: Array = []
var idx := 0
var theme_name := "dark"
var palette: Dictionary = THEMES["dark"]
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
var home_button: Button
var panel_retry: Button
var panel: PanelContainer
var panel_label: Label
var veil: ColorRect
var home_screen: ColorRect
var home_art: Node2D
var settings_title: Label
var home_title: TextureRect
var home_title_accent: TextureRect
var home_level: Label
var play_button: Button
var settings_button: Button
var settings_veil: ColorRect
var settings_panel: PanelContainer
var theme_button: Button
var settings_close: Button
var board_layer: Node2D
var board_offset := 0.0
var input_locked := false
var win_tween: Tween
var win_sound: AudioStreamPlayer
var celebration := 0.0
var mascot: Node2D
var mascot_body: StyleBoxFlat
var mascot_state := "idle"
var mascot_blink_in := randf_range(2.0, 5.0)
var mascot_tween: Tween
var language := OS.get_locale_language()


func _ready() -> void:
	levels = _load_levels()
	if levels.is_empty():
		push_error("No levels found in res://levels/")
		return
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	var save := _load_save()
	var saved_theme = save.get("theme", "dark")
	_apply_theme(saved_theme if THEMES.has(saved_theme) else "dark")
	start(clampi(int(save.get("level", 0)), 0, levels.size() - 1))
	_show_home(true)


func _localized(turkish: String) -> String:
	return turkish if language == "tr" else ENGLISH_TEXT[turkish]


func _load_levels() -> Array:
	for p in ["res://levels/levels.json", "res://levels/proto.json", "res://levels/dev_sample.json"]:
		if FileAccess.file_exists(p):
			var data = JSON.parse_string(FileAccess.get_file_as_string(p))
			if data is Array and not data.is_empty():
				return data
	return []


func _load_save() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)) if FileAccess.file_exists(SAVE_PATH) else null
	return data if data is Dictionary else {}


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"level": idx, "theme": theme_name}))


func _toggle_theme() -> void:
	_apply_theme("light" if theme_name == "dark" else "dark")
	_save()


func start(i: int, entering := false) -> void:
	if win_tween and not entering:
		win_tween.kill()
		win_tween = null
		win_sound.stop()
	celebration = 0.0
	board_layer.scale = Vector2.ONE
	board_offset = 18.0 if entering else 0.0
	board_layer.modulate.a = 0.0 if entering else 1.0
	input_locked = entering
	idx = i
	_save()
	for n in board_layer.get_children():
		n.hide()
		n.queue_free()
	nodes.clear()
	if landing_tween:
		landing_tween.kill()
	landing = 1.0
	s = Logic.new_state(levels[idx])
	if mascot_tween:
		mascot_tween.kill()
		mascot_tween = null
	mascot.rotation = 0.0
	_update_mascot_mood()
	_layout()
	for a in s.arrows:
		_make_arrow(a)
	panel.visible = false
	veil.visible = false
	retry.disabled = input_locked
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
	_move_board(board_offset)
	retry.position = Vector2(vs.x - left - retry.size.x, 48)
	home_button.position = retry.position + Vector2(-home_button.size.x - 12, (retry.size.y - home_button.size.y) * 0.5)
	_layout_home(vs)
	veil.size = vs
	panel.position = (vs - panel.size) * 0.5
	for a in s.arrows:
		if nodes.has(a.id):
			var n: Node2D = nodes[a.id]
			n.position = origin - tray.get_center() + Vector2(Logic.head(a)) * cell
			n.set_meta("base", n.position)
			n.queue_redraw()
	queue_redraw()
	board_layer.queue_redraw()


func _mark(canvas: CanvasItem, pos: Vector2, radius: float, color_name: String) -> void:
	var width := radius * 0.42
	match color_name:
		"green":
			canvas.draw_arc(pos, radius * 0.8, 0, TAU, 28, palette.cream, width, true)
		"purple":
			for x in [-0.6, 0.6]:
				canvas.draw_line(pos + Vector2(x, -0.8) * radius, pos + Vector2(x, 0.8) * radius, palette.cream, width, true)
		"blue":
			canvas.draw_circle(pos, radius * 0.78, palette.cream, true, -1, true)
		"orange":
			canvas.draw_line(pos - Vector2.ONE * radius * 0.8, pos + Vector2.ONE * radius * 0.8, palette.cream, width, true)
		"yellow":
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2.UP * radius, pos + Vector2(1, 0.8) * radius, pos + Vector2(-1, 0.8) * radius]), palette.cream)
		"red":
			canvas.draw_line(pos - Vector2.RIGHT * radius, pos + Vector2.RIGHT * radius, palette.cream, width, true)
			canvas.draw_line(pos - Vector2.DOWN * radius, pos + Vector2.DOWN * radius, palette.cream, width, true)


func _make_arrow(a: Dictionary) -> void:
	var n := Node2D.new()
	n.position = origin - tray.get_center() + Vector2(Logic.head(a)) * cell
	n.set_meta("base", n.position)
	n.draw.connect(func():
		var d := Vector2(Logic.DIRS[a.dir])
		var side := d.orthogonal()
		var head := Vector2.ONE * cell * 0.5
		var tail := head - d * cell * (int(a.len) - 1)
		var col: Color = palette.arrows[a.color]
		var tip := head + d * cell * 0.34
		var neck := head - d * cell * 0.14
		n.draw_line(tail, head, col, cell * 0.34, true)
		n.draw_circle(tail, cell * 0.17, col, true, -1, true)
		n.draw_colored_polygon(PackedVector2Array([tip, neck + side * cell * 0.32, neck - side * cell * 0.32]), col)
		_mark(n, tail, cell * 0.087, a.color))
	board_layer.add_child(n)
	nodes[a.id] = n


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not is_node_ready() or not home_screen:
		return
	if settings_veil.visible:
		_show_settings(false)
	elif not home_screen.visible:
		_show_home(true)
	else:
		get_tree().quit()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and settings_veil.visible:
		_show_settings(false)
		get_viewport().set_input_as_handled()
		return
	if e is InputEventScreenTouch and e.pressed:
		_tap(e.position)
	# touch also emits emulated mouse events (device -1); skip those to avoid double taps
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT \
			and e.device != InputEvent.DEVICE_ID_EMULATION:
		_tap(e.position)


func _tap(pos: Vector2) -> void:
	if s.is_empty() or home_screen.visible or input_locked or s.status != "playing":
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
		_shake_mascot()
		var base: Vector2 = n.get_meta("base")
		var t := n.create_tween()
		for off in [d * 8, -d * 6, d * 4, Vector2.ZERO]:
			t.tween_property(n, "position", base + off, 0.05)
	else:
		nodes.erase(a.id)
		var t := create_tween() if r == "won" else n.create_tween()
		t.tween_property(n, "position", n.position + d * cell * (maxi(s.w, s.h) + 2), 0.3)
		t.parallel().tween_property(n, "modulate:a", 0.0, 0.3)
		t.tween_callback(n.queue_free)
		if r == "won":
			_celebrate_win(t)
		elif r == "lost":
			panel_label.text = _localized("Cep doldu")
			panel.visible = true
			veil.visible = true
			retry.disabled = true
		if r != "won" and mascot_state != "blocked":
			_update_mascot_mood()
	queue_redraw()


func _celebrate_win(t: Tween) -> void:
	if mascot_tween:
		mascot_tween.kill()
		mascot_tween = null
	mascot.rotation = 0.0
	mascot_state = "win"
	mascot.queue_redraw()
	input_locked = true
	retry.disabled = true
	win_tween = t
	t.tween_callback(win_sound.play)
	t.tween_method(_show_celebration, 0.0, 1.0, 0.9)
	t.tween_property(board_layer, "modulate:a", 0.0, 0.3)
	t.parallel().tween_method(_move_board, 0.0, -18.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): start((idx + 1) % levels.size(), true))
	t.tween_property(board_layer, "modulate:a", 1.0, 0.35)
	t.parallel().tween_method(_move_board, 18.0, 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		input_locked = false
		retry.disabled = false
		win_tween = null)


func _show_celebration(progress: float) -> void:
	celebration = progress
	mascot.queue_redraw()
	board_layer.scale = Vector2.ONE * (1.0 + sin(PI * progress) * 0.04)
	board_layer.queue_redraw()
	queue_redraw()


func _update_mascot_mood() -> void:
	var mood := "worried" if not s.pocket.is_empty() and s.pocket.size() >= s.cap - 1 else "idle"
	if mascot_state != mood and mood == "idle":
		mascot_blink_in = randf_range(2.0, 5.0)
	mascot_state = mood
	mascot.queue_redraw()


func _shake_mascot() -> void:
	if mascot_tween:
		mascot_tween.kill()
	mascot_state = "blocked"
	mascot.queue_redraw()
	mascot_tween = mascot.create_tween()
	for angle in [-0.21, 0.17, -0.09, 0.0]:
		mascot_tween.tween_property(mascot, "rotation", angle, 0.06)
	mascot_tween.tween_callback(_update_mascot_mood)


func _process(delta: float) -> void:
	if mascot_state != "idle" or not mascot:
		return
	mascot_blink_in -= delta
	if mascot_blink_in <= -0.13:
		mascot_blink_in = randf_range(2.0, 5.0)
	mascot.queue_redraw()


func _draw_mascot() -> void:
	var breath := 1.0
	var jump := 0.0
	if mascot_state == "idle":
		breath += 0.035 * sin(Time.get_ticks_msec() * 0.0025)
	elif mascot_state == "win":
		jump = 4.0 * absf(sin(celebration * TAU))
	mascot.draw_set_transform(Vector2.UP * jump, 0, Vector2.ONE * breath)
	mascot.draw_style_box(mascot_body, Rect2(-21, -12, 34, 24))
	mascot.draw_colored_polygon(PackedVector2Array([Vector2(7, -17), Vector2(25, 0), Vector2(7, 17)]), palette.accent)
	for x in [-10.0, 2.0]:
		var eye := Vector2(x, -4)
		if mascot_state == "win":
			mascot.draw_arc(eye + Vector2.DOWN * 2, 3.0, PI, TAU, 10, palette.cream, 1.8, true)
		elif mascot_state == "idle" and mascot_blink_in <= 0:
			mascot.draw_line(eye - Vector2.RIGHT * 3, eye + Vector2.RIGHT * 3, palette.cream, 2, true)
		else:
			mascot.draw_circle(eye, 3.6 if mascot_state == "blocked" else 2.9, palette.cream, true, -1, true)
	match mascot_state:
		"blocked":
			mascot.draw_circle(Vector2(-4, 5), 2.6, palette.cream, true, -1, true)
		"worried":
			mascot.draw_arc(Vector2(-4, 8), 4, PI, TAU, 10, palette.cream, 1.8, true)
		_:
			var smile := 5.0 if mascot_state == "win" else 3.0
			mascot.draw_arc(Vector2(-4, 3), smile, 0, PI, 10, palette.cream, 1.8, true)


func _move_board(offset: float) -> void:
	board_offset = offset
	board_layer.position = tray.get_center() + Vector2.DOWN * offset


func _make_win_chime() -> AudioStreamWAV:
	const RATE := 22050
	const NOTE_LENGTH := 0.32
	const NOTE_INTERVAL := 0.14
	var sample_count := roundi(0.6 * RATE)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var notes := [523.25, 659.25, 783.99]
	for i in sample_count:
		var time := float(i) / RATE
		var sample := 0.0
		for note in notes.size():
			var age := time - note * NOTE_INTERVAL
			if age < 0.0 or age >= NOTE_LENGTH:
				continue
			var envelope := smoothstep(0.0, 0.018, age) * exp(-11.0 * age)
			envelope *= 1.0 - smoothstep(0.23, NOTE_LENGTH, age)
			sample += sin(TAU * notes[note] * age) * envelope * 0.26
		pcm.encode_s16(i * 2, roundi(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = pcm
	return stream



func _style(tint: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(radius)
	return style


func _text(pos: Vector2, text: String, size: int, color: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, display := false) -> void:
	draw_string(DISPLAY_FONT if display else BODY_FONT, pos, text, align, width, size, color)


func _draw() -> void:
	if s.is_empty():
		return
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), palette.cream)
	var width := vs.x - 2 * left
	_text(Vector2(left, 112), _localized("Bölüm %02d") % (idx + 1), 50, palette.ink, -1, HORIZONTAL_ALIGNMENT_LEFT, true)

	# The queue's first item gets a fixed slot; the preview fits the remaining width.
	draw_texture_rect(HUD_ICONS.queue, Rect2(left, 180, 28, 28), false, palette.accent)
	_text(Vector2(left + 40, 203), _localized("Sıradaki"), 26, palette.accent)
	var count := mini(s.queue.size(), 6)
	var step := (width - 184) / 5.0
	for k in count:
		var pos := Vector2(left + 36 if k == 0 else left + 134 + (k - 1) * step, 259)
		if k == 0:
			draw_arc(pos, 34, 0, TAU, 48, palette.accent, 2, true)
		draw_circle(pos, 26 if k == 0 else 18, palette.arrows[s.queue[k]], true, -1, true)
		_mark(self, pos, 9 if k == 0 else 7, s.queue[k])
	if s.queue.size() > count:
		_text(Vector2(vs.x - left - 64, 267), "+%d" % (s.queue.size() - count), 26, palette.muted, 44, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_texture_rect(HUD_ICONS.remaining, Rect2(left, 330, 28, 28), false, palette.muted)
	_text(Vector2(left + 40, 353), str(s.arrows.size()), 26, palette.muted)
	var mistakes_width := BODY_FONT.get_string_size(str(s.mistakes), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_texture_rect(HUD_ICONS.mistakes, Rect2(vs.x - left - mistakes_width - 40, 330, 28, 28), false, palette.muted)
	_text(Vector2(left, 353), str(s.mistakes), 26, palette.muted, width, HORIZONTAL_ALIGNMENT_RIGHT)

	if celebration > 0.0 and celebration < 1.0:
		var opacity := smoothstep(0.0, 0.2, celebration) * (1.0 - smoothstep(0.72, 1.0, celebration))
		_text(Vector2(left, 353), _localized("Tamamlandı"), 26, Color(palette.accent, opacity), width, HORIZONTAL_ALIGNMENT_CENTER, true)

	draw_texture_rect(HUD_ICONS.pocket, Rect2(left, pocket_y - 51, 28, 28), false, palette.ink)
	_text(Vector2(left + 40, pocket_y - 28), _localized("Geçici cep"), 26, palette.ink)
	_text(Vector2(left, pocket_y - 28), "%d / %d" % [s.pocket.size(), s.cap], 26, palette.accent if s.pocket.size() == s.cap else palette.muted, width, HORIZONTAL_ALIGNMENT_RIGHT)
	for k in s.cap:
		var pos := Vector2(left + width * (k + 0.5) / s.cap, pocket_y + 47)
		draw_arc(pos, 29, 0, TAU, 48, palette.muted, 2, true)
		if k < s.pocket.size():
			if k == s.pocket.size() - 1:
				pos.y -= 18 * (1.0 - landing)
			draw_circle(pos, 25, palette.arrows[s.pocket[k]], true, -1, true)
			_mark(self, pos, 9, s.pocket[k])

	if idx == 0:
		_text(Vector2(left, vs.y - 62), _localized("Çıkışı açık bir oka dokun."), 26, palette.muted, width, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(left, vs.y - 30), _localized("Sırası gelmeyen renkler cepte bekler."), 24, palette.muted, width, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_board() -> void:
	var center := tray.get_center()
	board_layer.draw_style_box(_style(palette.surface, 24), Rect2(tray.position - center, tray.size))
	for y in s.h:
		for x in s.w:
			var dot := origin - center + (Vector2(x, y) + Vector2.ONE * 0.5) * cell
			board_layer.draw_circle(dot, 2.5, palette.grid, true, -1, true)
	if celebration > 0.0 and celebration < 1.0:
		var radius := lerpf(8.0, minf(tray.size.x, tray.size.y) * 0.45, sin(celebration * PI * 0.5))
		var opacity := smoothstep(0.0, 0.15, celebration) * (1.0 - smoothstep(0.3, 1.0, celebration))
		board_layer.draw_circle(Vector2.ZERO, radius, Color(palette.accent, opacity * 0.06), false, 18, true)
		board_layer.draw_circle(Vector2.ZERO, radius, Color(palette.accent, opacity * 0.12), false, 10, true)
		board_layer.draw_circle(Vector2.ZERO, radius, Color(palette.accent, opacity * 0.24), false, 4, true)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(204, 84)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_font_override("font", BODY_FONT)
	b.pressed.connect(cb)
	return b


func _style_button(b: Button) -> void:
	b.add_theme_color_override("icon_normal_color", palette.cream)
	b.add_theme_color_override("icon_hover_color", palette.cream)
	b.add_theme_color_override("icon_pressed_color", palette.cream)
	b.add_theme_color_override("font_focus_color", palette.cream)
	b.add_theme_color_override("icon_focus_color", palette.cream)
	b.add_theme_color_override("font_color", palette.cream)
	b.add_theme_color_override("font_hover_color", palette.cream)
	b.add_theme_color_override("font_pressed_color", palette.cream)
	b.add_theme_stylebox_override("normal", _style(palette.accent, 18))
	b.add_theme_stylebox_override("hover", _style(palette.accent.lightened(0.14), 18))
	b.add_theme_stylebox_override("pressed", _style(palette.accent.darkened(0.14), 18))
	var focus := _style(Color.TRANSPARENT, 18)
	focus.set_border_width_all(3)
	focus.border_color = palette.ink
	focus.expand_margin_left = 5
	focus.expand_margin_right = 5
	focus.expand_margin_top = 5
	focus.expand_margin_bottom = 5
	b.add_theme_stylebox_override("focus", focus)


func _apply_theme(next_theme: String) -> void:
	theme_name = next_theme
	palette = THEMES[theme_name]
	mascot_body = _style(palette.accent, 10)
	mascot_body.anti_aliasing_size = 0.15
	mascot.queue_redraw()
	for button in [retry, home_button, panel_retry, play_button, settings_button, theme_button, settings_close]:
		_style_button(button)
	retry.add_theme_color_override("icon_normal_color", palette.ink)
	retry.add_theme_color_override("icon_hover_color", palette.cream)
	retry.add_theme_color_override("icon_pressed_color", palette.cream)
	panel_label.add_theme_color_override("font_color", palette.ink)
	home_screen.color = palette.cream
	home_art.queue_redraw()
	_style_neutral_button(settings_button)
	_style_neutral_button(settings_close)
	settings_title.add_theme_color_override("font_color", palette.ink)
	home_title.self_modulate = Color("#faf1d9") if theme_name == "dark" else palette.ink
	home_title_accent.self_modulate = palette.accent
	home_level.add_theme_color_override("font_color", palette.muted)
	theme_button.text = _localized("Açık tema" if theme_name == "dark" else "Koyu tema")
	veil.color = palette.veil
	settings_veil.color = palette.veil
	var modal := _style(palette.surface, 28)
	modal.content_margin_left = 30
	modal.content_margin_right = 30
	modal.content_margin_top = 36
	modal.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", modal)
	settings_panel.add_theme_stylebox_override("panel", modal)
	for arrow in board_layer.get_children():
		arrow.queue_redraw()
	board_layer.queue_redraw()
	queue_redraw()


func _build_ui() -> void:
	board_layer = Node2D.new()
	board_layer.draw.connect(_draw_board)
	add_child(board_layer)
	mascot = Node2D.new()
	mascot.name = "Mascot"
	mascot.draw.connect(_draw_mascot)
	add_child(mascot)
	win_sound = AudioStreamPlayer.new()
	win_sound.stream = _make_win_chime()
	add_child(win_sound)
	veil = ColorRect.new()
	veil.z_index = 9
	add_child(veil)
	retry = _button("", func():
		if not input_locked:
			start(idx))
	retry.icon = preload("res://assets/restart.svg")
	retry.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retry.flat = true
	retry.custom_minimum_size = Vector2(88, 88)
	retry.tooltip_text = _localized("Yeniden başlat")
	retry.accessibility_name = retry.tooltip_text
	add_child(retry)

	home_button = _button("", _show_home.bind(true))
	home_button.icon = preload("res://assets/home.svg")
	home_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_button.custom_minimum_size = Vector2(60, 60)
	home_button.tooltip_text = _localized("Ana ekran")
	home_button.accessibility_name = home_button.tooltip_text
	add_child(home_button)

	panel = PanelContainer.new()
	panel.z_index = 10
	panel.custom_minimum_size = Vector2(540, 360)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	panel_label = Label.new()
	panel_label.add_theme_font_override("font", DISPLAY_FONT)
	panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_label.add_theme_font_size_override("font_size", 34)
	box.add_child(panel_label)
	panel_retry = _button(_localized("Bölümü tekrar oyna"), func(): start(idx))
	box.add_child(panel_retry)
	panel.add_child(box)
	add_child(panel)
	_build_home()


func _build_home() -> void:
	home_screen = ColorRect.new()
	home_screen.z_index = 11
	add_child(home_screen)

	home_art = Node2D.new()
	home_art.draw.connect(_draw_home_art)
	home_screen.add_child(home_art)
	home_title = TextureRect.new()
	home_title.texture = preload("res://assets/home-logo.svg")
	home_title.accessibility_name = "Arrow Traffic"
	home_title_accent = TextureRect.new()
	home_title_accent.texture = preload("res://assets/home-logo-accent.svg")
	for layer in [home_title, home_title_accent]:
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_screen.add_child(home_title)
	home_title.add_child(home_title_accent)
	home_title_accent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_level = _home_label("", BODY_FONT, 32)
	play_button = _button(_localized("Oyna"), _show_home.bind(false))
	play_button.custom_minimum_size = Vector2(304, 120)
	play_button.add_theme_font_size_override("font_size", 34)
	home_screen.add_child(play_button)

	settings_button = _button("", _show_settings.bind(true))
	settings_button.icon = preload("res://assets/settings.svg")
	settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_button.custom_minimum_size = Vector2(104, 104)
	settings_button.expand_icon = true
	settings_button.add_theme_constant_override("icon_max_width", 48)
	settings_button.tooltip_text = _localized("Ayarlar")
	settings_button.accessibility_name = settings_button.tooltip_text
	home_screen.add_child(settings_button)

	settings_veil = ColorRect.new()
	settings_veil.z_index = 2
	settings_veil.hide()
	home_screen.add_child(settings_veil)
	var settings_center := CenterContainer.new()
	settings_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_veil.add_child(settings_center)
	settings_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel = PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(480, 0)
	settings_center.add_child(settings_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	settings_panel.add_child(box)
	settings_title = Label.new()
	settings_title.text = settings_button.tooltip_text
	settings_title.add_theme_font_override("font", DISPLAY_FONT)
	settings_title.add_theme_font_size_override("font_size", 38)
	box.add_child(settings_title)
	theme_button = _button("", _toggle_theme)
	theme_button.custom_minimum_size.y = 104
	box.add_child(theme_button)
	settings_close = _button(_localized("Kapat"), _show_settings.bind(false))
	settings_close.custom_minimum_size.y = 104
	box.add_child(settings_close)
	theme_button.focus_neighbor_top = theme_button.get_path_to(settings_close)
	theme_button.focus_neighbor_bottom = theme_button.get_path_to(settings_close)
	settings_close.focus_neighbor_top = settings_close.get_path_to(theme_button)
	settings_close.focus_neighbor_bottom = settings_close.get_path_to(theme_button)


func _home_label(text: String, font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	home_screen.add_child(label)
	return label


func _show_home(open: bool) -> void:
	home_screen.visible = open
	retry.visible = not open
	home_button.visible = not open
	if not open:
		_show_settings(false)
	_layout_home(get_viewport_rect().size)
	if open:
		play_button.grab_focus()
	else:
		home_button.grab_focus()


func _show_settings(open: bool) -> void:
	settings_veil.visible = open
	var menu_focus := Control.FOCUS_NONE if open else Control.FOCUS_ALL
	play_button.focus_mode = menu_focus
	settings_button.focus_mode = menu_focus
	if open:
		theme_button.grab_focus()
	else:
		settings_button.grab_focus()


func _layout_home(vs: Vector2) -> void:
	var safe := Rect2(Vector2.ZERO, vs)
	if OS.has_feature("mobile"):
		var screen_size := Vector2(DisplayServer.screen_get_size())
		var display_safe := DisplayServer.get_display_safe_area()
		safe = Rect2(Vector2(display_safe.position) / screen_size * vs, Vector2(display_safe.size) / screen_size * vs)
	var width := minf(safe.size.x - 108, 780)
	var edge := safe.position.x + (safe.size.x - width) * 0.5
	var is_home := home_screen.visible
	var art_scale := minf(width / 600.0, (safe.size.y - 640) / 440.0)
	home_art.position = Vector2(safe.get_center().x, safe.position.y + (400 + safe.size.y - 300) * 0.5)
	home_art.scale = Vector2.ONE * art_scale
	mascot.z_index = 12 if is_home else 0
	mascot.position = home_art.position if is_home else Vector2(vs.x * 0.5, pocket_y - 28)
	mascot.scale = Vector2.ONE * (5.2 * art_scale if is_home else 1.5)
	home_screen.size = vs
	settings_veil.size = vs
	home_title.position = Vector2(edge, safe.position.y + 150)
	home_title.size = Vector2(minf(width, 550), 240)
	home_level.text = _localized("Bölüm %02d") % (idx + 1)
	home_level.position = Vector2(edge, safe.end.y - 282)
	home_level.size.x = width
	play_button.size = Vector2(width, 120)
	play_button.position = Vector2(edge, safe.end.y - 204)
	settings_button.position = Vector2(edge + width - 104, safe.position.y + 32)


func _style_neutral_button(button: Button) -> void:
	button.add_theme_color_override("font_focus_color", palette.ink)
	button.add_theme_color_override("icon_focus_color", palette.ink)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, _style(palette.surface if state == "normal" else palette.grid, 18))
		var suffix: String = "normal" if state == "normal" else state
		button.add_theme_color_override("icon_" + suffix + "_color", palette.ink)
		button.add_theme_color_override("font_" + ("color" if state == "normal" else suffix + "_color"), palette.ink)


func _draw_home_art() -> void:
	# These routes use the board's own colours and direction language.
	var routes := [
		["blue", [Vector2(-274, 104), Vector2(-274, -124), Vector2(-112, -124), Vector2(-112, -196)]],
		["red", [Vector2(-218, 180), Vector2(-82, 180), Vector2(-82, 114), Vector2(120, 114)]],
		["yellow", [Vector2(14, -196), Vector2(14, -116), Vector2(206, -116), Vector2(206, -28)]],
		["green", [Vector2(274, -168), Vector2(274, 178), Vector2(190, 178)]],
		["orange", [Vector2(-200, -42), Vector2(-200, 48), Vector2(-148, 48)]],
		["purple", [Vector2(72, 196), Vector2(72, 166), Vector2(14, 166)]],
	]
	for route in routes:
		var points: PackedVector2Array = PackedVector2Array(route[1])
		var color: Color = palette.arrows[route[0]]
		for i in points.size() - 1:
			home_art.draw_line(points[i], points[i + 1], color, 24, true)
			home_art.draw_circle(points[i], 12, color, true, -1, true)
		var tip := points[-1]
		var direction := (tip - points[-2]).normalized()
		var neck := tip - direction * 20
		home_art.draw_colored_polygon(PackedVector2Array([tip + direction * 10, neck + direction.orthogonal() * 26, neck - direction.orthogonal() * 26]), color)
		_mark(home_art, points[0], 7, route[0])
