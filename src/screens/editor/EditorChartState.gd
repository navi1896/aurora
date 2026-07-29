extends RefCounted

class_name EditorChartState

const EDITOR_ID_KEY := "_editor_id"

var notes: Array[Dictionary] = []
var key_count := 4
var duration_seconds := 120.0
var selected_note_ids: Array[int] = []

var _next_note_id := 1


func _init(
	raw_notes: Array = [],
	next_key_count: int = 4,
	next_duration_seconds: float = 120.0,
	next_selected_note_ids: Array[int] = []
) -> void:
	key_count = clampi(next_key_count, 1, 16)
	duration_seconds = maxf(next_duration_seconds, 1.0)
	_assign_notes(raw_notes)
	set_selection(next_selected_note_ids)


func duplicate_state() -> EditorChartState:
	var copy := EditorChartState.new(
		notes,
		key_count,
		duration_seconds,
		selected_note_ids
	)
	copy._next_note_id = _next_note_id
	return copy


func replace_notes(raw_notes: Array) -> void:
	_assign_notes(raw_notes)
	set_selection(selected_note_ids)


func add_note(time: float, lane: int, duration: float = 0.0) -> int:
	var note_id := _allocate_note_id()
	notes.append(
		{
			"time": maxf(time, 0.0),
			"lane": clampi(lane, 0, key_count - 1),
			"duration": maxf(duration, 0.0),
			EDITOR_ID_KEY: note_id,
		}
	)
	_sort_notes()
	return note_id


func remove_note_by_id(note_id: int) -> bool:
	var note_index := find_note_index(note_id)
	if note_index < 0:
		return false
	notes.remove_at(note_index)
	selected_note_ids.erase(note_id)
	return true


func find_note_index(note_id: int) -> int:
	for index in range(notes.size()):
		if int(notes[index].get(EDITOR_ID_KEY, 0)) == note_id:
			return index
	return -1


func get_note_by_id(note_id: int) -> Dictionary:
	var note_index := find_note_index(note_id)
	if note_index < 0:
		return {}
	return notes[note_index].duplicate(true)


func get_note_ids() -> Array[int]:
	var result: Array[int] = []
	for note in notes:
		result.append(int(note.get(EDITOR_ID_KEY, 0)))
	return result


func set_selection(note_ids: Array[int]) -> void:
	selected_note_ids.clear()
	var available_ids: Dictionary = {}
	for note in notes:
		available_ids[int(note.get(EDITOR_ID_KEY, 0))] = true
	for note_id in note_ids:
		if (
			note_id > 0
			and available_ids.has(note_id)
			and note_id not in selected_note_ids
		):
			selected_note_ids.append(note_id)


func export_notes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source_note in notes:
		var note: Dictionary = source_note.duplicate(true)
		note.erase(EDITOR_ID_KEY)
		result.append(note)
	return result


func state_equals(other: EditorChartState) -> bool:
	if other == null:
		return false
	return (
		document_equals(other)
		and selected_note_ids == other.selected_note_ids
	)


func document_equals(other: EditorChartState) -> bool:
	if other == null:
		return false
	return (
		key_count == other.key_count
		and is_equal_approx(duration_seconds, other.duration_seconds)
		and notes == other.notes
	)


func _assign_notes(raw_notes: Array) -> void:
	notes.clear()
	var highest_existing_id := 0
	for raw_note in raw_notes:
		if raw_note is Dictionary:
			highest_existing_id = maxi(
				highest_existing_id,
				int(raw_note.get(EDITOR_ID_KEY, 0))
			)
	_next_note_id = maxi(highest_existing_id + 1, 1)

	var used_ids: Dictionary = {}
	for raw_note in raw_notes:
		if not (raw_note is Dictionary):
			continue
		var note: Dictionary = raw_note.duplicate(true)
		note["time"] = maxf(float(note.get("time", 0.0)), 0.0)
		note["lane"] = clampi(int(note.get("lane", 0)), 0, key_count - 1)
		note["duration"] = maxf(float(note.get("duration", 0.0)), 0.0)

		var note_id := int(note.get(EDITOR_ID_KEY, 0))
		if note_id <= 0 or used_ids.has(note_id):
			note_id = _allocate_note_id()
		else:
			_next_note_id = maxi(_next_note_id, note_id + 1)
		note[EDITOR_ID_KEY] = note_id
		used_ids[note_id] = true
		notes.append(note)
	_sort_notes()


func _allocate_note_id() -> int:
	var note_id := _next_note_id
	_next_note_id += 1
	return note_id


func _sort_notes() -> void:
	notes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_time := float(a.get("time", 0.0))
			var b_time := float(b.get("time", 0.0))
			if not is_equal_approx(a_time, b_time):
				return a_time < b_time
			var a_lane := int(a.get("lane", 0))
			var b_lane := int(b.get("lane", 0))
			if a_lane != b_lane:
				return a_lane < b_lane
			return int(a.get(EDITOR_ID_KEY, 0)) < int(b.get(EDITOR_ID_KEY, 0))
	)
