extends SceneTree

const TEST_ROOT := (
	"user://aurora_waveform_integration_tests"
)
const SOURCE_PATH := TEST_ROOT + "/source.wav"
const INVALID_SOURCE_PATH := TEST_ROOT + "/invalid.wav"
const CHART_PATH := TEST_ROOT + "/chart.json"
const PROJECT_PATH := TEST_ROOT + "/project.json"

var failures: PackedStringArray = []
var app: Node
var editor: Editor
var source_key := ""
var invalid_source_key := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_reset_test_root()
	_create_fixture()
	var original_hash := FileAccess.get_sha256(SOURCE_PATH)

	var app_scene := load("res://src/App.tscn") as PackedScene
	_expect(app_scene != null, "App se puede cargar")
	if app_scene == null:
		_finish()
		return
	app = app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	var scene_manager := app.get_node(
		"Managers/SceneManager"
	) as SceneManager
	var game_manager := app.get_node(
		"Managers/GameManager"
	) as GameManager
	game_manager.request_editor_project(PROJECT_PATH)
	scene_manager.load_scene("editor")
	await process_frame
	await process_frame
	editor = scene_manager.current_scene as Editor
	_expect(editor != null, "El editor se abre")
	if editor == null:
		_finish()
		return

	source_key = editor._media_source_cache_key(SOURCE_PATH)
	var ready := await _wait_for_waveform(15.0)
	_test_ready_state_and_controls(ready)
	_test_cache_hit()
	_test_timeline_sync_and_large_chart()
	await _test_cancellation()
	await _test_failed_extraction()
	_expect(
		FileAccess.get_sha256(SOURCE_PATH)
		== original_hash,
		"La extracción nunca modifica el audio original"
	)
	_expect(
		_cache_has_no_temporary_artifacts(),
		"No quedan PCM temporales ni artefactos atómicos"
	)
	_finish()


func _test_ready_state_and_controls(
	ready: bool
) -> void:
	_expect(
		ready
		and editor.waveform_status_label.text
		== AuroraLocale.text("LISTA")
		and editor.timeline.is_waveform_available(),
		"La extracción asíncrona termina únicamente en estado LISTA con datos válidos"
	)
	_expect(
		editor.timeline.get_waveform_bucket_count()
		> 0
		and editor.timeline.get_waveform_bucket_count()
		<= 8192,
		"La forma de onda respeta el límite de 8192 bloques"
	)
	_expect(
		editor.waveform_toggle_button.focus_mode
		== Control.FOCUS_ALL
		and editor.waveform_toggle_button.toggle_mode,
		"El control de visibilidad acepta foco de teclado y mando"
	)
	editor.waveform_toggle_button.set_pressed_no_signal(
		false
	)
	editor._on_waveform_visibility_toggled(false)
	_expect(
		not editor.timeline.waveform_visible
		and editor.timeline.is_waveform_available(),
		"Ocultar la forma de onda conserva la caché preparada"
	)
	editor.waveform_toggle_button.set_pressed_no_signal(
		true
	)
	editor._on_waveform_visibility_toggled(true)


func _test_cache_hit() -> void:
	var cache_path: String = (
		editor.waveform_envelope_model
		.get_cache_path_for_source(source_key)
	)
	_expect(
		FileAccess.file_exists(cache_path),
		"La envolvente se guarda por la huella del medio"
	)
	editor._request_waveform_for_current_media()
	_expect(
		editor.waveform_process_id <= 0
		and editor.timeline.is_waveform_available()
		and editor.waveform_status_label.text
		== AuroraLocale.text("LISTA"),
		"Una segunda solicitud reutiliza la caché sin ejecutar FFmpeg"
	)


func _test_timeline_sync_and_large_chart() -> void:
	var timeline := ChartTimeline.new()
	timeline.name = "WaveformPerformanceTimeline"
	timeline.size = Vector2(1200.0, 300.0)
	root.add_child(timeline)
	timeline.set_waveform(
		editor.timeline.waveform_envelope
	)
	var many_notes: Array[Dictionary] = []
	many_notes.resize(50000)
	for index in range(many_notes.size()):
		many_notes[index] = {
			"time": float(index) * 0.07,
			"lane": index % 4,
			"duration": 0.0,
			"_editor_id": index + 1,
		}
	var started_usec := Time.get_ticks_usec()
	timeline.set_chart(
		many_notes,
		3600.0,
		128.0,
		4
	)
	timeline.set_zoom(160.0)
	timeline.set_scroll_time(1.0)
	timeline.set_playhead(2.0)
	var segments := (
		timeline._get_visible_waveform_segments()
	)
	var elapsed_msec := (
		float(Time.get_ticks_usec() - started_usec)
		/ 1000.0
	)
	var synchronized := not segments.is_empty()
	if synchronized:
		var first: Dictionary = segments[0]
		synchronized = is_equal_approx(
			float(first["x"]),
			timeline.viewport_model.time_to_x(
				float(first["time"])
			)
		)
	_expect(
		synchronized
		and is_equal_approx(
			timeline.viewport_model.time_to_x(
				timeline.current_time
			),
			timeline.viewport_model.time_to_x(2.0)
		),
		"Onda y playhead comparten zoom, desplazamiento y escala temporal"
	)
	_expect(
		segments.size() <= 2048
		and elapsed_msec < 3000.0,
		"El dibujo visible queda acotado y el timeline acepta 50 mil notas"
	)
	timeline.queue_free()

	var model := WaveformEnvelopeModel.new(
		TEST_ROOT + "/model_cache"
	)
	var pcm := PackedFloat32Array()
	pcm.resize(9000)
	for index in range(pcm.size()):
		pcm[index] = sin(float(index) * 0.01)
	var capped := model.build_envelope(
		"bucket-cap",
		pcm,
		1,
		9000,
		1000
	)
	_expect(
		int(capped.get("bucket_count", 0))
		== 8192,
		"El modelo recorta solicitudes superiores a 8192 bloques"
	)


func _test_cancellation() -> void:
	editor.waveform_envelope_model.invalidate_source(
		source_key
	)
	editor._request_waveform_for_current_media()
	var temporary_path := editor.waveform_temporary_path
	var extraction_started := (
		editor.waveform_process_id > 0
	)
	editor._cancel_waveform_extraction(true)
	await process_frame
	_expect(
		extraction_started
		and editor.waveform_process_id <= 0
		and not editor.timeline.is_waveform_available()
		and editor.waveform_status_label.text
		== AuroraLocale.text("NO DISPONIBLE")
		and (
			temporary_path.is_empty()
			or not FileAccess.file_exists(
				temporary_path
			)
		),
		"Cambiar de medio o salir cancela FFmpeg y elimina su temporal"
	)
	editor._request_waveform_for_current_media()
	_expect(
		await _wait_for_waveform(15.0),
		"Después de cancelar se puede preparar la onda nuevamente"
	)


func _test_failed_extraction() -> void:
	var invalid_file := FileAccess.open(
		INVALID_SOURCE_PATH,
		FileAccess.WRITE
	)
	invalid_file.store_string("not audio")
	invalid_file.close()
	invalid_source_key = editor._media_source_cache_key(
		INVALID_SOURCE_PATH
	)
	editor._start_waveform_extraction(
		INVALID_SOURCE_PATH
	)
	var deadline := Time.get_ticks_msec() + 10000
	while (
		editor.waveform_process_id > 0
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	_expect(
		editor.waveform_process_id <= 0
		and not editor.timeline.is_waveform_available()
		and editor.waveform_status_label.text
		== AuroraLocale.text("NO DISPONIBLE"),
		"Una extracción fallida nunca muestra LISTA ni datos anteriores"
	)


func _wait_for_waveform(
	timeout_seconds: float
) -> bool:
	var deadline := (
		Time.get_ticks_msec()
		+ int(timeout_seconds * 1000.0)
	)
	while (
		editor != null
		and editor.waveform_process_id > 0
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	return (
		editor != null
		and editor.waveform_process_id <= 0
		and editor.timeline.is_waveform_available()
		and editor.waveform_status_label.text
		== AuroraLocale.text("LISTA")
	)


func _cache_has_no_temporary_artifacts() -> bool:
	var cache_directory := DirAccess.open(
		WaveformEnvelopeModel.DEFAULT_CACHE_DIRECTORY
	)
	if cache_directory == null:
		return true
	cache_directory.list_dir_begin()
	var file_name := cache_directory.get_next()
	while not file_name.is_empty():
		if (
			file_name.ends_with(".tmp")
			or file_name.contains(".waveform.f32")
			or file_name.contains(".tmp.")
			or file_name.ends_with(".bak")
		):
			cache_directory.list_dir_end()
			return false
		file_name = cache_directory.get_next()
	cache_directory.list_dir_end()
	return true


func _create_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEST_ROOT)
	)
	_write_bytes(SOURCE_PATH, _make_wav_bytes(6.0))
	var chart_document := ChartData.make_chart_document(
		[
			{
				"time": 1.0,
				"lane": 0,
				"duration": 0.0,
			},
			{
				"time": 2.0,
				"lane": 3,
				"duration": 0.5,
			},
		],
		4
	)
	_write_text(
		CHART_PATH,
		JSON.stringify(chart_document)
	)
	_write_text(
		PROJECT_PATH,
		JSON.stringify({
			"version": 3,
			"type": "aurora_editor_project",
			"metadata": {
				"title": "Waveform Integration",
				"artist": "Aurora Tests",
				"bpm": 128.0,
				"duration_seconds": 6.0,
				"key_count": 4,
				"difficulty": "NORMAL",
				"difficulty_level": 4,
				"automatic_density": 1,
				"creation_mode": "manual",
			},
			"media": {
				"video_path": "",
				"video_source_path": "",
				"audio_path": SOURCE_PATH,
			},
			"chart_path": CHART_PATH,
		})
	)


func _make_wav_bytes(
	duration: float
) -> PackedByteArray:
	var sample_rate := 8000
	var sample_count := roundi(duration * sample_rate)
	var data_size := sample_count * 2
	var bytes := PackedByteArray()
	bytes.resize(44 + data_size)
	_write_ascii(bytes, 0, "RIFF")
	_write_u32_le(bytes, 4, 36 + data_size)
	_write_ascii(bytes, 8, "WAVE")
	_write_ascii(bytes, 12, "fmt ")
	_write_u32_le(bytes, 16, 16)
	_write_u16_le(bytes, 20, 1)
	_write_u16_le(bytes, 22, 1)
	_write_u32_le(bytes, 24, sample_rate)
	_write_u32_le(bytes, 28, sample_rate * 2)
	_write_u16_le(bytes, 32, 2)
	_write_u16_le(bytes, 34, 16)
	_write_ascii(bytes, 36, "data")
	_write_u32_le(bytes, 40, data_size)
	for index in range(sample_count):
		var sample := roundi(
			sin(
				float(index)
				/ float(sample_rate)
				* TAU
				* 220.0
			) * 12000.0
		)
		_write_u16_le(
			bytes,
			44 + index * 2,
			sample & 0xffff
		)
	return bytes


func _write_ascii(
	bytes: PackedByteArray,
	offset: int,
	value: String
) -> void:
	var encoded := value.to_ascii_buffer()
	for index in range(encoded.size()):
		bytes[offset + index] = encoded[index]


func _write_u16_le(
	bytes: PackedByteArray,
	offset: int,
	value: int
) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff


func _write_u32_le(
	bytes: PackedByteArray,
	offset: int,
	value: int
) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff
	bytes[offset + 2] = (value >> 16) & 0xff
	bytes[offset + 3] = (value >> 24) & 0xff


func _write_bytes(
	path: String,
	bytes: PackedByteArray
) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.flush()


func _write_text(
	path: String,
	text: String
) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.flush()


func _reset_test_root() -> void:
	_remove_test_tree(
		ProjectSettings.globalize_path(TEST_ROOT)
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEST_ROOT)
	)


func _remove_test_tree(
	absolute_path: String
) -> void:
	var allowed := ProjectSettings.globalize_path(
		TEST_ROOT
	).simplify_path().replace("\\", "/")
	var normalized := absolute_path.simplify_path().replace(
		"\\",
		"/"
	)
	if (
		normalized != allowed
		and not normalized.begins_with(allowed + "/")
	):
		push_error(
			"Rejected unsafe test cleanup: %s"
			% normalized
		)
		return
	if not DirAccess.dir_exists_absolute(normalized):
		return
	var directory := DirAccess.open(normalized)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := normalized.path_join(entry)
		if directory.current_is_dir():
			_remove_test_tree(child)
		else:
			DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(normalized)


func _expect(
	condition: bool,
	description: String
) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if editor != null:
		editor._cancel_waveform_extraction(false)
		if not source_key.is_empty():
			editor.waveform_envelope_model.invalidate_source(
				source_key
			)
		if not invalid_source_key.is_empty():
			editor.waveform_envelope_model.invalidate_source(
				invalid_source_key
			)
	_remove_test_tree(
		ProjectSettings.globalize_path(TEST_ROOT)
	)
	if failures.is_empty():
		print("EDITOR WAVEFORM INTEGRATION TESTS PASSED")
		quit(0)
		return
	print(
		"EDITOR WAVEFORM INTEGRATION TESTS FAILED: %d"
		% failures.size()
	)
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
