extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app_scene := load("res://src/App.tscn") as PackedScene
	_expect(app_scene != null, "App se puede cargar")
	if app_scene == null:
		_finish()
		return
	var app := app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	var scene_manager := app.get_node("Managers/SceneManager") as SceneManager
	scene_manager.load_scene("editor")
	await process_frame
	await process_frame
	var editor := scene_manager.current_scene as Editor
	_expect(editor != null, "Editor se abre")
	if editor == null:
		_finish()
		return

	_expect(
		editor.video_dialog.use_native_dialog and editor.audio_dialog.use_native_dialog,
		"Los selectores multimedia usan el diálogo nativo"
	)
	editor._set_video_conversion_controls_disabled(true)
	_expect(
		not editor.video_select_button.disabled
		and editor.video_select_button.text == AuroraLocale.text("CANCELAR CONVERSIÓN"),
		"Durante una conversión queda disponible la acción Cancelar"
	)
	editor._set_video_conversion_controls_disabled(false)
	_expect(
		editor.video_select_button.text == AuroraLocale.text("ELEGIR VIDEO"),
		"El selector recupera su función después de cancelar"
	)
	_expect(
		editor.VIDEO_CONVERSION_PROFILE.contains("v6")
		and editor._is_untrusted_legacy_video_cache(
			"user://aurora_editor/media/probe_theora_v3_720p30.ogv"
		),
		"El perfil nuevo no reutiliza silenciosamente la caché v3"
	)

	var source_path := "user://aurora_editor/media/cache_probe_source.mp4"
	var output_path := (
		"user://aurora_editor/media/cache_probe_%s.ogv"
		% editor.VIDEO_CONVERSION_PROFILE
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://aurora_editor/media")
	)
	var source_file := FileAccess.open(source_path, FileAccess.WRITE)
	source_file.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6]))
	source_file.close()
	var output_file := FileAccess.open(output_path, FileAccess.WRITE)
	output_file.store_buffer(PackedByteArray([10, 20, 30, 40]))
	output_file.close()
	var source_key := editor._media_source_cache_key(source_path)
	_expect(not source_key.is_empty(), "La fuente obtiene una clave de caché")
	_expect(
		editor._write_conversion_manifest(
			output_path,
			source_path,
			source_key,
			"ffmpeg test sha256=probe",
			{
				"passed": true,
				"average_ssim": 0.97,
				"average_psnr_db": 33.0,
				"frame_samples": 120,
			}
		),
		"Publica un manifiesto de conversión atómico"
	)
	_expect(
		editor._is_valid_cached_conversion(output_path, source_key),
		"Reutiliza solo una conversión con calidad visual aprobada"
	)
	output_file = FileAccess.open(output_path, FileAccess.WRITE)
	output_file.store_buffer(PackedByteArray([10, 20, 30, 40, 50]))
	output_file.close()
	_expect(
		not editor._is_valid_cached_conversion(output_path, source_key),
		"Rechaza una salida modificada después del manifiesto"
	)
	editor._remove_generated_file(source_path)
	editor._remove_generated_file(output_path)
	editor._remove_generated_file(editor._conversion_manifest_path(output_path))
	_finish()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		printerr("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("MEDIA CACHE TESTS PASSED")
		quit(0)
	else:
		printerr("MEDIA CACHE TESTS FAILED: %s" % ", ".join(failures))
		quit(1)
