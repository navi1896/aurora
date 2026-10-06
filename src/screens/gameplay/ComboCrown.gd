extends Control

## Reusable cabinet crown, reserved for a completed song without misses.

func _draw() -> void:
	var scale_factor := minf(size.x / 160.0, size.y / 90.0)
	var origin := Vector2((size.x - 160.0 * scale_factor) * 0.5, (size.y - 90.0 * scale_factor) * 0.5)
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	var gold := Color(1.0, 0.72, 0.10)
	var bright := Color(1.0, 0.94, 0.50)
	var shadow := Color(0.35, 0.12, 0.04)
	draw_colored_polygon(PackedVector2Array([
		Vector2(16, 25), Vector2(48, 46), Vector2(80, 10), Vector2(112, 46),
		Vector2(144, 25), Vector2(130, 70), Vector2(30, 70),
	]), shadow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, 20), Vector2(49, 44), Vector2(80, 9), Vector2(111, 44),
		Vector2(142, 20), Vector2(127, 64), Vector2(33, 64),
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(37, 51), Vector2(80, 17), Vector2(123, 51), Vector2(116, 58),
		Vector2(44, 58),
	]), bright)
	draw_rect(Rect2(34, 66, 92, 10), shadow)
	draw_rect(Rect2(34, 63, 92, 9), gold)
	draw_rect(Rect2(47, 65, 66, 3), bright)
	for point in [Vector2(18, 17), Vector2(80, 6), Vector2(142, 17)]:
		draw_circle(point, 5.0, bright)
	for point in [Vector2(7, 44), Vector2(153, 44), Vector2(80, 84)]:
		draw_line(point - Vector2(5, 0), point + Vector2(5, 0), bright, 2.0)
		draw_line(point - Vector2(0, 5), point + Vector2(0, 5), bright, 2.0)
	draw_set_transform(Vector2.ZERO)
