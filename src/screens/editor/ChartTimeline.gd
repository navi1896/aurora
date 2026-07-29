extends Control

class_name ChartTimeline

signal seek_requested(seconds: float)
signal selection_requested(note_id: int, additive: bool, toggle: bool)
signal marquee_selection_requested(note_ids: Array[int], additive: bool)
signal create_note_requested(seconds: float, lane: int)
signal move_selection_requested(delta_seconds: float, delta_lane: int)
signal resize_hold_requested(note_id: int, duration_seconds: float)
signal zoom_changed(pixels_per_second: float)
signal scroll_changed(start_seconds: float)

const PIXEL_FONT := preload("res://assets/menu/fonts/PressStart2P-Regular.ttf")
const VIEWPORT_MODEL := preload("res://src/screens/editor/TimelineViewport.gd")
const EDITOR_ID_KEY := "_editor_id"
const HEADER_HEIGHT := 28.0
const MIN_HOLD_DURATION := 0.18
const NOTE_HANDLE_WIDTH := 9.0
const DRAG_THRESHOLD := 5.0
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
var selected_note_ids: Array[int] = []
var duration_seconds := 120.0
var current_time := 0.0
var bpm := 120.0
var key_count := 4
var snap_steps_per_beat := 4
var viewport_model = VIEWPORT_MODEL.new()
var maximum_hold_duration := 0.0

var drag_mode := ""
var drag_start_position := Vector2.ZERO
var drag_current_position := Vector2.ZERO
var drag_start_scroll := 0.0
var drag_note_id := 0
var drag_note_time := 0.0
var drag_note_lane := 0
var drag_note_duration := 0.0
var drag_time_delta := 0.0
var drag_lane_delta := 0
var drag_resize_duration := 0.0
var hovered_note_id := 0


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 180.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_update_viewport_geometry()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and viewport_model != null:
		_update_viewport_geometry()
		queue_redraw()


func set_chart(
	next_notes: Array[Dictionary],
	next_duration: float,
	next_bpm: float,
	next_key_count: int,
	next_selected_note_ids: Array[int] = []
) -> void:
	notes.clear()
	maximum_hold_duration = 0.0
	for note in next_notes:
		notes.append(note.duplicate(true))
		maximum_hold_duration = maxf(
			maximum_hold_duration,
			maxf(float(note.get("duration", 0.0)), 0.0)
		)
	selected_note_ids.clear()
	for note_id in next_selected_note_ids:
		if note_id > 0 and note_id not in selected_note_ids:
			selected_note_ids.append(note_id)
	duration_seconds = maxf(next_duration, 1.0)
	bpm = maxf(next_bpm, 1.0)
	key_count = clampi(next_key_count, 1, 16)
	viewport_model.set_duration(duration_seconds)
	viewport_model.set_key_count(key_count)
	_update_viewport_geometry()
	queue_redraw()


func set_playhead(seconds: float) -> void:
	current_time = clampf(seconds, 0.0, duration_seconds)
	queue_redraw()


func set_snap_steps(steps_per_beat: int) -> void:
	snap_steps_per_beat = maxi(steps_per_beat, 1)
	queue_redraw()


func get_snap_seconds() -> float:
	return 60.0 / maxf(bpm, 1.0) / float(maxi(snap_steps_per_beat, 1))


func set_zoom(pixels_per_second: float, anchor_x: float = -1.0) -> void:
	viewport_model.set_zoom(pixels_per_second, anchor_x)
	zoom_changed.emit(viewport_model.pixels_per_second)
	scroll_changed.emit(viewport_model.scroll_time)
	queue_redraw()


func zoom_by(factor: float, anchor_x: float = -1.0) -> void:
	set_zoom(viewport_model.pixels_per_second * factor, anchor_x)


func set_scroll_time(seconds: float) -> void:
	viewport_model.set_scroll_time(seconds)
	scroll_changed.emit(viewport_model.scroll_time)
	queue_redraw()


func scroll_by(seconds: float) -> void:
	set_scroll_time(viewport_model.scroll_time + seconds)


func reveal_time(seconds: float, margin_ratio: float = 0.12) -> void:
	var visible_start := viewport_model.get_visible_start()
	var visible_end := viewport_model.get_visible_end()
	var margin := viewport_model.get_visible_duration() * clampf(margin_ratio, 0.0, 0.45)
	if seconds < visible_start + margin:
		set_scroll_time(seconds - margin)
	elif seconds > visible_end - margin:
		set_scroll_time(seconds - viewport_model.get_visible_duration() + margin)


func get_zoom_text() -> String:
	return "%.0f PX/S" % viewport_model.pixels_per_second


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		if event.ctrl_pressed:
			zoom_by(1.25, event.position.x)
		else:
			scroll_by(-viewport_model.get_visible_duration() * (0.35 if event.shift_pressed else 0.12))
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		if event.ctrl_pressed:
			zoom_by(0.8, event.position.x)
		else:
			scroll_by(viewport_model.get_visible_duration() * (0.35 if event.shift_pressed else 0.12))
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			drag_mode = "pan"
			drag_start_position = event.position
			drag_current_position = event.position
			drag_start_scroll = viewport_model.scroll_time
		else:
			drag_mode = ""
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		grab_focus()
		_begin_left_drag(event)
	else:
		_finish_left_drag(event)
	accept_event()


func _begin_left_drag(event: InputEventMouseButton) -> void:
	drag_start_position = event.position
	drag_current_position = event.position
	drag_time_delta = 0.0
	drag_lane_delta = 0
	drag_resize_duration = 0.0
	var hit := _find_note_at(event.position)
	if not hit.is_empty():
		drag_note_id = int(hit.get(EDITOR_ID_KEY, 0))
		drag_note_time = float(hit.get("time", 0.0))
		drag_note_lane = int(hit.get("lane", 0))
		drag_note_duration = float(hit.get("duration", 0.0))
		var rect := viewport_model.get_note_rect(hit)
		var on_resize_handle := (
			drag_note_duration >= MIN_HOLD_DURATION
			and event.position.x >= rect.end.x - NOTE_HANDLE_WIDTH
		)
		selection_requested.emit(
			drag_note_id,
			event.shift_pressed or event.ctrl_pressed,
			event.ctrl_pressed
		)
		drag_mode = "resize" if on_resize_handle else "move"
		return
	drag_note_id = 0
	var lane := viewport_model.y_to_lane(event.position.y)
	if event.double_click and lane >= 0:
		drag_mode = ""
		create_note_requested.emit(
			viewport_model.snap_time(
				viewport_model.x_to_time(event.position.x),
				bpm,
				snap_steps_per_beat
			),
			lane
		)
		return
	drag_mode = "marquee"


func _finish_left_drag(event: InputEventMouseButton) -> void:
	drag_current_position = event.position
	match drag_mode:
		"move":
			if (
				absf(drag_time_delta) > 0.0005
				or drag_lane_delta != 0
			):
				move_selection_requested.emit(drag_time_delta, drag_lane_delta)
		"resize":
			if absf(drag_resize_duration - drag_note_duration) > 0.0005:
				resize_hold_requested.emit(drag_note_id, drag_resize_duration)
		"marquee":
			var marquee := _get_marquee_rect()
			if marquee.size.length() >= DRAG_THRESHOLD:
				marquee_selection_requested.emit(
					_get_note_ids_in_rect(marquee),
					event.shift_pressed or event.ctrl_pressed
				)
			else:
				seek_requested.emit(viewport_model.x_to_time(event.position.x))
	drag_mode = ""
	drag_note_id = 0
	queue_redraw()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	drag_current_position = event.position
	hovered_note_id = int(_find_note_at(event.position).get(EDITOR_ID_KEY, 0))
	match drag_mode:
		"pan":
			viewport_model.set_scroll_time(
				drag_start_scroll
				- (event.position.x - drag_start_position.x)
				/ viewport_model.pixels_per_second
			)
			scroll_changed.emit(viewport_model.scroll_time)
		"move":
			var target_time := viewport_model.snap_time(
				drag_note_time
				+ (event.position.x - drag_start_position.x)
				/ viewport_model.pixels_per_second,
				bpm,
				snap_steps_per_beat
			)
			drag_time_delta = target_time - drag_note_time
			var target_lane := viewport_model.y_to_lane(event.position.y)
			drag_lane_delta = (
				target_lane - drag_note_lane
				if target_lane >= 0
				else 0
			)
		"resize":
			var target_end := viewport_model.snap_time(
				viewport_model.x_to_time(event.position.x),
				bpm,
				snap_steps_per_beat
			)
			drag_resize_duration = maxf(
				target_end - drag_note_time,
				MIN_HOLD_DURATION
			)
	queue_redraw()


func _find_note_at(position: Vector2) -> Dictionary:
	if position.y < HEADER_HEIGHT:
		return {}
	var visible_notes := viewport_model.get_visible_notes(
		notes,
		maximum_hold_duration,
		true
	)
	for index in range(visible_notes.size() - 1, -1, -1):
		var note: Dictionary = visible_notes[index]
		if viewport_model.get_note_rect(note).grow(2.0).has_point(position):
			return note
	return {}


func _get_note_ids_in_rect(rect: Rect2) -> Array[int]:
	var ids: Array[int] = []
	for note in viewport_model.get_visible_notes(
		notes,
		maximum_hold_duration,
		true
	):
		if not viewport_model.get_note_rect(note).intersects(rect):
			continue
		var note_id := int(note.get(EDITOR_ID_KEY, 0))
		if note_id > 0:
			ids.append(note_id)
	return ids


func _get_marquee_rect() -> Rect2:
	return Rect2(
		Vector2(
			minf(drag_start_position.x, drag_current_position.x),
			minf(drag_start_position.y, drag_current_position.y)
		),
		Vector2(
			absf(drag_current_position.x - drag_start_position.x),
			absf(drag_current_position.y - drag_start_position.y)
		)
	)


func _update_viewport_geometry() -> void:
	viewport_model.set_viewport_size(size)
	viewport_model.set_header_height(HEADER_HEIGHT)


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.008, 0.012, 0.035, 0.96), true)
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_draw_lanes()
	_draw_grid()
	_draw_notes()
	_draw_playhead()
	_draw_header()
	if drag_mode == "marquee":
		var marquee := _get_marquee_rect()
		draw_rect(marquee, Color(0.08, 0.86, 1.0, 0.12), true)
		draw_rect(marquee, Color(0.08, 0.86, 1.0, 0.92), false, 2.0)
	draw_rect(bounds, Color(0.18, 0.82, 0.82, 0.42), false, 2.0)


func _draw_lanes() -> void:
	var lane_height := viewport_model.get_lane_height()
	for lane in range(key_count):
		var lane_rect := Rect2(
			0.0,
			HEADER_HEIGHT + float(lane) * lane_height,
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


func _draw_grid() -> void:
	var step_seconds := get_snap_seconds()
	var first_step := floori(viewport_model.get_visible_start() / step_seconds)
	var last_step := ceili(viewport_model.get_visible_end() / step_seconds)
	var max_lines := 500
	if last_step - first_step > max_lines:
		var stride := ceili(float(last_step - first_step) / float(max_lines))
		first_step = floori(float(first_step) / float(stride)) * stride
		for step in range(first_step, last_step + 1, stride):
			_draw_grid_line(step, step_seconds)
		return
	for step in range(first_step, last_step + 1):
		_draw_grid_line(step, step_seconds)


func _draw_grid_line(step: int, step_seconds: float) -> void:
	var step_time := float(step) * step_seconds
	var x := viewport_model.time_to_x(step_time)
	var beat_index := floori(float(step) / float(snap_steps_per_beat))
	var on_beat := step % snap_steps_per_beat == 0
	var on_measure := on_beat and beat_index % 4 == 0
	draw_line(
		Vector2(x, HEADER_HEIGHT if on_measure else HEADER_HEIGHT + 7.0),
		Vector2(x, size.y),
		Color(
			0.18,
			0.82,
			0.82,
			0.30 if on_measure else (0.14 if on_beat else 0.06)
		),
		2.0 if on_measure else 1.0
	)
	if on_measure:
		draw_string(
			PIXEL_FONT,
			Vector2(x + 4.0, 18.0),
			"%02d" % (floori(float(beat_index) / 4.0) + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			7,
			Color(0.62, 0.66, 0.76, 0.82)
		)


func _draw_notes() -> void:
	for source_note in viewport_model.get_visible_notes(
		notes,
		maximum_hold_duration,
		true
	):
		var note := source_note.duplicate(true)
		var note_id := int(note.get(EDITOR_ID_KEY, 0))
		if drag_mode == "move" and note_id in selected_note_ids:
			note["time"] = float(note.get("time", 0.0)) + drag_time_delta
			note["lane"] = int(note.get("lane", 0)) + drag_lane_delta
		elif drag_mode == "resize" and note_id == drag_note_id:
			note["duration"] = drag_resize_duration
		var lane := clampi(int(note.get("lane", 0)), 0, key_count - 1)
		var rect := viewport_model.get_note_rect(note)
		var tint := LANE_COLORS[lane % LANE_COLORS.size()]
		var selected := note_id in selected_note_ids
		var hovered := note_id == hovered_note_id
		draw_rect(
			rect,
			Color(tint.r, tint.g, tint.b, 0.92 if selected else 0.74),
			true
		)
		draw_rect(
			rect,
			Color(1.0, 0.76, 0.32, 1.0)
			if selected
			else Color(0.90, 0.98, 1.0, 0.96 if hovered else 0.72),
			false,
			3.0 if selected else 1.0
		)
		if float(note.get("duration", 0.0)) >= MIN_HOLD_DURATION:
			var handle := Rect2(
				rect.end.x - NOTE_HANDLE_WIDTH,
				rect.position.y,
				NOTE_HANDLE_WIDTH,
				rect.size.y
			)
			draw_rect(
				handle,
				Color(1.0, 0.90, 0.56, 0.96)
				if selected
				else Color(0.94, 0.99, 1.0, 0.84),
				true
			)


func _draw_playhead() -> void:
	var x := viewport_model.time_to_x(current_time)
	if x < 0.0 or x > size.x:
		return
	draw_line(
		Vector2(x, 0.0),
		Vector2(x, size.y),
		Color(1.0, 0.76, 0.32, 1.0),
		3.0
	)
	draw_circle(Vector2(x, 10.0), 5.0, Color(1.0, 0.76, 0.32, 1.0))


func _draw_header() -> void:
	var visible_start := viewport_model.get_visible_start()
	var visible_end := viewport_model.get_visible_end()
	var label := "%s — %s   %s" % [
		_format_short_time(visible_start),
		_format_short_time(visible_end),
		get_zoom_text(),
	]
	draw_string(
		PIXEL_FONT,
		Vector2(size.x - 8.0, 18.0),
		label,
		HORIZONTAL_ALIGNMENT_RIGHT,
		-1.0,
		7,
		Color(0.72, 0.76, 0.86, 0.90)
	)
	var track_width := minf(size.x * 0.26, 260.0)
	var track_rect := Rect2(size.x - track_width - 8.0, 22.0, track_width, 3.0)
	draw_rect(track_rect, Color(1.0, 1.0, 1.0, 0.14), true)
	var duration_ratio: float = viewport_model.get_visible_duration() / duration_seconds
	var scroll_ratio: float = (
		0.0
		if viewport_model.get_max_scroll_time() <= 0.0
		else viewport_model.scroll_time / viewport_model.get_max_scroll_time()
	)
	draw_rect(
		Rect2(
			track_rect.position.x + scroll_ratio * track_rect.size.x * (1.0 - duration_ratio),
			track_rect.position.y,
			maxf(track_rect.size.x * duration_ratio, 8.0),
			track_rect.size.y
		),
		Color(0.08, 0.86, 1.0, 0.82),
		true
	)


func _format_short_time(seconds: float) -> String:
	var safe := maxf(seconds, 0.0)
	return "%02d:%02d" % [floori(safe / 60.0), floori(fmod(safe, 60.0))]
