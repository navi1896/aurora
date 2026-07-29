extends SceneTree

const EditorChartStateType := preload(
	"res://src/screens/editor/EditorChartState.gd"
)
const ChartEditHistoryType := preload(
	"res://src/screens/editor/ChartEditHistory.gd"
)
const TimelineViewportType := preload(
	"res://src/screens/editor/TimelineViewport.gd"
)

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_state_copies_and_ids()
	_test_history_undo_redo_dirty_and_limit()
	_test_timeline_conversions_zoom_and_scroll()
	_test_timeline_lanes_and_snapping()
	_test_timeline_visibility_and_stable_ids()
	_finish()


func _test_state_copies_and_ids() -> void:
	var raw_notes: Array[Dictionary] = [
		{"time": 10.0, "lane": 2, "duration": 0.0},
		{"time": 12.0, "lane": 1, "duration": 1.5},
	]
	var state = EditorChartStateType.new(raw_notes, 4, 120.0)
	var original_ids: Array[int] = state.get_note_ids()
	raw_notes[0]["time"] = 99.0
	_expect(
		is_equal_approx(float(state.notes[0]["time"]), 10.0),
		"EditorChartState copia profundamente las notas de entrada"
	)

	var copy = state.duplicate_state()
	copy.notes[0]["time"] = 3.0
	_expect(
		is_equal_approx(float(state.notes[0]["time"]), 10.0),
		"duplicate_state no comparte diccionarios con el original"
	)
	_expect(
		copy.get_note_ids() == original_ids,
		"duplicate_state conserva los IDs internos"
	)

	var exported: Array[Dictionary] = state.export_notes()
	_expect(
		not exported[0].has(EditorChartStateType.EDITOR_ID_KEY),
		"export_notes excluye los IDs internos"
	)
	exported[0]["time"] = 42.0
	_expect(
		is_equal_approx(float(state.notes[0]["time"]), 10.0),
		"export_notes también entrega copias profundas"
	)

	var existing_id := int(state.notes[0][EditorChartStateType.EDITOR_ID_KEY])
	var added_id: int = state.add_note(5.0, 0)
	_expect(
		added_id != existing_id
		and int(state.notes[1][EditorChartStateType.EDITOR_ID_KEY]) == existing_id,
		"Ordenar notas no cambia sus IDs estables"
	)


func _test_history_undo_redo_dirty_and_limit() -> void:
	var initial = EditorChartStateType.new(
		[{"time": 10.0, "lane": 0, "duration": 0.0}],
		4,
		120.0
	)
	var history = ChartEditHistoryType.new(2)
	history.initialize(initial)
	_expect(not history.is_dirty(), "Un historial inicial comienza limpio")

	var inserted = history.get_current_state()
	inserted.add_note(5.0, 1)
	_expect(history.commit(inserted, "Añadir nota"), "commit acepta un cambio real")
	inserted.notes[0]["time"] = 77.0
	_expect(
		is_equal_approx(float(history.get_current_state().notes[0]["time"]), 5.0),
		"commit conserva una copia profunda del estado"
	)
	_expect(history.is_dirty(), "Editar el chart marca el historial como modificado")

	var undone = history.undo()
	_expect(
		undone.notes.size() == 1
		and is_equal_approx(float(undone.notes[0]["time"]), 10.0),
		"Undo restaura la acción anterior aunque la nota nueva estuviera antes en el tiempo"
	)
	var redone = history.redo()
	_expect(
		redone.notes.size() == 2
		and is_equal_approx(float(redone.notes[0]["time"]), 5.0)
		and is_equal_approx(float(redone.notes[1]["time"]), 10.0),
		"Redo restaura el estado ordenado"
	)

	history.mark_saved()
	_expect(not history.is_dirty(), "mark_saved establece el punto limpio")
	var after_save = history.get_current_state()
	after_save.add_note(20.0, 2)
	history.commit(after_save, "Añadir tercera nota")
	_expect(history.is_dirty(), "Un cambio posterior al guardado vuelve a marcar dirty")
	history.undo()
	_expect(
		not history.is_dirty(),
		"Undo hasta el contenido guardado limpia el indicador dirty"
	)
	history.redo()
	_expect(history.is_dirty(), "Redo vuelve a separar el chart del punto guardado")

	history.undo()
	var replacement = history.get_current_state()
	replacement.add_note(30.0, 3)
	history.commit(replacement, "Rama nueva")
	_expect(not history.can_redo(), "Un commit nuevo elimina la rama de Redo")

	var limited = ChartEditHistoryType.new(2)
	limited.initialize(EditorChartStateType.new())
	for note_time in [1.0, 2.0, 3.0]:
		var next_state = limited.get_current_state()
		next_state.add_note(note_time, 0)
		limited.commit(next_state, "Añadir")
	_expect(limited.get_undo_count() == 2, "El historial respeta su límite")
	limited.undo()
	limited.undo()
	_expect(not limited.can_undo(), "Solo se conservan las operaciones más recientes")
	_expect(
		limited.get_current_state().notes.size() == 1,
		"Descartar historial antiguo no altera el estado actual"
	)


func _test_timeline_conversions_zoom_and_scroll() -> void:
	var viewport = TimelineViewportType.new(120.0, 1000.0, 300.0, 4, 100.0)
	viewport.set_scroll_time(20.0)
	var x := viewport.time_to_x(23.0)
	_expect(
		is_equal_approx(x, 300.0)
		and absf(viewport.x_to_time(x) - 23.0) < 0.001,
		"Las conversiones tiempo-x son reversibles"
	)

	var anchor_time := viewport.x_to_time(500.0)
	viewport.set_zoom(200.0, 500.0)
	_expect(
		absf(viewport.x_to_time(500.0) - anchor_time) < 0.001,
		"El zoom conserva el tiempo situado bajo el ancla"
	)
	viewport.set_scroll_time(999.0)
	_expect(
		is_equal_approx(viewport.scroll_time, viewport.get_max_scroll_time()),
		"El scroll se limita al final de la canción"
	)
	viewport.set_scroll_time(-20.0)
	_expect(is_zero_approx(viewport.scroll_time), "El scroll no admite tiempos negativos")


func _test_timeline_lanes_and_snapping() -> void:
	var viewport = TimelineViewportType.new(120.0, 800.0, 346.0, 4, 80.0)
	viewport.set_header_height(26.0)
	_expect(viewport.y_to_lane(26.0) == 0, "La primera fila corresponde al carril 1")
	_expect(viewport.y_to_lane(346.0) == 3, "La última fila corresponde al último carril")
	_expect(viewport.y_to_lane(10.0) == -1, "El encabezado no se interpreta como carril")
	for lane in range(4):
		_expect(
			viewport.y_to_lane(viewport.lane_to_y(lane)) == lane,
			"lane_to_y y y_to_lane son reversibles para el carril %d" % lane
		)

	for bpm in [40.0, 128.0, 300.0]:
		var step_seconds: float = 60.0 / bpm / 4.0
		var target: float = step_seconds * 7.18
		var expected: float = step_seconds * 7.0
		_expect(
			absf(viewport.snap_time(target, bpm, 4) - expected) < 0.0001,
			"El snapping a cuartos de beat funciona a %.0f BPM" % bpm
		)


func _test_timeline_visibility_and_stable_ids() -> void:
	var state = EditorChartStateType.new(
		[
			{"time": 9.9, "lane": 0, "duration": 0.0},
			{"time": 10.0, "lane": 1, "duration": 0.0},
			{"time": 5.0, "lane": 2, "duration": 6.0},
			{"time": 20.0, "lane": 3, "duration": 2.0},
			{"time": 20.1, "lane": 0, "duration": 0.0},
		],
		4,
		60.0
	)
	var viewport = TimelineViewportType.new(60.0, 1000.0, 300.0, 4, 100.0)
	viewport.set_scroll_time(10.0)
	var visible_ids: Array[int] = viewport.get_visible_note_ids(state.notes)
	_expect(visible_ids.size() == 3, "La visibilidad incluye taps y holds que cruzan el viewport")

	var id_at_9_9 := _find_note_id_at_time(state.notes, 9.9)
	var id_at_10 := _find_note_id_at_time(state.notes, 10.0)
	var crossing_hold_id := _find_note_id_at_time(state.notes, 5.0)
	var end_hold_id := _find_note_id_at_time(state.notes, 20.0)
	var id_at_20_1 := _find_note_id_at_time(state.notes, 20.1)
	_expect(id_at_9_9 not in visible_ids, "Un tap anterior al viewport queda oculto")
	_expect(id_at_10 in visible_ids, "Un tap en el borde inicial es visible")
	_expect(crossing_hold_id in visible_ids, "Un hold iniciado antes que cruza el borde es visible")
	_expect(end_hold_id in visible_ids, "Un hold en el borde final es visible")
	_expect(id_at_20_1 not in visible_ids, "Un tap posterior al viewport queda oculto")

	var reordered: Array[Dictionary] = state.notes.duplicate(true)
	reordered.reverse()
	var reordered_ids: Array[int] = viewport.get_visible_note_ids(reordered)
	visible_ids.sort()
	reordered_ids.sort()
	_expect(
		reordered_ids == visible_ids,
		"Reordenar el array no cambia los IDs de las notas visibles"
	)


func _find_note_id_at_time(notes: Array[Dictionary], time: float) -> int:
	for note in notes:
		if is_equal_approx(float(note.get("time", -1.0)), time):
			return int(note.get(EditorChartStateType.EDITOR_ID_KEY, 0))
	return 0


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("EDITOR FOUNDATIONS TESTS PASSED")
		quit(0)
		return
	print("EDITOR FOUNDATIONS TESTS FAILED: %d" % failures.size())
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
