extends SceneTree

const EXPORTER_TYPE = preload(
	"res://src/screens/editor/EditorPackageExporter.gd"
)
const PROJECT_STORE = preload(
	"res://src/screens/editor/EditorProjectStore.gd"
)
const PACKAGE_SERVICE_TYPE = preload(
	"res://src/packages/SongPackageService.gd"
)

const TEST_ROOT := "user://editor_package_export_tests"
const PACKAGE_ID := "editor-package-export-test"

var failures: PackedStringArray = []
var exporter
var package_service


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_tree(TEST_ROOT)
	exporter = EXPORTER_TYPE.new()
	package_service = PACKAGE_SERVICE_TYPE.new()
	_test_portable_single_chart_export()
	_test_destination_is_never_overwritten()
	_test_nonportable_video_is_rejected()
	_test_failed_manifest_leaves_no_staging()
	_test_package_service_failure_cleans_staging()
	_finish()


func _test_portable_single_chart_export() -> void:
	var fixture := _create_project_fixture(
		"portable",
		"Nivel portable",
		true
	)
	var project_path := str(fixture.get("project_path", ""))
	var audio_path := str(fixture.get("audio_path", ""))
	var chart_path := str(fixture.get("chart_path", ""))
	var audio_before := _read_bytes(audio_path)
	var chart_before := _read_bytes(chart_path)
	var output_path := TEST_ROOT.path_join(
		"exports/portable.aurora"
	)
	var result: Dictionary = exporter.export_saved_project(
		project_path,
		output_path,
		PACKAGE_ID
	)
	_expect(
		bool(result.get("ok", false))
		and FileAccess.file_exists(output_path),
		"Exporta un proyecto v3 de un chart como .aurora"
	)

	var validation: Dictionary = package_service.validate_package(
		output_path
	)
	var manifest: Dictionary = validation.get("manifest", {})
	var song: Dictionary = manifest.get("song", {})
	var charts: Array = song.get("charts", [])
	var media: Dictionary = song.get("media", {})
	_expect(
		bool(validation.get("ok", false))
		and str(manifest.get("package_id", "")) == PACKAGE_ID
		and charts.size() == 1,
		"El paquete final supera validación completa y conserva su ID"
	)
	_expect(
		str((charts[0] as Dictionary).get("path", ""))
		== "charts/chart.json"
		and str(
			(media.get("audio", {}) as Dictionary).get("path", "")
		) == "media/audio.wav"
		and not str(
			(charts[0] as Dictionary).get("path", "")
		).contains("://"),
		"El manifiesto usa únicamente rutas internas portables"
	)
	_expect(
		_descriptor_has_integrity(charts[0])
		and _descriptor_has_integrity(media.get("audio", {})),
		"SongPackageService calcula hashes y tamaños de chart y audio"
	)
	_expect(
		_read_bytes(audio_path) == audio_before
		and _read_bytes(chart_path) == chart_before,
		"La exportación conserva intactos los archivos fuente"
	)
	_expect(
		_staging_root_is_empty()
		and not _has_exporting_temporary_files(
			output_path.get_base_dir()
		),
		"Limpia staging y archivos temporales después del éxito"
	)


func _test_destination_is_never_overwritten() -> void:
	var fixture := _create_project_fixture(
		"no_overwrite",
		"No sobrescribir",
		true
	)
	var output_path := TEST_ROOT.path_join(
		"exports/existing.aurora"
	)
	_write_bytes(output_path, "sentinel".to_utf8_buffer())
	var before := _read_bytes(output_path)
	var result: Dictionary = exporter.export_saved_project(
		str(fixture.get("project_path", "")),
		output_path,
		"editor-no-overwrite-test"
	)
	_expect(
		not bool(result.get("ok", true))
		and str(result.get("error_code", ""))
		== "destination_exists"
		and _read_bytes(output_path) == before,
		"Nunca sobrescribe un paquete de destino existente"
	)
	_expect(
		_staging_root_is_empty(),
		"Rechazar un destino existente no crea staging"
	)


func _test_nonportable_video_is_rejected() -> void:
	var fixture := _create_project_fixture(
		"mp4_only",
		"Video sin convertir",
		false,
		"mp4"
	)
	var output_path := TEST_ROOT.path_join(
		"exports/nonportable.aurora"
	)
	var source_path := str(fixture.get("video_path", ""))
	var source_before := _read_bytes(source_path)
	var result: Dictionary = exporter.export_saved_project(
		str(fixture.get("project_path", "")),
		output_path,
		"editor-nonportable-video-test"
	)
	_expect(
		not bool(result.get("ok", true))
		and str(result.get("error_code", ""))
		== "video_not_portable"
		and not FileAccess.file_exists(output_path),
		"No publica un MP4 que Godot no pueda reproducir directamente"
	)
	_expect(
		_read_bytes(source_path) == source_before
		and _staging_root_is_empty(),
		"El rechazo tampoco modifica el video fuente ni deja temporales"
	)


func _test_failed_manifest_leaves_no_staging() -> void:
	var fixture := _create_project_fixture(
		"invalid_manifest",
		"",
		true
	)
	var output_path := TEST_ROOT.path_join(
		"exports/invalid.aurora"
	)
	var audio_path := str(fixture.get("audio_path", ""))
	var audio_before := _read_bytes(audio_path)
	var result: Dictionary = exporter.export_saved_project(
		str(fixture.get("project_path", "")),
		output_path,
		"editor-invalid-manifest-test"
	)
	_expect(
		not bool(result.get("ok", true))
		and str(result.get("error_code", "")) == "invalid_title"
		and not FileAccess.file_exists(output_path),
		"Un manifiesto inválido no produce un paquete parcial"
	)
	_expect(
		_read_bytes(audio_path) == audio_before
		and _staging_root_is_empty()
		and not _has_exporting_temporary_files(
			output_path.get_base_dir()
		),
		"Los errores conservan fuentes y limpian todo temporal propio"
	)


func _test_package_service_failure_cleans_staging() -> void:
	var fixture := _create_project_fixture(
		"service_failure",
		"Fallo controlado",
		true
	)
	var strict_service := PACKAGE_SERVICE_TYPE.new({
		"max_entry_bytes": 16,
	})
	var strict_exporter := EXPORTER_TYPE.new(strict_service)
	var output_path := TEST_ROOT.path_join(
		"exports/service-failure.aurora"
	)
	var audio_path := str(fixture.get("audio_path", ""))
	var source_before := _read_bytes(audio_path)
	var result: Dictionary = strict_exporter.export_saved_project(
		str(fixture.get("project_path", "")),
		output_path,
		"editor-service-failure-test"
	)
	_expect(
		not bool(result.get("ok", true))
		and str(result.get("error_code", "")) == "entry_too_large"
		and not FileAccess.file_exists(output_path),
		"Un error del empaquetador no instala un archivo final"
	)
	_expect(
		_read_bytes(audio_path) == source_before
		and _staging_root_is_empty()
		and not _has_exporting_temporary_files(
			output_path.get_base_dir()
		),
		"Limpia staging y temporal después de fallar dentro del empaquetador"
	)


func _create_project_fixture(
	name: String,
	title: String,
	with_audio: bool,
	video_extension: String = ""
) -> Dictionary:
	var fixture_root := TEST_ROOT.path_join(name)
	var project_path := fixture_root.path_join("project/project.json")
	var audio_path := ""
	if with_audio:
		audio_path = fixture_root.path_join("sources/song.wav")
		_write_bytes(audio_path, _make_wav_bytes())
	var video_path := ""
	if not video_extension.is_empty():
		video_path = fixture_root.path_join(
			"sources/background.%s" % video_extension
		)
		_write_bytes(
			video_path,
			"prototype-video-source".to_utf8_buffer()
		)

	var project := {
		"version": PROJECT_STORE.PROJECT_VERSION,
		"type": PROJECT_STORE.PROJECT_TYPE,
		"package_id": "editor-%s" % name,
		"metadata": {
			"title": title,
			"artist": "Aurora Tests",
			"difficulty": "NORMAL",
			"difficulty_level": 4,
			"bpm": 128.0,
			"duration_seconds": 30.0,
			"preview_start_seconds": 2.0,
			"preview_duration_seconds": 10.0,
			"key_count": 4,
			"creation_mode": "automatic",
			"automatic_density": 1,
		},
		"media": {
			"video_path": video_path,
			"video_source_path": video_path,
			"audio_path": audio_path,
		},
		"chart_path": fixture_root.path_join(
			"project/chart.json"
		),
	}
	var chart := ChartData.make_chart_document(
		[
			{"time": 1.0, "lane": 0, "duration": 0.0},
			{"time": 2.0, "lane": 3, "duration": 0.75},
		],
		4
	)
	var save_result := PROJECT_STORE.save_bundle(
		project_path,
		project,
		chart
	)
	_expect(
		bool(save_result.get("ok", false)),
		"Prepara fixture %s" % name
	)
	return {
		"project_path": project_path,
		"chart_path": str(save_result.get("chart_path", "")),
		"audio_path": audio_path,
		"video_path": video_path,
	}


func _descriptor_has_integrity(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var descriptor: Dictionary = value
	return (
		str(descriptor.get("sha256", "")).length() == 64
		and int(descriptor.get("size_bytes", 0)) > 0
	)


func _staging_root_is_empty() -> bool:
	var root := EXPORTER_TYPE.EXPORT_STAGING_ROOT
	var directory := DirAccess.open(root)
	if directory == null:
		return true
	directory.list_dir_begin()
	var entry := directory.get_next()
	directory.list_dir_end()
	return entry.is_empty()


func _has_exporting_temporary_files(directory_path: String) -> bool:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return false
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with(".aurora-exporting-"):
			directory.list_dir_end()
			return true
		entry = directory.get_next()
	directory.list_dir_end()
	return false


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
	text: String
) -> void:
	for index in range(text.length()):
		bytes[offset + index] = text.unicode_at(index)


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


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	return file.get_buffer(file.get_length())


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
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path(child)
			)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	_remove_tree(TEST_ROOT)
	if failures.is_empty():
		print("EDITOR PACKAGE EXPORT TESTS PASSED")
		quit(0)
		return
	push_error(
		"EDITOR PACKAGE EXPORT TESTS FAILED (%d): %s"
		% [failures.size(), "; ".join(failures)]
	)
	quit(1)
