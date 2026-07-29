extends SceneTree

const Store = preload("res://src/screens/editor/EditorProjectStore.gd")

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_root := "user://editor_store_tests"
	var project_path := "%s/roundtrip/project.json" % test_root
	var project := _project_document("Prueba segura")
	var notes := [
		{"time": 1.0, "lane": 0, "duration": 0.0},
		{"time": 2.5, "lane": 3, "duration": 1.25},
	]
	var chart := ChartData.make_chart_document(notes, 4)
	var save_result := Store.save_bundle(project_path, project, chart)
	_expect(bool(save_result.get("ok", false)), "Guarda el bundle inicial")

	var load_result := Store.load_bundle(project_path)
	_expect(bool(load_result.get("ok", false)), "Reabre el bundle guardado")
	_expect(load_result.get("notes", []) == notes, "Conserva taps y holds exactamente")
	var saved_project: Dictionary = load_result.get("project", {})
	_expect(int(saved_project.get("version", 0)) == 3, "Guarda el proyecto en formato v3")
	_expect(not saved_project.has("notes"), "project.json no duplica las notas")

	var replacement_notes := [{"time": 9.0, "lane": 2, "duration": 0.0}]
	var replacement_result := Store.save_bundle(
		project_path,
		_project_document("Prueba actualizada"),
		ChartData.make_chart_document(replacement_notes, 4)
	)
	_expect(bool(replacement_result.get("ok", false)), "Reemplaza un bundle existente")
	var replacement_load := Store.load_bundle(project_path)
	_expect(
		replacement_load.get("notes", []) == replacement_notes,
		"Proyecto y chart quedan sincronizados después de reemplazar"
	)
	_expect(
		not FileAccess.file_exists(project_path + Store.TEMP_SUFFIX)
		and not FileAccess.file_exists(project_path + Store.BACKUP_SUFFIX),
		"No deja temporales del proyecto"
	)
	var chart_path := "%s/roundtrip/chart.json" % test_root
	_expect(
		not FileAccess.file_exists(chart_path + Store.TEMP_SUFFIX)
		and not FileAccess.file_exists(chart_path + Store.BACKUP_SUFFIX),
		"No deja temporales del chart"
	)

	var legacy_path := "%s/legacy/project.json" % test_root
	_write_json(legacy_path, {
		"version": 2,
		"type": "aurora_editor_project",
		"metadata": {
			"title": "Antiguo",
			"artist": "Aurora",
			"key_count": 4,
		},
		"media": {},
		"chart_path": "%s/legacy/chart.json" % test_root,
		"notes": [{"time": 4.0, "lane": 1, "duration": 0.0}],
	})
	var legacy_load := Store.load_bundle(legacy_path)
	_expect(bool(legacy_load.get("ok", false)), "Abre un proyecto v2 sin chart")
	_expect(bool(legacy_load.get("needs_migration", false)), "Marca el proyecto v2 para migrar")
	_expect(
		legacy_load.get("notes", []).size() == 1,
		"Recupera las notas embebidas cuando el chart antiguo no existe"
	)

	var authority_path := "%s/authority/project.json" % test_root
	var authority_chart_path := "%s/authority/chart.json" % test_root
	_write_json(authority_path, {
		"version": 2,
		"type": "aurora_editor_project",
		"metadata": {
			"title": "Autoridad",
			"artist": "Aurora",
			"key_count": 4,
		},
		"media": {},
		"chart_path": authority_chart_path,
		"notes": [{"time": 2.0, "lane": 0, "duration": 0.0}],
	})
	_write_json(
		authority_chart_path,
		ChartData.make_chart_document([{"time": 8.0, "lane": 3, "duration": 0.5}], 4)
	)
	var authority_load := Store.load_bundle(authority_path)
	_expect(
		is_equal_approx(float(authority_load.get("notes", [])[0]["time"]), 8.0),
		"chart.json válido tiene autoridad sobre las notas v2 embebidas"
	)

	var collision_directory := "%s/collision" % test_root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(collision_directory))
	var collision := Store.make_new_project_path(test_root, "collision")
	_expect(
		not bool(collision.get("ok", true)) and int(collision.get("error", OK)) == ERR_ALREADY_EXISTS,
		"No sobrescribe silenciosamente otro proyecto con el mismo nombre"
	)

	_finish()


func _project_document(title: String) -> Dictionary:
	return {
		"version": 2,
		"type": "aurora_editor_project",
		"metadata": {
			"title": title,
			"artist": "Aurora",
			"difficulty": "NORMAL",
			"difficulty_level": 4,
			"bpm": 128.0,
			"duration_seconds": 30.0,
			"key_count": 4,
			"creation_mode": "automatic",
			"automatic_density": 1,
		},
		"media": {
			"video_path": "",
			"video_source_path": "",
			"audio_path": "",
		},
		"chart_path": "chart.json",
		"notes": [],
	}


func _write_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "\t"))


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("OK  ", description)
	else:
		failures.append(description)
		push_error("FAIL  %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("EDITOR PROJECT STORE TESTS PASSED")
		quit(0)
	else:
		print("EDITOR PROJECT STORE TESTS FAILED: ", ", ".join(failures))
		quit(1)
