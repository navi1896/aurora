extends SceneTree

const EditorChartStateType := preload(
	"res://src/screens/editor/EditorChartState.gd"
)
const TimelineEditOperationsType := preload(
	"res://src/screens/editor/TimelineEditOperations.gd"
)

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_create_note()
	_test_simple_and_multiple_selection()
	_test_delete_selection()
	_test_move_with_snapping_and_bounds()
	_test_move_rejects_overlap_transactionally()
	_test_hold_resize_and_minimum_duration()
	_test_copy_paste_and_duplicate_ids()
	_test_duplicate_and_overlap_detection()
	_finish()


func _test_create_note() -> void:
	var state = EditorChartStateType.new(
		[{"time": 1.0, "lane": 0, "duration": 0.0}],
		4,
		10.0
	)
	var operations = TimelineEditOperationsType.new()
	var result: Dictionary = operations.create_note(state, 2.12, 1, 0.0, 0.25)
	_expect(
		bool(result.get("ok", false))
		and is_equal_approx(float(result.get("time", 0.0)), 2.0)
		and state.selected_note_ids == [int(result.get("note_id", 0))],
		"Crear una nota aplica snapping y selecciona su ID nuevo"
	)
	var before := state.duplicate_state()
	result = operations.create_note(state, 1.0, 0)
	_expect(
		not bool(result.get("ok", true))
		and str(result.get("error_code", "")) == "duplicate_note"
		and state.state_equals(before),
		"Crear rechaza duplicados sin alterar el chart"
	)


func _test_simple_and_multiple_selection() -> void:
	var state = EditorChartStateType.new(
		[
			{"time": 1.0, "lane": 0, "duration": 0.0},
			{"time": 2.0, "lane": 1, "duration": 0.0},
			{"time": 3.0, "lane": 2, "duration": 0.0},
		],
		4,
		20.0
	)
	var operations = TimelineEditOperationsType.new()
	var ids: Array[int] = state.get_note_ids()

	_expect(
		operations.select_note(state, ids[0])
		and state.selected_note_ids == [ids[0]],
		"La selección simple reemplaza la selección anterior"
	)
	_expect(
		operations.select_note(state, ids[1], true)
		and state.selected_note_ids == [ids[0], ids[1]],
		"La selección aditiva conserva varias notas"
	)
	_expect(
		operations.select_note(state, ids[0], false, true)
		and state.selected_note_ids == [ids[1]],
		"La selección con toggle desmarca una nota"
	)
	var requested: Array[int] = [ids[2], 99999]
	operations.select_notes(state, requested)
	_expect(
		state.selected_note_ids == [ids[2]],
		"La selección múltiple ignora IDs inexistentes"
	)


func _test_delete_selection() -> void:
	var state = EditorChartStateType.new(
		[
			{"time": 1.0, "lane": 0, "duration": 0.0},
			{"time": 2.0, "lane": 1, "duration": 0.0},
			{"time": 3.0, "lane": 2, "duration": 0.0},
		],
		4,
		20.0
	)
	var operations = TimelineEditOperationsType.new()
	var ids: Array[int] = state.get_note_ids()
	var selection: Array[int] = [ids[0], ids[2]]
	operations.select_notes(state, selection)
	var result: Dictionary = operations.delete_selection(state)

	_expect(
		bool(result.get("ok", false))
		and bool(result.get("changed", false))
		and int(result.get("removed_count", 0)) == 2,
		"Borrar elimina toda la selección en una operación"
	)
	_expect(
		state.notes.size() == 1
		and int(
			state.notes[0].get(EditorChartStateType.EDITOR_ID_KEY, 0)
		) == ids[1]
		and state.selected_note_ids.is_empty(),
		"Borrar conserva el ID de la nota restante y limpia la selección"
	)


func _test_move_with_snapping_and_bounds() -> void:
	var state = EditorChartStateType.new(
		[
			{"time": 1.1, "lane": 1, "duration": 0.0},
			{"time": 2.1, "lane": 2, "duration": 1.0},
		],
		4,
		10.0
	)
	var operations = TimelineEditOperationsType.new()
	var ids: Array[int] = state.get_note_ids()
	operations.select_notes(state, ids)

	var result: Dictionary = operations.move_selection(
		state,
		0.32,
		9,
		0.25
	)
	_expect(
		bool(result.get("ok", false))
		and is_equal_approx(float(result.get("delta_time", 0.0)), 0.4)
		and int(result.get("delta_lane", 0)) == 1,
		"Mover aplica snapping al ancla y limita el grupo a los carriles"
	)
	_expect(
		_has_note(state, ids[0], 1.5, 2)
		and _has_note(state, ids[1], 2.5, 3),
		"Mover conserva distancias relativas e IDs estables"
	)

	result = operations.move_selection(state, -99.0, -99)
	_expect(
		bool(result.get("ok", false))
		and _has_note(state, ids[0], 0.0, 0)
		and _has_note(state, ids[1], 1.0, 1),
		"Mover limita tiempo y carriles sin separar la selección"
	)


func _test_move_rejects_overlap_transactionally() -> void:
	var state = EditorChartStateType.new(
		[
			{"time": 1.0, "lane": 0, "duration": 0.0},
			{"time": 2.0, "lane": 0, "duration": 0.0},
		],
		4,
		10.0
	)
	var operations = TimelineEditOperationsType.new()
	var ids: Array[int] = state.get_note_ids()
	operations.select_note(state, ids[1])
	var before = state.duplicate_state()
	var result: Dictionary = operations.move_selection(state, -1.0, 0)

	_expect(
		not bool(result.get("ok", true))
		and str(result.get("error_code", "")) == "duplicate_note",
		"Mover rechaza una nota duplicada en el mismo carril y tiempo"
	)
	_expect(
		state.state_equals(before),
		"Un movimiento rechazado no altera notas, IDs ni selección"
	)


func _test_hold_resize_and_minimum_duration() -> void:
	var state = EditorChartStateType.new(
		[
			{"time": 1.0, "lane": 0, "duration": 1.0},
			{"time": 3.0, "lane": 0, "duration": 0.0},
			{"time": 4.0, "lane": 1, "duration": 0.0},
		],
		4,
		10.0
	)
	var operations = TimelineEditOperationsType.new()
	var ids: Array[int] = state.get_note_ids()

	var result: Dictionary = operations.resize_hold(
		state,
		ids[0],
		0.001,
		0.0,
		0.1
	)
	_expect(
		bool(result.get("ok", false))
		and is_equal_approx(
			float(state.get_note_by_id(ids[0]).get("duration", 0.0)),
			0.1
		),
		"Redimensionar un hold respeta la duración mínima"
	)

	result = operations.resize_hold(state, ids[0], 2.5, 0.25, 0.1)
	_expect(
		not bool(result.get("ok", true))
		and str(result.get("error_code", "")) == "overlap"
		and is_equal_approx(
			float(state.get_note_by_id(ids[0]).get("duration", 0.0)),
			0.1
		),
		"Un hold no puede crecer sobre otra nota y el fallo es transaccional"
	)

	result = operations.resize_hold(state, ids[2], 1.0)
	_expect(
		not bool(result.get("ok", true))
		and str(result.get("error_code", "")) == "not_a_hold",
		"Redimensionar rechaza notas de toque"
	)


func _test_copy_paste_and_duplicate_ids() -> void:
	var state = EditorChartStateType.new(
		[
			{"time": 1.0, "lane": 0, "duration": 0.0},
			{"time": 2.0, "lane": 1, "duration": 0.5},
			{"time": 8.0, "lane": 3, "duration": 0.0},
		],
		4,
		20.0
	)
	var operations = TimelineEditOperationsType.new()
	var original_ids: Array[int] = state.get_note_ids()
	var selection: Array[int] = [original_ids[0], original_ids[1]]
	operations.select_notes(state, selection)

	var copy_result: Dictionary = operations.copy_selection(state)
	var paste_result: Dictionary = operations.paste(state, 5.12, 1, 0.25)
	var pasted_ids: Array[int] = []
	pasted_ids.assign(paste_result.get("pasted_ids", []))
	_expect(
		bool(copy_result.get("ok", false))
		and int(copy_result.get("copied_count", 0)) == 2
		and bool(paste_result.get("ok", false))
		and pasted_ids.size() == 2,
		"Copiar y pegar conserva el grupo completo"
	)
	_expect(
		not _arrays_intersect(original_ids, pasted_ids)
		and state.selected_note_ids == pasted_ids,
		"Pegar genera IDs nuevos y selecciona únicamente las copias"
	)
	_expect(
		_has_note(state, pasted_ids[0], 5.0, 1)
		and _has_note(state, pasted_ids[1], 6.0, 2),
		"Pegar conserva el espaciado, alinea carriles y aplica snapping"
	)
	_expect(
		_is_sorted(state.notes),
		"Las notas quedan ordenadas después de pegar"
	)

	var before_duplicate_ids: Array[int] = state.get_note_ids()
	var duplicate_result: Dictionary = operations.duplicate_selection(
		state,
		3.0,
		-1
	)
	var duplicated_ids: Array[int] = []
	duplicated_ids.assign(duplicate_result.get("pasted_ids", []))
	_expect(
		bool(duplicate_result.get("ok", false))
		and duplicated_ids.size() == 2
		and not _arrays_intersect(before_duplicate_ids, duplicated_ids),
		"Duplicar genera un grupo equivalente con IDs nuevos"
	)

	operations.select_notes(state, selection)
	var before_rejected_paste = state.duplicate_state()
	operations.copy_selection(state)
	var rejected: Dictionary = operations.paste(state, 1.0, 0)
	_expect(
		not bool(rejected.get("ok", true))
		and str(rejected.get("error_code", "")) == "duplicate_note"
		and state.state_equals(before_rejected_paste),
		"Pegar encima del original se rechaza sin alterar el estado"
	)


func _test_duplicate_and_overlap_detection() -> void:
	var operations = TimelineEditOperationsType.new()
	var duplicate_ids: Array[Dictionary] = [
		{
			"time": 1.0,
			"lane": 0,
			"duration": 0.0,
			EditorChartStateType.EDITOR_ID_KEY: 7,
		},
		{
			"time": 2.0,
			"lane": 1,
			"duration": 0.0,
			EditorChartStateType.EDITOR_ID_KEY: 7,
		},
	]
	var result: Dictionary = operations.validate_notes(
		duplicate_ids,
		4,
		10.0
	)
	_expect(
		str(result.get("error_code", "")) == "duplicate_id",
		"La validación detecta IDs internos duplicados"
	)

	var overlaps: Array[Dictionary] = [
		{
			"time": 1.0,
			"lane": 2,
			"duration": 2.0,
			EditorChartStateType.EDITOR_ID_KEY: 1,
		},
		{
			"time": 2.0,
			"lane": 2,
			"duration": 0.0,
			EditorChartStateType.EDITOR_ID_KEY: 2,
		},
	]
	result = operations.validate_notes(overlaps, 4, 10.0)
	_expect(
		str(result.get("error_code", "")) == "overlap",
		"La validación detecta solapamientos dentro de un carril"
	)

	var touching: Array[Dictionary] = [
		{
			"time": 1.0,
			"lane": 2,
			"duration": 1.0,
			EditorChartStateType.EDITOR_ID_KEY: 1,
		},
		{
			"time": 2.0,
			"lane": 2,
			"duration": 0.0,
			EditorChartStateType.EDITOR_ID_KEY: 2,
		},
	]
	result = operations.validate_notes(touching, 4, 10.0)
	_expect(
		bool(result.get("ok", false)),
		"El final de un hold puede coincidir con el inicio de otra nota"
	)


func _has_note(
	state: EditorChartState,
	note_id: int,
	expected_time: float,
	expected_lane: int
) -> bool:
	var note := state.get_note_by_id(note_id)
	return (
		not note.is_empty()
		and absf(float(note.get("time", -1.0)) - expected_time) < 0.0001
		and int(note.get("lane", -1)) == expected_lane
	)


func _arrays_intersect(first: Array[int], second: Array[int]) -> bool:
	for value in first:
		if value in second:
			return true
	return false


func _is_sorted(notes: Array[Dictionary]) -> bool:
	var previous_time := -INF
	var previous_lane := -1
	var previous_id := -1
	for note in notes:
		var note_time := float(note.get("time", 0.0))
		var lane := int(note.get("lane", 0))
		var note_id := int(
			note.get(EditorChartStateType.EDITOR_ID_KEY, 0)
		)
		if note_time < previous_time - 0.0001:
			return false
		if is_equal_approx(note_time, previous_time):
			if lane < previous_lane:
				return false
			if lane == previous_lane and note_id < previous_id:
				return false
		previous_time = note_time
		previous_lane = lane
		previous_id = note_id
	return true


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("TIMELINE EDIT OPERATIONS TESTS PASSED")
		quit(0)
		return
	print(
		"TIMELINE EDIT OPERATIONS TESTS FAILED: %d"
		% failures.size()
	)
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
