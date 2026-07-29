extends RefCounted

class_name SongPackageService

const PACKAGE_TYPE := "aurora_song_package"
const FORMAT_VERSION := 1
const MANIFEST_PATH := "manifest.json"
const IMPORT_TEMP_SUFFIX := ".aurora-importing"
const ZIP_LOCAL_FILE_SIGNATURE := 0x04034b50
const ZIP_CENTRAL_FILE_SIGNATURE := 0x02014b50
const ZIP_END_SIGNATURE := 0x06054b50
const ZIP_MAX_COMMENT_BYTES := 65535

const DEFAULT_LIMITS := {
	"max_archive_bytes": 512 * 1024 * 1024,
	"max_manifest_bytes": 1024 * 1024,
	"max_entry_bytes": 256 * 1024 * 1024,
	"max_total_uncompressed_bytes": 1024 * 1024 * 1024,
	"max_file_count": 64,
	"max_chart_count": 32,
}

const AUDIO_EXTENSIONS := ["mp3", "ogg", "wav"]
const VIDEO_EXTENSIONS := ["ogv", "mp4", "mov", "mkv", "webm", "avi", "m4v"]
const COVER_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const CHART_EXTENSIONS := ["json"]

var _limits: Dictionary = DEFAULT_LIMITS.duplicate(true)


func _init(custom_limits: Dictionary = {}) -> void:
	for key in custom_limits:
		if _limits.has(key):
			_limits[key] = maxi(int(custom_limits[key]), 1)


func export_package(
	staging_root: String,
	manifest_draft: Dictionary,
	output_package_path: String
) -> Dictionary:
	var output_check := _validate_package_file_path(
		output_package_path,
		false
	)
	if not bool(output_check.get("ok", false)):
		return output_check
	if _path_exists(output_package_path):
		return _failure(
			"destination_exists",
			ERR_ALREADY_EXISTS,
			"El archivo de paquete ya existe y no será sobrescrito."
		)

	var staging_absolute := _absolute_path(staging_root)
	if not DirAccess.dir_exists_absolute(staging_absolute):
		return _failure(
			"staging_not_found",
			ERR_FILE_NOT_FOUND,
			"No se encontró la carpeta de staging indicada."
		)

	var manifest: Dictionary = manifest_draft.duplicate(true)
	manifest["type"] = PACKAGE_TYPE
	manifest["format_version"] = FORMAT_VERSION
	var structure_check := validate_manifest(manifest, false)
	if not bool(structure_check.get("ok", false)):
		return structure_check

	var records := _get_manifest_file_records(manifest)
	var payloads: Dictionary = {}
	var total_payload_bytes := 0

	for record_value in records:
		var record: Dictionary = record_value
		var relative_path := str(record.get("path", ""))
		var read_result := _read_staging_file(
			staging_absolute,
			relative_path
		)
		if not bool(read_result.get("ok", false)):
			return read_result
		var bytes: PackedByteArray = read_result.get(
			"bytes",
			PackedByteArray()
		)
		if bytes.is_empty():
			return _failure(
				"empty_payload",
				ERR_INVALID_DATA,
				"El archivo %s está vacío." % relative_path
			)
		if bytes.size() > _limit("max_entry_bytes"):
			return _failure(
				"entry_too_large",
				ERR_OUT_OF_MEMORY,
				"El archivo %s supera el límite permitido." % relative_path
			)
		total_payload_bytes += bytes.size()
		if total_payload_bytes > _limit("max_total_uncompressed_bytes"):
			return _failure(
				"package_too_large",
				ERR_OUT_OF_MEMORY,
				"El contenido descomprimido supera el límite permitido."
			)

		if str(record.get("kind", "")) == "chart":
			var chart_check := _validate_chart_bytes(
				bytes,
				int(record.get("key_count", 0)),
				relative_path
			)
			if not bool(chart_check.get("ok", false)):
				return chart_check

		payloads[relative_path] = bytes
		_set_record_integrity(
			manifest,
			record,
			compute_sha256(bytes),
			bytes.size()
		)

	var strict_check := validate_manifest(manifest, true)
	if not bool(strict_check.get("ok", false)):
		return strict_check

	var manifest_bytes := JSON.stringify(
		manifest,
		"\t",
		true
	).to_utf8_buffer()
	if manifest_bytes.size() > _limit("max_manifest_bytes"):
		return _failure(
			"manifest_too_large",
			ERR_OUT_OF_MEMORY,
			"El manifiesto supera el límite permitido."
		)

	var output_directory := output_package_path.get_base_dir()
	if output_directory.is_empty():
		output_directory = "."
	var directory_error := DirAccess.make_dir_recursive_absolute(
		_absolute_path(output_directory)
	)
	if directory_error != OK:
		return _failure(
			"output_directory_failed",
			directory_error,
			"No se pudo preparar la carpeta de salida."
		)
	if _path_exists(output_package_path):
		return _failure(
			"destination_exists",
			ERR_ALREADY_EXISTS,
			"El archivo de paquete apareció durante la exportación."
		)

	var packer := ZIPPacker.new()
	var packer_error := packer.open(output_package_path)
	if packer_error != OK:
		return _failure(
			"archive_create_failed",
			packer_error,
			"No se pudo crear el paquete."
		)

	packer_error = _write_zip_entry(
		packer,
		MANIFEST_PATH,
		manifest_bytes
	)
	if packer_error == OK:
		var payload_paths := PackedStringArray(payloads.keys())
		payload_paths.sort()
		for relative_path in payload_paths:
			var payload: PackedByteArray = payloads[relative_path]
			packer_error = _write_zip_entry(
				packer,
				relative_path,
				payload
			)
			if packer_error != OK:
				break
	var close_error := packer.close()
	if packer_error == OK:
		packer_error = close_error
	if packer_error != OK:
		_remove_file_created_by_service(output_package_path)
		return _failure(
			"archive_write_failed",
			packer_error,
			"No se pudo completar el paquete."
		)

	var verification := validate_package(output_package_path)
	if not bool(verification.get("ok", false)):
		_remove_file_created_by_service(output_package_path)
		return _failure(
			"archive_verification_failed",
			ERR_INVALID_DATA,
			"El paquete creado no superó su validación final.",
			{"cause": verification}
		)

	return _success({
		"package_path": output_package_path,
		"manifest": manifest,
		"file_count": payloads.size() + 1,
		"payload_bytes": total_payload_bytes,
	})


func validate_package_manifest(package_path: String) -> Dictionary:
	return _inspect_archive(package_path, false)


func validate_package(package_path: String) -> Dictionary:
	return _inspect_archive(package_path, true)


func import_package(
	package_path: String,
	destination_staging_path: String
) -> Dictionary:
	var inspection := _inspect_archive(package_path, true)
	if not bool(inspection.get("ok", false)):
		return inspection

	var destination_absolute := _absolute_path(destination_staging_path)
	if _path_exists(destination_staging_path):
		return _failure(
			"destination_exists",
			ERR_ALREADY_EXISTS,
			"El destino ya existe y no será sobrescrito."
		)
	var temporary_path := destination_staging_path + IMPORT_TEMP_SUFFIX
	var temporary_absolute := _absolute_path(temporary_path)
	if (
		DirAccess.dir_exists_absolute(temporary_absolute)
		or FileAccess.file_exists(temporary_absolute)
	):
		return _failure(
			"temporary_destination_exists",
			ERR_ALREADY_EXISTS,
			"Ya existe un staging temporal; no se reemplazará."
		)

	var create_error := DirAccess.make_dir_recursive_absolute(
		temporary_absolute
	)
	if create_error != OK:
		return _failure(
			"staging_create_failed",
			create_error,
			"No se pudo crear el staging temporal."
		)

	var manifest_bytes: PackedByteArray = inspection.get(
		"manifest_bytes",
		PackedByteArray()
	)
	var write_error := _write_staged_file(
		temporary_absolute,
		MANIFEST_PATH,
		manifest_bytes
	)
	var payloads: Dictionary = inspection.get("payloads", {})
	if write_error == OK:
		var payload_paths := PackedStringArray(payloads.keys())
		payload_paths.sort()
		for relative_path in payload_paths:
			var payload: PackedByteArray = payloads[relative_path]
			write_error = _write_staged_file(
				temporary_absolute,
				relative_path,
				payload
			)
			if write_error != OK:
				break
	if write_error != OK:
		_remove_tree_created_by_service(temporary_absolute)
		return _failure(
			"staging_write_failed",
			write_error,
			"No se pudo escribir el staging importado."
		)

	if _path_exists(destination_staging_path):
		_remove_tree_created_by_service(temporary_absolute)
		return _failure(
			"destination_exists",
			ERR_ALREADY_EXISTS,
			"El destino apareció durante la importación."
		)
	var rename_error := DirAccess.rename_absolute(
		temporary_absolute,
		destination_absolute
	)
	if rename_error != OK:
		_remove_tree_created_by_service(temporary_absolute)
		return _failure(
			"staging_install_failed",
			rename_error,
			"No se pudo instalar el staging importado."
		)

	return _success({
		"destination_path": destination_staging_path,
		"manifest_path": destination_staging_path.path_join(
			MANIFEST_PATH
		),
		"manifest": inspection.get("manifest", {}),
		"file_count": payloads.size() + 1,
	})


func validate_manifest(
	document_value: Variant,
	require_integrity: bool = true
) -> Dictionary:
	if not (document_value is Dictionary):
		return _failure(
			"manifest_not_dictionary",
			ERR_INVALID_DATA,
			"El manifiesto no es un objeto JSON."
		)
	var document: Dictionary = document_value
	if str(document.get("type", "")) != PACKAGE_TYPE:
		return _failure(
			"invalid_package_type",
			ERR_INVALID_DATA,
			"El tipo de paquete no corresponde a Aurora."
		)

	var version_value: Variant = document.get("format_version", null)
	if not _is_whole_number(version_value):
		return _failure(
			"invalid_format_version",
			ERR_INVALID_DATA,
			"La versión del paquete no es válida."
		)
	var format_version := int(version_value)
	if format_version > FORMAT_VERSION:
		return _failure(
			"future_version",
			ERR_UNAVAILABLE,
			"El paquete usa una versión futura no compatible."
		)
	if format_version != FORMAT_VERSION:
		return _failure(
			"unsupported_version",
			ERR_UNAVAILABLE,
			"La versión del paquete no es compatible."
		)

	var package_id := str(document.get("package_id", "")).strip_edges()
	if not _is_safe_identifier(package_id):
		return _failure(
			"invalid_package_id",
			ERR_INVALID_DATA,
			"El package_id no es válido."
		)

	var song_value: Variant = document.get("song", null)
	if not (song_value is Dictionary):
		return _failure(
			"missing_song",
			ERR_INVALID_DATA,
			"El manifiesto no contiene una canción."
		)
	var song: Dictionary = song_value
	var song_id := str(song.get("song_id", "")).strip_edges()
	if not _is_safe_identifier(song_id):
		return _failure(
			"invalid_song_id",
			ERR_INVALID_DATA,
			"El song_id no es válido."
		)
	var title := str(song.get("title", "")).strip_edges()
	var artist := str(song.get("artist", "")).strip_edges()
	if title.is_empty() or title.length() > 200:
		return _failure(
			"invalid_title",
			ERR_INVALID_DATA,
			"El título de la canción no es válido."
		)
	if artist.is_empty() or artist.length() > 200:
		return _failure(
			"invalid_artist",
			ERR_INVALID_DATA,
			"El artista de la canción no es válido."
		)

	for numeric_field in [
		"bpm",
		"duration_seconds",
		"preview_start_seconds",
		"preview_duration_seconds",
	]:
		if not _is_finite_number(song.get(numeric_field, null)):
			return _failure(
				"invalid_song_metadata",
				ERR_INVALID_DATA,
				"El campo %s no es numérico." % numeric_field
			)
	var bpm := float(song.get("bpm", 0.0))
	var duration_seconds := float(song.get("duration_seconds", 0.0))
	var preview_start := float(song.get("preview_start_seconds", 0.0))
	var preview_duration := float(
		song.get("preview_duration_seconds", 0.0)
	)
	if bpm < 1.0 or bpm > 400.0:
		return _failure(
			"invalid_bpm",
			ERR_INVALID_DATA,
			"El BPM está fuera del rango permitido."
		)
	if duration_seconds <= 0.0 or duration_seconds > 14400.0:
		return _failure(
			"invalid_duration",
			ERR_INVALID_DATA,
			"La duración está fuera del rango permitido."
		)
	if (
		preview_start < 0.0
		or preview_start > duration_seconds
		or preview_duration <= 0.0
		or preview_duration > 120.0
	):
		return _failure(
			"invalid_preview",
			ERR_INVALID_DATA,
			"La vista previa está fuera del rango permitido."
		)

	var media_value: Variant = song.get("media", null)
	if not (media_value is Dictionary):
		return _failure(
			"missing_media",
			ERR_INVALID_DATA,
			"La canción no declara medios compartidos."
		)
	var media: Dictionary = media_value
	if not media.has("audio") and not media.has("video"):
		return _failure(
			"missing_playable_media",
			ERR_INVALID_DATA,
			"El paquete necesita audio o video."
		)

	var references: Dictionary = {}
	for media_kind in ["audio", "video", "cover"]:
		if not media.has(media_kind):
			continue
		var descriptor_check := _validate_descriptor(
			media.get(media_kind),
			media_kind,
			require_integrity
		)
		if not bool(descriptor_check.get("ok", false)):
			return descriptor_check
		var media_path := str(descriptor_check.get("path", ""))
		var reference_error := _register_reference(
			references,
			media_path,
			{
				"kind": media_kind,
				"path": media_path,
				"descriptor": media.get(media_kind),
			}
		)
		if not bool(reference_error.get("ok", false)):
			return reference_error

	var charts_value: Variant = song.get("charts", null)
	if not (charts_value is Array):
		return _failure(
			"missing_charts",
			ERR_INVALID_DATA,
			"La canción no contiene un arreglo de charts."
		)
	var charts: Array = charts_value
	if charts.is_empty() or charts.size() > _limit("max_chart_count"):
		return _failure(
			"invalid_chart_count",
			ERR_INVALID_DATA,
			"La cantidad de charts no es válida."
		)

	var chart_ids: Dictionary = {}
	var chart_signatures: Dictionary = {}
	for chart_index in range(charts.size()):
		var chart_value: Variant = charts[chart_index]
		if not (chart_value is Dictionary):
			return _failure(
				"invalid_chart_descriptor",
				ERR_INVALID_DATA,
				"Un descriptor de chart no es válido."
			)
		var chart: Dictionary = chart_value
		var chart_id := str(chart.get("chart_id", "")).strip_edges()
		if not _is_safe_identifier(chart_id):
			return _failure(
				"invalid_chart_id",
				ERR_INVALID_DATA,
				"Un chart_id no es válido."
			)
		var chart_id_key := chart_id.to_lower()
		if chart_ids.has(chart_id_key):
			return _failure(
				"duplicate_chart_id",
				ERR_INVALID_DATA,
				"Hay chart_id duplicados."
			)
		chart_ids[chart_id_key] = true

		var key_count_value: Variant = chart.get("key_count", null)
		if (
			not _is_whole_number(key_count_value)
			or int(key_count_value) not in [4, 6, 8]
		):
			return _failure(
				"invalid_key_count",
				ERR_INVALID_DATA,
				"Los charts del paquete solo admiten 4K, 6K u 8K."
			)
		var key_count := int(key_count_value)
		var difficulty := str(
			chart.get("difficulty", "")
		).strip_edges().to_upper()
		var difficulty_level_value: Variant = chart.get(
			"difficulty_level",
			null
		)
		if difficulty.is_empty() or difficulty.length() > 40:
			return _failure(
				"invalid_difficulty",
				ERR_INVALID_DATA,
				"La dificultad de un chart no es válida."
			)
		if (
			not _is_whole_number(difficulty_level_value)
			or int(difficulty_level_value) < 1
			or int(difficulty_level_value) > 20
		):
			return _failure(
				"invalid_difficulty_level",
				ERR_INVALID_DATA,
				"El nivel de dificultad está fuera del rango permitido."
			)
		var signature := "%d|%s|%d" % [
			key_count,
			difficulty,
			int(difficulty_level_value),
		]
		if chart_signatures.has(signature):
			return _failure(
				"duplicate_chart_signature",
				ERR_INVALID_DATA,
				"Hay dos charts con el mismo modo y dificultad."
			)
		chart_signatures[signature] = true

		var descriptor_check := _validate_descriptor(
			chart,
			"chart",
			require_integrity
		)
		if not bool(descriptor_check.get("ok", false)):
			return descriptor_check
		var chart_path := str(descriptor_check.get("path", ""))
		var reference_error := _register_reference(
			references,
			chart_path,
			{
				"kind": "chart",
				"path": chart_path,
				"descriptor": chart,
				"chart_index": chart_index,
				"key_count": key_count,
			}
		)
		if not bool(reference_error.get("ok", false)):
			return reference_error

	if references.size() + 1 > _limit("max_file_count"):
		return _failure(
			"too_many_files",
			ERR_OUT_OF_MEMORY,
			"El manifiesto declara demasiados archivos."
		)
	if require_integrity:
		var declared_payload_bytes := 0
		for record_value in references.values():
			var record: Dictionary = record_value
			var descriptor: Dictionary = record.get("descriptor", {})
			declared_payload_bytes += int(
				descriptor.get("size_bytes", 0)
			)
			if declared_payload_bytes > _limit(
				"max_total_uncompressed_bytes"
			):
				return _failure(
					"package_too_large",
					ERR_OUT_OF_MEMORY,
					"El tamaño total declarado supera el límite."
				)

	return _success({
		"manifest": document,
		"references": references,
	})


func migrate_editor_v3_to_manifest(
	project_document_value: Variant,
	chart_document_value: Variant = {},
	requested_package_id: String = ""
) -> Dictionary:
	if not (project_document_value is Dictionary):
		return _failure(
			"migration_invalid_project",
			ERR_INVALID_DATA,
			"El documento del editor no es válido."
		)
	var project: Dictionary = project_document_value
	if (
		int(project.get("version", 0)) != 3
		or str(project.get("type", "")) != "aurora_editor_project"
	):
		return _failure(
			"migration_unsupported_project",
			ERR_UNAVAILABLE,
			"Solo se puede migrar lógicamente un proyecto v3."
		)
	var metadata_value: Variant = project.get("metadata", null)
	var media_value: Variant = project.get("media", null)
	if (
		not (metadata_value is Dictionary)
		or not (media_value is Dictionary)
	):
		return _failure(
			"migration_missing_sections",
			ERR_INVALID_DATA,
			"El proyecto v3 no contiene metadata y media válidos."
		)
	var metadata: Dictionary = metadata_value
	var legacy_media: Dictionary = media_value

	var chart_path := str(
		project.get("chart_path", "")
	).strip_edges()
	var chart_path_check := _validate_relative_file_path(chart_path)
	if not bool(chart_path_check.get("ok", false)):
		return _failure(
			"migration_non_relative_path",
			ERR_INVALID_DATA,
			"El chart v3 no usa una ruta relativa portable."
		)
	var key_count := int(metadata.get("key_count", 4))
	if key_count not in [4, 6, 8]:
		return _failure(
			"migration_invalid_key_count",
			ERR_INVALID_DATA,
			"El chart v3 no usa 4K, 6K u 8K."
		)
	if (
		chart_document_value is Dictionary
		and not (chart_document_value as Dictionary).is_empty()
		and not ChartData.is_valid_chart_document(
			chart_document_value,
			key_count
		)
	):
		return _failure(
			"migration_invalid_chart",
			ERR_INVALID_DATA,
			"El chart v3 proporcionado no es válido."
		)

	var package_id := requested_package_id.strip_edges()
	if package_id.is_empty():
		var identity_seed := JSON.stringify({
			"title": str(metadata.get("title", "Nuevo nivel")),
			"artist": str(metadata.get("artist", "Aurora Creator")),
			"chart_path": chart_path,
		})
		package_id = "editor-%s" % compute_sha256(
			identity_seed.to_utf8_buffer()
		).substr(
			0,
			32
		)
	if not _is_safe_identifier(package_id):
		return _failure(
			"migration_invalid_package_id",
			ERR_INVALID_DATA,
			"El package_id solicitado no es válido."
		)

	var migrated_media: Dictionary = {}
	for media_kind in ["audio", "video", "cover"]:
		var source_key := "%s_path" % media_kind
		var source_path := str(
			legacy_media.get(source_key, "")
		).strip_edges()
		if source_path.is_empty():
			continue
		var path_check := _validate_relative_file_path(source_path)
		if not bool(path_check.get("ok", false)):
			return _failure(
				"migration_non_relative_path",
				ERR_INVALID_DATA,
				"El medio %s no usa una ruta relativa portable."
				% media_kind
			)
		migrated_media[media_kind] = {"path": source_path}
	if not migrated_media.has("audio") and not migrated_media.has("video"):
		return _failure(
			"migration_missing_media",
			ERR_INVALID_DATA,
			"El proyecto v3 no declara audio o video portable."
		)

	var difficulty := str(
		metadata.get("difficulty", "NORMAL")
	).strip_edges().to_upper()
	var difficulty_level := clampi(
		int(metadata.get("difficulty_level", 4)),
		1,
		20
	)
	var chart_id := "%dk-%s-%02d" % [
		key_count,
		_slugify_identifier(difficulty),
		difficulty_level,
	]
	var manifest := {
		"type": PACKAGE_TYPE,
		"format_version": FORMAT_VERSION,
		"package_id": package_id,
		"song": {
			"song_id": str(
				metadata.get("song_id", package_id)
			).strip_edges(),
			"title": str(
				metadata.get("title", "Nuevo nivel")
			).strip_edges(),
			"artist": str(
				metadata.get("artist", "Aurora Creator")
			).strip_edges(),
			"bpm": float(metadata.get("bpm", 128.0)),
			"duration_seconds": float(
				metadata.get("duration_seconds", 120.0)
			),
			"preview_start_seconds": float(
				metadata.get("preview_start_seconds", 0.0)
			),
			"preview_duration_seconds": float(
				metadata.get("preview_duration_seconds", 15.0)
			),
			"media": migrated_media,
			"charts": [
				{
					"chart_id": chart_id,
					"key_count": key_count,
					"difficulty": difficulty,
					"difficulty_level": difficulty_level,
					"path": chart_path,
				},
			],
		},
	}
	var draft_check := validate_manifest(manifest, false)
	if not bool(draft_check.get("ok", false)):
		return draft_check
	return _success({
		"manifest": manifest,
		"requires_staging_hashes": true,
		"source_version": 3,
	})


func _inspect_archive(
	package_path: String,
	read_payloads: bool
) -> Dictionary:
	var package_check := _validate_package_file_path(
		package_path,
		true
	)
	if not bool(package_check.get("ok", false)):
		return package_check

	var package_file := FileAccess.open(package_path, FileAccess.READ)
	if package_file == null:
		return _failure(
			"archive_open_failed",
			FileAccess.get_open_error(),
			"No se pudo abrir el paquete."
		)
	var archive_size := package_file.get_length()
	if archive_size > _limit("max_archive_bytes"):
		package_file.close()
		return _failure(
			"archive_too_large",
			ERR_OUT_OF_MEMORY,
			"El archivo de paquete supera el límite permitido."
		)
	var metadata_check := _inspect_zip_metadata(
		package_file,
		archive_size
	)
	package_file.close()
	if not bool(metadata_check.get("ok", false)):
		return metadata_check

	var reader := ZIPReader.new()
	var open_error := reader.open(package_path)
	if open_error != OK:
		return _failure(
			"archive_open_failed",
			open_error,
			"El paquete ZIP está truncado o no es válido."
		)
	var result := _inspect_open_archive(
		reader,
		read_payloads,
		metadata_check
	)
	reader.close()
	return result


func _inspect_open_archive(
	reader: ZIPReader,
	read_payloads: bool,
	zip_metadata: Dictionary
) -> Dictionary:
	var entries := reader.get_files()
	if entries.size() > _limit("max_file_count"):
		return _failure(
			"too_many_files",
			ERR_OUT_OF_MEMORY,
			"El paquete contiene demasiadas entradas."
		)
	var metadata_entries: Dictionary = zip_metadata.get("entries", {})
	if entries.size() != int(
		zip_metadata.get("entry_count", -1)
	):
		return _failure(
			"archive_index_mismatch",
			ERR_FILE_CORRUPT,
			"El índice ZIP no coincide con su directorio central."
		)

	var seen_paths: Dictionary = {}
	var file_paths: PackedStringArray = []
	for raw_entry in entries:
		var entry := str(raw_entry)
		var is_directory := entry.ends_with("/")
		var path_to_validate := (
			entry.trim_suffix("/") if is_directory else entry
		)
		var path_check := _validate_relative_file_path(
			path_to_validate
		)
		if not bool(path_check.get("ok", false)):
			return _failure(
				"unsafe_archive_path",
				ERR_INVALID_DATA,
				"El paquete contiene una ruta no segura: %s"
				% entry
			)
		var canonical_key := path_to_validate.to_lower()
		if seen_paths.has(canonical_key):
			return _failure(
				"duplicate_archive_path",
				ERR_INVALID_DATA,
				"El paquete repite la ruta %s." % path_to_validate
			)
		seen_paths[canonical_key] = true
		if is_directory:
			continue
		if not _is_archive_extension_allowed(path_to_validate):
			return _failure(
				"unsupported_extension",
				ERR_INVALID_DATA,
				"El paquete contiene una extensión no admitida: %s"
				% path_to_validate
			)
		file_paths.append(path_to_validate)
		if not metadata_entries.has(path_to_validate):
			return _failure(
				"archive_index_mismatch",
				ERR_FILE_CORRUPT,
				"Una entrada no coincide con el directorio central."
			)

	if MANIFEST_PATH not in file_paths:
		return _failure(
			"manifest_missing",
			ERR_FILE_NOT_FOUND,
			"El paquete no contiene manifest.json."
		)
	var manifest_metadata: Dictionary = metadata_entries.get(
		MANIFEST_PATH,
		{}
	)
	if int(
		manifest_metadata.get("uncompressed_size", -1)
	) > _limit("max_manifest_bytes"):
		return _failure(
			"manifest_too_large",
			ERR_OUT_OF_MEMORY,
			"El manifiesto supera el límite antes de descomprimir."
		)
	var manifest_bytes := reader.read_file(MANIFEST_PATH, true)
	if (
		manifest_bytes.is_empty()
		or manifest_bytes.size() > _limit("max_manifest_bytes")
		or manifest_bytes.size() != int(
			manifest_metadata.get("uncompressed_size", -1)
		)
	):
		return _failure(
			"manifest_too_large",
			ERR_OUT_OF_MEMORY,
			"El manifiesto está vacío o supera el límite."
		)
	var parsed_manifest = JSON.parse_string(
		manifest_bytes.get_string_from_utf8()
	)
	var manifest_check := validate_manifest(parsed_manifest, true)
	if not bool(manifest_check.get("ok", false)):
		return manifest_check
	var manifest: Dictionary = parsed_manifest
	var references: Dictionary = manifest_check.get("references", {})

	var referenced_keys: Dictionary = {
		MANIFEST_PATH.to_lower(): true,
	}
	for reference_path_value in references.keys():
		var reference_path := str(reference_path_value)
		referenced_keys[reference_path.to_lower()] = true
		if not reader.file_exists(reference_path, true):
			return _failure(
				"referenced_file_missing",
				ERR_FILE_NOT_FOUND,
				"Falta el archivo declarado %s." % reference_path
			)
	for file_path in file_paths:
		if not referenced_keys.has(file_path.to_lower()):
			return _failure(
				"unreferenced_file",
				ERR_INVALID_DATA,
				"El paquete contiene un archivo no declarado: %s"
				% file_path
			)

	if not read_payloads:
		return _success({
			"manifest": manifest,
			"manifest_bytes": manifest_bytes,
			"file_count": file_paths.size(),
			"payloads_validated": false,
		})

	var payloads: Dictionary = {}
	var total_payload_bytes := 0
	var sorted_reference_paths := PackedStringArray(
		references.keys()
	)
	sorted_reference_paths.sort()
	for reference_path in sorted_reference_paths:
		var descriptor_record: Dictionary = references[
			reference_path
		]
		var entry_metadata: Dictionary = metadata_entries.get(
			reference_path,
			{}
		)
		var indexed_size := int(
			entry_metadata.get("uncompressed_size", -1)
		)
		if indexed_size < 0:
			return _failure(
				"archive_index_mismatch",
				ERR_FILE_CORRUPT,
				"Falta metadata ZIP para %s." % reference_path
			)
		if indexed_size > _limit("max_entry_bytes"):
			return _failure(
				"entry_too_large",
				ERR_OUT_OF_MEMORY,
				"El archivo %s supera el límite antes de descomprimir."
				% reference_path
			)
		var indexed_descriptor: Dictionary = descriptor_record.get(
			"descriptor",
			{}
		)
		if indexed_size != int(
			indexed_descriptor.get("size_bytes", -1)
		):
			return _failure(
				"size_mismatch",
				ERR_INVALID_DATA,
				"El tamaño ZIP de %s no coincide con el manifiesto."
				% reference_path
			)
		var bytes := reader.read_file(reference_path, true)
		if bytes.is_empty():
			return _failure(
				"empty_payload",
				ERR_INVALID_DATA,
				"El archivo %s está vacío." % reference_path
			)
		if bytes.size() > _limit("max_entry_bytes"):
			return _failure(
				"entry_too_large",
				ERR_OUT_OF_MEMORY,
				"El archivo %s supera el límite permitido."
				% reference_path
			)
		total_payload_bytes += bytes.size()
		if total_payload_bytes > _limit(
			"max_total_uncompressed_bytes"
		):
			return _failure(
				"package_too_large",
				ERR_OUT_OF_MEMORY,
				"El contenido descomprimido supera el límite."
			)

		var descriptor: Dictionary = descriptor_record.get(
			"descriptor",
			{}
		)
		if bytes.size() != int(descriptor.get("size_bytes", -1)):
			return _failure(
				"size_mismatch",
				ERR_INVALID_DATA,
				"El tamaño de %s no coincide con el manifiesto."
				% reference_path
			)
		if compute_sha256(bytes).to_lower() != str(
			descriptor.get("sha256", "")
		).to_lower():
			return _failure(
				"hash_mismatch",
				ERR_INVALID_DATA,
				"El hash SHA-256 de %s no coincide."
				% reference_path
			)
		if str(descriptor_record.get("kind", "")) == "chart":
			var chart_check := _validate_chart_bytes(
				bytes,
				int(descriptor_record.get("key_count", 0)),
				reference_path
			)
			if not bool(chart_check.get("ok", false)):
				return chart_check
		payloads[reference_path] = bytes

	return _success({
		"manifest": manifest,
		"manifest_bytes": manifest_bytes,
		"payloads": payloads,
		"file_count": file_paths.size(),
		"payload_bytes": total_payload_bytes,
		"payloads_validated": true,
	})


func _inspect_zip_metadata(
	package_file: FileAccess,
	archive_size: int
) -> Dictionary:
	if archive_size < 22:
		return _failure(
			"archive_open_failed",
			ERR_FILE_CORRUPT,
			"El archivo ZIP está truncado."
		)
	var tail_size := mini(
		archive_size,
		ZIP_MAX_COMMENT_BYTES + 22
	)
	var tail_offset := archive_size - tail_size
	package_file.seek(tail_offset)
	var tail := package_file.get_buffer(tail_size)
	var end_index := -1
	for index in range(tail.size() - 22, -1, -1):
		if _read_u32_le(tail, index) == ZIP_END_SIGNATURE:
			end_index = index
			break
	if end_index < 0:
		return _failure(
			"archive_open_failed",
			ERR_FILE_CORRUPT,
			"No se encontró el final del directorio ZIP."
		)

	var comment_length := _read_u16_le(tail, end_index + 20)
	var absolute_end_offset := tail_offset + end_index
	if (
		absolute_end_offset + 22 + comment_length
		!= archive_size
	):
		return _failure(
			"archive_open_failed",
			ERR_FILE_CORRUPT,
			"El final del ZIP está truncado o contiene datos inesperados."
		)
	var disk_number := _read_u16_le(tail, end_index + 4)
	var central_disk := _read_u16_le(tail, end_index + 6)
	var entries_on_disk := _read_u16_le(tail, end_index + 8)
	var entry_count := _read_u16_le(tail, end_index + 10)
	var central_size := _read_u32_le(tail, end_index + 12)
	var central_offset := _read_u32_le(tail, end_index + 16)
	if disk_number != 0 or central_disk != 0 or entries_on_disk != entry_count:
		return _failure(
			"multi_disk_archive",
			ERR_UNAVAILABLE,
			"Los paquetes ZIP multidisco no están admitidos."
		)
	if (
		entry_count == 0xffff
		or central_size == 0xffffffff
		or central_offset == 0xffffffff
	):
		return _failure(
			"zip64_not_supported",
			ERR_UNAVAILABLE,
			"ZIP64 no está admitido para paquetes Aurora."
		)
	if entry_count > _limit("max_file_count"):
		return _failure(
			"too_many_files",
			ERR_OUT_OF_MEMORY,
			"El paquete declara demasiadas entradas."
		)
	if (
		central_offset < 0
		or central_size < 0
		or central_offset + central_size > absolute_end_offset
	):
		return _failure(
			"archive_open_failed",
			ERR_FILE_CORRUPT,
			"El directorio central ZIP está fuera del archivo."
		)

	package_file.seek(central_offset)
	var central_bytes := package_file.get_buffer(central_size)
	if central_bytes.size() != central_size:
		return _failure(
			"archive_open_failed",
			ERR_FILE_CORRUPT,
			"El directorio central ZIP está truncado."
		)

	var entry_metadata: Dictionary = {}
	var canonical_paths: Dictionary = {}
	var total_uncompressed_bytes := 0
	var cursor := 0
	for entry_index in range(entry_count):
		if (
			cursor + 46 > central_bytes.size()
			or _read_u32_le(central_bytes, cursor)
			!= ZIP_CENTRAL_FILE_SIGNATURE
		):
			return _failure(
				"archive_open_failed",
				ERR_FILE_CORRUPT,
				"Una cabecera del directorio ZIP no es válida."
			)
		var flags := _read_u16_le(central_bytes, cursor + 8)
		var compression_method := _read_u16_le(
			central_bytes,
			cursor + 10
		)
		var compressed_size := _read_u32_le(
			central_bytes,
			cursor + 20
		)
		var uncompressed_size := _read_u32_le(
			central_bytes,
			cursor + 24
		)
		var name_length := _read_u16_le(
			central_bytes,
			cursor + 28
		)
		var extra_length := _read_u16_le(
			central_bytes,
			cursor + 30
		)
		var file_comment_length := _read_u16_le(
			central_bytes,
			cursor + 32
		)
		var entry_disk := _read_u16_le(
			central_bytes,
			cursor + 34
		)
		var local_header_offset := _read_u32_le(
			central_bytes,
			cursor + 42
		)
		var entry_end := (
			cursor
			+ 46
			+ name_length
			+ extra_length
			+ file_comment_length
		)
		if (
			name_length <= 0
			or entry_end > central_bytes.size()
			or entry_disk != 0
			or local_header_offset >= central_offset
		):
			return _failure(
				"archive_open_failed",
				ERR_FILE_CORRUPT,
				"Una entrada ZIP tiene metadata inválida."
			)
		if flags & 1:
			return _failure(
				"encrypted_archive",
				ERR_UNAVAILABLE,
				"Los paquetes ZIP cifrados no están admitidos."
			)
		if compression_method not in [0, 8]:
			return _failure(
				"unsupported_compression",
				ERR_UNAVAILABLE,
				"El paquete usa un método de compresión no admitido."
			)
		if (
			compressed_size == 0xffffffff
			or uncompressed_size == 0xffffffff
			or local_header_offset == 0xffffffff
		):
			return _failure(
				"zip64_not_supported",
				ERR_UNAVAILABLE,
				"Una entrada requiere ZIP64."
			)

		var name_bytes := central_bytes.slice(
			cursor + 46,
			cursor + 46 + name_length
		)
		var entry_path := name_bytes.get_string_from_utf8()
		var is_directory := entry_path.ends_with("/")
		var path_to_validate := (
			entry_path.trim_suffix("/")
			if is_directory
			else entry_path
		)
		var path_check := _validate_relative_file_path(
			path_to_validate
		)
		if not bool(path_check.get("ok", false)):
			return _failure(
				"unsafe_archive_path",
				ERR_INVALID_DATA,
				"El paquete contiene una ruta no segura: %s"
				% entry_path
			)
		var canonical_path := path_to_validate.to_lower()
		if canonical_paths.has(canonical_path):
			return _failure(
				"duplicate_archive_path",
				ERR_INVALID_DATA,
				"El paquete repite la ruta %s." % path_to_validate
			)
		canonical_paths[canonical_path] = true
		if not is_directory:
			if uncompressed_size > _limit("max_entry_bytes"):
				return _failure(
					"entry_too_large",
					ERR_OUT_OF_MEMORY,
					"El archivo %s supera el límite antes de descomprimir."
					% path_to_validate
				)
			total_uncompressed_bytes += uncompressed_size
			if total_uncompressed_bytes > _limit(
				"max_total_uncompressed_bytes"
			):
				return _failure(
					"package_too_large",
					ERR_OUT_OF_MEMORY,
					"El ZIP declara demasiado contenido descomprimido."
				)
		entry_metadata[path_to_validate] = {
			"compressed_size": compressed_size,
			"uncompressed_size": uncompressed_size,
			"compression_method": compression_method,
			"is_directory": is_directory,
			"entry_index": entry_index,
		}
		cursor = entry_end

	if cursor != central_bytes.size():
		return _failure(
			"archive_open_failed",
			ERR_FILE_CORRUPT,
			"El directorio central contiene datos no reconocidos."
		)
	return _success({
		"entries": entry_metadata,
		"entry_count": entry_count,
		"total_uncompressed_bytes": total_uncompressed_bytes,
	})


func _read_u16_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 2 > bytes.size():
		return -1
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


func _read_u32_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > bytes.size():
		return -1
	return (
		int(bytes[offset])
		| (int(bytes[offset + 1]) << 8)
		| (int(bytes[offset + 2]) << 16)
		| (int(bytes[offset + 3]) << 24)
	)


func _validate_descriptor(
	descriptor_value: Variant,
	kind: String,
	require_integrity: bool
) -> Dictionary:
	if not (descriptor_value is Dictionary):
		return _failure(
			"invalid_file_descriptor",
			ERR_INVALID_DATA,
			"El descriptor %s no es válido." % kind
		)
	var descriptor: Dictionary = descriptor_value
	var relative_path := str(
		descriptor.get("path", "")
	).strip_edges()
	var path_check := _validate_relative_file_path(relative_path)
	if not bool(path_check.get("ok", false)):
		return _failure(
			"unsafe_manifest_path",
			ERR_INVALID_DATA,
			"El descriptor %s no usa una ruta relativa segura."
			% kind
		)
	if not _is_extension_allowed_for_kind(relative_path, kind):
		return _failure(
			"unsupported_extension",
			ERR_INVALID_DATA,
			"La extensión de %s no está admitida para %s."
			% [relative_path, kind]
		)

	if require_integrity:
		var hash_text := str(
			descriptor.get("sha256", "")
		).to_lower()
		if not _is_sha256_text(hash_text):
			return _failure(
				"invalid_sha256",
				ERR_INVALID_DATA,
				"El hash de %s no es un SHA-256 válido."
				% relative_path
			)
		var size_value: Variant = descriptor.get(
			"size_bytes",
			null
		)
		if (
			not _is_whole_number(size_value)
			or int(size_value) <= 0
			or int(size_value) > _limit("max_entry_bytes")
		):
			return _failure(
				"invalid_declared_size",
				ERR_INVALID_DATA,
				"El tamaño declarado de %s no es válido."
				% relative_path
			)
	return _success({"path": relative_path})


func _register_reference(
	references: Dictionary,
	relative_path: String,
	record: Dictionary
) -> Dictionary:
	var path_key := relative_path.to_lower()
	for existing_path_value in references.keys():
		if str(existing_path_value).to_lower() == path_key:
			return _failure(
				"duplicate_manifest_path",
				ERR_INVALID_DATA,
				"Dos elementos del manifiesto usan la misma ruta."
			)
	references[relative_path] = record
	return _success()


func _get_manifest_file_records(
	manifest: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var song: Dictionary = manifest.get("song", {})
	var media: Dictionary = song.get("media", {})
	for media_kind in ["audio", "video", "cover"]:
		if media.has(media_kind):
			var descriptor: Dictionary = media[media_kind]
			result.append({
				"kind": media_kind,
				"path": str(descriptor.get("path", "")),
			})
	var charts: Array = song.get("charts", [])
	for chart_index in range(charts.size()):
		var chart: Dictionary = charts[chart_index]
		result.append({
			"kind": "chart",
			"path": str(chart.get("path", "")),
			"chart_index": chart_index,
			"key_count": int(chart.get("key_count", 0)),
		})
	return result


func _set_record_integrity(
	manifest: Dictionary,
	record: Dictionary,
	sha256: String,
	size_bytes: int
) -> void:
	var song: Dictionary = manifest.get("song", {})
	var kind := str(record.get("kind", ""))
	if kind == "chart":
		var charts: Array = song.get("charts", [])
		var chart_index := int(record.get("chart_index", -1))
		if chart_index >= 0 and chart_index < charts.size():
			var chart: Dictionary = charts[chart_index]
			chart["sha256"] = sha256
			chart["size_bytes"] = size_bytes
			charts[chart_index] = chart
			song["charts"] = charts
	else:
		var media: Dictionary = song.get("media", {})
		var descriptor: Dictionary = media.get(kind, {})
		descriptor["sha256"] = sha256
		descriptor["size_bytes"] = size_bytes
		media[kind] = descriptor
		song["media"] = media
	manifest["song"] = song


func _read_staging_file(
	staging_absolute: String,
	relative_path: String
) -> Dictionary:
	var full_path := staging_absolute.path_join(
		relative_path
	).simplify_path()
	var normalized_root := _normalized_absolute(
		staging_absolute
	).trim_suffix("/")
	var normalized_full := _normalized_absolute(full_path)
	if not normalized_full.begins_with(normalized_root + "/"):
		return _failure(
			"staging_path_escape",
			ERR_INVALID_PARAMETER,
			"Una ruta sale de la carpeta de staging."
		)
	var file := FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		return _failure(
			"staging_file_missing",
			FileAccess.get_open_error(),
			"No se encontró %s dentro del staging." % relative_path
		)
	var length := file.get_length()
	if length > _limit("max_entry_bytes"):
		return _failure(
			"entry_too_large",
			ERR_OUT_OF_MEMORY,
			"El archivo %s supera el límite permitido."
			% relative_path
		)
	return _success({"bytes": file.get_buffer(length)})


func _validate_chart_bytes(
	bytes: PackedByteArray,
	key_count: int,
	relative_path: String
) -> Dictionary:
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not ChartData.is_valid_chart_document(parsed, key_count):
		return _failure(
			"invalid_chart",
			ERR_INVALID_DATA,
			"El chart %s no es válido para %dK."
			% [relative_path, key_count]
		)
	return _success()


func _write_zip_entry(
	packer: ZIPPacker,
	relative_path: String,
	bytes: PackedByteArray
) -> Error:
	var error := packer.start_file(relative_path)
	if error != OK:
		return error
	error = packer.write_file(bytes)
	if error != OK:
		return error
	return packer.close_file()


func _write_staged_file(
	staging_absolute: String,
	relative_path: String,
	bytes: PackedByteArray
) -> Error:
	var full_path := staging_absolute.path_join(
		relative_path
	).simplify_path()
	var parent_error := DirAccess.make_dir_recursive_absolute(
		full_path.get_base_dir()
	)
	if parent_error != OK:
		return parent_error
	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	return file.get_error()


func _validate_package_file_path(
	package_path: String,
	must_exist: bool
) -> Dictionary:
	var clean_path := package_path.strip_edges()
	if (
		clean_path.is_empty()
		or clean_path != package_path
		or clean_path.get_extension().to_lower() != "aurora"
	):
		return _failure(
			"invalid_package_path",
			ERR_INVALID_PARAMETER,
			"El paquete debe usar la extensión .aurora."
		)
	if must_exist and not FileAccess.file_exists(clean_path):
		return _failure(
			"package_not_found",
			ERR_FILE_NOT_FOUND,
			"No se encontró el paquete indicado."
		)
	return _success()


func _validate_relative_file_path(relative_path: String) -> Dictionary:
	if relative_path.is_empty() or relative_path != relative_path.strip_edges():
		return _failure(
			"unsafe_path",
			ERR_INVALID_PARAMETER,
			"La ruta está vacía o contiene espacios externos."
		)
	if (
		relative_path.contains("\\")
		or relative_path.contains("://")
		or relative_path.begins_with("/")
		or relative_path.is_absolute_path()
		or relative_path.contains(":")
		or _contains_nul(relative_path)
		or relative_path.contains("//")
		or relative_path.ends_with("/")
	):
		return _failure(
			"unsafe_path",
			ERR_INVALID_PARAMETER,
			"La ruta no es relativa y canónica."
		)
	var parts := relative_path.split("/", true)
	if parts.is_empty():
		return _failure(
			"unsafe_path",
			ERR_INVALID_PARAMETER,
			"La ruta no contiene un archivo."
		)
	for part in parts:
		if part.is_empty() or part == "." or part == "..":
			return _failure(
				"unsafe_path",
				ERR_INVALID_PARAMETER,
				"La ruta contiene traversal o segmentos vacíos."
			)
	if relative_path.simplify_path() != relative_path:
		return _failure(
			"unsafe_path",
			ERR_INVALID_PARAMETER,
			"La ruta no está normalizada."
		)
	return _success({"path": relative_path})


func _is_archive_extension_allowed(path: String) -> bool:
	if path == MANIFEST_PATH:
		return true
	var extension := path.get_extension().to_lower()
	return (
		extension in AUDIO_EXTENSIONS
		or extension in VIDEO_EXTENSIONS
		or extension in COVER_EXTENSIONS
		or extension in CHART_EXTENSIONS
	)


func _is_extension_allowed_for_kind(
	path: String,
	kind: String
) -> bool:
	var extension := path.get_extension().to_lower()
	match kind:
		"audio":
			return extension in AUDIO_EXTENSIONS
		"video":
			return extension in VIDEO_EXTENSIONS
		"cover":
			return extension in COVER_EXTENSIONS
		"chart":
			return extension in CHART_EXTENSIONS
	return false


func _is_safe_identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	var allowed_characters := (
		"abcdefghijklmnopqrstuvwxyz"
		+ "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		+ "0123456789_.-"
	)
	for index in range(value.length()):
		var character := value[index]
		if not allowed_characters.contains(character):
			return false
	return true


func _slugify_identifier(value: String) -> String:
	var result := ""
	var allowed_characters := (
		"abcdefghijklmnopqrstuvwxyz0123456789_"
	)
	for character in value.to_lower():
		if allowed_characters.contains(character):
			result += character
		elif not result.ends_with("-"):
			result += "-"
	result = result.trim_prefix("-").trim_suffix("-")
	return result if not result.is_empty() else "normal"


func _is_sha256_text(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


func compute_sha256(bytes: PackedByteArray) -> String:
	var hashing_context := HashingContext.new()
	var start_error := hashing_context.start(
		HashingContext.HASH_SHA256
	)
	if start_error != OK:
		return ""
	hashing_context.update(bytes)
	return hashing_context.finish().hex_encode()


func _contains_nul(value: String) -> bool:
	for index in range(value.length()):
		if value.unicode_at(index) == 0:
			return true
	return false


func _is_finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var numeric_value := float(value)
	return not is_nan(numeric_value) and not is_inf(numeric_value)


func _is_whole_number(value: Variant) -> bool:
	if not _is_finite_number(value):
		return false
	var numeric_value := float(value)
	return is_equal_approx(numeric_value, float(int(numeric_value)))


func _limit(name: String) -> int:
	return int(_limits.get(name, 1))


func _path_exists(path: String) -> bool:
	var absolute := _absolute_path(path)
	return (
		FileAccess.file_exists(path)
		or FileAccess.file_exists(absolute)
		or DirAccess.dir_exists_absolute(absolute)
	)


func _absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(path).simplify_path()


func _normalized_absolute(path: String) -> String:
	return _absolute_path(path).replace("\\", "/")


func _remove_file_created_by_service(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute_path(path))


func _remove_tree_created_by_service(absolute_path: String) -> void:
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var entry_path := absolute_path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree_created_by_service(entry_path)
			else:
				DirAccess.remove_absolute(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _success(values: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": true,
		"error": OK,
		"error_code": "",
		"message": "",
	}
	result.merge(values, true)
	return result


func _failure(
	error_code: String,
	error: Error,
	message: String,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"ok": false,
		"error": error,
		"error_code": error_code,
		"message": message,
	}
	result.merge(extra, true)
	return result
