extends SceneTree

const ServiceType := preload(
	"res://src/packages/SongPackageService.gd"
)
const ProjectStoreType := preload(
	"res://src/screens/editor/EditorProjectStore.gd"
)

const TEST_ROOT := "user://song_package_library_tests"
const TEST_PACKAGE_ID := "aurora-library-integration-test"
const TEST_SONG_ID := "package_" + TEST_PACKAGE_ID
const INSTALLED_PACKAGE_ROOT := (
	"user://aurora_packages/" + TEST_PACKAGE_ID
)

var failures: PackedStringArray = []
var service
var app: Node
var scene_manager: SceneManager
var song_manager: SongManager
var settings_manager: SettingsManager
var original_last_package_directory := ""
var package_path := ""
var editor_copy_root := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_reset_owned_paths()
	service = ServiceType.new()
	package_path = TEST_ROOT.path_join(
		"multichart-library-test.aurora"
	)
	var exported := _create_test_package()
	_expect(
		exported,
		"Prepara un paquete .aurora multichart válido"
	)
	if not exported:
		_finish()
		return

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

	scene_manager = app.get_node(
		"Managers/SceneManager"
	) as SceneManager
	song_manager = app.get_node(
		"Managers/SongManager"
	) as SongManager
	settings_manager = app.get_node(
		"Managers/SettingsManager"
	) as SettingsManager
	original_last_package_directory = str(
		settings_manager.get_setting(
			"last_package_directory",
			""
		)
	)

	scene_manager.load_scene("song_select")
	await process_frame
	await process_frame
	var screen := scene_manager.current_scene as SongSelect
	_expect(screen != null, "La biblioteca se abre")
	if screen == null:
		_finish()
		return

	_test_import_button_and_native_dialog(screen)
	await _test_import_and_multichart_selection(screen)
	screen = await _test_edit_selected_song(screen)
	await _test_safe_rejection_and_authorized_deletion(screen)
	_finish()


func _test_import_button_and_native_dialog(
	screen: SongSelect
) -> void:
	var button_rect := screen.import_package_button.get_global_rect()
	var logical_viewport := Vector2(
		float(
			ProjectSettings.get_setting(
				"display/window/size/viewport_width",
				1920
			)
		),
		float(
			ProjectSettings.get_setting(
				"display/window/size/viewport_height",
				1080
			)
		)
	)
	_expect(
		screen.import_package_button.visible
		and not screen.import_package_button.disabled
		and button_rect.position.x >= 0.0
		and button_rect.position.y >= 0.0
		and button_rect.end.x <= logical_viewport.x
		and button_rect.end.y <= logical_viewport.y,
		"IMPORTAR .AURORA queda dentro del viewport escalable a 1280x720"
	)
	_expect(
		screen.package_dialog != null
		and screen.package_dialog.use_native_dialog
		and screen.package_dialog.file_mode
		== FileDialog.FILE_MODE_OPEN_FILE
		and "*.aurora ; Aurora Song Package"
		in screen.package_dialog.filters,
		"Usa selector nativo limitado a paquetes .aurora"
	)


func _test_import_and_multichart_selection(
	screen: SongSelect
) -> void:
	screen._on_package_file_selected(
		ProjectSettings.globalize_path(package_path)
	)
	_expect(
		screen.package_install_panel != null
		and not screen._is_package_import_active()
		and screen.package_install_panel.install_button.text
		== AuroraLocale.text("INSTALAR NIVEL"),
		"Muestra título y contenido antes de instalar el paquete"
	)
	screen._confirm_package_install(
		ProjectSettings.globalize_path(package_path)
	)
	_expect(
		screen._is_package_import_active()
		and screen.import_package_button.disabled
		and screen.import_package_button.text
		== AuroraLocale.text("INSTALANDO..."),
		"La importación se ejecuta sin bloquear la interfaz"
	)
	await _wait_for_package_import(screen)
	var package_song := _find_song(TEST_SONG_ID)
	_expect(
		package_song != null
		and package_song.charts.size() == 4,
		"El paquete aparece en la biblioteca con cuatro charts"
	)
	if package_song == null:
		return
	_expect(
		package_song.audio == null
		and package_song.background_video == null
		and song_manager.has_available_media(package_song),
		"El escaneo registra el medio compartido sin cargarlo"
	)
	_expect(
		str(
			settings_manager.get_setting(
				"last_package_directory",
				""
			)
		) == ProjectSettings.globalize_path(
			TEST_ROOT
		),
		"Recuerda la última carpeta usada para importar"
	)

	var package_index := _screen_song_index(
		screen,
		TEST_SONG_ID
	)
	_expect(
		package_index >= 0,
		"La canción importada está disponible en la lista visible"
	)
	if package_index < 0:
		return
	screen._select_song(package_index, false)
	await process_frame
	var labels := PackedStringArray()
	for button in screen.mode_buttons:
		labels.append(button.text)
	_expect(
		screen.mode_buttons.size() == 4
		and "4K  NORMAL 04" in labels
		and "4K  HARD 08" in labels
		and "6K  HARD 09" in labels
		and "8K  MAXIMUM 12" in labels,
		"Distingue modo y dificultad en cada chart"
	)
	screen._select_chart(1)
	_expect(
		screen.selected_chart_index == 1
		and screen.difficulty_label.text.contains("HARD 08"),
		"Permite seleccionar otra dificultad del mismo modo 4K"
	)


func _test_edit_selected_song(screen: SongSelect) -> SongSelect:
	var package_song := _find_song(TEST_SONG_ID)
	var package_index := _screen_song_index(screen, TEST_SONG_ID)
	if package_song == null or package_index < 0:
		_expect(false, "La canción importada existe antes de editarla")
		return screen
	screen._select_song(package_index, false)
	screen._select_chart(1)
	var source_chart := package_song.charts[1]
	var source_chart_path := source_chart.chart_path
	var source_chart_file := FileAccess.open(source_chart_path, FileAccess.READ)
	var source_chart_text := (
		source_chart_file.get_as_text()
		if source_chart_file != null
		else ""
	)
	_expect(
		not screen.edit_button.disabled
		and screen.edit_button.text
		== AuroraLocale.text("EDITAR CANCION"),
		"Una canción importada ofrece EDITAR CANCIÓN para el chart elegido"
	)
	screen._edit_selected_song()
	await process_frame
	await process_frame
	await process_frame
	var editor := scene_manager.current_scene as Editor
	_expect(editor != null, "EDITAR CANCIÓN abre directamente el editor")
	if editor == null:
		return screen
	editor_copy_root = editor.current_project_path.get_base_dir()
	_expect(
		editor.title_edit.text == package_song.title
		and editor.artist_edit.text == package_song.artist
		and editor.key_count == 4
		and int(editor.difficulty_level_spin.value) == 8
		and editor._get_difficulty_id() == "DIFICIL",
		"El editor conserva nombre, creador, modo y dificultad seleccionada"
	)
	var timeline_ids: Array[int] = editor.timeline_state.get_note_ids()
	var first_id: int = timeline_ids[0]
	var original_first_time := float(editor.notes[0].get("time", 0.0))
	editor._on_timeline_selection_requested(first_id, false, false)
	editor._on_timeline_move_requested(0.25, 0)
	editor.title_edit.text = "Biblioteca Editable"
	editor.artist_edit.text = "Aurora Tester"
	editor._select_difficulty("MAXIMA")
	editor.difficulty_level_spin.value = 11.0
	_expect(editor._save_project(), "La copia modificada se guarda desde el editor")
	var saved: Dictionary = ProjectStoreType.load_bundle(
		editor.current_project_path
	)
	var saved_project: Dictionary = saved.get("project", {})
	var saved_media: Dictionary = saved_project.get("media", {})
	var saved_notes: Array = saved.get("notes", [])
	_expect(
		bool(saved.get("ok", false))
		and str(saved_project.get("package_id", "")) == TEST_PACKAGE_ID
		and str(saved_project.get("package_version", "")) == "1.0.1"
		and str(saved_project.get("source_song_id", ""))
		== TEST_SONG_ID
		and not str(
			saved_project.get("source_chart_signature", "")
		).is_empty()
		and float(saved_notes[0].get("time", 0.0))
		!= original_first_time,
		"Guardar conserva el origen y prepara la siguiente versión del paquete"
	)
	var copied_audio_path := str(saved_media.get("audio_path", ""))
	_expect(
		copied_audio_path.begins_with(editor_copy_root + "/")
		and FileAccess.file_exists(copied_audio_path)
		and not copied_audio_path.begins_with(INSTALLED_PACKAGE_ROOT + "/"),
		"La copia editable conserva su propio medio independiente"
	)
	var source_after := FileAccess.open(source_chart_path, FileAccess.READ)
	_expect(
		source_after != null
		and source_after.get_as_text() == source_chart_text,
		"Editar la copia no modifica el chart importado original"
	)
	scene_manager.load_scene("song_select")
	await process_frame
	await process_frame
	var returned_screen := scene_manager.current_scene as SongSelect
	_expect(
		returned_screen != null
		and returned_screen._get_selected_song() != null
		and returned_screen._get_selected_song().title
		== "Biblioteca Editable"
		and returned_screen._get_selected_song().artist
		== "Aurora Tester",
		"Al volver, la biblioteca muestra inmediatamente el nombre y creador nuevos"
	)
	return returned_screen if returned_screen != null else screen


func _test_safe_rejection_and_authorized_deletion(
	screen: SongSelect
) -> void:
	var duplicate_count := song_manager.get_all_songs().size()
	screen._on_package_file_selected(
		ProjectSettings.globalize_path(package_path)
	)
	_expect(
		song_manager.get_all_songs().size() == duplicate_count
		and screen.package_install_panel != null
		and screen.package_install_panel.install_button.disabled
		and screen.package_install_panel.install_button.text
		== AuroraLocale.text("YA INSTALADO")
		and not screen._is_package_import_active(),
		"Rechaza una importación duplicada antes de reemplazar contenido"
	)
	screen._close_package_install_confirmation()
	await process_frame

	var integrated_song := SongData.new()
	integrated_song.song_id = &"integrated-protected-probe"
	_expect(
		song_manager.move_local_song_to_trash(
			integrated_song
		) == ERR_UNAUTHORIZED,
		"Rechaza borrar una canción no registrada como contenido local"
	)

	var package_index := _screen_song_index(
		screen,
		TEST_SONG_ID
	)
	if package_index < 0:
		_expect(false, "El paquete sigue seleccionado antes de borrarlo")
		return
	screen._select_song(package_index, false)
	screen._request_delete_selected_song()
	_expect(
		screen.delete_modal.visible
		and screen.pending_delete_song != null,
		"El borrado autorizado exige confirmación"
	)
	screen._confirm_delete_selected_song()
	await process_frame
	await process_frame
	_expect(
		not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(
				INSTALLED_PACKAGE_ROOT
			)
		)
		and _find_song(TEST_SONG_ID) == null,
		"La confirmación mueve solo el paquete local a la papelera"
	)


func _wait_for_package_import(screen: SongSelect) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while (
		screen._is_package_import_active()
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	_expect(
		not screen._is_package_import_active(),
		"La importación termina dentro del límite"
	)


func _create_test_package() -> bool:
	var staging_root := TEST_ROOT.path_join("staging")
	_write_bytes(
		staging_root.path_join("media/song.wav"),
		_make_wav_bytes()
	)
	var chart_specs := [
		{
			"path": "charts/4k-normal.json",
			"key_count": 4,
			"difficulty": "NORMAL",
			"level": 4,
		},
		{
			"path": "charts/4k-hard.json",
			"key_count": 4,
			"difficulty": "HARD",
			"level": 8,
		},
		{
			"path": "charts/6k-hard.json",
			"key_count": 6,
			"difficulty": "HARD",
			"level": 9,
		},
		{
			"path": "charts/8k-maximum.json",
			"key_count": 8,
			"difficulty": "MAXIMUM",
			"level": 12,
		},
	]
	var charts: Array[Dictionary] = []
	for spec_value in chart_specs:
		var spec: Dictionary = spec_value
		var key_count := int(spec["key_count"])
		var chart_path := str(spec["path"])
		var chart_document := ChartData.make_chart_document(
			[
				{
					"time": 1.0,
					"lane": 0,
					"duration": 0.0,
				},
				{
					"time": 2.0,
					"lane": key_count - 1,
					"duration": 0.75,
				},
			],
			key_count
		)
		_write_bytes(
			staging_root.path_join(chart_path),
			JSON.stringify(chart_document).to_utf8_buffer()
		)
		charts.append({
			"chart_id": "%dk-%s-%02d" % [
				key_count,
				str(spec["difficulty"]).to_lower(),
				int(spec["level"]),
			],
			"key_count": key_count,
			"difficulty": str(spec["difficulty"]),
			"difficulty_level": int(spec["level"]),
			"path": chart_path,
		})

	var manifest := {
		"type": ServiceType.PACKAGE_TYPE,
		"format_version": ServiceType.FORMAT_VERSION,
		"package_version": "1.0.0",
		"package_id": TEST_PACKAGE_ID,
		"song": {
			"song_id": "library-integration-song",
			"title": "Aurora Library Package Test",
			"artist": "Aurora Tests",
			"bpm": 128.0,
			"duration_seconds": 30.0,
			"preview_start_seconds": 2.0,
			"preview_duration_seconds": 8.0,
			"media": {
				"audio": {"path": "media/song.wav"},
			},
			"charts": charts,
		},
	}
	var result: Dictionary = service.export_package(
		staging_root,
		manifest,
		package_path
	)
	return bool(result.get("ok", false))


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


func _find_song(song_id: String) -> SongData:
	for song in song_manager.get_all_songs():
		if str(song.song_id) == song_id:
			return song
	return null


func _screen_song_index(
	screen: SongSelect,
	song_id: String
) -> int:
	for index in range(screen.songs.size()):
		if str(screen.songs[index].song_id) == song_id:
			return index
	return -1


func _write_bytes(
	path: String,
	bytes: PackedByteArray
) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(
			path.get_base_dir()
		)
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.flush()


func _reset_owned_paths() -> void:
	_remove_owned_tree(TEST_ROOT, TEST_ROOT)
	_remove_owned_tree(
		INSTALLED_PACKAGE_ROOT,
		INSTALLED_PACKAGE_ROOT
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEST_ROOT)
	)


func _remove_owned_tree(
	path: String,
	allowed_root: String
) -> void:
	var absolute := ProjectSettings.globalize_path(
		path
	).simplify_path().replace("\\", "/").trim_suffix("/")
	var allowed_absolute := ProjectSettings.globalize_path(
		allowed_root
	).simplify_path().replace("\\", "/").trim_suffix("/")
	if (
		absolute != allowed_absolute
		and not absolute.begins_with(
			allowed_absolute + "/"
		)
	):
		push_error(
			"Test cleanup rejected unsafe path: %s"
			% absolute
		)
		return
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := absolute.path_join(entry)
			if directory.current_is_dir():
				_remove_owned_tree(
					child,
					allowed_root
				)
			else:
				DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)


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
	if settings_manager != null:
		settings_manager.set_setting(
			"last_package_directory",
			original_last_package_directory,
			false
		)
	if (
		DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(
				INSTALLED_PACKAGE_ROOT
			)
		)
	):
		_remove_owned_tree(
			INSTALLED_PACKAGE_ROOT,
			INSTALLED_PACKAGE_ROOT
		)
	if (
		not editor_copy_root.is_empty()
		and DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(editor_copy_root)
		)
	):
		_remove_owned_tree(editor_copy_root, editor_copy_root)
	_remove_owned_tree(TEST_ROOT, TEST_ROOT)
	if failures.is_empty():
		print("SONG PACKAGE LIBRARY TESTS PASSED")
		quit(0)
		return
	print(
		"SONG PACKAGE LIBRARY TESTS FAILED: %d"
		% failures.size()
	)
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
