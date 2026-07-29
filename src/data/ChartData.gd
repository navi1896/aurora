extends Resource

class_name ChartData

@export_range(1, 16, 1) var key_count := 4
@export var difficulty_name := "NORMAL"
@export_range(1, 20, 1) var difficulty_level := 1
@export var chart_path := ""
@export_range(-5.0, 5.0, 0.001) var audio_offset_seconds := 0.0


func get_mode_label() -> String:
	return "%dK" % key_count


func get_difficulty_label() -> String:
	return "%s %02d" % [difficulty_name, difficulty_level]


func load_notes(bpm: float, duration_seconds: float) -> Array[Dictionary]:
	# A missing path is an intentional practice chart. Once a file path is set,
	# an empty or malformed file must remain unplayable instead of being replaced
	# by generated notes.
	if chart_path.is_empty():
		return _generate_practice_notes(bpm, duration_seconds)
	return _load_notes_from_file(bpm)


func has_valid_file_chart() -> bool:
	return is_valid_chart_document(_read_chart_document(), key_count)


func get_chart_end_time(bpm: float, duration_seconds: float) -> float:
	var notes := load_notes(bpm, duration_seconds)
	var end_time := 0.0
	for note in notes:
		end_time = maxf(
			end_time,
			float(note.get("time", 0.0)) + float(note.get("duration", 0.0))
		)
	return end_time


static func normalize_notes(raw_notes: Array, note_key_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var safe_key_count := clampi(note_key_count, 1, 16)
	for raw_note in raw_notes:
		if not (raw_note is Dictionary):
			continue
		var lane := int(raw_note.get("lane", -1))
		var note_time := float(raw_note.get("time", -1.0))
		if lane < 0 or lane >= safe_key_count or note_time < 0.0:
			continue
		result.append({
			"time": snappedf(note_time, 0.001),
			"lane": lane,
			"duration": snappedf(maxf(float(raw_note.get("duration", 0.0)), 0.0), 0.001),
		})
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if is_equal_approx(float(a["time"]), float(b["time"])):
				return int(a["lane"]) < int(b["lane"])
			return float(a["time"]) < float(b["time"])
	)
	return result


static func make_chart_document(
	raw_notes: Array,
	note_key_count: int,
	offset_seconds: float = 0.0
) -> Dictionary:
	return {
		"version": 2,
		"offset_seconds": snappedf(offset_seconds, 0.001),
		"key_count": clampi(note_key_count, 1, 16),
		"notes": normalize_notes(raw_notes, note_key_count),
	}


func _load_notes_from_file(bpm: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parsed = _read_chart_document()
	if not is_valid_chart_document(parsed, key_count):
		return result
	var document: Dictionary = parsed

	var raw_notes: Array = document["notes"]
	var chart_offset := float(document.get("offset_seconds", 0.0)) + audio_offset_seconds
	var beat_seconds := 60.0 / maxf(bpm, 1.0)

	for raw_note in raw_notes:
		if not (raw_note is Dictionary):
			continue
		var lane := int(raw_note.get("lane", -1))
		if lane < 0 or lane >= key_count:
			continue
		var note_time := chart_offset
		if raw_note.has("time"):
			note_time += float(raw_note["time"])
		else:
			note_time += float(raw_note.get("beat", 0.0)) * beat_seconds
		var note_duration := 0.0
		if raw_note.has("duration"):
			note_duration = maxf(float(raw_note["duration"]), 0.0)
		elif raw_note.has("length_beats"):
			note_duration = maxf(float(raw_note["length_beats"]) * beat_seconds, 0.0)
		result.append({
			"time": maxf(note_time, 0.0),
			"lane": lane,
			"duration": note_duration,
		})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	return result


func _read_chart_document() -> Variant:
	if chart_path.is_empty() or not FileAccess.file_exists(chart_path):
		return null
	var file := FileAccess.open(chart_path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


static func _is_valid_chart_document(document_value: Variant, note_key_count: int) -> bool:
	return is_valid_chart_document(document_value, note_key_count)


static func is_valid_chart_document(document_value: Variant, note_key_count: int) -> bool:
	if not (document_value is Dictionary):
		return false
	var document: Dictionary = document_value
	var safe_key_count := clampi(note_key_count, 1, 16)

	if document.has("version"):
		var version_value: Variant = document["version"]
		if not _is_whole_number(version_value) or int(version_value) < 1:
			return false
	if document.has("offset_seconds") and not _is_number(document["offset_seconds"]):
		return false
	if document.has("key_count"):
		var document_key_count: Variant = document["key_count"]
		if (
			not _is_whole_number(document_key_count)
			or int(document_key_count) != safe_key_count
		):
			return false
	if not document.has("notes") or not (document["notes"] is Array):
		return false

	var raw_notes: Array = document["notes"]
	if raw_notes.is_empty():
		return false
	for raw_note in raw_notes:
		if not _is_valid_raw_note(raw_note, safe_key_count):
			return false
	return not _has_note_conflicts(raw_notes)


static func _is_valid_raw_note(raw_note_value: Variant, note_key_count: int) -> bool:
	if not (raw_note_value is Dictionary):
		return false
	var raw_note: Dictionary = raw_note_value
	if not raw_note.has("lane") or not _is_whole_number(raw_note["lane"]):
		return false
	var lane := int(raw_note["lane"])
	if lane < 0 or lane >= note_key_count:
		return false

	var has_time := raw_note.has("time")
	var has_beat := raw_note.has("beat")
	if has_time == has_beat:
		return false
	if has_time and (not _is_number(raw_note["time"]) or float(raw_note["time"]) < 0.0):
		return false
	if has_beat and (not _is_number(raw_note["beat"]) or float(raw_note["beat"]) < 0.0):
		return false
	if (
		raw_note.has("duration")
		and (
			not _is_number(raw_note["duration"])
			or float(raw_note["duration"]) < 0.0
		)
	):
		return false
	if (
		raw_note.has("length_beats")
		and (
			not _is_number(raw_note["length_beats"])
			or float(raw_note["length_beats"]) < 0.0
		)
	):
		return false
	if raw_note.has("duration") and raw_note.has("length_beats"):
		return false
	if has_time and raw_note.has("length_beats"):
		return false
	if has_beat and raw_note.has("duration"):
		return false
	return true


static func _has_note_conflicts(raw_notes: Array) -> bool:
	var notes_by_lane: Dictionary = {}
	for raw_note_value in raw_notes:
		var raw_note: Dictionary = raw_note_value
		var lane := int(raw_note["lane"])
		var uses_seconds := raw_note.has("time")
		var start := snappedf(
			float(raw_note["time"] if uses_seconds else raw_note["beat"]),
			0.001
		)
		var duration := snappedf(
			maxf(
				float(
					raw_note.get(
						"duration" if uses_seconds else "length_beats",
						0.0
					)
				),
				0.0
			),
			0.001
		)
		if not notes_by_lane.has(lane):
			notes_by_lane[lane] = []
		var lane_notes: Array = notes_by_lane[lane]
		lane_notes.append({
			"start": start,
			"end": start + duration,
			"unit": "seconds" if uses_seconds else "beats",
		})

	for lane_value in notes_by_lane.values():
		var lane_notes: Array = lane_value
		lane_notes.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return float(a["start"]) < float(b["start"])
		)
		var previous: Dictionary = {}
		for note_value in lane_notes:
			var note: Dictionary = note_value
			if not previous.is_empty():
				if str(previous["unit"]) != str(note["unit"]):
					return true
				var previous_start := float(previous["start"])
				var previous_end := float(previous["end"])
				var note_start := float(note["start"])
				if is_equal_approx(previous_start, note_start):
					return true
				if previous_end > note_start + 0.0005:
					return true
			previous = note
	return false


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_whole_number(value: Variant) -> bool:
	if not _is_number(value):
		return false
	var numeric_value := float(value)
	return is_equal_approx(numeric_value, float(int(numeric_value)))


func _generate_practice_notes(bpm: float, duration_seconds: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var beat_seconds := 60.0 / maxf(bpm, 1.0)
	var subdivision := 0.5 if difficulty_level >= 7 else 1.0
	var step_seconds := beat_seconds * subdivision
	var lead_in := 2.0 + audio_offset_seconds
	var target_duration := minf(maxf(duration_seconds, 18.0), 28.0)
	var step_count := maxi(24, floori((target_duration - lead_in) / step_seconds))

	for step in range(step_count):
		var lane := (step * 3 + floori(float(step) / float(maxi(key_count, 1)))) % key_count
		result.append({
			"time": lead_in + float(step) * step_seconds,
			"lane": lane,
			"duration": beat_seconds * 1.5 if step > 0 and step % 12 == 0 else 0.0,
		})
		if step > 0 and step % 8 == 0:
			result.append({
				"time": lead_in + float(step) * step_seconds,
				"lane": (lane + floori(float(key_count) / 2.0)) % key_count,
				"duration": 0.0,
			})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	return result
