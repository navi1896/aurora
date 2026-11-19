extends Control

const FNF_UP_ARROW := [
	Vector2(0.0, -0.92),
	Vector2(0.92, 0.02),
	Vector2(0.42, 0.02),
	Vector2(0.42, 0.90),
	Vector2(-0.42, 0.90),
	Vector2(-0.42, 0.02),
	Vector2(-0.92, 0.02),
]

## Drawn in the cabinet's reference coordinates so a note keeps its proportions.
var tint := Color(0.08, 0.86, 1.0)
var style_profile := "aurora"
var lane_direction := 2
var is_hold := false
var holding := false
var phase := 0.0
var reduced_motion := false
var note_size_scale := 1.0


static func draw_fnf_arrow(
	canvas: CanvasItem,
	center: Vector2,
	half_extent: float,
	direction: int,
	fill: Color,
	outline: Color,
	outline_width: float = 2.0,
	glow_alpha: float = 0.0,
	inner_highlight: bool = true
) -> void:
	if half_extent < 2.0:
		return
	var outer := PackedVector2Array()
	var halo := PackedVector2Array()
	var inner := PackedVector2Array()
	for p in FNF_UP_ARROW:
		var rotated: Vector2
		match direction:
			0:
				rotated = Vector2(p.y, -p.x)
			1:
				rotated = Vector2(-p.x, -p.y)
			3:
				rotated = Vector2(-p.y, p.x)
			_:
				rotated = p
		outer.append(center + rotated * half_extent)
		if glow_alpha > 0.0:
			halo.append(center + rotated * (half_extent * 1.18))
		if inner_highlight:
			inner.append(center + rotated * (half_extent * 0.56))
	if glow_alpha > 0.0:
		canvas.draw_colored_polygon(halo, Color(fill.r, fill.g, fill.b, glow_alpha))
	canvas.draw_colored_polygon(outer, fill)
	if inner_highlight and fill.a > 0.45:
		canvas.draw_colored_polygon(inner, Color(1.0, 1.0, 1.0, 0.24 * fill.a))
	var closed := PackedVector2Array(outer)
	closed.append(outer[0])
	canvas.draw_polyline(closed, outline, outline_width, true)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(false)


func set_holding(value: bool) -> void:
	if holding == value:
		return
	holding = value
	set_process(value and not reduced_motion)
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	set_process(holding and not reduced_motion)
	queue_redraw()


func _process(delta: float) -> void:
	phase += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var scale_value := clampf(note_size_scale, 0.8, 1.6)
	# Match 2 * NOTE_HALF_HEIGHT * scale_value so tap and hold heads center on the HitLine.
	var chip_height := minf(20.0 * scale_value, size.y)
	var head_y := maxf(size.y - chip_height, 0.0)
	if style_profile == "fnf":
		_draw_fnf_note(scale_value, chip_height, head_y)
		return
	if is_hold and size.y > chip_height * 1.4:
		var body_bottom := head_y + chip_height * 0.5
		var body := Rect2(1.0, chip_height * 0.25, size.x - 2.0, maxf(body_bottom - chip_height * 0.25, 1.0))
		var body_color := tint.darkened(0.15)
		draw_rect(body, Color(body_color, 0.96 if holding else 0.86))
		# Broad color and repeated chevrons remain recognizable before the hold starts.
		draw_rect(Rect2(size.x * 0.38, body.position.y, size.x * 0.24, body.size.y), Color(tint.lerp(Color.WHITE, 0.55), 0.28))
		var arrow_y := head_y - 14.0 * scale_value
		var center_x := size.x * 0.5
		var arrow_color := Color(0.88, 1.0, 1.0, 0.76 if holding else 0.54)
		var line_w := 2.0 * scale_value
		var step_y := 38.0 * scale_value
		var min_arrow_y := chip_height + 8.0 * scale_value
		while arrow_y > min_arrow_y:
			var apex := Vector2(center_x, arrow_y - 3.0)
			draw_line(Vector2(center_x - 13.0, arrow_y + 5.0), apex, arrow_color, line_w)
			draw_line(apex, Vector2(center_x + 13.0, arrow_y + 5.0), arrow_color, line_w)
			arrow_y -= step_y
		for edge in [body.position.x, body.end.x]:
			draw_rect(Rect2(edge - 1.0 * scale_value, body.position.y, 2.0 * scale_value, body.size.y), Color(tint.lerp(Color.WHITE, 0.72), 1.0))
		if holding:
			var strand_x := size.x * (0.50 + (0.0 if reduced_motion else sin(phase * 5.0) * 0.13))
			draw_rect(Rect2(strand_x - 2.0 * scale_value, body.position.y, 4.0 * scale_value, body.size.y), Color(1, 1, 1, 0.48))
		# A slim striped tail cannot be confused with another falling tap.
		draw_rect(Rect2(0, 0, size.x, 7.0 * scale_value), tint.lerp(Color.WHITE, 0.65))
		draw_rect(Rect2(0, 7.0 * scale_value, size.x, 2.0 * scale_value), tint.darkened(0.45))
	_draw_chip(Rect2(0, head_y, size.x, chip_height), 1.0)
	if is_hold:
		for x in [size.x * 0.5 - 8.0 * scale_value, size.x * 0.5 + 4.0 * scale_value]:
			draw_rect(Rect2(x - 1.0 * scale_value, head_y + 3.0 * scale_value, 6.0 * scale_value, maxf(chip_height - 6.0 * scale_value, 6.0)), tint.darkened(0.65))
			draw_rect(Rect2(x, head_y + 4.0 * scale_value, 4.0 * scale_value, maxf(chip_height - 8.0 * scale_value, 4.0)), Color.WHITE)


func _draw_chip(rect: Rect2, intensity: float) -> void:
	for spread in [7.0, 4.0, 2.0]:
		draw_rect(rect.grow(spread), Color(tint, intensity * 0.035), false, spread * 0.9)
	draw_rect(rect, tint.darkened(0.15))
	draw_rect(rect, tint.lerp(Color.WHITE, 0.65), false, 1.5)
	draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), tint.lerp(Color.WHITE, 0.22))
	draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, 5)), Color(0.93, 1.0, 1.0, 0.96))
	draw_rect(Rect2(rect.position + Vector2(3, rect.size.y - 5), Vector2(rect.size.x - 6, 2)), Color(tint, 0.92))
	draw_rect(Rect2(rect.position + Vector2(0, 3), Vector2(3, rect.size.y - 6)), Color.WHITE)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 3, 3), Vector2(3, rect.size.y - 6)), Color.WHITE)


func _draw_fnf_note(scale_value: float, chip_height: float, head_y: float) -> void:
	var center_x := size.x * 0.5
	var head_center := Vector2(center_x, head_y + chip_height * 0.5)
	var half_extent := minf(size.x * 0.34, chip_height * 0.96)
	if is_hold and size.y > chip_height * 1.35:
		var body_w := clampf(size.x * 0.32, 10.0, half_extent * 1.05)
		var body_x := center_x - body_w * 0.5
		var body_top := 6.0 * scale_value
		var body_h := maxf(head_center.y - body_top, 2.0)
		var body := Rect2(body_x, body_top, body_w, body_h)
		draw_rect(body, Color(tint.r, tint.g, tint.b, 0.68 if holding else 0.48))
		draw_rect(Rect2(center_x - body_w * 0.16, body_top, body_w * 0.32, body_h), Color(1.0, 1.0, 1.0, 0.28 if holding else 0.16))
		draw_rect(body, tint.lerp(Color.WHITE, 0.55), false, 1.5)
		draw_rect(Rect2(body_x - 1.0, 0.0, body_w + 2.0, body_top + 2.0), tint.lerp(Color.WHITE, 0.35))
	draw_fnf_arrow(
		self,
		head_center,
		half_extent,
		lane_direction,
		Color(tint.r, tint.g, tint.b, 0.98),
		Color(0.08, 0.06, 0.12, 0.95),
		maxf(2.0 * scale_value, 1.8),
		0.18 if holding else 0.10,
		true
	)
