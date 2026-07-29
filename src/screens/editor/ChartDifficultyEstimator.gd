extends RefCounted

class_name ChartDifficultyEstimator

const SUPPORTED_KEY_COUNTS: Array[int] = [4, 6, 8]
const HOLD_THRESHOLD_SECONDS := 0.18
const CHORD_WINDOW_SECONDS := 0.03
const PEAK_WINDOW_SECONDS := 2.0


func estimate(
	raw_notes: Array,
	key_count: int,
	duration_seconds: float = -1.0
) -> Dictionary:
	if key_count not in SUPPORTED_KEY_COUNTS:
		return _unsupported_result(key_count)

	var invalid_note_count := 0
	var notes: Array[Dictionary] = []
	for raw_note in raw_notes:
		if not (raw_note is Dictionary):
			invalid_note_count += 1
			continue
		var time := float(raw_note.get("time", 0.0))
		var lane := int(raw_note.get("lane", -1))
		var hold_duration := float(raw_note.get("duration", 0.0))
		if (
			is_nan(time)
			or is_inf(time)
			or is_nan(hold_duration)
			or is_inf(hold_duration)
			or time < 0.0
			or lane < 0
			or lane >= key_count
		):
			invalid_note_count += 1
			continue
		notes.append(
			{
				"time": time,
				"lane": lane,
				"duration": maxf(hold_duration, 0.0),
			}
		)
	notes.sort_custom(_sort_note)

	if notes.is_empty():
		return _empty_chart_result(key_count, maxf(duration_seconds, 0.0), invalid_note_count)

	var first_time := float(notes.front()["time"])
	var last_end_time := first_time
	for note in notes:
		last_end_time = maxf(
			last_end_time,
			float(note["time"]) + float(note["duration"])
		)
	var effective_duration := duration_seconds
	if (
		effective_duration <= 0.0
		or is_nan(effective_duration)
		or is_inf(effective_duration)
	):
		effective_duration = maxf(last_end_time - first_time, 1.0)
	else:
		effective_duration = maxf(maxf(effective_duration, last_end_time), 1.0)

	var events := _group_onset_events(notes)
	var chord_note_count := 0
	var chord_event_count := 0
	var max_chord_size := 1
	for event_notes in events:
		var chord_size: int = event_notes.size()
		max_chord_size = maxi(max_chord_size, chord_size)
		if chord_size > 1:
			chord_event_count += 1
			chord_note_count += chord_size

	var hold_count := 0
	var total_hold_seconds := 0.0
	for note in notes:
		var note_duration := float(note["duration"])
		if note_duration >= HOLD_THRESHOLD_SECONDS:
			hold_count += 1
			total_hold_seconds += note_duration

	var average_nps := float(notes.size()) / effective_duration
	var peak_nps := _calculate_peak_nps(notes)
	var burst_ratio := peak_nps / maxf(average_nps, 0.01)
	var chord_note_ratio := float(chord_note_count) / float(notes.size())
	var chord_event_ratio := float(chord_event_count) / float(events.size())
	var hold_ratio := float(hold_count) / float(notes.size())
	var hold_occupancy := clampf(
		total_hold_seconds / (effective_duration * float(key_count)),
		0.0,
		1.0
	)
	var lane_metrics := _calculate_lane_metrics(events, key_count)
	var lane_change_ratio := float(lane_metrics["change_ratio"])
	var lane_travel_ratio := float(lane_metrics["travel_ratio"])

	var density_points := clampf(average_nps * 1.15, 0.0, 6.0)
	var chord_points := clampf(
		chord_note_ratio * 2.5
		+ (
			float(max_chord_size - 1)
			/ maxf(float(key_count - 1), 1.0)
		),
		0.0,
		3.5
	)
	var hold_points := clampf(
		hold_ratio * 1.5 + minf(hold_occupancy * 4.0, 1.0),
		0.0,
		2.5
	)
	var peak_points := clampf(
		peak_nps * 0.35 + maxf(burst_ratio - 1.0, 0.0) * 0.5,
		0.0,
		4.0
	)
	var lane_points := clampf(
		lane_change_ratio * 1.5 + lane_travel_ratio * 1.5,
		0.0,
		3.0
	)
	var key_count_points: float = float(
		{4: 0.0, 6: 0.5, 8: 1.0}[key_count]
	)
	var raw_score := clampf(
		1.0
		+ density_points
		+ chord_points
		+ hold_points
		+ peak_points
		+ lane_points
		+ key_count_points,
		1.0,
		20.0
	)

	return {
		"valid": true,
		"informational": true,
		"level": clampi(roundi(raw_score), 1, 20),
		"raw_score": snappedf(raw_score, 0.001),
		"key_count": key_count,
		"note_count": notes.size(),
		"event_count": events.size(),
		"duration_seconds": snappedf(effective_duration, 0.001),
		"invalid_note_count": invalid_note_count,
		"metrics": {
			"average_nps": snappedf(average_nps, 0.001),
			"peak_nps": snappedf(peak_nps, 0.001),
			"burst_ratio": snappedf(burst_ratio, 0.001),
			"chord_note_ratio": snappedf(chord_note_ratio, 0.001),
			"chord_event_ratio": snappedf(chord_event_ratio, 0.001),
			"max_chord_size": max_chord_size,
			"hold_ratio": snappedf(hold_ratio, 0.001),
			"hold_occupancy": snappedf(hold_occupancy, 0.001),
			"lane_change_ratio": snappedf(lane_change_ratio, 0.001),
			"lane_travel_ratio": snappedf(lane_travel_ratio, 0.001),
		},
		"breakdown": {
			"density": snappedf(density_points, 0.001),
			"chords": snappedf(chord_points, 0.001),
			"holds": snappedf(hold_points, 0.001),
			"peaks": snappedf(peak_points, 0.001),
			"lane_changes": snappedf(lane_points, 0.001),
			"key_count": snappedf(float(key_count_points), 0.001),
		},
	}


func _group_onset_events(notes: Array[Dictionary]) -> Array:
	var events: Array = []
	var current_event: Array[Dictionary] = []
	var event_start_time := 0.0
	for note in notes:
		var note_time := float(note["time"])
		if (
			current_event.is_empty()
			or note_time - event_start_time <= CHORD_WINDOW_SECONDS
		):
			if current_event.is_empty():
				event_start_time = note_time
			current_event.append(note)
		else:
			events.append(current_event)
			current_event = [note]
			event_start_time = note_time
	if not current_event.is_empty():
		events.append(current_event)
	return events


func _calculate_peak_nps(notes: Array[Dictionary]) -> float:
	var left_index := 0
	var largest_window_count := 0
	for right_index in range(notes.size()):
		var right_time := float(notes[right_index]["time"])
		while (
			left_index < right_index
			and right_time - float(notes[left_index]["time"]) > PEAK_WINDOW_SECONDS
		):
			left_index += 1
		largest_window_count = maxi(
			largest_window_count,
			right_index - left_index + 1
		)
	return float(largest_window_count) / PEAK_WINDOW_SECONDS


func _calculate_lane_metrics(events: Array, key_count: int) -> Dictionary:
	if events.size() < 2:
		return {"change_ratio": 0.0, "travel_ratio": 0.0}
	var centers: Array[float] = []
	for event_notes in events:
		var lane_total := 0.0
		for note in event_notes:
			lane_total += float(note["lane"])
		centers.append(lane_total / float(event_notes.size()))

	var changed_transition_count := 0
	var normalized_travel_total := 0.0
	for index in range(1, centers.size()):
		var travel := absf(centers[index] - centers[index - 1])
		if travel > 0.25:
			changed_transition_count += 1
		normalized_travel_total += travel / float(key_count - 1)
	var transition_count := centers.size() - 1
	return {
		"change_ratio": float(changed_transition_count) / float(transition_count),
		"travel_ratio": normalized_travel_total / float(transition_count),
	}


func _empty_chart_result(
	key_count: int,
	duration_seconds: float,
	invalid_note_count: int
) -> Dictionary:
	return {
		"valid": true,
		"informational": true,
		"level": 1,
		"raw_score": 1.0,
		"key_count": key_count,
		"note_count": 0,
		"event_count": 0,
		"duration_seconds": duration_seconds,
		"invalid_note_count": invalid_note_count,
		"metrics": {
			"average_nps": 0.0,
			"peak_nps": 0.0,
			"burst_ratio": 0.0,
			"chord_note_ratio": 0.0,
			"chord_event_ratio": 0.0,
			"max_chord_size": 0,
			"hold_ratio": 0.0,
			"hold_occupancy": 0.0,
			"lane_change_ratio": 0.0,
			"lane_travel_ratio": 0.0,
		},
		"breakdown": {
			"density": 0.0,
			"chords": 0.0,
			"holds": 0.0,
			"peaks": 0.0,
			"lane_changes": 0.0,
			"key_count": 0.0,
		},
	}


func _unsupported_result(key_count: int) -> Dictionary:
	var result := _empty_chart_result(key_count, 0.0, 0)
	result["valid"] = false
	result["error"] = "unsupported_key_count"
	return result


func _sort_note(a: Dictionary, b: Dictionary) -> bool:
	var a_time := float(a["time"])
	var b_time := float(b["time"])
	if not is_equal_approx(a_time, b_time):
		return a_time < b_time
	return int(a["lane"]) < int(b["lane"])
