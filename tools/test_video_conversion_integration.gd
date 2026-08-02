extends SceneTree

const SOURCE_PATH := "res://tools/ffmpeg_matrix_fixtures/01-mp4-h264-aac.mp4"
const TIMEOUT_MSEC := 45000

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var source_absolute := ProjectSettings.globalize_path(SOURCE_PATH)
	var original_hash := FileAccess.get_sha256(source_absolute)
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
	var scene_manager := app.get_node(
		"Managers/SceneManager"
	) as SceneManager
	scene_manager.load_scene("editor")
	await process_frame
	await process_frame
	var editor := scene_manager.current_scene as Editor
	_expect(editor != null, "Editor se abre")
	if editor == null:
		_finish()
		return

	var ffmpeg_path := editor._find_ffmpeg_executable()
	_expect(
		not ffmpeg_path.is_empty()
		and editor._ffmpeg_has_required_capabilities(ffmpeg_path),
		"El FFmpeg incluido posee conversión y filtros de calidad"
	)
	editor._start_video_conversion(source_absolute)
	var output_path := editor.video_conversion_output_path
	var temporary_path := editor.video_conversion_temporary_path
	var progress_path := editor.video_conversion_progress_path
	var ssim_path := editor.video_quality_ssim_path
	var psnr_path := editor.video_quality_psnr_path
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while (
		editor.video_conversion_pid > 0
		and Time.get_ticks_msec() < deadline
	):
		await create_timer(0.02).timeout
	_expect(
		editor.video_conversion_pid <= 0,
		"La conversión, decodificación y comparación visual terminan"
	)
	var source_key := editor._media_source_cache_key(source_absolute)
	var manifest_path := editor._conversion_manifest_path(output_path)
	var manifest: Dictionary = _read_json(manifest_path)
	_expect(
		FileAccess.file_exists(output_path)
		and editor._is_valid_cached_conversion(output_path, source_key),
		"Solo publica una salida reutilizable después de aprobar calidad"
	)
	_expect(
		bool(manifest.get("visual_quality_passed", false))
		and float(manifest.get("visual_quality_ssim", 0.0)) >= 0.90
		and float(manifest.get("visual_quality_psnr_db", 0.0)) >= 25.0
		and int(manifest.get("visual_quality_frames", 0)) >= 10,
		"El manifiesto conserva la evidencia SSIM y PSNR"
	)
	_expect(
		not FileAccess.file_exists(temporary_path)
		and not FileAccess.file_exists(progress_path)
		and not FileAccess.file_exists(ssim_path)
		and not FileAccess.file_exists(psnr_path),
		"No quedan temporales de conversión o de calidad"
	)
	_expect(
		FileAccess.get_sha256(source_absolute) == original_hash,
		"El MP4 original permanece intacto"
	)
	editor._cancel_waveform_extraction(false)
	editor._remove_generated_file(output_path)
	editor._remove_generated_file(manifest_path)
	_finish()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("VIDEO CONVERSION INTEGRATION TESTS PASSED")
		quit(0)
	else:
		push_error(
			"VIDEO CONVERSION INTEGRATION TESTS FAILED: %s"
			% ", ".join(failures)
		)
		quit(1)
