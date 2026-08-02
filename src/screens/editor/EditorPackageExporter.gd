extends RefCounted

class_name EditorPackageExporter

const PROJECT_STORE = preload(
	"res://src/screens/editor/EditorProjectStore.gd"
)
const PACKAGE_SERVICE_TYPE = preload(
	"res://src/packages/SongPackageService.gd"
)

const EXPORT_STAGING_ROOT := "user://aurora_editor/.package_export"
const PORTABLE_CHART_PATH := "charts/chart.json"
const SUPPORTED_KEY_COUNTS: Array[int] = [4, 6, 8]
const AUDIO_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]
const COVER_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]

var package_service


func _init(custom_package_service = null) -> void:
	package_service = (
		custom_package_service
		if custom_package_service != null
		else PACKAGE_SERVICE_TYPE.new()
	)


func export_saved_project(
	project_path: String,
	output_package_path: String,
	requested_package_id: String = ""
) -> Dictionary:
	var output_check := _validate_output_path(output_package_path)
	if not bool(output_check.get("ok", false)):
		return output_check

	var load_result: Dictionary = PROJECT_STORE.load_bundle(project_path)
	if not bool(load_result.get("ok", false)):
		return _failure(
			"project_load_failed",
			int(load_result.get("error", ERR_FILE_CANT_OPEN)),
			str(load_result.get("message", "No se pudo abrir el proyecto."))
		)
	var project: Dictionary = load_result.get("project", {})
	if (
		int(project.get("version", 0)) != PROJECT_STORE.PROJECT_VERSION
		or str(project.get("type", "")) != PROJECT_STORE.PROJECT_TYPE
	):
		return _failure(
			"unsupported_project",
			ERR_UNAVAILABLE,
			"Guarda el proyecto en el formato actual antes de exportarlo."
		)

	var chart: Dictionary = load_result.get("chart", {})
	var metadata: Dictionary = project.get("metadata", {})
	var key_count := int(metadata.get("key_count", 0))
	if key_count not in SUPPORTED_KEY_COUNTS:
		return _failure(
			"unsupported_key_count",
			ERR_INVALID_DATA,
			"Los paquetes Aurora solo admiten charts 4K, 6K u 8K."
		)
	var notes_value: Variant = chart.get("notes", null)
	if not (notes_value is Array) or (notes_value as Array).is_empty():
		return _failure(
			"empty_chart",
			ERR_INVALID_DATA,
			"Agrega al menos una nota antes de exportar."
		)

	var media_plan := _build_media_plan(project.get("media", {}))
	if not bool(media_plan.get("ok", false)):
		return media_plan

	var portable_project := project.duplicate(true)
	portable_project["chart_path"] = PORTABLE_CHART_PATH
	var portable_media: Dictionary = {}
	for entry_value in media_plan.get("entries", []):
		var entry: Dictionary = entry_value
		portable_media["%s_path" % str(entry.get("kind", ""))] = str(
			entry.get("relative_path", "")
		)
	portable_project["media"] = portable_media

	var package_id := requested_package_id.strip_edges()
	if package_id.is_empty():
		package_id = str(project.get("package_id", "")).strip_edges()
	if package_id.is_empty():
		package_id = str(metadata.get("package_id", "")).strip_edges()
	var migration_result: Dictionary = (
		package_service.migrate_editor_v3_to_manifest(
			portable_project,
			chart,
			package_id
		)
	)
	if not bool(migration_result.get("ok", false)):
		return migration_result

	var token := _make_job_token()
	var staging_root := EXPORT_STAGING_ROOT.path_join(token)
	var temporary_package_path := _temporary_package_path(
		output_package_path,
		token
	)
	var created_staging_paths: Array[String] = []
	var staging_result := _write_staging(
		staging_root,
		chart,
		media_plan.get("entries", []),
		created_staging_paths
	)
	if not bool(staging_result.get("ok", false)):
		_cleanup_staging(staging_root, created_staging_paths)
		return staging_result

	var output_directory := output_package_path.get_base_dir()
	if output_directory.is_empty():
		output_directory = "."
	var output_directory_error := DirAccess.make_dir_recursive_absolute(
		_absolute_path(output_directory)
	)
	if output_directory_error != OK:
		_cleanup_staging(staging_root, created_staging_paths)
		return _failure(
			"output_directory_failed",
			output_directory_error,
			"No se pudo preparar la carpeta de exportación."
		)

	var export_result: Dictionary = package_service.export_package(
		staging_root,
		migration_result.get("manifest", {}),
		temporary_package_path
	)
	_cleanup_staging(staging_root, created_staging_paths)
	if not bool(export_result.get("ok", false)):
		_remove_temporary_package(
			temporary_package_path,
			output_package_path
		)
		return export_result

	if _path_exists(output_package_path):
		_remove_temporary_package(
			temporary_package_path,
			output_package_path
		)
		return _failure(
			"destination_exists",
			ERR_ALREADY_EXISTS,
			"El archivo de destino apareció durante la exportación."
		)
	var rename_error := DirAccess.rename_absolute(
		_absolute_path(temporary_package_path),
		_absolute_path(output_package_path)
	)
	if rename_error != OK:
		_remove_temporary_package(
			temporary_package_path,
			output_package_path
		)
		return _failure(
			"package_install_failed",
			rename_error,
			"El paquete fue validado, pero no se pudo instalar en el destino."
		)

	var result := export_result.duplicate(true)
	result["package_path"] = output_package_path
	result["source_project_path"] = str(
		load_result.get("project_path", project_path)
	)
	return result


func _build_media_plan(media_value: Variant) -> Dictionary:
	if not (media_value is Dictionary):
		return _failure(
			"invalid_media",
			ERR_INVALID_DATA,
			"El proyecto no contiene una sección de medios válida."
		)
	var media: Dictionary = media_value
	var entries: Array[Dictionary] = []

	var video_path := str(media.get("video_path", "")).strip_edges()
	if not video_path.is_empty():
		if video_path.get_extension().to_lower() != "ogv":
			return _failure(
				"video_not_portable",
				ERR_UNAVAILABLE,
				"El video debe terminar su conversión a OGV antes de exportar."
			)
		var video_check := _validate_source_file(video_path)
		if not bool(video_check.get("ok", false)):
			return video_check
		entries.append({
			"kind": "video",
			"source_path": video_path,
			"relative_path": "media/background.ogv",
		})

	var audio_path := str(media.get("audio_path", "")).strip_edges()
	if not audio_path.is_empty():
		var audio_extension := audio_path.get_extension().to_lower()
		if audio_extension not in AUDIO_EXTENSIONS:
			return _failure(
				"audio_not_portable",
				ERR_UNAVAILABLE,
				"El audio debe ser MP3, OGG o WAV."
			)
		var audio_check := _validate_source_file(audio_path)
		if not bool(audio_check.get("ok", false)):
			return audio_check
		entries.append({
			"kind": "audio",
			"source_path": audio_path,
			"relative_path": "media/audio.%s" % audio_extension,
		})

	var cover_path := str(media.get("cover_path", "")).strip_edges()
	if not cover_path.is_empty():
		var cover_extension := cover_path.get_extension().to_lower()
		if cover_extension not in COVER_EXTENSIONS:
			return _failure(
				"cover_not_portable",
				ERR_UNAVAILABLE,
				"La portada debe ser PNG, JPG, JPEG o WEBP."
			)
		var cover_check := _validate_source_file(cover_path)
		if not bool(cover_check.get("ok", false)):
			return cover_check
		entries.append({
			"kind": "cover",
			"source_path": cover_path,
			"relative_path": "media/cover.%s" % cover_extension,
		})

	var has_playable_media := false
	for entry in entries:
		if str(entry.get("kind", "")) in ["audio", "video"]:
			has_playable_media = true
			break
	if not has_playable_media:
		return _failure(
			"missing_playable_media",
			ERR_FILE_NOT_FOUND,
			"El proyecto necesita audio o video para poder exportarse."
		)
	return _success({"entries": entries})


func _validate_source_file(source_path: String) -> Dictionary:
	if not FileAccess.file_exists(source_path):
		return _failure(
			"source_media_missing",
			ERR_FILE_NOT_FOUND,
			"No se encontró el medio %s." % source_path.get_file()
		)
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return _failure(
			"source_media_open_failed",
			FileAccess.get_open_error(),
			"No se pudo abrir el medio %s." % source_path.get_file()
		)
	if file.get_length() <= 0:
		return _failure(
			"source_media_empty",
			ERR_INVALID_DATA,
			"El medio %s está vacío." % source_path.get_file()
		)
	return _success()


func _write_staging(
	staging_root: String,
	chart: Dictionary,
	media_entries: Array,
	created_paths: Array[String]
) -> Dictionary:
	if not _is_owned_staging_root(staging_root):
		return _failure(
			"unsafe_staging_path",
			ERR_UNAUTHORIZED,
			"La carpeta temporal de exportación no es segura."
		)
	if DirAccess.dir_exists_absolute(_absolute_path(staging_root)):
		return _failure(
			"staging_exists",
			ERR_ALREADY_EXISTS,
			"La carpeta temporal de exportación ya existe."
		)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		_absolute_path(staging_root.path_join("charts"))
	)
	if directory_error == OK:
		directory_error = DirAccess.make_dir_recursive_absolute(
			_absolute_path(staging_root.path_join("media"))
		)
	if directory_error != OK:
		return _failure(
			"staging_create_failed",
			directory_error,
			"No se pudo preparar la exportación temporal."
		)

	var chart_bytes := JSON.stringify(
		chart,
		"\t",
		true
	).to_utf8_buffer()
	# Register the owned target before writing so cleanup also removes a file
	# left partially written by an I/O error.
	created_paths.append(PORTABLE_CHART_PATH)
	var chart_error := _write_owned_staging_file(
		staging_root,
		PORTABLE_CHART_PATH,
		chart_bytes
	)
	if chart_error != OK:
		return _failure(
			"chart_stage_failed",
			chart_error,
			"No se pudo preparar el chart para el paquete."
		)

	for entry_value in media_entries:
		var entry: Dictionary = entry_value
		var relative_path := str(entry.get("relative_path", ""))
		var destination := staging_root.path_join(relative_path)
		if not _is_path_inside_staging(staging_root, destination):
			return _failure(
				"unsafe_staging_path",
				ERR_UNAUTHORIZED,
				"Un medio intentó salir de la carpeta temporal."
			)
		# DirAccess.copy_absolute may leave a partial target on an I/O error.
		# Marking it first keeps cleanup deterministic without touching sources.
		created_paths.append(relative_path)
		var copy_error := DirAccess.copy_absolute(
			_absolute_path(str(entry.get("source_path", ""))),
			_absolute_path(destination)
		)
		if copy_error != OK:
			return _failure(
				"media_stage_failed",
				copy_error,
				"No se pudo copiar %s al paquete."
				% str(entry.get("kind", "medio"))
			)
	return _success()


func _write_owned_staging_file(
	staging_root: String,
	relative_path: String,
	bytes: PackedByteArray
) -> Error:
	var target_path := staging_root.path_join(relative_path)
	if not _is_path_inside_staging(staging_root, target_path):
		return ERR_UNAUTHORIZED
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	return file.get_error()


func _validate_output_path(output_path: String) -> Dictionary:
	if (
		output_path.is_empty()
		or output_path != output_path.strip_edges()
		or output_path.get_extension().to_lower() != "aurora"
	):
		return _failure(
			"invalid_package_path",
			ERR_INVALID_PARAMETER,
			"El archivo exportado debe usar la extensión .aurora."
		)
	if _path_exists(output_path):
		return _failure(
			"destination_exists",
			ERR_ALREADY_EXISTS,
			"El archivo de destino ya existe y no será sobrescrito."
		)
	return _success()


func _temporary_package_path(output_path: String, token: String) -> String:
	var directory := output_path.get_base_dir()
	if directory.is_empty():
		directory = "."
	return directory.path_join(
		".aurora-exporting-%s.aurora" % token
	)


func _make_job_token() -> String:
	var random_bytes := Crypto.new().generate_random_bytes(16)
	var token := random_bytes.hex_encode()
	if token.is_empty():
		token = str(Time.get_ticks_usec())
	return token


func _cleanup_staging(
	staging_root: String,
	created_paths: Array[String]
) -> void:
	if not _is_owned_staging_root(staging_root):
		return
	for index in range(created_paths.size() - 1, -1, -1):
		var target := staging_root.path_join(created_paths[index])
		if _is_path_inside_staging(staging_root, target):
			DirAccess.remove_absolute(_absolute_path(target))
	for relative_directory in ["media", "charts"]:
		var directory_path := staging_root.path_join(relative_directory)
		if _is_path_inside_staging(staging_root, directory_path):
			DirAccess.remove_absolute(_absolute_path(directory_path))
	DirAccess.remove_absolute(_absolute_path(staging_root))


func _remove_temporary_package(
	temporary_path: String,
	final_path: String
) -> void:
	var temporary_absolute := _normalized_absolute(temporary_path)
	var final_absolute := _normalized_absolute(final_path)
	if (
		temporary_absolute.get_base_dir() != final_absolute.get_base_dir()
		or not temporary_absolute.get_file().begins_with(
			".aurora-exporting-"
		)
		or temporary_absolute.get_extension().to_lower() != "aurora"
	):
		return
	if FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(_absolute_path(temporary_path))


func _is_owned_staging_root(staging_root: String) -> bool:
	var allowed_root := _normalized_absolute(
		EXPORT_STAGING_ROOT
	).trim_suffix("/")
	var candidate := _normalized_absolute(staging_root).trim_suffix("/")
	return (
		candidate.begins_with(allowed_root + "/")
		and candidate.get_base_dir() == allowed_root
	)


func _is_path_inside_staging(
	staging_root: String,
	candidate_path: String
) -> bool:
	var normalized_root := _normalized_absolute(
		staging_root
	).trim_suffix("/")
	var normalized_candidate := _normalized_absolute(candidate_path)
	return normalized_candidate.begins_with(normalized_root + "/")


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
	var normalized := _absolute_path(path).replace("\\", "/")
	return normalized.to_lower() if OS.get_name() == "Windows" else normalized


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
	error: int,
	message: String
) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"error_code": error_code,
		"message": message,
	}
