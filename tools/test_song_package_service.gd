extends SceneTree

const ServiceType := preload(
	"res://src/packages/SongPackageService.gd"
)

const TEST_ROOT := "user://song_package_service_tests"

var failures: PackedStringArray = []
var service
var valid_manifest: Dictionary = {}
var valid_payloads: Dictionary = {}
var valid_package_path := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_test_root()
	service = ServiceType.new()
	_test_export_multichart_package()
	_test_content_version_helpers()
	_test_manifest_only_and_full_validation()
	_test_import_is_transactional_and_never_overwrites()
	_test_future_version_and_manifest_paths()
	_test_archive_traversal_absolute_duplicates_and_extensions()
	_test_hash_and_chart_validation()
	_test_limits_and_truncated_archive()
	_test_editor_v3_logical_migration()
	_finish()


func _test_export_multichart_package() -> void:
	var staging_root := TEST_ROOT.path_join("export_staging")
	valid_payloads = _create_valid_staging(staging_root)
	valid_package_path = TEST_ROOT.path_join("valid.aurora")
	var result: Dictionary = service.export_package(
		staging_root,
		_manifest_draft(),
		valid_package_path
	)
	_expect(
		bool(result.get("ok", false))
		and FileAccess.file_exists(valid_package_path),
		"Exporta un staging explícito como archivo .aurora"
	)
	valid_manifest = result.get("manifest", {})
	var song: Dictionary = valid_manifest.get("song", {})
	var charts: Array = song.get("charts", [])
	_expect(
		str(valid_manifest.get("type", "")) == ServiceType.PACKAGE_TYPE
		and int(valid_manifest.get("format_version", 0))
		== ServiceType.FORMAT_VERSION
		and str(valid_manifest.get("package_version", "")) == "1.0.0"
		and charts.size() == 3,
		"El manifiesto separa versión de contenido y conserva charts 4K, 6K y 8K"
	)
	_expect(
		_descriptor_has_integrity(
			(song.get("media", {}) as Dictionary).get("audio", {})
		)
		and _descriptor_has_integrity(charts[0])
		and _descriptor_has_integrity(charts[1])
		and _descriptor_has_integrity(charts[2]),
		"El exportador calcula tamaño y SHA-256 de medios y charts"
	)

	var archive_before := _read_bytes(valid_package_path)
	var second_result: Dictionary = service.export_package(
		staging_root,
		_manifest_draft(),
		valid_package_path
	)
	_expect(
		not bool(second_result.get("ok", true))
		and str(second_result.get("error_code", ""))
		== "destination_exists"
		and _read_bytes(valid_package_path) == archive_before,
		"Exportar nunca sobrescribe un paquete existente"
	)


func _test_content_version_helpers() -> void:
	_expect(
		ServiceType.is_valid_package_version("2.10.3")
		and not ServiceType.is_valid_package_version("2.10")
		and ServiceType.normalize_package_version("01.002.0003") == "1.2.3"
		and ServiceType.compare_package_versions("1.10.0", "1.2.9") > 0
		and ServiceType.increment_patch_version("1.2.9") == "1.2.10",
		"Valida, normaliza, compara e incrementa versiones MAYOR.MENOR.PARCHE"
	)


func _test_manifest_only_and_full_validation() -> void:
	var extraction_probe := TEST_ROOT.path_join(
		"must_not_be_created"
	)
	var manifest_result: Dictionary = service.validate_package_manifest(
		valid_package_path
	)
	_expect(
		bool(manifest_result.get("ok", false))
		and not bool(
			manifest_result.get("payloads_validated", true)
		)
		and not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(extraction_probe)
		),
		"Valida manifest e índice sin extraer el paquete"
	)

	var full_result: Dictionary = service.validate_package(
		valid_package_path
	)
	_expect(
		bool(full_result.get("ok", false))
		and bool(full_result.get("payloads_validated", false))
		and (full_result.get("payloads", {}) as Dictionary).size()
		== valid_payloads.size(),
		"La validación completa comprueba todos los payloads"
	)


func _test_import_is_transactional_and_never_overwrites() -> void:
	var destination := TEST_ROOT.path_join("imported")
	var result: Dictionary = service.import_package(
		valid_package_path,
		destination
	)
	_expect(
		bool(result.get("ok", false))
		and FileAccess.file_exists(
			destination.path_join(ServiceType.MANIFEST_PATH)
		)
		and FileAccess.file_exists(
			destination.path_join("charts/4k-normal.json")
		)
		and FileAccess.file_exists(
			destination.path_join("media/song.ogg")
		),
		"Importa a staging solo después de validar el paquete"
	)
	_expect(
		not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(
				destination + ServiceType.IMPORT_TEMP_SUFFIX
			)
		),
		"La importación exitosa no deja staging temporal"
	)

	var sentinel_path := destination.path_join("sentinel.txt")
	_write_bytes(sentinel_path, "keep".to_utf8_buffer())
	var second_result: Dictionary = service.import_package(
		valid_package_path,
		destination
	)
	_expect(
		not bool(second_result.get("ok", true))
		and str(second_result.get("error_code", ""))
		== "destination_exists"
		and _read_bytes(sentinel_path).get_string_from_utf8()
		== "keep",
		"La misma versión nunca sobrescribe un destino existente"
	)

	var update_manifest := _manifest_draft()
	update_manifest["package_version"] = "1.1.0"
	var update_path := TEST_ROOT.path_join("update.aurora")
	var update_export: Dictionary = service.export_package(
		TEST_ROOT.path_join("export_staging"),
		update_manifest,
		update_path
	)
	var update_result: Dictionary = service.import_package(
		update_path,
		destination
	)
	var installed_check: Dictionary = service.validate_staging(destination, true)
	var installed_manifest: Dictionary = installed_check.get("manifest", {})
	_expect(
		bool(update_export.get("ok", false))
		and bool(update_result.get("ok", false))
		and bool(update_result.get("updated", false))
		and str(update_result.get("previous_package_version", "")) == "1.0.0"
		and str(installed_manifest.get("package_version", "")) == "1.1.0"
		and not FileAccess.file_exists(sentinel_path),
		"Una versión posterior reemplaza la instalación completa tras validarla"
	)
	_expect(
		not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(destination + ServiceType.UPDATE_TEMP_SUFFIX)
		)
		and not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(destination + ServiceType.UPDATE_BACKUP_SUFFIX)
		),
		"La actualización válida no deja temporales ni respaldos pendientes"
	)
	var downgrade_result: Dictionary = service.import_package(
		valid_package_path,
		destination
	)
	_expect(
		not bool(downgrade_result.get("ok", true))
		and str(downgrade_result.get("error_code", "")) == "destination_exists"
		and str(downgrade_result.get("installed_version", "")) == "1.1.0",
		"Rechaza paquetes iguales o anteriores después de actualizar"
	)


func _test_future_version_and_manifest_paths() -> void:
	var future_manifest: Dictionary = valid_manifest.duplicate(true)
	future_manifest["format_version"] = (
		ServiceType.FORMAT_VERSION + 1
	)
	var future_path := TEST_ROOT.path_join("future.aurora")
	_write_raw_archive(future_path, future_manifest, valid_payloads)
	var result: Dictionary = service.validate_package_manifest(
		future_path
	)
	_expect(
		str(result.get("error_code", "")) == "future_version",
		"Rechaza versiones futuras del formato"
	)

	var unsafe_manifest: Dictionary = valid_manifest.duplicate(true)
	var unsafe_song: Dictionary = unsafe_manifest.get("song", {})
	var unsafe_media: Dictionary = unsafe_song.get("media", {})
	var unsafe_audio: Dictionary = unsafe_media.get("audio", {})
	unsafe_audio["path"] = "../outside.ogg"
	unsafe_media["audio"] = unsafe_audio
	unsafe_song["media"] = unsafe_media
	unsafe_manifest["song"] = unsafe_song
	var unsafe_path := TEST_ROOT.path_join(
		"unsafe_manifest.aurora"
	)
	_write_raw_archive(unsafe_path, unsafe_manifest, valid_payloads)
	result = service.validate_package_manifest(unsafe_path)
	_expect(
		str(result.get("error_code", ""))
		== "unsafe_manifest_path",
		"Rechaza traversal declarado dentro del manifiesto"
	)


func _test_archive_traversal_absolute_duplicates_and_extensions() -> void:
	var traversal_path := TEST_ROOT.path_join("traversal.aurora")
	var wrote_traversal := _write_raw_archive(
		traversal_path,
		valid_manifest,
		valid_payloads,
		[
			{
				"path": "../escape.ogg",
				"bytes": "escape".to_utf8_buffer(),
			},
		]
	)
	var result: Dictionary = service.validate_package_manifest(
		traversal_path
	)
	_expect(
		wrote_traversal
		and str(result.get("error_code", ""))
		== "unsafe_archive_path",
		"Rechaza entradas ZIP con traversal"
	)

	var absolute_path := TEST_ROOT.path_join("absolute.aurora")
	var wrote_absolute := _write_raw_archive(
		absolute_path,
		valid_manifest,
		valid_payloads,
		[
			{
				"path": "C:/escape.ogg",
				"bytes": "escape".to_utf8_buffer(),
			},
		]
	)
	result = service.validate_package_manifest(absolute_path)
	_expect(
		wrote_absolute
		and str(result.get("error_code", ""))
		== "unsafe_archive_path",
		"Rechaza entradas ZIP con rutas absolutas"
	)

	var duplicate_path := TEST_ROOT.path_join("duplicate.aurora")
	var wrote_duplicate := _write_raw_archive(
		duplicate_path,
		valid_manifest,
		valid_payloads,
		[
			{
				"path": "media/song.ogg",
				"bytes": "duplicate".to_utf8_buffer(),
			},
		]
	)
	result = service.validate_package_manifest(duplicate_path)
	_expect(
		wrote_duplicate
		and str(result.get("error_code", ""))
		== "duplicate_archive_path",
		"Rechaza rutas duplicadas dentro del ZIP"
	)

	var extension_path := TEST_ROOT.path_join(
		"unsupported.aurora"
	)
	_write_raw_archive(
		extension_path,
		valid_manifest,
		valid_payloads,
		[
			{
				"path": "payload.exe",
				"bytes": PackedByteArray([77, 90]),
			},
		]
	)
	result = service.validate_package_manifest(extension_path)
	_expect(
		str(result.get("error_code", ""))
		== "unsupported_extension",
		"Rechaza extensiones no admitidas"
	)


func _test_hash_and_chart_validation() -> void:
	var wrong_hash_manifest: Dictionary = valid_manifest.duplicate(true)
	var wrong_hash_song: Dictionary = wrong_hash_manifest.get(
		"song",
		{}
	)
	var wrong_hash_media: Dictionary = wrong_hash_song.get(
		"media",
		{}
	)
	var wrong_hash_audio: Dictionary = wrong_hash_media.get(
		"audio",
		{}
	)
	wrong_hash_audio["sha256"] = "0".repeat(64)
	wrong_hash_media["audio"] = wrong_hash_audio
	wrong_hash_song["media"] = wrong_hash_media
	wrong_hash_manifest["song"] = wrong_hash_song
	var wrong_hash_path := TEST_ROOT.path_join("wrong_hash.aurora")
	_write_raw_archive(
		wrong_hash_path,
		wrong_hash_manifest,
		valid_payloads
	)
	var result: Dictionary = service.validate_package(wrong_hash_path)
	_expect(
		str(result.get("error_code", "")) == "hash_mismatch",
		"Rechaza un payload cuyo SHA-256 no coincide"
	)

	var invalid_chart_payloads: Dictionary = valid_payloads.duplicate(
		true
	)
	var invalid_chart_bytes := JSON.stringify({
		"version": 2,
		"key_count": 4,
		"notes": [
			{"time": 1.0, "lane": 0, "duration": 2.0},
			{"time": 2.0, "lane": 0, "duration": 0.0},
		],
	}).to_utf8_buffer()
	invalid_chart_payloads["charts/4k-normal.json"] = (
		invalid_chart_bytes
	)
	var invalid_chart_manifest: Dictionary = valid_manifest.duplicate(
		true
	)
	_set_chart_integrity(
		invalid_chart_manifest,
		0,
		invalid_chart_bytes
	)
	var invalid_chart_path := TEST_ROOT.path_join(
		"invalid_chart.aurora"
	)
	_write_raw_archive(
		invalid_chart_path,
		invalid_chart_manifest,
		invalid_chart_payloads
	)
	result = service.validate_package(invalid_chart_path)
	_expect(
		str(result.get("error_code", "")) == "invalid_chart",
		"Rechaza un chart inválido aunque tamaño y hash coincidan"
	)


func _test_limits_and_truncated_archive() -> void:
	var strict_count_service = ServiceType.new({
		"max_file_count": 2,
	})
	var result: Dictionary = strict_count_service.validate_package_manifest(
		valid_package_path
	)
	_expect(
		str(result.get("error_code", "")) == "too_many_files",
		"Aplica un límite determinista a la cantidad de entradas"
	)

	var strict_size_service = ServiceType.new({
		"max_entry_bytes": 8,
		"max_manifest_bytes": 1024 * 1024,
	})
	result = strict_size_service.validate_package_manifest(
		valid_package_path
	)
	_expect(
		str(result.get("error_code", ""))
		== "entry_too_large",
		"Rechaza desde el índice ZIP entradas que superan el límite configurado"
	)

	var original_bytes := _read_bytes(valid_package_path)
	var bomb_bytes := _patch_central_uncompressed_size(
		original_bytes,
		"media/song.ogg",
		ServiceType.DEFAULT_LIMITS["max_entry_bytes"] + 1
	)
	var bomb_path := TEST_ROOT.path_join("declared_bomb.aurora")
	_write_bytes(bomb_path, bomb_bytes)
	result = service.validate_package_manifest(bomb_path)
	_expect(
		not bomb_bytes.is_empty()
		and str(result.get("error_code", ""))
		== "entry_too_large",
		"Bloquea tamaños descomprimidos gigantes antes de read_file"
	)

	var truncated_bytes := original_bytes.slice(
		0,
		maxi(1, original_bytes.size() / 2)
	)
	var truncated_path := TEST_ROOT.path_join("truncated.aurora")
	_write_bytes(truncated_path, truncated_bytes)
	result = service.validate_package_manifest(truncated_path)
	_expect(
		str(result.get("error_code", ""))
		== "archive_open_failed",
		"Rechaza un ZIP truncado antes de importar"
	)


func _test_editor_v3_logical_migration() -> void:
	var project_v3 := {
		"version": 3,
		"type": "aurora_editor_project",
		"metadata": {
			"title": "Migración lógica",
			"artist": "Aurora Creator",
			"bpm": 150.0,
			"duration_seconds": 45.0,
			"preview_start_seconds": 5.0,
			"preview_duration_seconds": 12.0,
			"key_count": 6,
			"difficulty": "HARD",
			"difficulty_level": 8,
		},
		"media": {
			"audio_path": "media/song.ogg",
			"video_path": "media/background.webm",
		},
		"chart_path": "charts/6k-hard.json",
	}
	var chart := ChartData.make_chart_document(
		[
			{"time": 1.0, "lane": 0, "duration": 0.0},
			{"time": 2.0, "lane": 5, "duration": 1.0},
		],
		6
	)
	var sentinel_path := TEST_ROOT.path_join(
		"migration_must_not_write"
	)
	var result: Dictionary = service.migrate_editor_v3_to_manifest(
		project_v3,
		chart
	)
	var manifest: Dictionary = result.get("manifest", {})
	var song: Dictionary = manifest.get("song", {})
	var charts: Array = song.get("charts", [])
	_expect(
		bool(result.get("ok", false))
		and bool(result.get("requires_staging_hashes", false))
		and charts.size() == 1
		and int((charts[0] as Dictionary).get("key_count", 0)) == 6
		and str(
			(charts[0] as Dictionary).get("difficulty", "")
		) == "HARD",
		"Migra lógicamente un documento v3 a un borrador de manifiesto"
	)
	_expect(
		not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(sentinel_path)
		)
		and not FileAccess.file_exists(sentinel_path),
		"La migración lógica no toca archivos reales"
	)

	var absolute_project: Dictionary = project_v3.duplicate(true)
	var absolute_media: Dictionary = absolute_project.get("media", {})
	absolute_media["audio_path"] = "C:/music/song.ogg"
	absolute_project["media"] = absolute_media
	result = service.migrate_editor_v3_to_manifest(
		absolute_project,
		chart
	)
	_expect(
		str(result.get("error_code", ""))
		== "migration_non_relative_path",
		"La migración solo acepta rutas portables relativas"
	)


func _manifest_draft() -> Dictionary:
	return {
		"type": ServiceType.PACKAGE_TYPE,
		"format_version": ServiceType.FORMAT_VERSION,
		"package_version": "1.0.0",
		"package_id": "123e4567-e89b-12d3-a456-426614174000",
		"song": {
			"song_id": "fixture-song",
			"title": "Aurora Package Fixture",
			"artist": "Aurora Tests",
			"bpm": 128.0,
			"duration_seconds": 60.0,
			"preview_start_seconds": 5.0,
			"preview_duration_seconds": 15.0,
			"media": {
				"audio": {"path": "media/song.ogg"},
				"video": {"path": "media/background.webm"},
				"cover": {"path": "media/cover.png"},
			},
			"charts": [
				{
					"chart_id": "4k-normal-04",
					"key_count": 4,
					"difficulty": "NORMAL",
					"difficulty_level": 4,
					"path": "charts/4k-normal.json",
				},
				{
					"chart_id": "6k-hard-08",
					"key_count": 6,
					"difficulty": "HARD",
					"difficulty_level": 8,
					"path": "charts/6k-hard.json",
				},
				{
					"chart_id": "8k-maximum-12",
					"key_count": 8,
					"difficulty": "MAXIMUM",
					"difficulty_level": 12,
					"path": "charts/8k-maximum.json",
				},
			],
		},
	}


func _create_valid_staging(staging_root: String) -> Dictionary:
	var payloads := {
		"media/song.ogg": "OggS-Aurora-audio-fixture".to_utf8_buffer(),
		"media/background.webm": PackedByteArray([
			26, 69, 223, 163, 65, 117, 114, 111, 114, 97,
		]),
		"media/cover.png": PackedByteArray([
			137, 80, 78, 71, 13, 10, 26, 10, 65, 85, 82, 79, 82, 65,
		]),
		"charts/4k-normal.json": JSON.stringify(
			ChartData.make_chart_document(
				[
					{"time": 1.0, "lane": 0, "duration": 0.0},
					{"time": 2.0, "lane": 3, "duration": 0.5},
				],
				4
			)
		).to_utf8_buffer(),
		"charts/6k-hard.json": JSON.stringify(
			ChartData.make_chart_document(
				[
					{"time": 1.0, "lane": 5, "duration": 0.0},
					{"time": 2.5, "lane": 2, "duration": 0.75},
				],
				6
			)
		).to_utf8_buffer(),
		"charts/8k-maximum.json": JSON.stringify(
			ChartData.make_chart_document(
				[
					{"time": 1.25, "lane": 7, "duration": 0.0},
					{"time": 3.0, "lane": 4, "duration": 1.0},
				],
				8
			)
		).to_utf8_buffer(),
	}
	for relative_path in payloads:
		_write_bytes(
			staging_root.path_join(relative_path),
			payloads[relative_path]
		)
	return payloads


func _write_raw_archive(
	path: String,
	manifest: Dictionary,
	payloads: Dictionary,
	extra_entries: Array[Dictionary] = []
) -> bool:
	var output_directory := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(output_directory)
	)
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return false
	if not _packer_add(
		packer,
		ServiceType.MANIFEST_PATH,
		JSON.stringify(manifest).to_utf8_buffer()
	):
		packer.close()
		return false
	var paths := PackedStringArray(payloads.keys())
	paths.sort()
	for relative_path in paths:
		if not _packer_add(
			packer,
			relative_path,
			payloads[relative_path]
		):
			packer.close()
			return false
	for entry in extra_entries:
		if not _packer_add(
			packer,
			str(entry.get("path", "")),
			entry.get("bytes", PackedByteArray())
		):
			packer.close()
			return false
	return packer.close() == OK


func _packer_add(
	packer: ZIPPacker,
	path: String,
	bytes: PackedByteArray
) -> bool:
	if packer.start_file(path) != OK:
		return false
	if packer.write_file(bytes) != OK:
		return false
	return packer.close_file() == OK


func _set_chart_integrity(
	manifest: Dictionary,
	chart_index: int,
	bytes: PackedByteArray
) -> void:
	var song: Dictionary = manifest.get("song", {})
	var charts: Array = song.get("charts", [])
	var chart: Dictionary = charts[chart_index]
	chart["sha256"] = service.compute_sha256(bytes)
	chart["size_bytes"] = bytes.size()
	charts[chart_index] = chart
	song["charts"] = charts
	manifest["song"] = song


func _patch_central_uncompressed_size(
	source: PackedByteArray,
	target_path: String,
	new_size: int
) -> PackedByteArray:
	var result := source.duplicate()
	var cursor := 0
	while cursor + 46 <= result.size():
		if (
			_read_u32_le(result, cursor)
			!= ServiceType.ZIP_CENTRAL_FILE_SIGNATURE
		):
			cursor += 1
			continue
		var name_length := _read_u16_le(result, cursor + 28)
		var extra_length := _read_u16_le(result, cursor + 30)
		var comment_length := _read_u16_le(result, cursor + 32)
		var entry_end := (
			cursor + 46 + name_length + extra_length + comment_length
		)
		if name_length <= 0 or entry_end > result.size():
			return PackedByteArray()
		var entry_path := result.slice(
			cursor + 46,
			cursor + 46 + name_length
		).get_string_from_utf8()
		if entry_path == target_path:
			_write_u32_le(result, cursor + 24, new_size)
			return result
		cursor = entry_end
	return PackedByteArray()


func _read_u16_le(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


func _read_u32_le(bytes: PackedByteArray, offset: int) -> int:
	return (
		int(bytes[offset])
		| (int(bytes[offset + 1]) << 8)
		| (int(bytes[offset + 2]) << 16)
		| (int(bytes[offset + 3]) << 24)
	)


func _write_u32_le(
	bytes: PackedByteArray,
	offset: int,
	value: int
) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff
	bytes[offset + 2] = (value >> 16) & 0xff
	bytes[offset + 3] = (value >> 24) & 0xff


func _descriptor_has_integrity(descriptor_value: Variant) -> bool:
	if not (descriptor_value is Dictionary):
		return false
	var descriptor: Dictionary = descriptor_value
	return (
		str(descriptor.get("sha256", "")).length() == 64
		and int(descriptor.get("size_bytes", 0)) > 0
	)


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


func _reset_test_root() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	_remove_test_tree(absolute)
	DirAccess.make_dir_recursive_absolute(absolute)


func _remove_test_tree(absolute_path: String) -> void:
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := absolute_path.path_join(entry)
			if directory.current_is_dir():
				_remove_test_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("SONG PACKAGE SERVICE TESTS PASSED")
		quit(0)
		return
	print(
		"SONG PACKAGE SERVICE TESTS FAILED: %d"
		% failures.size()
	)
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
