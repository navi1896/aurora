extends Control

class_name ChartTimeline

signal seek_requested(seconds: float)

const PIXEL_FONT := preload("res://assets/menu/fonts/PressStart2P-Regular.ttf")
const LANE_COLORS: Array[Color] = [
	Color(0.08, 0.86, 1.0),
	Color(0.42, 0.24, 1.0),
	Color(1.0, 0.20, 0.72),
	Color(0.08, 0.86, 1.0),
	Color(0.08, 0.86, 1.0),
	Color(1.0, 0.20, 0.72),
	Color(0.42, 0.24, 1.0),
	Color(0.08, 0.86, 1.0),
]

var notes: Array[Dictionary] = []
var duration_seconds := 120.0
var current_time := 0.0
var bpm := 120.0
var key_count := 4


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 230.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_chart(
	next_notes: Array[Dictionary],
	next_duration: float,
	next_bpm: float,
	next_key_count: int
) -> void:
	notes = next_notes
	duration_seconds = maxf(next_duration, 1.0)
	bpm = maxf(next_bpm, 1.0)
	key_count = clampi(next_key_count, 1, 16)
	queue_redraw()


func set_playhead(seconds: float) -> void:
	current_time = clampf(seconds, 0.0, duration_seconds)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ratio := clampf(event.position.x / maxf(size.x, 1.0), 0.0, 1.0)
		seek_requested.emit(ratio * duration_seconds)
		accept_event()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.008, 0.012, 0.035, 0.96), true)
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var header_height := 26.0
	var lane_height := (size.y - header_height) / float(maxi(key_count, 1))
	for lane in range(key_count):
		var lane_rect := Rect2(
			0.0,
			header_height + float(lane) * lane_height,
			size.x,
			lane_height
		)
		var tint := LANE_COLORS[lane % LANE_COLORS.size()]
		draw_rect(
			lane_rect,
			Color(tint.r, tint.g, tint.b, 0.055 if lane % 2 == 0 else 0.028),
			true
		)
		draw_line(
			Vector2(0.0, lane_rect.end.y),
			Vector2(size.x, lane_rect.end.y),
			Color(1.0, 1.0, 1.0, 0.09),
			1.0
		)
		draw_string(
			PIXEL_FONT,
			Vector2(8.0, lane_rect.position.y + lane_height * 0.62),
			"%02d" % (lane + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			8,
			Color(tint.r, tint.g, tint.b, 0.86)
		)

	var beat_seconds := 60.0 / maxf(bpm, 1.0)
	var beat := 0
	var beat_time := 0.0
	while beat_time <= duration_seconds and beat < 2000:
		var x := beat_time / duration_seconds * size.x
		var measure := beat % 4 == 0
		draw_line(
			Vector2(x, header_height if measure else header_height + 8.0),
			Vector2(x, size.y),
			Color(0.18, 0.82, 0.82, 0.28 if measure else 0.10),
			2.0 if measure else 1.0
		)
		if measure:
			draw_string(
				PIXEL_FONT,
				Vector2(x + 4.0, 17.0),
				"%02d" % floori(float(beat) / 4.0 + 1.0),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				7,
				Color(0.62, 0.66, 0.76, 0.82)
			)
		beat += 1
		beat_time = float(beat) * beat_seconds

	for note in notes:
		var lane := int(note.get("lane", -1))
		if lane < 0 or lane >= key_count:
			continue
		var note_time := float(note.get("time", 0.0))
		var note_duration := float(note.get("duration", 0.0))
		var x := note_time / duration_seconds * size.x
		var width := maxf(note_duration / duration_seconds * size.x, 7.0)
		var y := header_height + float(lane) * lane_height + 5.0
		var note_rect := Rect2(x, y, width, maxf(lane_height - 10.0, 4.0))
		var tint := LANE_COLORS[lane % LANE_COLORS.size()]
		draw_rect(note_rect, Color(tint.r, tint.g, tint.b, 0.78), true)
		draw_rect(note_rect, Color(0.90, 0.98, 1.0, 0.96), false, 1.0)
		if note_duration >= 0.18:
			var head_rect := Rect2(note_rect.end.x - 5.0, note_rect.position.y, 5.0, note_rect.size.y)
			draw_rect(head_rect, Color(0.94, 0.99, 1.0, 0.96), true)

	var playhead_x := current_time / duration_seconds * size.x
	draw_line(
		Vector2(playhead_x, 0.0),
		Vector2(playhead_x, size.y),
		Color(1.0, 0.76, 0.32, 1.0),
		3.0
	)
	draw_circle(Vector2(playhead_x, 10.0), 5.0, Color(1.0, 0.76, 0.32, 1.0))
	draw_rect(bounds, Color(0.18, 0.82, 0.82, 0.42), false, 2.0)
