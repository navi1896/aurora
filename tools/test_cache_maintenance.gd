extends SceneTree

const CACHE_MAINTENANCE := preload(
	"res://src/maintenance/CacheMaintenanceService.gd"
)

var failures := 0


func _init() -> void:
	_check(
		load("res://src/screens/Settings.gd") != null,
		"Configuración compila con el mantenimiento de caché"
	)
	var root := "user://aurora_cache_tests/%d" % Time.get_ticks_usec()
	var editor_root := root.path_join("editor")
	var media_root := editor_root.path_join("media")
	var waveform_root := editor_root.path_join("waveform_cache")
	var recovery_path := editor_root.path_join(".recovery/recovery.json")
	var project_root := editor_root.path_join("safe_project")
	for directory in [
		media_root,
		waveform_root,
		recovery_path.get_base_dir(),
		project_root,
	]:
		_check(
			DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path(directory)
			) in [OK, ERR_ALREADY_EXISTS],
			"Prepara el perfil aislado de mantenimiento"
		)

	var kept_video := media_root.path_join("kept.ogv")
	var kept_manifest := media_root.path_join("kept.manifest.json")
	var orphan_audio := media_root.path_join("orphan.mp3")
	var stale_progress := media_root.path_join("stale.progress")
	var waveform_cache := waveform_root.path_join("source.waveform.json")
	var outside_file := root.path_join("original-never-delete.mp4")
	for file_entry in [
		[kept_video, "video"],
		[kept_manifest, "manifest"],
		[orphan_audio, "orphan"],
		[stale_progress, "progress"],
		[waveform_cache, "waveform"],
		[outside_file, "original"],
	]:
		_write_text(str(file_entry[0]), str(file_entry[1]))
	_write_json(
		project_root.path_join("project.json"),
		{
			"type": "aurora_editor_project",
			"media": {"video_path": kept_video},
		}
	)
	_write_json(
		recovery_path,
		{
			"type": "aurora_editor_recovery",
			"project": {"media": {"video_path": kept_video}},
		}
	)

	var service = CACHE_MAINTENANCE.new()
	var plan: Dictionary = service.build_cleanup_plan(
		editor_root,
		media_root,
		waveform_root,
		recovery_path
	)
	_check(bool(plan.get("ok", false)), "Construye un plan de limpieza válido")
	var planned_paths: Array[String] = []
	for record_value in plan.get("files", []):
		var record: Dictionary = record_value
		planned_paths.append(str(record.get("path", "")))
	_check(
		not _contains_path(planned_paths, kept_video),
		"Protege medios referenciados por proyectos"
	)
	_check(
		not _contains_path(planned_paths, kept_manifest),
		"Protege el manifiesto asociado al medio en uso"
	)
	_check(
		_contains_path(planned_paths, orphan_audio),
		"Detecta medios huérfanos dentro de la caché"
	)
	_check(
		_contains_path(planned_paths, stale_progress),
		"Detecta residuos temporales de conversión"
	)
	_check(
		_contains_path(planned_paths, waveform_cache),
		"La forma de onda regenerable puede limpiarse"
	)
	_check(
		not _contains_path(planned_paths, outside_file),
		"Los originales externos nunca entran al plan"
	)

	var cleanup: Dictionary = service.execute_cleanup_plan(plan)
	_check(bool(cleanup.get("ok", false)), "Ejecuta el plan permitido sin errores")
	_check(FileAccess.file_exists(kept_video), "Conserva el video referenciado")
	_check(FileAccess.file_exists(kept_manifest), "Conserva su manifiesto")
	_check(not FileAccess.file_exists(orphan_audio), "Elimina el medio huérfano")
	_check(not FileAccess.file_exists(stale_progress), "Elimina el progreso obsoleto")
	_check(not FileAccess.file_exists(waveform_cache), "Elimina la envolvente regenerable")
	_check(FileAccess.file_exists(outside_file), "Conserva intacto el archivo original")

	var malicious_plan := {
		"ok": true,
		"allowed_roots": [
			ProjectSettings.globalize_path(media_root),
			ProjectSettings.globalize_path(waveform_root),
		],
		"files": [
			{
				"path": ProjectSettings.globalize_path(outside_file),
				"size_bytes": 8,
			},
		],
	}
	var rejected: Dictionary = service.execute_cleanup_plan(malicious_plan)
	_check(
		not bool(rejected.get("ok", true)),
		"Rechaza rutas manipuladas fuera de las cachés"
	)
	_check(
		FileAccess.file_exists(outside_file),
		"Un plan manipulado tampoco toca el original"
	)

	if failures == 0:
		print("CACHE MAINTENANCE TESTS PASSED")
		quit(0)
	else:
		push_error("CACHE MAINTENANCE TESTS FAILED: %d" % failures)
		quit(1)


func _contains_path(paths: Array[String], candidate: String) -> bool:
	var normalized := ProjectSettings.globalize_path(
		candidate
	).simplify_path().replace("\\", "/")
	return normalized in paths


func _write_json(path: String, value: Variant) -> void:
	_write_text(path, JSON.stringify(value))


func _write_text(path: String, text: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		_check(false, "Puede escribir %s" % path)
		return
	file.store_string(text)
	file.close()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)
