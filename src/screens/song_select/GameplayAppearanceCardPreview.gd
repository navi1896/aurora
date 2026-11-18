extends Control

## Compact 4K lane, note, hold, receptor, and HUD sample for one profile card.

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

var profile_id := "aurora"
var custom_appearance: Dictionary = DEFAULT_CUSTOM.duplicate(true)


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(new_profile_id: String, appearance: Dictionary = {}) -> void:
	profile_id = new_profile_id if PROFILE_PALETTES.has(new_profile_id) else "aurora"
	custom_appearance = appearance.duplicate(true) if appearance is Dictionary else DEFAULT_CUSTOM.duplicate(true)
	queue_redraw()


func _draw() -> void:
	if size.x < 88.0 or size.y < 70.0:
		return

	var palette := _palette()
	var accent: Color = _custom_color("lane_accent", palette[0]) if profile_id == "custom" else palette[0]
	var secondary: Color = _custom_color("lane_divider", palette[1]) if profile_id == "custom" else palette[1]
	var font: Font = AuroraUi.PIXEL_FONT
	var width_scale := 1.0
	if profile_id == "custom":
		width_scale = clampf((712.0 - 2.0 * float(_custom_value("lane_inset", 92.0))) / 528.0, 0.72, 1.18)
	var field_width := minf(size.x * 0.66, 220.0) * width_scale
	var field_left := (size.x - field_width) * 0.5
	var field_top := 20.0
	var field_bottom := size.y - 19.0
	var lane_width := field_width / 4.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.004, 0.010, 0.026, 0.96))
	draw_rect(Rect2(Vector2.ZERO, size), Color(accent.r, accent.g, accent.b, 0.34), false, 1.0)
	draw_string(font, Vector2(6.0, 14.0), "4K // %s" % _lane_caption(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 7, accent)

	for lane_index in range(4):
		var lane_x := field_left + lane_width * float(lane_index)
		var tint: Color = palette[lane_index]
		if profile_id == "custom":
			var fill := _custom_color("lane_fill", Color("#091525"))
			_draw_custom_lane(
				Rect2(lane_x + 0.5, field_top, lane_width - 1.0, field_bottom - field_top),
				Color(fill.r, fill.g, fill.b, 0.76),
				_custom_color("lane_accent", accent),
				str(_custom_value("lane_shape", "rectangle"))
			)
		else:
			var lane_alpha := 0.34 if profile_id == "aurora" else 0.17 if profile_id == "djmax" else 0.12 if profile_id == "fnf" else 0.10
			draw_rect(Rect2(lane_x, field_top, lane_width, field_bottom - field_top), Color(0.018, 0.026, 0.045, lane_alpha))
		if lane_index > 0:
			var divider := Color(0.16, 0.72, 1.0) if profile_id == "aurora" else secondary if profile_id == "custom" else tint
			var divider_alpha := 0.58 if profile_id == "aurora" else 0.70 if profile_id == "djmax" else 0.52 if profile_id == "fnf" else 0.88
			draw_rect(Rect2(lane_x, field_top, 1.0, field_bottom - field_top), Color(divider.r, divider.g, divider.b, divider_alpha))
	if profile_id == "custom":
		var rail: Color = _custom_color("left_rail", Color("#9977ff"))
		draw_rect(Rect2(field_left - 3.0, field_top, 2.0, field_bottom - field_top), rail)
		draw_rect(Rect2(field_left + field_width + 1.0, field_top, 2.0, field_bottom - field_top), accent)

	var note_height := 8.0 if profile_id == "aurora" else 10.0 if profile_id == "djmax" else 9.0
	if profile_id == "custom":
		note_height *= float(_custom_value("note_size", 1.0))
	var field_span := maxf(field_bottom - field_top, 48.0)
	_draw_note(field_left + 2.0, field_top + field_span * 0.14, lane_width - 4.0, note_height, palette[0], accent, 0)
	_draw_hold(field_left + lane_width + 2.0, field_top + field_span * 0.24, lane_width - 4.0, field_span * 0.34, palette[1], 1)
	_draw_note(field_left + lane_width * 2.0 + 2.0, field_top + field_span * 0.42, lane_width - 4.0, note_height, palette[2], accent, 2)
	_draw_note(field_left + lane_width * 3.0 + 2.0, field_top + field_span * 0.60, lane_width - 4.0, note_height, palette[3], accent, 3)

	var receptor_y := field_bottom - 9.0
	draw_rect(Rect2(field_left, receptor_y - 1.0, field_width, 2.0), Color(accent.r, accent.g, accent.b, 0.74))
	for lane_index in range(4):
		var lane_x := field_left + lane_width * float(lane_index)
		var tint: Color = palette[lane_index]
		var receptor := Rect2(lane_x + 2.0, receptor_y - 4.0, lane_width - 4.0, 8.0)
		if profile_id == "fnf":
			var half_extent := clampf(minf(lane_width * 0.34, 7.0), 4.2, 7.5)
			var lit := lane_index == 1 or lane_index == 2
			NEON_NOTE.draw_fnf_arrow(
				self,
				receptor.get_center(),
				half_extent,
				lane_index,
				Color(tint.r, tint.g, tint.b, 0.94) if lit else Color(0.08, 0.11, 0.18, 0.96),
				Color.WHITE if lit else Color(0.62, 0.72, 0.84, 0.88),
				1.3,
				0.20 if lit else 0.0,
				lit
			)
		elif profile_id == "aurora":
			draw_rect(receptor.grow(2.0), Color(tint.r, tint.g, tint.b, 0.18), false, 1.0)
			draw_rect(receptor, tint)
			draw_rect(receptor, Color.WHITE, false, 1.0)
		elif profile_id == "custom":
			_draw_custom_shape(receptor, tint, _custom_color("note_border", Color.WHITE), int(_custom_value("outline_width", 2.0)), str(_custom_value("note_shape", "rectangle")))
		else:
			draw_rect(receptor, tint)
			draw_rect(receptor, Color.WHITE, false, 1.0)

	var readout := "COMBO / ACCURACY" if profile_id == "quaver" else "COMBO / RATE"
	draw_string(font, Vector2(6.0, size.y - 5.0), readout, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 6, secondary)


func _draw_custom_lane(rect: Rect2, fill: Color, outline: Color, shape_name: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(outline.r, outline.g, outline.b, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5 if shape_name == "rounded" else 0)
	draw_style_box(style, rect)


func _draw_note(x: float, y: float, width: float, height: float, tint: Color, accent: Color, lane_index: int = 0) -> void:
	var note := Rect2(x, y, width, height)
	if profile_id == "fnf":
		var half_extent := clampf(minf(width * 0.42, height * 0.78), 4.2, 8.0)
		NEON_NOTE.draw_fnf_arrow(self, note.get_center(), half_extent, lane_index, Color(tint.r, tint.g, tint.b, 0.98), Color(0.08, 0.12, 0.20, 0.98), 1.3, 0.16, true)
		return
	if profile_id == "aurora":
		draw_rect(note.grow(2.0), Color(tint.r, tint.g, tint.b, 0.22), false, 1.0)
		draw_rect(note, tint)
		draw_rect(note, Color.WHITE, false, 1.0)
	elif profile_id == "djmax":
		draw_rect(note, tint)
		draw_rect(Rect2(note.position, Vector2(width, 2.0)), Color.WHITE)
		draw_rect(note, Color.WHITE, false, 1.0)
	elif profile_id == "custom":
		_draw_custom_shape(note, tint, _custom_color("note_border", Color.WHITE), int(_custom_value("outline_width", 2.0)), str(_custom_value("note_shape", "rectangle")))
	else:
		draw_rect(note, tint)
		draw_rect(note, tint.lerp(Color.WHITE, 0.55), false, 1.0)
		draw_rect(Rect2(note.position.x, note.position.y, 2.0, height), accent)


func _draw_hold(x: float, y: float, width: float, height: float, tint: Color, lane_index: int = 1) -> void:
	var hold := Rect2(x, y, width, height)
	if profile_id == "fnf":
		var tail_width := clampf(width * 0.36, 4.0, 8.0)
		var tail_x := x + (width - tail_width) * 0.5
		var arrow_center := Vector2(x + width * 0.5, hold.end.y - 4.0)
		var tail_rect := Rect2(tail_x, y + 2.0, tail_width, maxf(arrow_center.y - (y + 2.0), 4.0))
		draw_rect(tail_rect, Color(tint.r, tint.g, tint.b, 0.36))
		draw_rect(tail_rect, tint, false, 1.0)
		draw_rect(Rect2(tail_x, y + 2.0, tail_width, 2.0), Color(1.0, 1.0, 1.0, 0.85))
		var half_extent := clampf(width * 0.42, 4.2, 8.0)
		NEON_NOTE.draw_fnf_arrow(self, arrow_center, half_extent, lane_index, Color(tint.r, tint.g, tint.b, 0.98), Color(0.08, 0.12, 0.20, 0.98), 1.3, 0.20, true)
		return
	if profile_id == "custom":
		_draw_custom_shape(hold, Color(tint.r, tint.g, tint.b, 0.42), _custom_color("note_border", Color.WHITE), int(_custom_value("outline_width", 2.0)), str(_custom_value("note_shape", "rectangle")))
	else:
		draw_rect(hold, Color(tint.r, tint.g, tint.b, 0.30 if profile_id == "aurora" else 0.48))
		draw_rect(hold, tint, false, 1.0)
	var cap_height := 5.0 if profile_id == "aurora" else 6.0
	draw_rect(Rect2(hold.position.x, hold.end.y - cap_height, hold.size.x, cap_height), tint)
	if profile_id != "quaver":
		draw_rect(Rect2(hold.position.x + 2.0, hold.position.y + 1.0, maxf(hold.size.x - 4.0, 1.0), 1.0), Color.WHITE)


func _draw_custom_shape(rect: Rect2, fill: Color, outline: Color, outline_width: int, shape_name: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(outline_width)
	match shape_name:
		"rounded":
			style.set_corner_radius_all(4)
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


func _lane_caption() -> String:
	match profile_id:
		"djmax":
			return "CENTRAL"
		"quaver":
			return "NÍTIDO"
		"fnf":
			return "FNF"
		"custom":
			return "PROPIO"
		_:
			return "AURORA"
