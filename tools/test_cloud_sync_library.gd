extends SceneTree

const ServiceType := preload("res://src/packages/SongPackageService.gd")

const TEST_ROOT := "user://cloud_sync_tests"
const UNPACKED_PACKAGE_ID := "cloud-sync-unpacked-test"
const ARCHIVE_PACKAGE_ID := "cloud-sync-archive-test"

var failures: PackedStringArray = []
var service = ServiceType.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_cleanup()
	var sync_dir := TEST_ROOT.path_join("drive_sync")
	var packages_subdir := sync_dir.path_join("packages")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(packages_subdir))

	# 1. Paquete descomprimido en shared_library/packages/
	var unpacked_staging := TEST_ROOT.path_join("unpacked_staging")
	_build_staging(unpacked_staging, UNPACKED_PACKAGE_ID, "1.0.0", "Cloud Unpacked Track")
	var unpacked_aurora := TEST_ROOT.path_join("unpacked-source.aurora")
	var unpacked_export: Dictionary = service.export_package(
		unpacked_staging,
		_read_manifest(unpacked_staging),
		unpacked_aurora
	)
	_expect(bool(unpacked_export.get("ok", false)), "Exporta paquete fuente para carpeta compartida")
	var unpacked_root := packages_subdir.path_join(UNPACKED_PACKAGE_ID)
	var unpacked_import: Dictionary = service.import_package(unpacked_aurora, unpacked_root)
	_expect(bool(unpacked_import.get("ok", false)), "Prepara paquete descomprimido válido")

	# 2. Paquete .aurora v1.0.0 en la carpeta sincronizada
	var archive_staging_v1 := TEST_ROOT.path_join("staging_v1")
	_build_staging(archive_staging_v1, ARCHIVE_PACKAGE_ID, "1.0.0", "Cloud Archive v1")
	var archive_path := sync_dir.path_join("cloud-archive.aurora")
	var export_v1: Dictionary = service.export_package(
		archive_staging_v1,
		_read_manifest(archive_staging_v1),
		archive_path
	)
	_expect(bool(export_v1.get("ok", false)), "Exporta paquete .aurora v1.0.0 para la nube")

	var app := (load("res://src/App.tscn") as PackedScene).instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame

	var settings_manager := app.get_node("Managers/SettingsManager") as SettingsManager
	var song_manager := app.get_node("Managers/SongManager") as SongManager
	settings_manager.set_setting("cloud_sync_directory", ProjectSettings.globalize_path(sync_dir), true)
	await process_frame

	var unpacked_song := _find_song(song_manager, "package_" + UNPACKED_PACKAGE_ID)
	var archive_song_v1 := _find_song(song_manager, "package_" + ARCHIVE_PACKAGE_ID)
	_expect(
		unpacked_song != null and unpacked_song.title == "Cloud Unpacked Track",
		"Detecta paquetes descomprimidos desde cloud_sync_directory"
	)
	_expect(
		archive_song_v1 != null and archive_song_v1.package_version == "1.0.0",
		"Auto-importa archivos .aurora desde cloud_sync_directory"
	)
	_expect(
		not song_manager.is_local_package_song(unpacked_song),
		"Protege paquetes en carpeta sincronizada frente a borrado local"
	)

	# 3. Actualiza el archivo .aurora a v1.1.0 y recarga sin duplicar canciones
	var archive_staging_v2 := TEST_ROOT.path_join("staging_v2")
	_build_staging(archive_staging_v2, ARCHIVE_PACKAGE_ID, "1.1.0", "Cloud Archive v1.1")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive_path))
	var export_v2: Dictionary = service.export_package(
		archive_staging_v2,
		_read_manifest(archive_staging_v2),
		archive_path
	)
	_expect(bool(export_v2.get("ok", false)), "Exporta paquete .aurora v1.1.0 actualizado")
	song_manager.load_songs()
	var matching_count := 0
	var updated_song: SongData
	for song in song_manager.get_all_songs():
		if str(song.song_id) == "package_" + ARCHIVE_PACKAGE_ID:
			matching_count += 1
			updated_song = song
	_expect(
		matching_count == 1
		and updated_song != null
		and updated_song.package_version == "1.1.0"
		and updated_song.title == "Cloud Archive v1.1",
		"Actualiza paquetes .aurora a la nueva versión sin duplicarlos"
	)

	settings_manager.set_setting("cloud_sync_directory", "", false)
	_cleanup()
	if failures.is_empty():
		print("CLOUD SYNC LIBRARY TESTS PASSED")
		quit(0)
	else:
		push_error("CLOUD SYNC LIBRARY TESTS FAILED:\n" + "\n".join(failures))
		quit(1)


func _build_staging(staging_root: String, package_id: String, version: String, title: String) -> void:
	_write_bytes(staging_root.path_join("media/song.wav"), _make_wav_bytes())
	var chart_path := "charts/4k-normal.json"
	var chart_doc := ChartData.make_chart_document(
		[{"time": 1.0, "lane": 0, "duration": 0.0}],
		4
	)
	_write_bytes(staging_root.path_join(chart_path), JSON.stringify(chart_doc).to_utf8_buffer())
	var manifest := {
		"type": ServiceType.PACKAGE_TYPE,
		"format_version": ServiceType.FORMAT_VERSION,
		"package_version": version,
		"package_id": package_id,
		"song": {
			"song_id": package_id,
			"title": title,
			"artist": "Aurora Sync Test",
			"bpm": 128.0,
			"duration_seconds": 10.0,
			"preview_start_seconds": 0.0,
			"preview_duration_seconds": 5.0,
			"media": {"audio": {"path": "media/song.wav"}},
			"charts": [{
				"chart_id": "4k-normal-04",
				"key_count": 4,
				"difficulty": "NORMAL",
				"difficulty_level": 4,
				"path": chart_path,
			}],
		},
	}
	var manifest_bytes := JSON.stringify(manifest).to_utf8_buffer()
	_write_bytes(staging_root.path_join(ServiceType.MANIFEST_PATH), manifest_bytes)


func _read_manifest(staging_root: String) -> Dictionary:
	var file := FileAccess.open(staging_root.path_join(ServiceType.MANIFEST_PATH), FileAccess.READ)
	return JSON.parse_string(file.get_as_text())


func _find_song(song_manager: SongManager, song_id: String) -> SongData:
	for song in song_manager.get_all_songs():
		if str(song.song_id) == song_id:
			return song
	return null


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


func _write_ascii(bytes: PackedByteArray, offset: int, value: String) -> void:
	var encoded := value.to_ascii_buffer()
	for index in range(encoded.size()):
		bytes[offset + index] = encoded[index]


func _write_u16_le(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff


func _write_u32_le(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff
	bytes[offset + 2] = (value >> 16) & 0xff
	bytes[offset + 3] = (value >> 24) & 0xff


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.flush()


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
	_remove_tree(ProjectSettings.globalize_path("user://aurora_packages/" + ARCHIVE_PACKAGE_ID))


func _remove_tree(absolute_path: String) -> void:
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var dir := DirAccess.open(absolute_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
