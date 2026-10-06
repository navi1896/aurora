extends Control

## Drawn in the cabinet's reference coordinates so a note keeps its proportions.
var tint := Color(0.08, 0.86, 1.0)
var is_hold := false
var holding := false
var phase := 0.0
var reduced_motion := false


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
	var chip_height := minf(18.0, size.y)
	if is_hold and size.y > chip_height * 1.5:
		var body := Rect2(1.0, chip_height * 0.35, size.x - 2.0, size.y - chip_height * 0.75)
		var body_color := tint.darkened(0.15)
		draw_rect(body, Color(body_color, 0.96 if holding else 0.86))
		# Broad color and repeated chevrons remain recognizable before the hold starts.
		draw_rect(Rect2(size.x * 0.38, body.position.y, size.x * 0.24, body.size.y), Color(tint.lerp(Color.WHITE, 0.55), 0.28))
		var arrow_y := chip_height + 12.0
		while arrow_y < size.y - chip_height - 8.0:
			var center_x := size.x * 0.5
			draw_polyline(PackedVector2Array([
				Vector2(center_x - 13.0, arrow_y + 5.0),
				Vector2(center_x, arrow_y - 3.0),
				Vector2(center_x + 13.0, arrow_y + 5.0),
			]), Color(0.88, 1.0, 1.0, 0.76 if holding else 0.54), 2.0)
			arrow_y += 38.0
		for edge in [body.position.x, body.end.x]:
			draw_rect(Rect2(edge - 1.0, body.position.y, 2.0, body.size.y), Color(tint.lerp(Color.WHITE, 0.72), 1.0))
		if holding:
			var strand_x := size.x * (0.50 + (0.0 if reduced_motion else sin(phase * 5.0) * 0.13))
			draw_rect(Rect2(strand_x - 2.0, body.position.y, 4.0, body.size.y), Color(1, 1, 1, 0.48))
		# A slim striped tail cannot be confused with another falling tap.
		draw_rect(Rect2(0, 0, size.x, 7.0), tint.lerp(Color.WHITE, 0.65))
		draw_rect(Rect2(0, 7.0, size.x, 2.0), tint.darkened(0.45))
	_draw_chip(Rect2(0, size.y - chip_height, size.x, chip_height), 1.0)
	if is_hold:
		var head_y := size.y - chip_height
		for x in [size.x * 0.5 - 8.0, size.x * 0.5 + 4.0]:
			draw_rect(Rect2(x - 1.0, head_y + 3.0, 6.0, 12.0), tint.darkened(0.65))
			draw_rect(Rect2(x, head_y + 4.0, 4.0, 10.0), Color.WHITE)


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
