extends SceneTree

const PROJECT_STORE = preload(
	"res://src/screens/editor/EditorProjectStore.gd"
)
const PACKAGE_SERVICE_TYPE = preload(
	"res://src/packages/SongPackageService.gd"
)

const TEST_ROOT := "user://editor_package_export_flow_tests"

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_tree(TEST_ROOT)
	root.size = Vector2i(1280, 720)
	var app_scene := load("res://src/App.tscn") as PackedScene
	_expect(app_scene != null, "App se puede cargar para probar la exportación")
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
	await process_frame
	var editor := scene_manager.current_scene as Editor
	_expect(editor != null, "Editor abre para exportar en segundo plano")
	if editor == null:
		_finish()
		return

	var fixture := _create_project_fixture()
	editor.current_project_path = str(fixture.get("project_path", ""))
	editor.package_id = "editor-flow-test"
	var output_path := TEST_ROOT.path_join("exports/flujo.aurora")
	editor._start_package_export(output_path)
	_expect(
		editor._is_package_export_active()
		and editor.package_export_button.disabled
		and editor.package_export_button.text
		== AuroraLocale.text("EXPORTANDO..."),
		"La interfaz indica y bloquea una exportación activa"
	)

	var deadline := Time.get_ticks_msec() + 10000
	while (
		editor._is_package_export_active()
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	_expect(
		not editor._is_package_export_active(),
		"El hilo de exportación termina dentro del límite"
	)
	_expect(
		FileAccess.file_exists(output_path)
		and not editor.package_export_button.disabled
		and editor.package_export_button.text
		== AuroraLocale.text("EXPORTAR .AURORA")
		and editor.status_label.text
		== AuroraLocale.text("PAQUETE EXPORTADO // %s")
		% output_path.get_file(),
		"Al terminar se publica el paquete y se restauran los controles"
	)

	var validation: Dictionary = (
		PACKAGE_SERVICE_TYPE.new().validate_package(output_path)
	)
	_expect(
		bool(validation.get("ok", false))
		and str(
			(validation.get("manifest", {}) as Dictionary).get(
				"package_id",
				""
			)
		) == "editor-flow-test",
		"El flujo UI produce un paquete Aurora íntegro"
	)

	editor.suppress_dirty_tracking = true
	current_scene = null
	app.queue_free()
	await process_frame
	await process_frame
	_remove_tree(TEST_ROOT)
	_finish()


func _create_project_fixture() -> Dictionary:
	var fixture_root := TEST_ROOT.path_join("fixture")
	var audio_path := fixture_root.path_join("sources/song.wav")
	_write_bytes(audio_path, _make_wav_bytes())
	var project_path := fixture_root.path_join("project/project.json")
	var project := {
		"version": PROJECT_STORE.PROJECT_VERSION,
		"type": PROJECT_STORE.PROJECT_TYPE,
		"package_id": "editor-flow-test",
		"metadata": {
			"title": "Flujo portable",
			"artist": "Aurora Tests",
			"difficulty": "NORMAL",
			"difficulty_level": 4,
			"bpm": 128.0,
			"duration_seconds": 10.0,
			"preview_start_seconds": 0.0,
			"preview_duration_seconds": 10.0,
			"key_count": 4,
			"creation_mode": "automatic",
			"automatic_density": 1,
		},
		"media": {
			"video_path": "",
			"video_source_path": "",
			"audio_path": audio_path,
		},
		"chart_path": fixture_root.path_join("project/chart.json"),
	}
	var chart := ChartData.make_chart_document(
		[
			{"time": 1.0, "lane": 0, "duration": 0.0},
			{"time": 2.0, "lane": 3, "duration": 0.75},
		],
		4
	)
	var result: Dictionary = PROJECT_STORE.save_bundle(
		project_path,
		project,
		chart
	)
	_expect(bool(result.get("ok", false)), "Prepara el proyecto portable del flujo")
	return result


func _make_wav_bytes() -> PackedByteArray:
	var sample_count := 2205
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
	_write_u32_le(bytes, 24, 22050)
	_write_u32_le(bytes, 28, 44100)
	_write_u16_le(bytes, 32, 2)
	_write_u16_le(bytes, 34, 16)
	_write_ascii(bytes, 36, "data")
	_write_u32_le(bytes, 40, data_size)
	return bytes


func _write_ascii(
	bytes: PackedByteArray,
	offset: int,
	value: String
) -> void:
	for index in range(value.length()):
		bytes[offset + index] = value.unicode_at(index)


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


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.flush()


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("EDITOR PACKAGE EXPORT FLOW TESTS PASSED")
		quit(0)
	else:
		printerr(
			"EDITOR PACKAGE EXPORT FLOW TESTS FAILED: %s"
			% ", ".join(failures)
		)
		quit(1)
