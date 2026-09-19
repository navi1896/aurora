extends SceneTree

const SERVICE_TYPE := preload(
	"res://src/online/CommunitySubmissionService.gd"
)
const PROJECT_STORE := preload(
	"res://src/screens/editor/EditorProjectStore.gd"
)
const PUBLISH_PANEL_TYPE := preload(
	"res://src/screens/song_select/CommunityPublishPanel.gd"
)

const TEST_ROOT := "user://aurora_editor/.community_submission_test"

var failures: PackedStringArray = []


func _init() -> void:
	_cleanup_tree(TEST_ROOT)
	var fixture := _create_fixture()
	_test_rights_required(fixture)
	_test_prepare_from_project(fixture)
	_test_publish_panel_autofill(fixture)
	_cleanup_tree(TEST_ROOT)
	if failures.is_empty():
		print("COMMUNITY SUBMISSION TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_rights_required(fixture: Dictionary) -> void:
	var service = SERVICE_TYPE.new()
	var result: Dictionary = service.prepare_submission(
		str(fixture.get("project_path", "")),
		_publication(false)
	)
	_expect(
		not bool(result.get("ok", false))
		and str(result.get("code", "")) == "rights_not_confirmed",
		"Publicar exige confirmar la autoría o los permisos"
	)


func _test_prepare_from_project(fixture: Dictionary) -> void:
	var project_path := str(fixture.get("project_path", ""))
	var before: Dictionary = PROJECT_STORE.load_bundle(project_path)
	var service = SERVICE_TYPE.new()
	var result: Dictionary = service.prepare_submission(
		project_path,
		_publication(true)
	)
	var package_path := str(result.get("package_path", ""))
	var submission_path := str(result.get("submission_path", ""))
	_expect(
		bool(result.get("ok", false))
		and FileAccess.file_exists(package_path)
		and FileAccess.file_exists(submission_path),
		"La publicación reúne el proyecto y crea el .aurora sin buscar archivos"
	)
	var record: Variant = _read_json(submission_path)
	_expect(
		record is Dictionary
		and str((record as Dictionary).get("title", "")) == "Prueba interna"
		and str((record as Dictionary).get("sha256", "")).length() == 64
		and int((record as Dictionary).get("size_bytes", 0)) > 0,
		"La ficha interna conserva metadatos, tamaño y SHA-256"
	)
	var after: Dictionary = PROJECT_STORE.load_bundle(project_path)
	var before_project: Dictionary = before.get("project", {})
	var after_project: Dictionary = after.get("project", {})
	var before_metadata: Dictionary = before_project.get("metadata", {})
	var after_metadata: Dictionary = after_project.get("metadata", {})
	_expect(
		str(before_metadata.get("title", ""))
		== str(after_metadata.get("title", ""))
		and str(before_project.get("chart_path", ""))
		== str(after_project.get("chart_path", ""))
		and (before.get("notes", []) as Array).size()
		== (after.get("notes", []) as Array).size(),
		"Preparar una publicación no modifica el proyecto original"
	)
	_remove_file(package_path)
	_remove_file(submission_path)


func _test_publish_panel_autofill(fixture: Dictionary) -> void:
	var manager := SongManager.new()
	var song := SongData.new()
	song.song_id = &"editor_community_submission_test"
	song.title = "Título original"
	song.artist = "Artista original"
	song.editor_project_path = str(fixture.get("project_path", ""))
	manager.songs = [song]
	var panel = PUBLISH_PANEL_TYPE.new()
	root.add_child(panel)
	panel.setup(manager, song)
	_expect(
		panel.selected_song == song
		and panel.title_edit.text == "Título original"
		and panel.artist_edit.text == "Artista original"
		and "song.wav" in panel.files_label.text,
		"El formulario selecciona la canción y completa sus archivos automáticamente"
	)
	_expect(
		panel.prepare_button.disabled,
		"Preparar permanece bloqueado hasta confirmar los derechos"
	)
	panel.rights_check.button_pressed = true
	_expect(
		not panel.prepare_button.disabled,
		"Confirmar los derechos habilita la preparación interna"
	)
	root.remove_child(panel)
	panel.free()
	manager.free()


func _publication(rights_confirmed: bool) -> Dictionary:
	return {
		"title": "Prueba interna",
		"artist": "Aurora Tests",
		"chart_author": "Test Author",
		"package_version": "1.2.3",
		"license": "OBRA ORIGINAL / CON PERMISO",
		"description": "Paquete preparado completamente dentro de Aurora.",
		"rights_confirmed": rights_confirmed,
	}


func _create_fixture() -> Dictionary:
	var project_path := TEST_ROOT.path_join("project/project.json")
	var chart_path := TEST_ROOT.path_join("project/chart.json")
	var audio_path := TEST_ROOT.path_join("source/song.wav")
	_write_bytes(audio_path, _make_wav_bytes())
	var project := {
		"version": PROJECT_STORE.PROJECT_VERSION,
		"type": PROJECT_STORE.PROJECT_TYPE,
		"package_id": "community-submission-test",
		"package_version": "1.0.0",
		"metadata": {
			"title": "Título original",
			"artist": "Artista original",
			"difficulty": "NORMAL",
			"difficulty_level": 4,
			"bpm": 128.0,
			"duration_seconds": 20.0,
			"key_count": 4,
			"creation_mode": "manual",
			"automatic_density": 1,
		},
		"media": {
			"video_path": "",
			"audio_path": audio_path,
		},
		"chart_path": chart_path,
	}
	var chart := ChartData.make_chart_document(
		[
			{"time": 1.0, "lane": 0, "duration": 0.0},
			{"time": 2.0, "lane": 2, "duration": 0.75},
		],
		4
	)
	var save_result: Dictionary = PROJECT_STORE.save_bundle(
		project_path,
		project,
		chart
	)
	_expect(bool(save_result.get("ok", false)), "Prepara el proyecto de publicación")
	return {"project_path": project_path}


func _make_wav_bytes() -> PackedByteArray:
	var sample_count := 512
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


func _write_ascii(bytes: PackedByteArray, offset: int, value: String) -> void:
	var encoded := value.to_ascii_buffer()
	for index in range(encoded.size()):
		bytes[offset + index] = encoded[index]


func _write_u16_le(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff


func _write_u32_le(bytes: PackedByteArray, offset: int, value: int) -> void:
	for shift in range(4):
		bytes[offset + shift] = (value >> (shift * 8)) & 0xff


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed


func _remove_file(path: String) -> void:
	if path.is_empty():
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _cleanup_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child_path := absolute_path.path_join(entry)
		if directory.current_is_dir():
			_cleanup_tree(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
