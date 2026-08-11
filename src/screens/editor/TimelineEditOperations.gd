extends RefCounted

class_name TimelineEditOperations

const EditorChartStateType := preload(
	"res://src/screens/editor/EditorChartState.gd"
)

const DEFAULT_MIN_HOLD_DURATION := 0.05
const TIME_EPSILON := 0.0005

var _clipboard_notes: Array[Dictionary] = []


func create_note(
	state: EditorChartState,
	time_seconds: float,
	lane: int,
	duration_seconds: float = 0.0,
	snap_seconds: float = 0.0
) -> Dictionary:
	var readiness := _validate_operation_state(state, false)
	if not bool(readiness.get("ok", false)):
		return readiness
	if (
		not _is_finite_number(time_seconds)
		or not _is_finite_number(duration_seconds)
		or not _is_finite_number(snap_seconds)
		or lane < 0
		or lane >= state.key_count
		or duration_seconds < 0.0
		or snap_seconds < 0.0
	):
		return _error("invalid_note", "La posición de la nota no es válida.")
	var note_time := clampf(time_seconds, 0.0, state.duration_seconds)
	if snap_seconds > TIME_EPSILON:
		note_time = snappedf(note_time, snap_seconds)
	var note_duration := minf(
		duration_seconds,
		maxf(state.duration_seconds - note_time, 0.0)
	)
	var candidate_state := state.duplicate_state()
	var note_id := candidate_state.add_note(note_time, lane, note_duration)
	candidate_state.set_selection([note_id])
	var validation := validate_state(candidate_state)
	if not bool(validation.get("ok", false)):
		return validation
	state.replace_notes(candidate_state.notes)
	state.set_selection([note_id])
	return _success(true, {
		"note_id": note_id,
		"time": note_time,
		"lane": lane,
		"duration": note_duration,
	})


func select_note(
	state: EditorChartState,
	note_id: int,
	additive: bool = false,
	toggle: bool = false
) -> bool:
	if state == null or state.find_note_index(note_id) < 0:
		return false

	var next_selection: Array[int] = []
	if additive or toggle:
		next_selection.assign(state.selected_note_ids)

	if toggle and note_id in next_selection:
		next_selection.erase(note_id)
	elif note_id not in next_selection:
		next_selection.append(note_id)

	state.set_selection(next_selection)
	return true


func select_notes(
	state: EditorChartState,
	note_ids: Array[int],
	replace_selection: bool = true
) -> Array[int]:
	if state == null:
		return []

	var next_selection: Array[int] = []
	if not replace_selection:
		next_selection.assign(state.selected_note_ids)
	for note_id in note_ids:
		if (
			state.find_note_index(note_id) >= 0
			and note_id not in next_selection
		):
			next_selection.append(note_id)
	state.set_selection(next_selection)

	var result: Array[int] = []
	result.assign(state.selected_note_ids)
	return result


func clear_selection(state: EditorChartState) -> void:
	if state != null:
		state.set_selection([])


func delete_selection(state: EditorChartState) -> Dictionary:
	var readiness := _validate_operation_state(state, true)
	if not bool(readiness.get("ok", false)):
		return readiness

	var selected_lookup := _make_id_lookup(state.selected_note_ids)
	var next_notes: Array[Dictionary] = []
	for note in state.notes:
		var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
		if not selected_lookup.has(note_id):
			next_notes.append(note.duplicate(true))

	var removed_ids: Array[int] = []
	removed_ids.assign(state.selected_note_ids)
	var commit_result := _commit_candidate(state, next_notes, [])
	if not bool(commit_result.get("ok", false)):
		return commit_result
	commit_result["removed_ids"] = removed_ids
	commit_result["removed_count"] = removed_ids.size()
	return commit_result


func move_selection(
	state: EditorChartState,
	delta_time_seconds: float,
	delta_lane: int,
	snap_seconds: float = 0.0
) -> Dictionary:
	var readiness := _validate_operation_state(state, true)
	if not bool(readiness.get("ok", false)):
		return readiness
	if not _is_finite_number(delta_time_seconds):
		return _error("invalid_time", "El desplazamiento de tiempo no es finito.")
	if not _is_finite_number(snap_seconds) or snap_seconds < 0.0:
		return _error("invalid_snap", "El intervalo de snapping no es válido.")

	var selected_lookup := _make_id_lookup(state.selected_note_ids)
	var earliest_time := INF
	var latest_end := -INF
	var minimum_lane := state.key_count
	var maximum_lane := -1
	for note in state.notes:
		var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
		if not selected_lookup.has(note_id):
			continue
		var note_time := float(note.get("time", 0.0))
		earliest_time = minf(earliest_time, note_time)
		latest_end = maxf(
			latest_end,
			note_time + float(note.get("duration", 0.0))
		)
		var lane := int(note.get("lane", 0))
		minimum_lane = mini(minimum_lane, lane)
		maximum_lane = maxi(maximum_lane, lane)

	var desired_anchor := earliest_time + delta_time_seconds
	if snap_seconds > TIME_EPSILON:
		desired_anchor = snappedf(desired_anchor, snap_seconds)
	var minimum_time_delta := -earliest_time
	var maximum_time_delta := state.duration_seconds - latest_end
	var actual_time_delta := clampf(
		desired_anchor - earliest_time,
		minimum_time_delta,
		maximum_time_delta
	)
	var actual_lane_delta := clampi(
		delta_lane,
		-minimum_lane,
		state.key_count - 1 - maximum_lane
	)

	if (
		absf(actual_time_delta) <= TIME_EPSILON
		and actual_lane_delta == 0
	):
		return _success(false, {
			"delta_time": 0.0,
			"delta_lane": 0,
		})

	var next_notes: Array[Dictionary] = []
	for source_note in state.notes:
		var note: Dictionary = source_note.duplicate(true)
		var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
		if selected_lookup.has(note_id):
			note["time"] = maxf(
				float(note.get("time", 0.0)) + actual_time_delta,
				0.0
			)
			note["lane"] = int(note.get("lane", 0)) + actual_lane_delta
		next_notes.append(note)

	var next_selection: Array[int] = []
	next_selection.assign(state.selected_note_ids)
	var commit_result := _commit_candidate(
		state,
		next_notes,
		next_selection
	)
	if bool(commit_result.get("ok", false)):
		commit_result["delta_time"] = actual_time_delta
		commit_result["delta_lane"] = actual_lane_delta
	return commit_result


func snap_selection(
	state: EditorChartState,
	snap_seconds: float,
	minimum_duration_seconds: float = DEFAULT_MIN_HOLD_DURATION
) -> Dictionary:
	var readiness := _validate_operation_state(state, true)
	if not bool(readiness.get("ok", false)):
		return readiness
	if (
		not _is_finite_number(snap_seconds)
		or not _is_finite_number(minimum_duration_seconds)
		or snap_seconds <= TIME_EPSILON
		or minimum_duration_seconds <= 0.0
	):
		return _error(
			"invalid_snap",
			"El intervalo de ajuste no es válido."
		)

	var selected_lookup := _make_id_lookup(state.selected_note_ids)
	var next_notes: Array[Dictionary] = []
	var snapped_count := 0
	for source in state.notes:
		var note: Dictionary = source.duplicate(true)
		var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
		if selected_lookup.has(note_id):
			var source_time := float(note.get("time", 0.0))
			var source_duration := float(note.get("duration", 0.0))
			var next_time := clampf(
				snappedf(source_time, snap_seconds),
				0.0,
				state.duration_seconds
			)
			if source_duration > TIME_EPSILON:
				if state.duration_seconds + TIME_EPSILON < minimum_duration_seconds:
					return _error(
						"duration_out_of_bounds",
						"El chart es demasiado corto para ajustar una nota sostenida.",
						{"note_id": note_id}
					)
				next_time = minf(
					next_time,
					state.duration_seconds - minimum_duration_seconds
				)
				var source_end := source_time + source_duration
				var next_end := clampf(
					snappedf(source_end, snap_seconds),
					0.0,
					state.duration_seconds
				)
				if next_end < next_time + minimum_duration_seconds:
					next_end = minf(
						state.duration_seconds,
						next_time + maxf(minimum_duration_seconds, snap_seconds)
					)
				note["duration"] = next_end - next_time
			note["time"] = next_time
			if (
				absf(next_time - source_time) > TIME_EPSILON
				or absf(float(note.get("duration", 0.0)) - source_duration) > TIME_EPSILON
			):
				snapped_count += 1
		next_notes.append(note)

	var next_selection: Array[int] = []
	next_selection.assign(state.selected_note_ids)
	var commit_result := _commit_candidate(
		state,
		next_notes,
		next_selection
	)
	if bool(commit_result.get("ok", false)):
		commit_result["snapped_count"] = snapped_count
	return commit_result


func resize_hold(
	state: EditorChartState,
	note_id: int,
	new_duration_seconds: float,
	snap_seconds: float = 0.0,
	minimum_duration_seconds: float = DEFAULT_MIN_HOLD_DURATION
) -> Dictionary:
	var readiness := _validate_operation_state(state, false)
	if not bool(readiness.get("ok", false)):
		return readiness
	if state.find_note_index(note_id) < 0:
		return _error("note_not_found", "La nota sostenida no existe.")
	if (
		not _is_finite_number(new_duration_seconds)
		or not _is_finite_number(snap_seconds)
		or not _is_finite_number(minimum_duration_seconds)
		or snap_seconds < 0.0
		or minimum_duration_seconds <= 0.0
	):
		return _error(
			"invalid_duration",
			"La duración o el intervalo de snapping no es válido."
		)

	var source_note := state.get_note_by_id(note_id)
	var source_duration := float(source_note.get("duration", 0.0))
	if source_duration <= TIME_EPSILON:
		return _error(
			"not_a_hold",
			"Solo las notas sostenidas se pueden redimensionar."
		)

	var start_time := float(source_note.get("time", 0.0))
	var available_duration := state.duration_seconds - start_time
	if available_duration + TIME_EPSILON < minimum_duration_seconds:
		return _error(
			"duration_out_of_bounds",
			"No queda espacio suficiente para la duración mínima."
		)

	var desired_end := start_time + maxf(
		new_duration_seconds,
		minimum_duration_seconds
	)
	if snap_seconds > TIME_EPSILON:
		desired_end = snappedf(desired_end, snap_seconds)
	var next_duration := clampf(
		desired_end - start_time,
		minimum_duration_seconds,
		available_duration
	)
	if absf(next_duration - source_duration) <= TIME_EPSILON:
		return _success(false, {"duration": source_duration})

	var next_notes: Array[Dictionary] = []
	for source in state.notes:
		var note: Dictionary = source.duplicate(true)
		if int(note.get(EditorChartState.EDITOR_ID_KEY, 0)) == note_id:
			note["duration"] = next_duration
		next_notes.append(note)

	var next_selection: Array[int] = []
	next_selection.assign(state.selected_note_ids)
	var commit_result := _commit_candidate(
		state,
		next_notes,
		next_selection
	)
	if bool(commit_result.get("ok", false)):
		commit_result["duration"] = next_duration
	return commit_result


func resize_selected_holds(
	state: EditorChartState,
	duration_delta_seconds: float,
	snap_seconds: float = 0.0,
	minimum_duration_seconds: float = DEFAULT_MIN_HOLD_DURATION
) -> Dictionary:
	var readiness := _validate_operation_state(state, true)
	if not bool(readiness.get("ok", false)):
		return readiness
	if (
		not _is_finite_number(duration_delta_seconds)
		or not _is_finite_number(snap_seconds)
		or not _is_finite_number(minimum_duration_seconds)
		or snap_seconds < 0.0
		or minimum_duration_seconds <= 0.0
	):
		return _error(
			"invalid_duration",
			"La duración o el intervalo de snapping no es válido."
		)

	var selected_lookup := _make_id_lookup(state.selected_note_ids)
	var next_notes: Array[Dictionary] = []
	for source in state.notes:
		var note: Dictionary = source.duplicate(true)
		var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
		if selected_lookup.has(note_id):
			var source_duration := float(note.get("duration", 0.0))
			if source_duration <= TIME_EPSILON:
				return _error(
					"selection_contains_tap",
					"La selección contiene una nota que no es sostenida.",
					{"note_id": note_id}
				)
			var start_time := float(note.get("time", 0.0))
			var available_duration := state.duration_seconds - start_time
			if available_duration + TIME_EPSILON < minimum_duration_seconds:
				return _error(
					"duration_out_of_bounds",
					"No queda espacio suficiente para la duración mínima.",
					{"note_id": note_id}
				)
			var desired_end := start_time + maxf(
				source_duration + duration_delta_seconds,
				minimum_duration_seconds
			)
			if snap_seconds > TIME_EPSILON:
				desired_end = snappedf(desired_end, snap_seconds)
			note["duration"] = clampf(
				desired_end - start_time,
				minimum_duration_seconds,
				available_duration
			)
		next_notes.append(note)

	var next_selection: Array[int] = []
	next_selection.assign(state.selected_note_ids)
	return _commit_candidate(state, next_notes, next_selection)


func copy_selection(state: EditorChartState) -> Dictionary:
	var readiness := _validate_operation_state(state, true)
	if not bool(readiness.get("ok", false)):
		return readiness

	var selected_lookup := _make_id_lookup(state.selected_note_ids)
	_clipboard_notes.clear()
	for note in state.notes:
		var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
		if selected_lookup.has(note_id):
			_clipboard_notes.append(note.duplicate(true))
	return _success(false, {"copied_count": _clipboard_notes.size()})


func clear_clipboard() -> void:
	_clipboard_notes.clear()


func has_clipboard() -> bool:
	return not _clipboard_notes.is_empty()


func get_clipboard_notes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for note in _clipboard_notes:
		result.append(note.duplicate(true))
	return result


func paste(
	state: EditorChartState,
	target_time_seconds: float,
	target_lane: int = -1,
	snap_seconds: float = 0.0
) -> Dictionary:
	if _clipboard_notes.is_empty():
		return _error("empty_clipboard", "No hay notas copiadas.")
	return _paste_notes(
		state,
		_clipboard_notes,
		target_time_seconds,
		target_lane,
		snap_seconds
	)


func duplicate_selection(
	state: EditorChartState,
	time_offset_seconds: float,
	lane_offset: int = 0,
	snap_seconds: float = 0.0
) -> Dictionary:
	var readiness := _validate_operation_state(state, true)
	if not bool(readiness.get("ok", false)):
		return readiness
	if not _is_finite_number(time_offset_seconds):
		return _error("invalid_time", "El desplazamiento de tiempo no es finito.")

	var selected_lookup := _make_id_lookup(state.selected_note_ids)
	var source_notes: Array[Dictionary] = []
	var anchor_time := INF
	var anchor_lane := state.key_count
	for note in state.notes:
		var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
		if not selected_lookup.has(note_id):
			continue
		source_notes.append(note.duplicate(true))
		anchor_time = minf(anchor_time, float(note.get("time", 0.0)))
		anchor_lane = mini(anchor_lane, int(note.get("lane", 0)))

	return _paste_notes(
		state,
		source_notes,
		anchor_time + time_offset_seconds,
		anchor_lane + lane_offset,
		snap_seconds
	)


func validate_state(state: EditorChartState) -> Dictionary:
	if state == null:
		return _error("missing_state", "No hay un estado de chart.")
	return validate_notes(
		state.notes,
		state.key_count,
		state.duration_seconds,
		true
	)


func validate_notes(
	raw_notes: Array,
	key_count: int,
	duration_seconds: float,
	require_stable_ids: bool = true
) -> Dictionary:
	var safe_key_count := clampi(key_count, 1, 16)
	if not _is_finite_number(duration_seconds) or duration_seconds < 1.0:
		return _error(
			"invalid_chart_duration",
			"La duración del chart no es válida."
		)

	var used_ids: Dictionary = {}
	var notes_by_lane: Dictionary = {}
	for raw_note_value in raw_notes:
		if not (raw_note_value is Dictionary):
			return _error("invalid_note", "El chart contiene una nota inválida.")
		var note: Dictionary = raw_note_value

		var note_id := int(note.get(EditorChartState.EDITOR_ID_KEY, 0))
		if require_stable_ids:
			if note_id <= 0:
				return _error(
					"missing_stable_id",
					"Una nota no tiene un ID interno estable."
				)
			if used_ids.has(note_id):
				return _error(
					"duplicate_id",
					"Dos notas comparten el mismo ID interno.",
					{"conflict_ids": [note_id, note_id]}
				)
			used_ids[note_id] = true

		var lane_value: Variant = note.get("lane", null)
		if not (lane_value is int):
			return _error(
				"invalid_lane",
				"El carril de una nota no es un entero.",
				{"note_id": note_id}
			)
		var lane := int(lane_value)
		if lane < 0 or lane >= safe_key_count:
			return _error(
				"lane_out_of_bounds",
				"Una nota está fuera de los carriles disponibles.",
				{"note_id": note_id}
			)

		var time_value: Variant = note.get("time", null)
		var duration_value: Variant = note.get("duration", 0.0)
		if (
			not _is_finite_number(time_value)
			or not _is_finite_number(duration_value)
		):
			return _error(
				"invalid_note_time",
				"El tiempo o la duración de una nota no es finito.",
				{"note_id": note_id}
			)
		var note_time := float(time_value)
		var note_duration := float(duration_value)
		if note_time < -TIME_EPSILON or note_duration < -TIME_EPSILON:
			return _error(
				"negative_note_time",
				"Una nota tiene tiempo o duración negativa.",
				{"note_id": note_id}
			)
		if note_time + note_duration > duration_seconds + TIME_EPSILON:
			return _error(
				"note_out_of_bounds",
				"Una nota termina después del final del chart.",
				{"note_id": note_id}
			)

		if not notes_by_lane.has(lane):
			notes_by_lane[lane] = []
		var lane_notes: Array = notes_by_lane[lane]
		lane_notes.append({
			"id": note_id,
			"start": maxf(note_time, 0.0),
			"end": maxf(note_time, 0.0) + maxf(note_duration, 0.0),
		})

	for lane_value in notes_by_lane.values():
		var lane_notes: Array = lane_value
		lane_notes.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				var a_start := float(a.get("start", 0.0))
				var b_start := float(b.get("start", 0.0))
				if not is_equal_approx(a_start, b_start):
					return a_start < b_start
				return float(a.get("end", 0.0)) > float(b.get("end", 0.0))
		)
		var previous: Dictionary = {}
		for lane_note_value in lane_notes:
			var lane_note: Dictionary = lane_note_value
			if not previous.is_empty():
				var previous_start := float(previous.get("start", 0.0))
				var previous_end := float(previous.get("end", previous_start))
				var note_start := float(lane_note.get("start", 0.0))
				var conflict_ids := [
					int(previous.get("id", 0)),
					int(lane_note.get("id", 0)),
				]
				if absf(previous_start - note_start) <= TIME_EPSILON:
					return _error(
						"duplicate_note",
						"Hay dos notas en el mismo carril y tiempo.",
						{"conflict_ids": conflict_ids}
					)
				if previous_end > note_start + TIME_EPSILON:
					return _error(
						"overlap",
						"Dos notas se solapan en el mismo carril.",
						{"conflict_ids": conflict_ids}
					)
			previous = lane_note

	return _success(false)


func _paste_notes(
	state: EditorChartState,
	source_notes: Array[Dictionary],
	target_time_seconds: float,
	target_lane: int,
	snap_seconds: float
) -> Dictionary:
	var readiness := _validate_operation_state(state, false)
	if not bool(readiness.get("ok", false)):
		return readiness
	if source_notes.is_empty():
		return _error("empty_clipboard", "No hay notas para pegar.")
	if (
		not _is_finite_number(target_time_seconds)
		or not _is_finite_number(snap_seconds)
		or snap_seconds < 0.0
	):
		return _error(
			"invalid_paste_target",
			"El destino o el snapping de pegado no es válido."
		)

	var source_anchor_time := INF
	var source_latest_end := -INF
	var source_minimum_lane := state.key_count
	var source_maximum_lane := -1
	for note in source_notes:
		var note_time := float(note.get("time", 0.0))
		source_anchor_time = minf(source_anchor_time, note_time)
		source_latest_end = maxf(
			source_latest_end,
			note_time + float(note.get("duration", 0.0))
		)
		source_minimum_lane = mini(
			source_minimum_lane,
			int(note.get("lane", 0))
		)
		source_maximum_lane = maxi(
			source_maximum_lane,
			int(note.get("lane", 0))
		)

	var source_span := source_latest_end - source_anchor_time
	if source_span > state.duration_seconds + TIME_EPSILON:
		return _error(
			"clipboard_too_long",
			"Las notas copiadas no caben dentro del chart."
		)

	var target_anchor := target_time_seconds
	if snap_seconds > TIME_EPSILON:
		target_anchor = snappedf(target_anchor, snap_seconds)
	target_anchor = clampf(
		target_anchor,
		0.0,
		maxf(state.duration_seconds - source_span, 0.0)
	)
	var time_delta := target_anchor - source_anchor_time

	var lane_delta := 0
	if target_lane >= 0:
		lane_delta = clampi(
			target_lane - source_minimum_lane,
			-source_minimum_lane,
			state.key_count - 1 - source_maximum_lane
		)

	var existing_ids := _make_id_lookup(state.get_note_ids())
	var candidate_notes: Array[Dictionary] = []
	for note in state.notes:
		candidate_notes.append(note.duplicate(true))
	for source in source_notes:
		var pasted_note: Dictionary = source.duplicate(true)
		pasted_note.erase(EditorChartState.EDITOR_ID_KEY)
		pasted_note["time"] = (
			float(pasted_note.get("time", 0.0)) + time_delta
		)
		pasted_note["lane"] = (
			int(pasted_note.get("lane", 0)) + lane_delta
		)
		candidate_notes.append(pasted_note)

	var candidate_state: EditorChartState = EditorChartStateType.new(
		candidate_notes,
		state.key_count,
		state.duration_seconds
	)
	var validation := validate_state(candidate_state)
	if not bool(validation.get("ok", false)):
		return validation

	var pasted_ids: Array[int] = []
	for note_id in candidate_state.get_note_ids():
		if not existing_ids.has(note_id):
			pasted_ids.append(note_id)
	candidate_state.set_selection(pasted_ids)

	state.replace_notes(candidate_state.notes)
	state.set_selection(pasted_ids)
	return _success(true, {
		"pasted_ids": pasted_ids,
		"pasted_count": pasted_ids.size(),
		"target_time": target_anchor,
		"lane_delta": lane_delta,
	})


func _validate_operation_state(
	state: EditorChartState,
	require_selection: bool
) -> Dictionary:
	if state == null:
		return _error("missing_state", "No hay un estado de chart.")
	var validation := validate_state(state)
	if not bool(validation.get("ok", false)):
		return validation
	if require_selection and state.selected_note_ids.is_empty():
		return _error("empty_selection", "No hay notas seleccionadas.")
	return _success(false)


func _commit_candidate(
	state: EditorChartState,
	raw_notes: Array[Dictionary],
	next_selection: Array[int]
) -> Dictionary:
	var candidate_state: EditorChartState = EditorChartStateType.new(
		raw_notes,
		state.key_count,
		state.duration_seconds,
		next_selection
	)
	var validation := validate_state(candidate_state)
	if not bool(validation.get("ok", false)):
		return validation
	if state.document_equals(candidate_state):
		state.set_selection(next_selection)
		return _success(false)
	state.replace_notes(candidate_state.notes)
	state.set_selection(next_selection)
	return _success(true)


func _make_id_lookup(note_ids: Array[int]) -> Dictionary:
	var result: Dictionary = {}
	for note_id in note_ids:
		result[note_id] = true
	return result


func _success(
	changed: bool,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"ok": true,
		"changed": changed,
		"error_code": "",
		"reason": "",
	}
	result.merge(extra, true)
	return result


func _error(
	error_code: String,
	reason: String,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"ok": false,
		"changed": false,
		"error_code": error_code,
		"reason": reason,
	}
	result.merge(extra, true)
	return result


func _is_finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var numeric_value := float(value)
	return not is_nan(numeric_value) and not is_inf(numeric_value)
