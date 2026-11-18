extends Control

## Large, original gameplay-style sample used by the appearance inventory.
## It intentionally previews Aurora's own lanes and HUD without importing assets
## from DJMAX or Quaver.

const NEON_NOTE := preload("res://src/screens/gameplay/NeonGameplayNote.gd")

const DEFAULT_CUSTOM := {
	"lane_fill": "#091525",
	"lane_divider": "#38d8f2",
	"lane_accent": "#ff62be",
	"left_rail": "#9977ff",
	"note_colors": ["#22ddff", "#ff56c7", "#ffd166", "#72e39a"],
	"note_border": "#f5f8ff",
	"note_shape": "rectangle",
	"note_size": 1.0,
	"lane_inset": 92.0,
	"lane_shape": "rectangle",
	"outline_width": 2,
}

const PROFILE_PALETTES := {
	"aurora": [Color(0.02, 0.86, 1.0), Color(1.0, 0.08, 0.92), Color(0.02, 0.86, 1.0), Color(1.0, 0.08, 0.92)],
	"djmax": [Color("#38e0db"), Color("#ff5c9f"), Color("#aa7bff"), Color("#ffd35a")],
	"quaver": [Color("#60e38c"), Color("#48d8ff"), Color("#ffe46b"), Color("#f28bfa")],
	"fnf": [Color("#e6459a"), Color("#18e2ff"), Color("#24ef58"), Color("#ff4252")],
	"custom": [Color("#22ddff"), Color("#ff56c7"), Color("#ffd166"), Color("#72e39a")],
}

const PROFILE_SCALE := {"aurora": 1.0, "djmax": 1.22, "quaver": 1.14, "fnf": 1.18, "custom": 1.0}

var profile_id := "aurora"
var note_size_scale := 1.0
var lane_opacity := 0.82
var note_speed := 5.5
var timing_offset_ms := 0
var show_lane_labels := true
var lane_key_labels: Array[String] = ["D", "F", "J", "K"]
var custom_appearance: Dictionary = DEFAULT_CUSTOM.duplicate(true)


func _ready() -> void:
	resized.connect(queue_redraw)


func configure(
	new_profile_id: String,
	new_note_size_scale: float,
	new_lane_opacity: float,
	new_note_speed: float,
	new_timing_offset_ms: int,
	new_show_lane_labels: bool,
	new_lane_key_labels: Array[String],
	new_custom_appearance: Dictionary = {}
) -> void:
	profile_id = new_profile_id if PROFILE_PALETTES.has(new_profile_id) else "aurora"
	note_size_scale = clampf(new_note_size_scale, 0.8, 1.4)
	lane_opacity = clampf(new_lane_opacity, 0.0, 1.0)
	note_speed = clampf(new_note_speed, 1.0, 10.0)
	timing_offset_ms = clampi(new_timing_offset_ms, -200, 200)
	show_lane_labels = new_show_lane_labels
	lane_key_labels = new_lane_key_labels.duplicate()
	custom_appearance = new_custom_appearance.duplicate(true) if new_custom_appearance is Dictionary else DEFAULT_CUSTOM.duplicate(true)
	queue_redraw()


func _draw() -> void:
	if size.x < 200.0 or size.y < 140.0:
		return
	var palette := _palette()
	var accent: Color = _custom_color("lane_accent", palette[0]) if profile_id == "custom" else palette[0]
	var secondary: Color = _custom_color("lane_divider", palette[1]) if profile_id == "custom" else palette[1]
	var background := Color(0.004, 0.010, 0.030, 0.98)
	var field_background := Color(0.008, 0.016, 0.040, 0.52)
	var border := Color(accent.r, accent.g, accent.b, 0.68)
	var font: Font = AuroraUi.PIXEL_FONT

	draw_rect(Rect2(Vector2.ZERO, size), background)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 1.5)
	draw_rect(Rect2(0.0, 0.0, size.x, 2.0), accent)
	var top_right_width := minf(size.x * 0.36, 152.0)
	var top_left_width := maxf(size.x - top_right_width - 28.0, 100.0)
	draw_string(font, Vector2(12.0, 18.0), AuroraLocale.text(_profile_caption()), HORIZONTAL_ALIGNMENT_LEFT, top_left_width, 8, accent)
	draw_string(font, Vector2(size.x - 12.0 - top_right_width, 18.0), AuroraLocale.text("VISTA PREVIA // 4K"), HORIZONTAL_ALIGNMENT_RIGHT, top_right_width, 7, Color(0.78, 0.86, 0.96, 0.78))

	var profile_width_scale := 1.0 if profile_id == "aurora" else 1.06 if profile_id == "djmax" else 1.04
	if profile_id == "custom":
		profile_width_scale = clampf((712.0 - 2.0 * float(_custom_value("lane_inset", 92.0))) / 528.0, 0.72, 1.18)
	var max_playfield_for_side_hud := maxf(size.x - 240.0, 132.0)
	var playfield_width := clampf(size.x * 0.44 * profile_width_scale, 132.0, minf(280.0, max_playfield_for_side_hud))
	var playfield_left := (size.x - playfield_width) * 0.5
	var playfield_top := 28.0
	var playfield_bottom := size.y - 26.0
	var lane_width := playfield_width / 4.0
	draw_rect(Rect2(playfield_left - 3.0, playfield_top, playfield_width + 6.0, playfield_bottom - playfield_top), field_background)
	draw_rect(Rect2(playfield_left - 3.0, playfield_top, playfield_width + 6.0, playfield_bottom - playfield_top), Color(accent.r, accent.g, accent.b, 0.34), false, 1.0)

	for lane_index in range(4):
		var lane_x := playfield_left + lane_width * float(lane_index)
		var tint: Color = palette[lane_index]
		if profile_id == "custom":
			var lane_fill := _custom_color("lane_fill", Color("#091525"))
			_draw_custom_lane(
				Rect2(lane_x + 0.5, playfield_top + 1.0, lane_width - 1.0, playfield_bottom - playfield_top - 2.0),
				Color(lane_fill.r, lane_fill.g, lane_fill.b, 0.72 * lane_opacity),
				Color(accent.r, accent.g, accent.b, 0.5),
				str(_custom_value("lane_shape", "rectangle"))
			)
		else:
			var lane_fill_alpha := 0.77 if profile_id == "aurora" else 0.38 if profile_id == "djmax" else 0.25
			draw_rect(Rect2(lane_x, playfield_top + 1.0, lane_width, playfield_bottom - playfield_top - 2.0), Color(0.008, 0.012, 0.028, lane_fill_alpha * lane_opacity))
		if lane_index > 0:
			var divider_tint := Color(0.16, 0.72, 1.0) if profile_id == "aurora" else secondary if profile_id == "custom" else tint
			var divider_alpha := 0.56 if profile_id == "aurora" else 0.42 if profile_id == "djmax" else 0.32
			draw_rect(Rect2(lane_x, playfield_top, 1.0, playfield_bottom - playfield_top), Color(divider_tint.r, divider_tint.g, divider_tint.b, divider_alpha * lane_opacity))
	if profile_id == "custom":
		var rail: Color = _custom_color("left_rail", Color("#9977ff"))
		draw_rect(Rect2(playfield_left - 4.0, playfield_top, 2.0, playfield_bottom - playfield_top), Color(rail.r, rail.g, rail.b, lane_opacity))
		draw_rect(Rect2(playfield_left + playfield_width + 2.0, playfield_top, 2.0, playfield_bottom - playfield_top), Color(accent.r, accent.g, accent.b, lane_opacity))

	for guide_index in range(1, 4):
		var guide_y := lerpf(playfield_top + 20.0, playfield_bottom - 38.0, float(guide_index) / 4.0)
		draw_rect(Rect2(playfield_left, guide_y, playfield_width, 1.0), Color(0.70, 0.84, 1.0, 0.10))

	var effective_note_scale := note_size_scale * float(PROFILE_SCALE[profile_id])
	if profile_id == "custom":
		effective_note_scale *= float(_custom_value("note_size", 1.0))
	var chip_height := 12.0 * effective_note_scale
	_draw_chip(playfield_left + 2.0, playfield_top + 30.0, lane_width - 4.0, chip_height, palette[0], accent, 0)
	_draw_hold(playfield_left + lane_width + 2.0, playfield_top + 54.0, lane_width - 4.0, palette[1], effective_note_scale, accent, 1)
	# A pair at the same height makes simultaneous lane hits easy to compare.
	_draw_chip(playfield_left + 2.0, playfield_top + 78.0, lane_width - 4.0, chip_height, palette[0], accent, 0)
	_draw_chip(playfield_left + lane_width * 3.0 + 2.0, playfield_top + 78.0, lane_width - 4.0, chip_height, palette[3], accent, 3)
	_draw_chip(playfield_left + lane_width * 2.0 + 2.0, playfield_top + 101.0, lane_width - 4.0, chip_height, palette[2], accent, 2)
	_draw_chip(playfield_left + lane_width * 3.0 + 2.0, playfield_top + 133.0, lane_width - 4.0, chip_height, palette[3], accent, 3)

	var hit_line_y := playfield_bottom - 31.0
	draw_rect(Rect2(playfield_left, hit_line_y, playfield_width, 2.0), Color(accent.r, accent.g, accent.b, 0.86))
	draw_string(font, Vector2(playfield_left + 4.0, hit_line_y - 7.0), "PERFECT", HORIZONTAL_ALIGNMENT_LEFT, playfield_width - 8.0, 7, Color(1.0, 0.95, 0.78, 0.95))
	var receptor_height := 14.0 if profile_id == "aurora" else 17.0 if profile_id == "djmax" else 16.0
	for lane_index in range(4):
		var lane_x := playfield_left + lane_width * float(lane_index)
		var tint: Color = palette[lane_index]
		_draw_receptor(lane_x + 4.0, hit_line_y - receptor_height * 0.5, lane_width - 8.0, receptor_height, tint, accent, lane_index)
		if show_lane_labels and lane_index < lane_key_labels.size():
			draw_string(font, Vector2(lane_x, size.y - 7.0), lane_key_labels[lane_index].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, lane_width, 7, Color(0.88, 0.94, 1.0, 0.92))

	_draw_side_readout(font, 12.0, playfield_left, playfield_left + playfield_width, accent, secondary)


func _draw_custom_lane(rect: Rect2, fill: Color, outline: Color, shape_name: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(5 if shape_name == "rounded" else 0)
	draw_style_box(style, rect)


func _draw_chip(x: float, y: float, width: float, height: float, tint: Color, accent: Color, lane_index: int = 0) -> void:
	var chip := Rect2(x, y, width, height)
	if profile_id == "fnf":
		var center := chip.get_center()
		var half_extent := clampf(minf(width * 0.42, height * 0.95), 7.5, 16.0)
		NEON_NOTE.draw_fnf_arrow(self, center, half_extent, lane_index, Color(tint.r, tint.g, tint.b, 0.98), Color(0.08, 0.12, 0.20, 0.98), 1.8, 0.20, true)
		return
	if profile_id == "aurora":
		draw_rect(chip.grow(4.0), Color(tint.r, tint.g, tint.b, 0.16), false, 2.0)
	if profile_id == "custom":
		_draw_custom_shape(chip, Color(tint.r, tint.g, tint.b, 0.96), _custom_color("note_border", Color.WHITE), int(_custom_value("outline_width", 2.0)), str(_custom_value("note_shape", "rectangle")))
		return
	draw_rect(chip, Color(tint.r, tint.g, tint.b, 0.96))
	if profile_id == "djmax":
		draw_rect(Rect2(chip.position, Vector2(width, 3.0)), Color.WHITE)
		draw_rect(Rect2(chip.position.x, chip.end.y - 3.0, width, 3.0), Color(0.10, 0.02, 0.12, 0.72))
	elif profile_id == "quaver":
		draw_rect(chip, tint.lerp(Color.WHITE, 0.60), false, 1.5)
		draw_rect(Rect2(chip.position, Vector2(3.0, chip.size.y)), accent)
	else:
		draw_rect(chip, Color(0.94, 0.98, 1.0, 0.96), false, 1.2)
		draw_rect(Rect2(chip.position + Vector2(3.0, 2.0), Vector2(maxf(width - 6.0, 1.0), 2.0)), Color(1.0, 1.0, 1.0, 0.92))


func _draw_hold(x: float, y: float, width: float, tint: Color, scale: float, accent: Color, lane_index: int = 1) -> void:
	var body := Rect2(x, y, width, 45.0 * scale)
	if profile_id == "fnf":
		var tail_width := clampf(width * 0.38, 7.0, 14.0)
		var tail_x := x + (width - tail_width) * 0.5
		var arrow_center := Vector2(x + width * 0.5, body.end.y - 6.0 * scale)
		var tail_rect := Rect2(tail_x, y + 3.0, tail_width, maxf(arrow_center.y - (y + 3.0), 6.0))
		draw_rect(tail_rect, Color(tint.r, tint.g, tint.b, 0.36))
		draw_rect(tail_rect, Color(tint.r, tint.g, tint.b, 0.88), false, 1.2)
		draw_rect(Rect2(tail_x, y + 3.0, tail_width, 3.0), Color(1.0, 1.0, 1.0, 0.85))
		var half_extent := clampf(minf(width * 0.42, 13.0 * scale), 7.5, 16.0)
		NEON_NOTE.draw_fnf_arrow(self, arrow_center, half_extent, lane_index, Color(tint.r, tint.g, tint.b, 0.98), Color(0.08, 0.12, 0.20, 0.98), 1.8, 0.24, true)
		return
	if profile_id == "custom":
		_draw_custom_shape(body, Color(tint.r, tint.g, tint.b, 0.34), _custom_color("note_border", Color.WHITE), int(_custom_value("outline_width", 2.0)), str(_custom_value("note_shape", "rectangle")))
		draw_rect(Rect2(body.position.x, body.end.y - 12.0 * scale, body.size.x, 12.0 * scale), Color(tint.r, tint.g, tint.b, 0.98))
		draw_rect(Rect2(body.position.x + 2.0, body.end.y - 10.0 * scale, maxf(body.size.x - 4.0, 1.0), 2.0), Color.WHITE)
		return
	draw_rect(body, Color(tint.r, tint.g, tint.b, 0.34))
	draw_rect(body, Color(tint.r, tint.g, tint.b, 0.90), false, 1.5)
	draw_rect(Rect2(body.position.x, body.end.y - 12.0 * scale, body.size.x, 12.0 * scale), Color(tint.r, tint.g, tint.b, 0.98))
	draw_rect(Rect2(body.position.x + 2.0, body.end.y - 10.0 * scale, maxf(body.size.x - 4.0, 1.0), 2.0), Color(1.0, 1.0, 1.0, 0.92))
	if profile_id == "aurora":
		draw_rect(Rect2(body.position.x + body.size.x * 0.45, body.position.y + 2.0, 2.0, maxf(body.size.y - 14.0 * scale, 1.0)), Color(accent.r, accent.g, accent.b, 0.52))


func _draw_side_readout(font: Font, margin_x: float, playfield_left: float, playfield_right: float, accent: Color, secondary: Color) -> void:
	var left_width := maxf(playfield_left - margin_x - 8.0, 64.0)
	var right_left := playfield_right + 8.0
	var right_width := maxf(size.x - margin_x - right_left, 64.0)
	var hud_size := 6 if minf(left_width, right_width) < 120.0 else 7
	var accuracy_label := "PRECISIÓN" if profile_id == "quaver" else "RATE"
	var timing_text := "%d" % timing_offset_ms
	if timing_offset_ms > 0:
		timing_text = "+%s" % timing_text
	var note_percent := roundi(note_size_scale * float(PROFILE_SCALE[profile_id]) * (float(_custom_value("note_size", 1.0)) if profile_id == "custom" else 1.0) * 100.0)
	draw_string(font, Vector2(margin_x, 67.0), AuroraLocale.text("MUESTRA VISUAL"), HORIZONTAL_ALIGNMENT_LEFT, left_width, hud_size, Color(0.77, 0.84, 0.96, 0.75))
	draw_string(font, Vector2(margin_x, 91.0), "%s %.1fx" % [AuroraLocale.text("VELOCIDAD"), note_speed], HORIZONTAL_ALIGNMENT_LEFT, left_width, hud_size, accent)
	draw_string(font, Vector2(margin_x, 115.0), "%s %s ms" % [AuroraLocale.text("SINCRONÍA"), timing_text], HORIZONTAL_ALIGNMENT_LEFT, left_width, hud_size, Color(0.77, 0.84, 0.96, 0.68))
	draw_string(font, Vector2(margin_x, 139.0), "%s %d%%" % [AuroraLocale.text("NOTA"), note_percent], HORIZONTAL_ALIGNMENT_LEFT, left_width, hud_size, accent)

	draw_string(font, Vector2(right_left, 67.0), AuroraLocale.text("HUD // EJEMPLO"), HORIZONTAL_ALIGNMENT_RIGHT, right_width, hud_size, Color(0.77, 0.84, 0.96, 0.75))
	draw_string(font, Vector2(right_left, 91.0), AuroraLocale.text("PUNTAJE"), HORIZONTAL_ALIGNMENT_RIGHT, right_width, hud_size, secondary)
	draw_string(font, Vector2(right_left, 115.0), AuroraLocale.text("COMBO 032"), HORIZONTAL_ALIGNMENT_RIGHT, right_width, hud_size, accent)
	draw_string(font, Vector2(right_left, 139.0), "%s 100.00%%" % accuracy_label, HORIZONTAL_ALIGNMENT_RIGHT, right_width, hud_size, Color(0.92, 0.96, 1.0, 0.9))


func _draw_receptor(x: float, y: float, width: float, height: float, tint: Color, accent: Color, lane_index: int = 0) -> void:
	var rect := Rect2(x, y, width, height)
	if profile_id == "fnf":
		var center := rect.get_center()
		var half_extent := clampf(minf(width * 0.44, height * 0.82), 7.5, 16.0)
		var lit := lane_index == 1 or lane_index == 2
		var fill := Color(tint.r, tint.g, tint.b, 0.95) if lit else Color(0.08, 0.11, 0.18, 0.96)
		var outline := Color.WHITE if lit else Color(0.62, 0.72, 0.84, 0.88)
		NEON_NOTE.draw_fnf_arrow(self, center, half_extent, lane_index, fill, outline, 1.8, 0.28 if lit else 0.0, lit)
		return
	if profile_id == "custom":
		_draw_custom_shape(rect, Color(tint.r, tint.g, tint.b, 0.88), _custom_color("note_border", Color.WHITE), int(_custom_value("outline_width", 2.0)), str(_custom_value("note_shape", "rectangle")))
	elif profile_id == "aurora":
		draw_rect(rect.grow(3.0), Color(tint.r, tint.g, tint.b, 0.18), false, 1.0)
		draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.88))
		draw_rect(rect, Color(0.95, 0.99, 1.0, 1.0), false, 1.0)
		draw_rect(Rect2(rect.position.x + 3.0, rect.position.y + 2.0, rect.size.x - 6.0, 2.0), Color.WHITE)
	elif profile_id == "djmax":
		draw_rect(rect, tint)
		draw_rect(rect, Color.WHITE, false, 1.0)
		draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0, rect.size.x - 4.0, 2.0), Color.WHITE)
		draw_rect(Rect2(rect.position.x + width * 0.32, rect.position.y + height * 0.46, width * 0.36, 4.0), Color(0.02, 0.02, 0.06, 0.75))
	else:
		draw_rect(rect, Color(0.008, 0.018, 0.034, 0.96))
		draw_rect(rect, tint.lerp(Color.WHITE, 0.10), false, 1.5)
		draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0, rect.size.x - 4.0, 2.0), Color.WHITE)
		draw_rect(Rect2(rect.position.x + 3.0, rect.position.y + 6.0, 2.0, rect.size.y - 12.0), tint)
		draw_rect(Rect2(rect.position.x + width - 5.0, rect.position.y + 6.0, 2.0, rect.size.y - 12.0), tint)


func _draw_custom_shape(rect: Rect2, fill: Color, outline: Color, outline_width: int, shape_name: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(outline_width)
	match shape_name:
		"rounded":
			style.set_corner_radius_all(5)
		"pill":
			style.set_corner_radius_all(mini(24, int(rect.size.y * 0.5)))
		_:
			style.set_corner_radius_all(0)
	draw_style_box(style, rect)


func _palette() -> Array:
	if profile_id != "custom":
		return PROFILE_PALETTES[profile_id]
	var raw: Array = custom_appearance.get("note_colors", DEFAULT_CUSTOM["note_colors"])
	var result: Array[Color] = []
	for lane_index in range(4):
		var fallback: Color = PROFILE_PALETTES["custom"][lane_index]
		var raw_color = raw[lane_index] if lane_index < raw.size() else DEFAULT_CUSTOM["note_colors"][lane_index]
		result.append(Color.from_string(str(raw_color), fallback))
	return result


func _custom_value(key: String, fallback):
	return custom_appearance.get(key, fallback)


func _custom_color(key: String, fallback: Color) -> Color:
	return Color.from_string(str(custom_appearance.get(key, fallback.to_html(false))), fallback)


func _profile_caption() -> String:
	match profile_id:
		"djmax":
			return "DJMAX-INSPIRED // COMBO + RATE"
		"quaver":
			return "QUAVER-INSPIRED // PRECISIÓN + 4K"
		"fnf":
			return "FNF-INSPIRED // FLECHAS + COMBO"
		"custom":
			return "PERSONALIZADO // TU DISEÑO"
		_:
			return "AURORA // CENTRAL NEON"
