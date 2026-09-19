extends RefCounted

class_name CommunitySubmissionService

const PROJECT_STORE := preload("res://src/screens/editor/EditorProjectStore.gd")
const PACKAGE_EXPORTER_TYPE := preload("res://src/screens/editor/EditorPackageExporter.gd")
const PACKAGE_SERVICE_TYPE := preload("res://src/packages/SongPackageService.gd")

const OUTBOX_ROOT := "user://aurora_submissions/outbox"
const STAGING_ROOT := "user://aurora_submissions/staging"
const MAX_DESCRIPTION_LENGTH := 600

var package_exporter = PACKAGE_EXPORTER_TYPE.new()


func prepare_submission(
	project_path: String,
	publication: Dictionary
) -> Dictionary:
	var validation := _validate_publication(project_path, publication)
	if not bool(validation.get("ok", false)):
		return validation

	var load_result: Dictionary = PROJECT_STORE.load_bundle(project_path)
	if not bool(load_result.get("ok", false)):
		return _failure(
			"project_load_failed",
			int(load_result.get("error", ERR_FILE_CANT_OPEN)),
			str(load_result.get("message", "No se pudo abrir el proyecto."))
		)

	var token := _make_token()
	var staging_directory := STAGING_ROOT.path_join(token)
	var staging_project_path := staging_directory.path_join("project.json")
	var project: Dictionary = (load_result.get("project", {}) as Dictionary).duplicate(true)
	var chart: Dictionary = (load_result.get("chart", {}) as Dictionary).duplicate(true)
	var metadata: Dictionary = (project.get("metadata", {}) as Dictionary).duplicate(true)
	metadata["title"] = str(publication.get("title", "")).strip_edges()
	metadata["artist"] = str(publication.get("artist", "")).strip_edges()
	metadata["chart_author"] = str(publication.get("chart_author", "")).strip_edges()
	project["metadata"] = metadata
	project["chart_path"] = "chart.json"
	project["package_version"] = PACKAGE_SERVICE_TYPE.normalize_package_version(
		str(publication.get("package_version", "1.0.0"))
	)
	var package_id := str(project.get("package_id", "")).strip_edges()

	var stage_result: Dictionary = PROJECT_STORE.save_bundle(
		staging_project_path,
		project,
		chart
	)
	if not bool(stage_result.get("ok", false)):
		_cleanup_staging(staging_directory)
		return _failure(
			"submission_stage_failed",
			int(stage_result.get("error", ERR_CANT_CREATE)),
			str(stage_result.get("message", "No se pudo preparar la publicación."))
		)

	var outbox_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTBOX_ROOT)
	)
	if outbox_error != OK:
		_cleanup_staging(staging_directory)
		return _failure(
			"outbox_create_failed",
			outbox_error,
			"No se pudo preparar la bandeja de publicaciones."
		)

	var base_name := _safe_file_name(
		str(publication.get("title", "cancion"))
	)
	var version := str(project.get("package_version", "1.0.0"))
	var output_path := OUTBOX_ROOT.path_join(
		"%s-v%s-%s.aurora" % [base_name, version, token]
	)
	var export_result: Dictionary = package_exporter.export_saved_project(
		staging_project_path,
		output_path,
		package_id
	)
	_cleanup_staging(staging_directory)
	if not bool(export_result.get("ok", false)):
		return export_result

	var absolute_package_path := ProjectSettings.globalize_path(output_path)
	var package_file := FileAccess.open(output_path, FileAccess.READ)
	if package_file == null:
		_remove_file(output_path)
		return _failure(
			"submission_package_missing",
			FileAccess.get_open_error(),
			"El paquete se creó, pero no pudo verificarse."
		)
	var size_bytes := package_file.get_length()
	package_file.close()
	var submission_record := {
		"type": "aurora_community_submission",
		"format_version": 1,
		"status": "prepared",
		"title": str(publication.get("title", "")).strip_edges(),
		"artist": str(publication.get("artist", "")).strip_edges(),
		"chart_author": str(publication.get("chart_author", "")).strip_edges(),
		"license": str(publication.get("license", "")).strip_edges(),
		"description": str(publication.get("description", "")).strip_edges(),
		"package_version": version,
		"package_file": output_path.get_file(),
		"package_path": output_path,
		"size_bytes": size_bytes,
		"sha256": FileAccess.get_sha256(absolute_package_path),
		"source_project_path": project_path,
		"rights_confirmed": true,
		"created_unix": int(Time.get_unix_time_from_system()),
	}
	var record_path := output_path.trim_suffix(".aurora") + ".submission.json"
	var record_error := _write_json(record_path, submission_record)
	if record_error != OK:
		_remove_file(output_path)
		return _failure(
			"submission_record_failed",
			record_error,
			"No se pudo guardar la ficha de publicación."
		)

	var result := export_result.duplicate(true)
	result["submission_path"] = record_path
	result["package_path"] = output_path
	result["size_bytes"] = size_bytes
	result["sha256"] = submission_record["sha256"]
	result["prepared"] = true
	return result


func _validate_publication(
	project_path: String,
	publication: Dictionary
) -> Dictionary:
	if project_path.strip_edges().is_empty():
		return _failure(
			"missing_project",
			ERR_INVALID_PARAMETER,
			"Selecciona una canción creada en el editor."
		)
	for field in ["title", "artist", "chart_author", "license"]:
		if str(publication.get(field, "")).strip_edges().is_empty():
			return _failure(
				"missing_%s" % field,
				ERR_INVALID_DATA,
				"Completa todos los datos obligatorios."
			)
	if not PACKAGE_SERVICE_TYPE.is_valid_package_version(
		str(publication.get("package_version", ""))
	):
		return _failure(
			"invalid_package_version",
			ERR_INVALID_DATA,
			"La versión debe usar el formato 1.0.0."
		)
	if str(publication.get("description", "")).length() > MAX_DESCRIPTION_LENGTH:
		return _failure(
			"description_too_long",
			ERR_INVALID_DATA,
			"La descripción es demasiado larga."
		)
	if not bool(publication.get("rights_confirmed", false)):
		return _failure(
			"rights_not_confirmed",
			ERR_UNAUTHORIZED,
			"Confirma que eres autor o tienes permiso para compartir los archivos."
		)
	return {"ok": true}


func _make_token() -> String:
	return "%d-%08x" % [
		int(Time.get_unix_time_from_system()),
		randi(),
	]


func _safe_file_name(value: String) -> String:
	var output := ""
	for character in value.strip_edges().to_lower():
		if character.is_valid_identifier() or character.is_valid_int():
			output += character
		elif character in [" ", "-", "_"] and not output.ends_with("-"):
			output += "-"
	output = output.trim_prefix("-").trim_suffix("-")
	return output if not output.is_empty() else "cancion"


func _cleanup_staging(directory_path: String) -> void:
	for file_name in ["project.json", "chart.json"]:
		_remove_file(directory_path.path_join(file_name))
	var absolute_directory := ProjectSettings.globalize_path(directory_path)
	if DirAccess.dir_exists_absolute(absolute_directory):
		DirAccess.remove_absolute(absolute_directory)


func _remove_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _write_json(path: String, value: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t", true))
	file.close()
	return OK


func _failure(code: String, error: Error, message: String) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"error": error,
		"message": message,
	}
