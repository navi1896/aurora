extends Control

## Scalable cabinet housing drawn behind the playable lanes.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 80.0 or h < 200.0:
		return
	var deck_top := h - 118.0
	var cyan := Color(0.06, 0.89, 1.0, 0.96)
	var pink := Color(1.0, 0.15, 0.78, 0.94)
	var navy := Color(0.005, 0.009, 0.039, 0.96)
	var metal := Color(0.025, 0.030, 0.085, 0.96)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(45, 0), Vector2(34, 62),
		Vector2(34, deck_top - 54), Vector2(52, deck_top), Vector2(0, deck_top + 28),
	]), navy)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w, 0), Vector2(w - 45, 0), Vector2(w - 34, 62),
		Vector2(w - 34, deck_top - 54), Vector2(w - 52, deck_top), Vector2(w, deck_top + 28),
	]), navy)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, 24), Vector2(22, 42), Vector2(22, deck_top - 46),
		Vector2(41, deck_top), Vector2(5, deck_top + 10),
	]), metal)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w - 5, 24), Vector2(w - 22, 42), Vector2(w - 22, deck_top - 46),
		Vector2(w - 41, deck_top), Vector2(w - 5, deck_top + 10),
	]), metal)
	draw_line(Vector2(34, 62), Vector2(34, deck_top - 54), cyan, 5.0)
	draw_line(Vector2(w - 34, 62), Vector2(w - 34, deck_top - 54), pink, 5.0)
	draw_line(Vector2(34, deck_top - 54), Vector2(52, deck_top), pink, 5.0)
	draw_line(Vector2(w - 34, deck_top - 54), Vector2(w - 52, deck_top), cyan, 5.0)
	for index in range(5):
		var y := 92.0 + float(index) * (deck_top - 160.0) / 5.0
		draw_rect(Rect2(8, y, 8, 34), cyan if index % 2 == 0 else pink)
		draw_rect(Rect2(w - 16, y, 8, 34), pink if index % 2 == 0 else cyan)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w - 44, 35), Vector2(44, 35),
	]), navy)
	draw_line(Vector2(45, 31), Vector2(w - 45, 31), cyan, 5.0)
	draw_line(Vector2(47, 38), Vector2(w - 47, 38), pink, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, deck_top), Vector2(54, deck_top - 8), Vector2(80, deck_top + 35),
		Vector2(0, deck_top + 82),
	]), metal)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w, deck_top), Vector2(w - 54, deck_top - 8), Vector2(w - 80, deck_top + 35),
		Vector2(w, deck_top + 82),
	]), metal)
	draw_line(Vector2(2, deck_top + 58), Vector2(70, deck_top + 26), pink, 4.0)
	draw_line(Vector2(w - 2, deck_top + 58), Vector2(w - 70, deck_top + 26), cyan, 4.0)
