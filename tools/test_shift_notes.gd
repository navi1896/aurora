extends SceneTree

const Store := preload("res://src/screens/editor/EditorProjectStore.gd")

var failures: PackedStringArray = []


func _initialize() -> void:
	var normal_notes := [{"time": 1.0, "lane": 0, "duration": 0.0}]
	var shifts := [
		{"time": 2.0, "lanes": [0, 3], "duration": 0.75},
		{"time": 4.0, "lanes": [1, 2], "duration": 0.0},
	]
	var chart := ChartData.make_chart_document(normal_notes, 4, 0.0, [], [], shifts)
	_expect(chart.version == 5, "El chart con Shift se guarda como versión 5")
	_expect(ChartData.is_valid_chart_document(chart, 4), "Acepta pares Shift de dos carriles")
	_expect(chart.get("shift_notes", []) == shifts, "Conserva tiempos, carriles y holds Shift")

	var duplicate_lane_chart := {
		"version": 5,
		"offset_seconds": 0.0,
		"key_count": 4,
		"notes": normal_notes,
		"shift_notes": [{"time": 2.0, "lanes": [1, 1], "duration": 0.0}],
	}
	_expect(
		not ChartData.is_valid_chart_document(duplicate_lane_chart, 4),
		"Rechaza un Shift que repite el mismo carril"
	)

	var fixture_root := "user://aurora_shift_note_fixture"
	var project_path := fixture_root.path_join("project.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_root))
	var project := {
		"version": Store.PROJECT_VERSION,
		"type": Store.PROJECT_TYPE,
		"package_id": "shift-fixture",
		"package_version": "1.0.0",
		"metadata": {
			"title": "Shift fixture",
			"artist": "Aurora Tests",
			"key_count": 4,
			"difficulty": "NORMAL",
			"difficulty_level": 4,
			"bpm": 120.0,
			"duration_seconds": 8.0,
			"creation_mode": "manual",
		},
		"media": {},
		"chart_path": "chart.json",
	}
	_expect(Store.save_bundle(project_path, project, chart).get("ok", false), "Guarda Shift en el proyecto")
	var loaded := Store.load_bundle(project_path)
	_expect(loaded.get("ok", false), "Reabre proyecto con Shift")
	_expect(loaded.get("shift_notes", []) == shifts, "Recupera Shift sin cambiarlo")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_root.path_join("project.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_root.path_join("chart.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_root))
	if failures.is_empty():
		print("SHIFT NOTES TEST PASSED")
		quit(0)
	else:
		push_error("SHIFT NOTES TEST FAILED:\n" + "\n".join(failures))
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
