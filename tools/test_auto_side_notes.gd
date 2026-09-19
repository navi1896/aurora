extends SceneTree

const Store = preload("res://src/screens/editor/EditorProjectStore.gd")
const Recovery = preload("res://src/screens/editor/EditorRecoveryStore.gd")
const SideTrack = preload("res://src/screens/gameplay/AutoSideTrack.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var normal := [{"time": 1.0, "lane": 0, "duration": 0.0}, {"time": 2.0, "lane": 3, "duration": 0.5}]
	var sides := [{"time": 1.0, "side": 0, "duration": 0.0}, {"time": 3.0, "side": 1, "duration": 1.0}]
	var document := ChartData.make_chart_document(normal, 4, 0.25, sides)
	_expect(ChartData.is_valid_chart_document(document, 4), "Acepta cuatro carriles y laterales independientes")
	_expect(document.version == 3 and document.notes == normal and document.side_notes == sides, "Conserva taps y mantener sin remapear carriles")
	_expect(ChartData.make_chart_document(normal, 4).version == 2, "Conserva compatibilidad con charts antiguos")
	for invalid in [
		[{"time": 0.0, "side": 2}], [{"time": -1.0, "side": 0}],
		[{"time": 0.0, "side": 0.5}], [{"time": INF, "side": 0}],
		[{"time": 0.0, "side": 0, "duration": 2.0}, {"time": 1.0, "side": 0}],
		[{"time": 0.0, "side": 0}, {"time": 0.0, "side": 0}],
		[{"time": 0.0, "beat": 1.0, "side": 0}],
	]:
		var bad := document.duplicate(true)
		bad.side_notes = invalid
		_expect(not ChartData.is_valid_chart_document(bad, 4), "Rechaza laterales inválidos o solapados")
	var project := {"version": 3, "type": Store.PROJECT_TYPE, "metadata": {"key_count": 4}, "media": {}, "chart_path": "chart.json"}
	var path := "user://auto_side_tests/project.json"
	_expect(Store.save_bundle(path, project, document).ok, "Guarda el proyecto con laterales")
	var loaded := Store.load_bundle(path)
	_expect(loaded.get("side_notes", []) == sides, "Reabre sin perder los laterales")
	var chart := ChartData.new()
	chart.chart_path = loaded.get("chart_path", "")
	chart.audio_offset_seconds = 0.1
	var playable := chart.load_notes(120.0, 10.0)
	var automatic := chart.load_side_notes(120.0, 10.0)
	_expect(playable.size() == 2 and automatic.size() == 2, "Las notas automáticas no cuentan como notas jugables")
	_expect(is_equal_approx(automatic[0].time, 1.35), "Aplica el mismo desfase al audio y las notas laterales")
	_expect(is_equal_approx(chart.get_chart_end_time(120.0, 0.0), 4.35), "El fallback de duración incluye mantener lateral")
	_expect(Recovery.save_snapshot("user://auto_side_tests/recovery.json", project, normal, path, sides).ok, "Recuperación guarda los laterales")
	_expect(Recovery.load_snapshot("user://auto_side_tests/recovery.json").get("side_notes", []) == sides, "Recuperación reabre los laterales")
	var track = SideTrack.new()
	track.notes = ChartData.normalize_side_notes(sides)
	track.set_playback_time(10.0, 1.0)
	_expect(track.cursor == 2, "Las notas laterales se resuelven solas")
	track.set_playback_time(0.0, 1.0)
	_expect(track.cursor == 0, "Reiniciar restaura el cursor automático")
	track.free()
	print("AUTO SIDE NOTES %s" % ("PASSED" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: %s" % label)
	else:
		print("PASS: %s" % label)
