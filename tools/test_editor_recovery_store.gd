extends SceneTree

const Store := preload("res://src/screens/editor/EditorRecoveryStore.gd")

var failures: Array[String] = []
var recovery_path := "user://recovery_store_test/recovery.json"


func _init() -> void:
	Store.discard_snapshot(recovery_path)
	var project := {
		"version": 3,
		"type": "aurora_editor_project",
		"metadata": {
			"title": "Borrador",
			"artist": "Aurora",
			"key_count": 4,
		},
		"media": {
			"video_path": "",
			"audio_path": "",
		},
		"chart_path": "chart.json",
	}
	var empty_save := Store.save_snapshot(
		recovery_path,
		project,
		[],
		"user://aurora_editor/original/project.json"
	)
	_expect(bool(empty_save.get("ok", false)), "Guarda un borrador aunque todavía no tenga notas")
	_expect(Store.has_valid_snapshot(recovery_path), "El borrador publicado supera la validación")

	var loaded := Store.load_snapshot(recovery_path)
	_expect(bool(loaded.get("ok", false)), "Carga el borrador publicado")
	_expect(
		str(loaded.get("source_project_path", "")).ends_with("original/project.json"),
		"Conserva la ruta del proyecto original sin reemplazarlo"
	)
	_expect((loaded.get("notes", []) as Array).is_empty(), "Conserva un chart vacío")

	var notes: Array[Dictionary] = [
		{"time": 1.0, "lane": 0, "duration": 0.0},
		{"time": 2.0, "lane": 1, "duration": 0.75},
	]
	var second_save := Store.save_snapshot(recovery_path, project, notes, "")
	_expect(bool(second_save.get("ok", false)), "Reemplaza atómicamente el borrador anterior")
	loaded = Store.load_snapshot(recovery_path)
	_expect((loaded.get("notes", []) as Array).size() == 2, "Recupera taps y holds")
	_expect(
		not FileAccess.file_exists(recovery_path + Store.TEMP_SUFFIX)
		and not FileAccess.file_exists(recovery_path + Store.BACKUP_SUFFIX),
		"No deja temporales ni respaldos después de guardar"
	)

	var invalid_notes: Array = [{"time": -1.0, "lane": 0, "duration": 0.0}]
	var rejected := Store.save_snapshot(recovery_path, project, invalid_notes, "")
	_expect(not bool(rejected.get("ok", false)), "Rechaza notas que se perderían al normalizar")
	loaded = Store.load_snapshot(recovery_path)
	_expect((loaded.get("notes", []) as Array).size() == 2, "Un fallo conserva el borrador válido anterior")

	_expect(Store.discard_snapshot(recovery_path) == OK, "Permite descartar la recuperación")
	_expect(not FileAccess.file_exists(recovery_path), "Descartar elimina solo el borrador")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("EDITOR RECOVERY STORE TESTS PASSED")
		quit(0)
	else:
		print("EDITOR RECOVERY STORE TESTS FAILED: ", ", ".join(failures))
		quit(1)
