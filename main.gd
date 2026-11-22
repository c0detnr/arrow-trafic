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
	"Bölüm %02d · ★ %d": "Level %02d · ★ %d",
	"İpucu": "Hint",
	"İpucu, %d kaldı": "Hint, %d left",
	"Buradan çıkış yok — geri al veya yeniden başlat": "No way out from here — undo or restart",
	"Reklam izle · Geri al": "Watch ad · Undo",
	"1 ipucu ile geri al": "Undo for 1 hint",
	"Mağaza": "Shop",
	"İpuçların: %d": "Your hints: %d",
	"Reklam izle · +1 ipucu": "Watch ad · +1 hint",
	"10 ipucu": "10 hints",
	"30 ipucu": "30 hints",
	"Reklamları kaldır (+5 ipucu)": "Remove ads (+5 hints)",
	"Destekçi paketi: reklamsız + 40 ipucu": "Supporter pack: no ads + 40 hints",
	"Satın alındı ✓": "Owned ✓",
	"Mağaza şu an kullanılamıyor": "Store unavailable right now",
	"Teşekkürler!": "Thank you!",
	"Satın alma tamamlanmadı": "Purchase didn't go through",
	"Günlük hediye: +1 ipucu": "Daily gift: +1 hint",
	"Günlük hediye: +%d ipucu": "Daily gift: +%d hints",
	"+1 ipucu · Seri %d gün": "+1 hint · %d-day streak",
	"+%d ipucu · Seri %d gün": "+%d hints · %d-day streak",
	"+1 ipucu": "+1 hint",
	"+1 ipucu bonusu": "+1 bonus hint",
	"+%d ipucu bonusu": "+%d bonus hints",
	"Satın alımları geri yükle": "Restore purchases",
	"Satın alımlar kontrol ediliyor": "Checking your purchases",
	"Gizlilik seçenekleri": "Privacy options",
}
const HUD_ICONS := {
	"remaining": preload("res://assets/remaining.svg"),
	"mistakes": preload("res://assets/mistakes.svg"),
	"queue": preload("res://assets/queue.svg"),
	"pocket": preload("res://assets/pocket.svg"),
}
const ICONS := {
	"hint": preload("res://assets/hint.svg"),
	"shop": preload("res://assets/shop.svg"),
	"ad": preload("res://assets/ad.svg"),
	"gift": preload("res://assets/gift.svg"),
	"undo": preload("res://assets/undo.svg"),
	"star": preload("res://assets/star.svg"),
}
## Store rows in display order with their Turkish names (English via ENGLISH_TEXT).
const SHOP_PRODUCTS := {
	"hints_10": "10 ipucu",
	"hints_30": "30 ipucu",
	"remove_ads": "Reklamları kaldır (+5 ipucu)",
	"supporter_pack": "Destekçi paketi: reklamsız + 40 ipucu",
}
const HISTORY_LIMIT := 30
## Consecutive blocked taps before the hint button pulses once.
const STUCK_TAPS := 3
## The hint button draws 88px but takes a 100px touch target (44pt on a 320pt-wide phone).
const HINT_TARGET := 100.0
const HINT_INSET := 6.0
const TOUCH_MIN := 100.0
const TOAST_SECONDS := 1.8

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
# Monetization UI
var hint_button: Button
var hint_badge: PanelContainer
var hint_badge_label: Label
var hint_badge_icon: TextureRect
var hint_nudge: Tween
var hinted_id := -1
var history: Array = []  # Logic.snapshot before each successful move, newest last
var blocked_streak := 0
var win_stars := 0
var revive_ad_button: Button
var revive_hint_button: Button
var shop_button: Button
var shop_veil: ColorRect
var shop_panel: PanelContainer
var shop_title: Label
var shop_hints_label: Label
var shop_scroll: ScrollContainer
var shop_list: VBoxContainer
var shop_ad_button: Button
var shop_rows := {}  # product id -> Button
var shop_unavailable: Label
var shop_close: Button
var shop_return_focus: Control
var daily_button: Button
var restore_button: Button
var privacy_button: Button
var toast: PanelContainer
var toast_label: Label
var toast_tween: Tween


func _ready() -> void:
	levels = _load_levels()
	if levels.is_empty():
		push_error("No levels found in res://levels/")
		return
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	Economy.hints_changed.connect(_on_hints_changed)
	Ads.rewarded_ready_changed.connect(_on_rewarded_ready_changed)
	IAP.products_updated.connect(_refresh_wallet)
	IAP.availability_changed.connect(_on_store_availability)
	IAP.purchase_completed.connect(_on_purchase_completed)
	IAP.purchase_failed.connect(_on_purchase_failed)
	var save := _load_save()
	var saved_theme = save.get("theme", "dark")
	_apply_theme(saved_theme if THEMES.has(saved_theme) else "dark")
	start(clampi(int(save.get("level", 0)), 0, levels.size() - 1))
	_show_home(true)
	Ads.request_consent.call_deferred()


func _localized(turkish: String) -> String:
	return turkish if language == "tr" else ENGLISH_TEXT.get(turkish, turkish)


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
	s = Logic.new_state(levels[idx])
	history.clear()
	blocked_streak = 0
	win_stars = 0
	if mascot_tween:
		mascot_tween.kill()
		mascot_tween = null
	mascot.rotation = 0.0
	_update_mascot_mood()
	_rebuild_board()
	panel.visible = false
	veil.visible = false
	retry.disabled = input_locked
	_refresh_hint_button()
	queue_redraw()


## Re-creates every arrow node from s.arrows (used by start and by revive/undo).
func _rebuild_board() -> void:
	for n in board_layer.get_children():
		n.hide()
		n.queue_free()
	nodes.clear()
	hinted_id = -1
	if landing_tween:
		landing_tween.kill()
	landing = 1.0
	_layout()
	for a in s.arrows:
		_make_arrow(a)


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
	# Visual 88px button sits 16px left of Home; its touch rect extends HINT_INSET past that.
	hint_button.size = Vector2.ONE * HINT_TARGET
	hint_button.position = Vector2(home_button.position.x - 16 - (HINT_TARGET - HINT_INSET), retry.position.y - HINT_INSET)
	hint_button.pivot_offset = hint_button.size * 0.5
	_layout_home(vs)
	veil.size = vs
	panel.reset_size()
	panel.position = (vs - panel.size) * 0.5
	_layout_shop(vs)
	if toast.visible:
		_place_toast()
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
		if int(a.id) == hinted_id:
			# Opaque halo (surface blended toward accent) so overlapping shapes leave no seams.
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
			var halo: Color = palette.surface.lerp(palette.accent, 0.55 + 0.35 * pulse)
			var grow := cell * (0.08 + 0.06 * pulse)
			n.draw_line(tail, head, halo, cell * 0.34 + grow * 2, true)
			n.draw_circle(tail, cell * 0.17 + grow, halo, true, -1, true)
			n.draw_colored_polygon(PackedVector2Array([tip + d * grow * 1.4, neck - d * grow + side * (cell * 0.32 + grow * 1.2),
				neck - d * grow - side * (cell * 0.32 + grow * 1.2)]), halo)
		n.draw_line(tail, head, col, cell * 0.34, true)
		n.draw_circle(tail, cell * 0.17, col, true, -1, true)
		n.draw_colored_polygon(PackedVector2Array([tip, neck + side * cell * 0.32, neck - side * cell * 0.32]), col)
		_mark(n, tail, cell * 0.087, a.color))
	board_layer.add_child(n)
	nodes[a.id] = n


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not is_node_ready() or not home_screen:
		return
	if shop_veil.visible:
		_show_shop(false)
	elif settings_veil.visible:
		_show_settings(false)
	elif not home_screen.visible:
		_show_home(true)
	else:
		get_tree().quit()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and (shop_veil.visible or settings_veil.visible):
		if shop_veil.visible:
			_show_shop(false)
		else:
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
	if s.is_empty() or home_screen.visible or shop_veil.visible or input_locked or s.status != "playing":
		return
	var i := Logic.arrow_at(s, Vector2i(((pos - origin) / cell).floor()))
	if i < 0:
		return
	var a: Dictionary = s.arrows[i]
	var n: Node2D = nodes[a.id]
	if Logic.can_exit(s, i):
		history.append(Logic.snapshot(s))
		if history.size() > HISTORY_LIMIT:
			history.pop_front()
	var r := Logic.tap(s, i)
	if r == "blocked":
		blocked_streak += 1
		if blocked_streak >= STUCK_TAPS:
			blocked_streak = 0
			_nudge_hint()
	else:
		blocked_streak = 0
		# Any real move changes the state, so an older hint no longer applies.
		hinted_id = -1
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
			var clear: Dictionary = Economy.record_clear(idx, s.mistakes)
			win_stars = int(clear.stars)
			if int(clear.bonus_hints) > 0:
				var bonus := int(clear.bonus_hints)
				_toast(_localized("+1 ipucu bonusu") if bonus == 1 else _localized("+%d ipucu bonusu") % bonus)
			_celebrate_win(t)
		elif r == "lost":
			_show_loss_panel()
		if r != "won" and mascot_state != "blocked":
			_update_mascot_mood()
	_refresh_hint_button()
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
		win_tween = null
		_refresh_hint_button()
		# Wins only: Ads applies its own pacing and usually shows nothing.
		Ads.on_level_cleared(Economy.levels_cleared))


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
	if hinted_id != -1 and nodes.has(hinted_id):
		nodes[hinted_id].queue_redraw()
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
	var title := _localized("Bölüm %02d") % (idx + 1)
	_text(Vector2(left, 112), title, _title_font_size(title), palette.ink, -1, HORIZONTAL_ALIGNMENT_LEFT, true)

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
		# Earned stars pop in one by one where the (now empty) queue was.
		for k in 3 if win_stars > 0 else 0:
			var pop := smoothstep(0.04 + 0.08 * k, 0.2 + 0.08 * k, celebration)
			var star_size := 46.0 * (0.6 + 0.4 * pop)
			var center := Vector2(vs.x * 0.5 + (k - 1) * 62, 259)
			var tint: Color = palette.accent if k < win_stars else palette.grid
			draw_texture_rect(ICONS.star, Rect2(center - Vector2.ONE * star_size * 0.5, Vector2.ONE * star_size), false, Color(tint, opacity * pop))

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
	b.add_theme_stylebox_override("disabled", _style(Color(palette.accent, 0.4), 18))
	b.add_theme_color_override("font_disabled_color", Color(palette.cream, 0.75))
	b.add_theme_color_override("icon_disabled_color", Color(palette.cream, 0.75))
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
	for button in [retry, home_button, panel_retry, play_button, settings_button, theme_button, settings_close,
			hint_button, revive_ad_button, shop_ad_button]:
		_style_button(button)
	retry.add_theme_color_override("icon_normal_color", palette.ink)
	retry.add_theme_color_override("icon_hover_color", palette.cream)
	retry.add_theme_color_override("icon_pressed_color", palette.cream)
	retry.add_theme_color_override("icon_disabled_color", Color(palette.ink, 0.3))
	_inset_button(hint_button, HINT_INSET)
	panel_label.add_theme_color_override("font_color", palette.ink)
	home_screen.color = palette.cream
	home_art.queue_redraw()
	for button in [settings_button, settings_close, shop_button, restore_button, privacy_button, shop_close, daily_button]:
		_style_neutral_button(button)
	_style_neutral_button(revive_hint_button, palette.cream)
	_tint_content(revive_ad_button, palette.cream)
	_tint_content(revive_hint_button, palette.ink)
	for id in shop_rows:
		_style_neutral_button(shop_rows[id], palette.cream)
	daily_button.add_theme_color_override("icon_normal_color", palette.accent)
	daily_button.add_theme_color_override("icon_hover_color", palette.accent)
	daily_button.add_theme_color_override("icon_pressed_color", palette.accent)
	_pad_button(daily_button, 30)
	var badge := _style(palette.ink, 18)
	badge.set_border_width_all(3)
	badge.border_color = palette.cream
	badge.content_margin_left = 9
	badge.content_margin_right = 9
	badge.content_margin_top = 1
	badge.content_margin_bottom = 1
	hint_badge.add_theme_stylebox_override("panel", badge)
	hint_badge_label.add_theme_color_override("font_color", palette.cream)
	hint_badge_icon.self_modulate = palette.cream
	var toast_box := _style(palette.surface, 18)
	toast_box.set_border_width_all(2)
	toast_box.border_color = palette.grid
	toast_box.shadow_color = Color(0, 0, 0, 0.22)
	toast_box.shadow_size = 12
	toast_box.content_margin_left = 26
	toast_box.content_margin_right = 26
	toast_box.content_margin_top = 16
	toast_box.content_margin_bottom = 16
	toast.add_theme_stylebox_override("panel", toast_box)
	toast_label.add_theme_color_override("font_color", palette.ink)
	settings_title.add_theme_color_override("font_color", palette.ink)
	shop_title.add_theme_color_override("font_color", palette.ink)
	shop_hints_label.add_theme_color_override("font_color", palette.muted)
	shop_unavailable.add_theme_color_override("font_color", palette.muted)
	shop_veil.color = palette.veil
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
	shop_panel.add_theme_stylebox_override("panel", modal)
	_refresh_wallet()
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

	hint_button = _button("", _on_hint_pressed)
	hint_button.icon = ICONS.hint
	hint_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_button.custom_minimum_size = Vector2.ONE * HINT_TARGET
	hint_button.tooltip_text = _localized("İpucu")
	hint_button.accessibility_name = hint_button.tooltip_text
	add_child(hint_button)
	hint_badge = PanelContainer.new()
	hint_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_badge_icon = TextureRect.new()
	hint_badge_icon.texture = ICONS.ad
	hint_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hint_badge_icon.custom_minimum_size = Vector2(22, 28)
	hint_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.add_child(hint_badge_icon)
	hint_badge_label = Label.new()
	hint_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_badge_label.custom_minimum_size.x = 14
	hint_badge_label.add_theme_font_override("font", DISPLAY_FONT)
	hint_badge_label.add_theme_font_size_override("font_size", 20)
	badge_row.add_child(hint_badge_label)
	hint_badge.add_child(badge_row)
	hint_button.add_child(hint_badge)

	panel = PanelContainer.new()
	panel.z_index = 10
	panel.custom_minimum_size = Vector2(540, 360)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel_label = Label.new()
	panel_label.add_theme_font_override("font", DISPLAY_FONT)
	panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_label.add_theme_font_size_override("font_size", 34)
	box.add_child(panel_label)
	revive_ad_button = _icon_text_button(ICONS.ad, _localized("Reklam izle · Geri al"), _on_revive_ad)
	revive_hint_button = _icon_text_button(ICONS.undo, _localized("1 ipucu ile geri al"), _on_revive_hint)
	panel_retry = _button(_localized("Bölümü tekrar oyna"), func(): start(idx))
	for button in [revive_ad_button, revive_hint_button, panel_retry]:
		button.custom_minimum_size.y = TOUCH_MIN
		box.add_child(button)
	panel.add_child(box)
	add_child(panel)
	_build_home()
	_build_shop()
	toast = PanelContainer.new()
	toast.z_index = 20
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.hide()
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_override("font", BODY_FONT)
	toast_label.add_theme_font_size_override("font_size", 26)
	toast.add_child(toast_label)
	add_child(toast)


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

	shop_button = _button("", func(): _show_shop(true, shop_button))
	shop_button.icon = ICONS.shop
	shop_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_button.custom_minimum_size = Vector2(104, 104)
	shop_button.expand_icon = true
	shop_button.add_theme_constant_override("icon_max_width", 48)
	shop_button.tooltip_text = _localized("Mağaza")
	shop_button.accessibility_name = shop_button.tooltip_text
	home_screen.add_child(shop_button)

	daily_button = _button("", _claim_daily)
	daily_button.icon = ICONS.gift
	daily_button.custom_minimum_size = Vector2(0, TOUCH_MIN)
	daily_button.add_theme_constant_override("h_separation", 14)
	home_screen.add_child(daily_button)

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
	restore_button = _button(_localized("Satın alımları geri yükle"), _restore_purchases)
	privacy_button = _button(_localized("Gizlilik seçenekleri"), func(): Ads.show_privacy_options())
	settings_close = _button(_localized("Kapat"), _show_settings.bind(false))
	for button in [restore_button, privacy_button, settings_close]:
		button.custom_minimum_size.y = 104
		box.add_child(button)
	_chain_focus([theme_button, restore_button, privacy_button, settings_close])


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
	hint_button.visible = not open
	if not open:
		_show_settings(false)
	_refresh_hint_button()
	_layout_home(get_viewport_rect().size)
	if open:
		play_button.grab_focus()
	else:
		home_button.grab_focus()


func _show_settings(open: bool) -> void:
	settings_veil.visible = open
	var menu_focus := Control.FOCUS_NONE if open else Control.FOCUS_ALL
	for button in [play_button, settings_button, shop_button, daily_button]:
		button.focus_mode = menu_focus
	if open:
		privacy_button.visible = Ads.can_show_privacy_options()
		_chain_focus([theme_button, restore_button, privacy_button, settings_close])
		theme_button.grab_focus()
	else:
		settings_button.grab_focus()


## Wraps up/down focus through the visible buttons of a modal.
func _chain_focus(buttons: Array) -> void:
	var shown := buttons.filter(func(b: Control) -> bool: return b.visible)
	for k in shown.size():
		var b: Control = shown[k]
		b.focus_neighbor_top = b.get_path_to(shown[k - 1])
		b.focus_neighbor_bottom = b.get_path_to(shown[(k + 1) % shown.size()])


func _layout_home(vs: Vector2) -> void:
	var safe := Rect2(Vector2.ZERO, vs)
	if OS.has_feature("mobile"):
		var screen_size := Vector2(DisplayServer.screen_get_size())
		var display_safe := DisplayServer.get_display_safe_area()
		safe = Rect2(Vector2(display_safe.position) / screen_size * vs, Vector2(display_safe.size) / screen_size * vs)
	var width := minf(safe.size.x - 108, 780)
	var edge := safe.position.x + (safe.size.x - width) * 0.5
	var is_home := home_screen.visible
	# The art sits between the title (ends at +390) and the daily gift row (starts 394 above the
	# bottom). The row is reserved even when hidden so claiming it never shifts the art.
	var art_top := 400.0
	var art_bottom := safe.size.y - 408
	var art_scale := minf(width / 600.0, (art_bottom - art_top) / 440.0)
	home_art.position = Vector2(safe.get_center().x, safe.position.y + (art_top + art_bottom) * 0.5)
	home_art.scale = Vector2.ONE * art_scale
	mascot.z_index = 12 if is_home else 0
	mascot.position = home_art.position if is_home else Vector2(vs.x * 0.5, pocket_y - 28)
	mascot.scale = Vector2.ONE * (5.2 * art_scale if is_home else 1.5)
	home_screen.size = vs
	settings_veil.size = vs
	home_title.position = Vector2(edge, safe.position.y + 150)
	home_title.size = Vector2(minf(width, 550), 240)
	var stars := Economy.total_stars()
	home_level.text = _localized("Bölüm %02d · ★ %d") % [idx + 1, stars] if stars > 0 else _localized("Bölüm %02d") % (idx + 1)
	home_level.position = Vector2(edge, safe.end.y - 282)
	home_level.size.x = width
	play_button.size = Vector2(width, 120)
	play_button.position = Vector2(edge, safe.end.y - 204)
	settings_button.position = Vector2(edge + width - 104, safe.position.y + 32)
	shop_button.position = settings_button.position - Vector2(104 + 16, 0)
	daily_button.visible = Economy.can_claim_daily()
	var gift := _next_daily_amount()
	daily_button.text = _localized("Günlük hediye: +1 ipucu") if gift == 1 else _localized("Günlük hediye: +%d ipucu") % gift
	daily_button.reset_size()
	daily_button.size.x = minf(daily_button.size.x, width)
	daily_button.position = Vector2(safe.get_center().x - daily_button.size.x * 0.5, home_level.position.y - 12 - TOUCH_MIN)


## `fill` defaults to the surface colour; pass palette.cream for a visible well on a surface panel.
func _style_neutral_button(button: Button, fill = null) -> void:
	var base: Color = palette.surface if fill == null else fill
	button.add_theme_color_override("font_focus_color", palette.ink)
	button.add_theme_color_override("icon_focus_color", palette.ink)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, _style(base if state == "normal" else palette.grid, 18))
		var suffix: String = "normal" if state == "normal" else state
		button.add_theme_color_override("icon_" + suffix + "_color", palette.ink)
		button.add_theme_color_override("font_" + ("color" if state == "normal" else suffix + "_color"), palette.ink)
	button.add_theme_stylebox_override("disabled", _style(base, 18))
	button.add_theme_color_override("font_disabled_color", palette.muted)
	button.add_theme_color_override("icon_disabled_color", palette.muted)


## Horizontal content padding for buttons that size to their text.
func _pad_button(button: Button, pad: float) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := button.get_theme_stylebox(state) as StyleBoxFlat
		if box:
			box.content_margin_left = pad
			box.content_margin_right = pad


## Draws the button `inset` px inside its (larger) touch rect.
func _inset_button(button: Button, inset: float) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := button.get_theme_stylebox(state) as StyleBoxFlat
		if box:
			var grow := (box.expand_margin_left if state == "focus" else 0.0) - inset
			box.expand_margin_left = grow
			box.expand_margin_right = grow
			box.expand_margin_top = grow
			box.expand_margin_bottom = grow


func _title_font_size(title: String) -> int:
	var room := (hint_button.position.x + HINT_INSET - 20 - left) if hint_button else INF
	var font_size := 50
	while font_size > 28 and DISPLAY_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 2
	return font_size


# --- Hints ---

## Whether the hint button is usable (it stays undimmed under the shop sheet).
func _hint_usable() -> bool:
	return not s.is_empty() and not home_screen.visible and not input_locked and s.status == "playing"


func _hint_allowed() -> bool:
	return _hint_usable() and not shop_veil.visible


func _on_hint_pressed() -> void:
	if not _hint_allowed():
		return
	if Economy.get_hints() <= 0:
		_show_shop(true, hint_button)
		return
	if hinted_id != -1 and nodes.has(hinted_id):
		return  # the current hint is still on screen; never charge twice for it
	var i := Logic.hint(s)
	if i < 0:
		_toast(_localized("Buradan çıkış yok — geri al veya yeniden başlat"))
		return
	if not Economy.spend_hint():
		return
	hinted_id = int(s.arrows[i].id)
	nodes[hinted_id].queue_redraw()


func _refresh_hint_button() -> void:
	if not hint_button or s.is_empty():
		return
	var hints := Economy.get_hints()
	hint_button.disabled = not _hint_usable()
	var show_ad := hints <= 0 and Ads.is_rewarded_ready()
	hint_badge_icon.visible = show_ad
	hint_badge_label.visible = not show_ad
	hint_badge_label.text = str(hints) if hints > 0 else "+"
	hint_badge.reset_size()
	hint_badge.position = Vector2(HINT_TARGET - HINT_INSET + 8 - hint_badge.size.x, -4)
	hint_button.accessibility_name = _localized("İpucu, %d kaldı") % hints


## Soft single pulse after repeated blocked taps; never a popup.
func _nudge_hint() -> void:
	if not hint_button.is_visible_in_tree() or hint_button.disabled:
		return
	if hint_nudge:
		hint_nudge.kill()
	hint_nudge = hint_button.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hint_nudge.tween_property(hint_button, "scale", Vector2.ONE * 1.08, 0.22)
	hint_nudge.tween_property(hint_button, "scale", Vector2.ONE, 0.28)


# --- Loss and revive ---

func _show_loss_panel() -> void:
	panel_label.text = _localized("Cep doldu")
	panel.visible = true
	veil.visible = true
	retry.disabled = true
	_refresh_loss_panel()


func _refresh_loss_panel() -> void:
	if not panel or s.is_empty():
		return
	var can_undo: bool = s.status == "lost" and not history.is_empty()
	revive_ad_button.visible = can_undo and Ads.is_rewarded_ready()
	revive_hint_button.visible = can_undo and Economy.get_hints() > 0
	# Replay is the main action only when there is nothing gentler to offer.
	if revive_ad_button.visible or revive_hint_button.visible:
		_style_neutral_button(panel_retry, palette.cream)
	else:
		_style_button(panel_retry)
	panel.reset_size()
	panel.position = (get_viewport_rect().size - panel.size) * 0.5


func _on_revive_ad() -> void:
	if s.status == "lost" and not history.is_empty():
		Ads.show_rewarded(Ads.PLACEMENT_REVIVE, _revive)


func _on_revive_hint() -> void:
	if s.status == "lost" and not history.is_empty() and Economy.spend_hint():
		_revive()


## Steps back to the state before the losing move without restarting the level.
func _revive() -> void:
	if s.is_empty() or s.status != "lost" or history.is_empty():
		return
	Logic.restore(s, history.pop_back())
	blocked_streak = 0
	_rebuild_board()
	panel.visible = false
	veil.visible = false
	retry.disabled = input_locked
	if mascot_tween:
		mascot_tween.kill()
		mascot_tween = null
	mascot.rotation = 0.0
	_update_mascot_mood()
	_refresh_hint_button()
	queue_redraw()


# --- Wallet (hints, ads, store) ---

func _on_hints_changed(_count: int) -> void:
	_refresh_wallet()


func _on_rewarded_ready_changed(_is_ready: bool) -> void:
	_refresh_wallet()


func _on_store_availability(_available: bool) -> void:
	_refresh_wallet()


func _refresh_wallet() -> void:
	_refresh_hint_button()
	_refresh_shop()
	if panel.visible:
		_refresh_loss_panel()
	if home_screen.visible:
		_layout_home(get_viewport_rect().size)


func _on_purchase_completed(_product_id: String) -> void:
	_toast(_localized("Teşekkürler!"))
	_refresh_wallet()


func _on_purchase_failed(_product_id: String, message: String) -> void:
	_refresh_wallet()
	if message.to_lower() in ["canceled", "cancelled", "user_canceled", "user_cancelled"]:
		return
	_toast(_localized("Satın alma tamamlanmadı"))


func _restore_purchases() -> void:
	if IAP.is_available():
		IAP.restore_purchases()
		_toast(_localized("Satın alımlar kontrol ediliyor"))
	else:
		_toast(_localized("Mağaza şu an kullanılamıyor"))


# --- Daily gift ---

## Mirrors Economy.claim_daily's streak rule so the pill can promise the right amount.
func _next_daily_amount() -> int:
	var today := str(Economy.today_provider.call())
	var next_streak: int = Economy.streak + 1 if Economy._is_day_before(Economy.last_daily, today) else 1
	return Economy.DAILY_CYCLE_HINTS if next_streak % Economy.DAILY_CYCLE == 0 else Economy.DAILY_HINTS


func _claim_daily() -> void:
	var amount := Economy.claim_daily()
	if amount > 0:
		var key := "+1 ipucu · Seri %d gün" if amount == 1 else "+%d ipucu · Seri %d gün"
		_toast(_localized(key) % ([Economy.streak] if amount == 1 else [amount, Economy.streak]))
	if daily_button.has_focus():
		play_button.grab_focus()
	_layout_home(get_viewport_rect().size)


# --- Toast ---

func _toast(text: String) -> void:
	toast_label.text = text
	var max_width := minf(get_viewport_rect().size.x - 96, 600) - 52
	var text_width := BODY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 4
	# Wrap only when needed; a wrapping Label measures its height at its current width.
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if text_width > max_width else TextServer.AUTOWRAP_OFF
	toast_label.custom_minimum_size.x = minf(text_width, max_width)
	toast_label.size = Vector2(toast_label.custom_minimum_size.x, 0)
	toast.reset_size()
	_place_toast()
	if toast_tween:
		toast_tween.kill()
	toast.modulate.a = 0.0
	toast.show()
	toast_tween = create_tween()
	toast_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	toast_tween.tween_interval(TOAST_SECONDS)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	toast_tween.tween_callback(toast.hide)


## Bottom centre, just above the pocket heading (and over the daily gift row on Home).
func _place_toast() -> void:
	var vs := get_viewport_rect().size
	toast.position = Vector2((vs.x - toast.size.x) * 0.5, vs.y - 300 - toast.size.y)


# --- Shop ---

func _build_shop() -> void:
	shop_veil = ColorRect.new()
	shop_veil.z_index = 14
	shop_veil.hide()
	shop_veil.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_show_shop(false))
	add_child(shop_veil)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_veil.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_panel = PanelContainer.new()
	center.add_child(shop_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	shop_panel.add_child(box)
	shop_title = Label.new()
	shop_title.text = _localized("Mağaza")
	shop_title.add_theme_font_override("font", DISPLAY_FONT)
	shop_title.add_theme_font_size_override("font_size", 38)
	box.add_child(shop_title)
	shop_hints_label = Label.new()
	shop_hints_label.add_theme_font_override("font", BODY_FONT)
	shop_hints_label.add_theme_font_size_override("font_size", 26)
	box.add_child(shop_hints_label)
	shop_scroll = ScrollContainer.new()
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(shop_scroll)
	# The margin keeps the 5px focus ring inside the scroll clip.
	var shop_margin := MarginContainer.new()
	shop_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		shop_margin.add_theme_constant_override("margin_" + side, 6)
	shop_scroll.add_child(shop_margin)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 14)
	shop_margin.add_child(shop_list)
	shop_ad_button = _shop_row(ICONS.ad, func():
		Ads.show_rewarded(Ads.PLACEMENT_HINT, func():
			Economy.add_hints(1)
			_toast(_localized("+1 ipucu"))))
	shop_ad_button.get_meta("name").text = _localized("Reklam izle · +1 ipucu")
	shop_list.add_child(shop_ad_button)
	for id in SHOP_PRODUCTS:
		var row := _shop_row(null, IAP.purchase.bind(id))
		shop_rows[id] = row
		shop_list.add_child(row)
	shop_unavailable = Label.new()
	shop_unavailable.text = _localized("Mağaza şu an kullanılamıyor")
	shop_unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_unavailable.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_unavailable.custom_minimum_size.y = 72
	shop_unavailable.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_unavailable.add_theme_font_override("font", BODY_FONT)
	shop_unavailable.add_theme_font_size_override("font_size", 26)
	shop_list.add_child(shop_unavailable)
	shop_close = _button(_localized("Kapat"), _show_shop.bind(false))
	shop_close.custom_minimum_size.y = 104
	box.add_child(shop_close)


## Button whose icon and label are centred together (Button alone pins the icon to the edge).
func _icon_text_button(icon: Texture2D, text: String, cb: Callable) -> Button:
	var b := _button("", cb)
	b.accessibility_name = text
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glyph := TextureRect.new()
	glyph.texture = icon
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(34, 34)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 26)
	row.add_child(label)
	b.set_meta("icon", glyph)
	b.set_meta("label", label)
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, row.get_combined_minimum_size().x + 48)
	return b


func _tint_content(button: Button, color: Color) -> void:
	button.get_meta("icon").self_modulate = color
	button.get_meta("label").add_theme_color_override("font_color", color)


## Full-width store row: optional icon, name (wraps to two lines) and a price on the right.
func _shop_row(icon: Texture2D, cb: Callable) -> Button:
	var b := _button("", cb)
	b.custom_minimum_size = Vector2(0, 104)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -24
	var glyph := TextureRect.new()
	glyph.texture = icon
	glyph.visible = icon != null
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(36, 36)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", BODY_FONT)
	name_label.add_theme_font_size_override("font_size", 26)
	row.add_child(name_label)
	var price := Label.new()
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.add_theme_font_override("font", DISPLAY_FONT)
	price.add_theme_font_size_override("font_size", 26)
	row.add_child(price)
	b.set_meta("icon", glyph)
	b.set_meta("name", name_label)
	b.set_meta("price", price)
	return b


func _refresh_shop() -> void:
	if not shop_veil:
		return
	shop_hints_label.text = _localized("İpuçların: %d") % Economy.get_hints()
	shop_ad_button.visible = Ads.is_rewarded_ready()
	shop_ad_button.get_meta("icon").self_modulate = palette.cream
	shop_ad_button.get_meta("name").add_theme_color_override("font_color", palette.cream)
	shop_ad_button.accessibility_name = shop_ad_button.get_meta("name").text
	var available := IAP.is_available()
	shop_unavailable.visible = not available
	for id in shop_rows:
		var row: Button = shop_rows[id]
		var owned: bool = IAP.PRODUCTS[id].type == "non_consumable" and IAP.owns(id)
		var name_label: Label = row.get_meta("name")
		var price: Label = row.get_meta("price")
		row.visible = available
		row.disabled = owned
		name_label.text = _localized(SHOP_PRODUCTS[id])
		price.text = _localized("Satın alındı ✓") if owned else IAP.get_price(id)
		name_label.add_theme_color_override("font_color", palette.muted if owned else palette.ink)
		price.add_theme_color_override("font_color", palette.muted if owned else palette.accent)
		row.accessibility_name = "%s, %s" % [name_label.text, price.text]
	var focusable: Array = [shop_ad_button]
	for id in shop_rows:
		focusable.append(shop_rows[id])
	focusable.append(shop_close)
	_chain_focus(focusable.filter(func(b: Button) -> bool: return not b.disabled))
	if shop_veil.visible:
		_layout_shop(get_viewport_rect().size)
		var owner := get_viewport().gui_get_focus_owner()
		if owner == null or not owner.is_visible_in_tree() or (owner is Button and owner.disabled):
			shop_close.grab_focus()


func _layout_shop(vs: Vector2) -> void:
	if not shop_veil:
		return
	shop_veil.size = vs
	shop_panel.custom_minimum_size.x = minf(vs.x - 72, 600)
	# Title, hint line, close and margins take ~330px; the rows scroll if the rest is too short.
	var rows_height := shop_list.get_combined_minimum_size().y + 12
	shop_scroll.custom_minimum_size.y = minf(rows_height, maxf(vs.y - 96 - 330, 208))


func _show_shop(open: bool, from: Control = null) -> void:
	if open == shop_veil.visible:
		return
	var background := [play_button, settings_button, shop_button, daily_button, hint_button, home_button, retry]
	for control in background:
		control.focus_mode = Control.FOCUS_NONE if open else Control.FOCUS_ALL
	if open:
		shop_return_focus = from
		shop_veil.show()
		_refresh_shop()
		_layout_shop(get_viewport_rect().size)
		shop_scroll.scroll_vertical = 0
		var first: Button = shop_ad_button if shop_ad_button.visible else shop_close
		for id in shop_rows:
			if first == shop_close and shop_rows[id].visible and not shop_rows[id].disabled:
				first = shop_rows[id]
		first.grab_focus()
	else:
		shop_veil.hide()
		if shop_return_focus and shop_return_focus.is_visible_in_tree():
			shop_return_focus.grab_focus()
	_refresh_hint_button()


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
