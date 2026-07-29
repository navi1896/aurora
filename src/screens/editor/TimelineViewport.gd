extends RefCounted

class_name TimelineViewport

const MIN_PIXELS_PER_SECOND := 8.0
const MAX_PIXELS_PER_SECOND := 2048.0

var duration_seconds := 120.0
var viewport_width := 1000.0
var viewport_height := 230.0
var header_height := 26.0
var key_count := 4
var pixels_per_second := 100.0
var scroll_time := 0.0


func _init(
	next_duration_seconds: float = 120.0,
	next_viewport_width: float = 1000.0,
	next_viewport_height: float = 230.0,
	next_key_count: int = 4,
	next_pixels_per_second: float = 100.0
) -> void:
	duration_seconds = maxf(next_duration_seconds, 1.0)
	viewport_width = maxf(next_viewport_width, 1.0)
	viewport_height = maxf(next_viewport_height, 1.0)
	key_count = clampi(next_key_count, 1, 16)
	pixels_per_second = clampf(
		next_pixels_per_second,
		MIN_PIXELS_PER_SECOND,
		MAX_PIXELS_PER_SECOND
	)
	_clamp_scroll()


func set_duration(next_duration_seconds: float) -> void:
	duration_seconds = maxf(next_duration_seconds, 1.0)
	_clamp_scroll()


func set_viewport_size(next_size: Vector2) -> void:
	viewport_width = maxf(next_size.x, 1.0)
	viewport_height = maxf(next_size.y, 1.0)
	_clamp_scroll()


func set_key_count(next_key_count: int) -> void:
	key_count = clampi(next_key_count, 1, 16)


func set_header_height(next_header_height: float) -> void:
	header_height = clampf(next_header_height, 0.0, viewport_height)


func get_visible_duration() -> float:
	return minf(viewport_width / pixels_per_second, duration_seconds)


func get_visible_start() -> float:
	return scroll_time


func get_visible_end() -> float:
	return minf(scroll_time + get_visible_duration(), duration_seconds)


func get_max_scroll_time() -> float:
	return maxf(duration_seconds - get_visible_duration(), 0.0)


func set_scroll_time(next_scroll_time: float) -> void:
	scroll_time = clampf(next_scroll_time, 0.0, get_max_scroll_time())


func set_zoom(next_pixels_per_second: float, anchor_x: float = -1.0) -> void:
	var safe_anchor_x := (
		viewport_width * 0.5
		if anchor_x < 0.0
		else clampf(anchor_x, 0.0, viewport_width)
	)
	var anchor_time := x_to_time(safe_anchor_x)
	pixels_per_second = clampf(
		next_pixels_per_second,
		MIN_PIXELS_PER_SECOND,
		MAX_PIXELS_PER_SECOND
	)
	set_scroll_time(anchor_time - safe_anchor_x / pixels_per_second)


func time_to_x(time: float) -> float:
	return (time - scroll_time) * pixels_per_second


func x_to_time(x: float) -> float:
	return clampf(
		scroll_time + x / pixels_per_second,
		0.0,
		duration_seconds
	)


func get_lane_height() -> float:
	return maxf(viewport_height - header_height, 1.0) / float(key_count)


func lane_to_y(lane: int) -> float:
	var safe_lane := clampi(lane, 0, key_count - 1)
	return header_height + (float(safe_lane) + 0.5) * get_lane_height()


func y_to_lane(y: float) -> int:
	if y < header_height or y > viewport_height:
		return -1
	return clampi(
		floori((y - header_height) / get_lane_height()),
		0,
		key_count - 1
	)


func snap_time(
	time: float,
	bpm: float,
	steps_per_beat: int = 4,
	offset_seconds: float = 0.0
) -> float:
	var safe_bpm := maxf(bpm, 1.0)
	var safe_steps := maxi(steps_per_beat, 1)
	var step_seconds := 60.0 / safe_bpm / float(safe_steps)
	var snapped: float = (
		round((time - offset_seconds) / step_seconds) * step_seconds
		+ offset_seconds
	)
	return clampf(snapped, 0.0, duration_seconds)


func is_note_visible(note: Dictionary) -> bool:
	var note_start := float(note.get("time", 0.0))
	var note_end := note_start + maxf(float(note.get("duration", 0.0)), 0.0)
	return note_end >= get_visible_start() and note_start <= get_visible_end()


func get_visible_notes(
	source_notes: Array[Dictionary],
	maximum_hold_duration: float = -1.0,
	assume_sorted: bool = false
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not assume_sorted:
		for note in source_notes:
			if is_note_visible(note):
				result.append(note.duplicate(true))
		return result
	var candidate_start := _first_visible_candidate_index(
		source_notes,
		maximum_hold_duration
	)
	var visible_end := get_visible_end()
	for index in range(candidate_start, source_notes.size()):
		var note: Dictionary = source_notes[index]
		if float(note.get("time", 0.0)) > visible_end:
			break
		if is_note_visible(note):
			result.append(note.duplicate(true))
	return result


func get_visible_note_ids(
	source_notes: Array[Dictionary],
	maximum_hold_duration: float = -1.0,
	assume_sorted: bool = false
) -> Array[int]:
	var result: Array[int] = []
	if not assume_sorted:
		for note in source_notes:
			if not is_note_visible(note):
				continue
			var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
			if note_id > 0:
				result.append(note_id)
		return result
	var candidate_start := _first_visible_candidate_index(
		source_notes,
		maximum_hold_duration
	)
	var visible_end := get_visible_end()
	for index in range(candidate_start, source_notes.size()):
		var note: Dictionary = source_notes[index]
		if float(note.get("time", 0.0)) > visible_end:
			break
		if not is_note_visible(note):
			continue
		var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
		if note_id > 0:
			result.append(note_id)
	return result


func _first_visible_candidate_index(
	source_notes: Array[Dictionary],
	maximum_hold_duration: float
) -> int:
	if source_notes.is_empty():
		return 0
	var safe_maximum_hold := maximum_hold_duration
	if safe_maximum_hold < 0.0:
		safe_maximum_hold = 0.0
		for note in source_notes:
			safe_maximum_hold = maxf(
				safe_maximum_hold,
				maxf(float(note.get("duration", 0.0)), 0.0)
			)
	var earliest_time := get_visible_start() - safe_maximum_hold
	var low := 0
	var high := source_notes.size()
	while low < high:
		var middle := (low + high) >> 1
		if float(source_notes[middle].get("time", 0.0)) < earliest_time:
			low = middle + 1
		else:
			high = middle
	return low


func get_note_rect(
	note: Dictionary,
	minimum_tap_width: float = 7.0,
	vertical_padding: float = 5.0
) -> Rect2:
	var lane := clampi(int(note.get("lane", 0)), 0, key_count - 1)
	var note_time := float(note.get("time", 0.0))
	var note_duration := maxf(float(note.get("duration", 0.0)), 0.0)
	var note_width := maxf(note_duration * pixels_per_second, minimum_tap_width)
	var lane_height := get_lane_height()
	return Rect2(
		time_to_x(note_time),
		header_height + float(lane) * lane_height + vertical_padding,
		note_width,
		maxf(lane_height - vertical_padding * 2.0, 1.0)
	)


func _clamp_scroll() -> void:
	scroll_time = clampf(scroll_time, 0.0, get_max_scroll_time())
