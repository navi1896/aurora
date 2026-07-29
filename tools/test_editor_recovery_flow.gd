extends SceneTree

const Store := preload("res://src/screens/editor/EditorRecoveryStore.gd")
const RECOVERY_PATH := "user://aurora_editor/.recovery/recovery.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Store.discard_snapshot(RECOVERY_PATH)
	var project := {
		"version": 3,
		"type": "aurora_editor_project",
		"metadata": {
			"title": "Nivel recuperado",
			"artist": "Prueba",
			"difficulty": "NORMAL",
			"difficulty_level": 5,
			"bpm": 120.0,
			"duration_seconds": 30.0,
			"key_count": 4,
			"creation_mode": "manual",
			"automatic_density": 1,
		},
		"media": {
			"video_path": "",
			"video_source_path": "",
			"audio_path": "",
		},
		"chart_path": "chart.json",
	}
	var notes: Array[Dictionary] = [
		{"time": 1.0, "lane": 0, "duration": 0.0},
		{"time": 2.0, "lane": 2, "duration": 1.0},
	]
	var save_result := Store.save_snapshot(
		RECOVERY_PATH,
		project,
		notes,
		"user://aurora_editor/original/project.json"
	)
	_expect(bool(save_result.get("ok", false)), "Prepara un borrador antes de abrir el editor")

	var app_scene := load("res://src/App.tscn") as PackedScene
	var app := app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	var scene_manager := app.get_node("Managers/SceneManager") as SceneManager
	scene_manager.load_scene("editor")
	await process_frame
	await process_frame
	var editor = scene_manager.current_scene
	_expect(editor != null and editor.name == "Editor", "Editor abre con recuperación disponible")
	if editor != null:
		_expect(editor.title_edit.text == "Nivel recuperado", "Restaura los metadatos del borrador")
		_expect(editor.notes.size() == 2, "Restaura taps y holds del borrador")
		_expect(
			editor.current_project_path.ends_with("original/project.json"),
			"Conserva el destino original para el siguiente guardado"
		)
		_expect(editor._is_editor_dirty(), "El borrador recuperado sigue marcado sin guardar")
		editor._mark_editor_saved()
		_expect(
			not FileAccess.file_exists(RECOVERY_PATH),
			"Confirmar un guardado elimina el borrador recuperado"
		)
	Store.discard_snapshot(RECOVERY_PATH)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("EDITOR RECOVERY FLOW TESTS PASSED")
		quit(0)
	else:
		print("EDITOR RECOVERY FLOW TESTS FAILED: ", ", ".join(failures))
		quit(1)
