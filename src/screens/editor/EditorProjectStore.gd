extends RefCounted

class_name EditorProjectStore

const PROJECT_VERSION := 3
const PROJECT_TYPE := "aurora_editor_project"
const PROJECT_FILE_NAME := "project.json"
const CHART_FILE_NAME := "chart.json"
const TEMP_SUFFIX := ".aurora-tmp"
const BACKUP_SUFFIX := ".aurora-backup"


static func make_new_project_path(editor_root: String, slug: String) -> Dictionary:
	var safe_slug := slug.strip_edges()
	if safe_slug.is_empty():
		return _failure(ERR_INVALID_PARAMETER, "El nombre del proyecto está vacío.")
	var project_directory := "%s/%s" % [editor_root.trim_suffix("/"), safe_slug]
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(project_directory)):
		return _failure(
			ERR_ALREADY_EXISTS,
			"Ya existe un proyecto llamado %s. Usa otro título." % safe_slug
		)
	return _success({
		"project_path": "%s/%s" % [project_directory, PROJECT_FILE_NAME],
		"chart_path": "%s/%s" % [project_directory, CHART_FILE_NAME],
	})


static func save_bundle(
	project_path: String,
	project_document: Dictionary,
	chart_document: Dictionary
) -> Dictionary:
	var normalized_project_path := project_path.simplify_path()
	if (
		normalized_project_path.is_empty()
		or normalized_project_path.get_file() != PROJECT_FILE_NAME
	):
		return _failure(ERR_INVALID_PARAMETER, "La ruta del proyecto no es válida.")

	var chart_path := _resolve_chart_path(
		normalized_project_path,
		str(project_document.get("chart_path", CHART_FILE_NAME))
	)
	if chart_path == normalized_project_path:
		return _failure(ERR_INVALID_PARAMETER, "El proyecto y el chart no pueden usar el mismo archivo.")

	var normalized_chart := _normalize_chart_document(chart_document)
	if not _is_well_formed_chart_document(normalized_chart):
		return _failure(ERR_INVALID_DATA, "El chart contiene datos no válidos.")

	var normalized_project := project_document.duplicate(true)
	normalized_project["version"] = PROJECT_VERSION
	normalized_project["type"] = PROJECT_TYPE
	normalized_project["chart_path"] = chart_path
	normalized_project.erase("notes")
	if not _is_well_formed_project_document(normalized_project):
		return _failure(ERR_INVALID_DATA, "El proyecto contiene datos no válidos.")

	var project_directory := normalized_project_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(project_directory)
	)
	if directory_error != OK:
		return _failure(directory_error, "No se pudo crear la carpeta del proyecto.")

	var chart_directory := chart_path.get_base_dir()
	if chart_directory != project_directory:
		directory_error = DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(chart_directory)
		)
		if directory_error != OK:
			return _failure(directory_error, "No se pudo crear la carpeta del chart.")

	var project_temp := normalized_project_path + TEMP_SUFFIX
	var chart_temp := chart_path + TEMP_SUFFIX
	var project_backup := normalized_project_path + BACKUP_SUFFIX
	var chart_backup := chart_path + BACKUP_SUFFIX
	_recover_or_clean_artifacts(normalized_project_path, project_temp, project_backup)
	_recover_or_clean_artifacts(chart_path, chart_temp, chart_backup)

	var write_error := _write_json(project_temp, normalized_project)
	if write_error != OK:
		_cleanup_file(project_temp)
		_cleanup_file(chart_temp)
		return _failure(write_error, "No se pudo preparar el archivo del proyecto.")
	write_error = _write_json(chart_temp, normalized_chart)
	if write_error != OK:
		_cleanup_file(project_temp)
		_cleanup_file(chart_temp)
		return _failure(write_error, "No se pudo preparar el archivo del chart.")

	var staged_project = _read_json(project_temp)
	var staged_chart = _read_json(chart_temp)
	if (
		not _is_well_formed_project_document(staged_project)
		or not _is_well_formed_chart_document(staged_chart)
	):
		_cleanup_file(project_temp)
		_cleanup_file(chart_temp)
		return _failure(ERR_INVALID_DATA, "La validación del guardado temporal falló.")

	var final_paths: Array[String] = [normalized_project_path, chart_path]
	var temp_paths: Array[String] = [project_temp, chart_temp]
	var backup_paths: Array[String] = [project_backup, chart_backup]
	var had_original: Array[bool] = [false, false]

	for index in range(final_paths.size()):
		var final_path := final_paths[index]
		if not FileAccess.file_exists(final_path):
			continue
		had_original[index] = true
		var backup_error := _rename_file(final_path, backup_paths[index])
		if backup_error != OK:
			_restore_backups(final_paths, backup_paths, had_original)
			_cleanup_file(project_temp)
			_cleanup_file(chart_temp)
			return _failure(backup_error, "No se pudo proteger el guardado anterior.")

	var installed_count := 0
	for index in range(temp_paths.size()):
		var install_error := _rename_file(temp_paths[index], final_paths[index])
		if install_error != OK:
			for installed_index in range(installed_count):
				_cleanup_file(final_paths[installed_index])
			_restore_backups(final_paths, backup_paths, had_original)
			_cleanup_file(project_temp)
			_cleanup_file(chart_temp)
			return _failure(install_error, "No se pudo completar el guardado.")
		installed_count += 1

	var saved_project = _read_json(normalized_project_path)
	var saved_chart = _read_json(chart_path)
	if (
		not _is_well_formed_project_document(saved_project)
		or not _is_well_formed_chart_document(saved_chart)
	):
		for final_path in final_paths:
			_cleanup_file(final_path)
		_restore_backups(final_paths, backup_paths, had_original)
		return _failure(ERR_INVALID_DATA, "Los archivos finales no superaron la validación.")

	for backup_path in backup_paths:
		_cleanup_file(backup_path)
	return _success({
		"project_path": normalized_project_path,
		"chart_path": chart_path,
		"project": saved_project,
		"chart": saved_chart,
	})


static func load_bundle(project_path: String) -> Dictionary:
	var normalized_project_path := project_path.simplify_path()
	if not FileAccess.file_exists(normalized_project_path):
		return _failure(ERR_FILE_NOT_FOUND, "No se encontró el proyecto.")

	var parsed_project = _read_json(normalized_project_path)
	if not _is_well_formed_project_document(parsed_project, true):
		return _failure(ERR_INVALID_DATA, "El proyecto JSON no es válido.")
	var project: Dictionary = parsed_project
	var chart_path := _resolve_chart_path(
		normalized_project_path,
		str(project.get("chart_path", CHART_FILE_NAME))
	)

	var chart: Dictionary
	var chart_exists := FileAccess.file_exists(chart_path)
	if chart_exists:
		var parsed_chart = _read_json(chart_path)
		if not _is_well_formed_chart_document(parsed_chart):
			return _failure(ERR_INVALID_DATA, "El chart JSON no es válido.")
		chart = parsed_chart
	elif int(project.get("version", 1)) <= 2 and project.get("notes", null) is Array:
		var metadata: Dictionary = project.get("metadata", {})
		chart = ChartData.make_chart_document(
			project.get("notes", []),
			int(metadata.get("key_count", 4))
		)
	else:
		return _failure(ERR_FILE_NOT_FOUND, "No se encontró el chart del proyecto.")

	var metadata: Dictionary = project.get("metadata", {})
	var normalized_notes := ChartData.normalize_notes(
		chart.get("notes", []),
		int(metadata.get("key_count", chart.get("key_count", 4)))
	)
	return _success({
		"project_path": normalized_project_path,
		"chart_path": chart_path,
		"project": project,
		"chart": chart,
		"notes": normalized_notes,
		"needs_migration": (
			int(project.get("version", 1)) < PROJECT_VERSION
			or project.has("notes")
			or not chart_exists
		),
	})


static func _normalize_chart_document(chart_document: Dictionary) -> Dictionary:
	var key_count := clampi(int(chart_document.get("key_count", 4)), 1, 16)
	return ChartData.make_chart_document(
		chart_document.get("notes", []),
		key_count,
		float(chart_document.get("offset_seconds", 0.0))
	)


static func _is_well_formed_project_document(
	document_value: Variant,
	allow_legacy: bool = false
) -> bool:
	if not (document_value is Dictionary):
		return false
	var document: Dictionary = document_value
	if str(document.get("type", "")) != PROJECT_TYPE:
		return false
	if not (document.get("metadata", null) is Dictionary):
		return false
	if not (document.get("media", null) is Dictionary):
		return false
	if not allow_legacy and int(document.get("version", 0)) != PROJECT_VERSION:
		return false
	return not str(document.get("chart_path", "")).strip_edges().is_empty()


static func _is_well_formed_chart_document(document_value: Variant) -> bool:
	if not (document_value is Dictionary):
		return false
	var document: Dictionary = document_value
	if not (document.get("notes", null) is Array):
		return false
	var key_count := int(document.get("key_count", 0))
	if key_count < 1 or key_count > 16:
		return false
	var normalized := ChartData.normalize_notes(document["notes"], key_count)
	return (
		normalized.size() == (document["notes"] as Array).size()
		and ChartData.is_valid_chart_document(document, key_count)
	)


static func _resolve_chart_path(project_path: String, stored_chart_path: String) -> String:
	var clean_path := stored_chart_path.strip_edges()
	if clean_path.is_empty():
		clean_path = CHART_FILE_NAME
	if clean_path.contains("://") or clean_path.is_absolute_path():
		return clean_path.simplify_path()
	return ("%s/%s" % [project_path.get_base_dir(), clean_path]).simplify_path()


static func _write_json(path: String, data: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	return OK


static func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


static func _rename_file(source_path: String, target_path: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(target_path)
	)


static func _recover_or_clean_artifacts(
	final_path: String,
	temp_path: String,
	backup_path: String
) -> void:
	_cleanup_file(temp_path)
	if not FileAccess.file_exists(backup_path):
		return
	if FileAccess.file_exists(final_path):
		_cleanup_file(backup_path)
	else:
		_rename_file(backup_path, final_path)


static func _restore_backups(
	final_paths: Array[String],
	backup_paths: Array[String],
	had_original: Array[bool]
) -> void:
	for index in range(final_paths.size()):
		if not had_original[index] or not FileAccess.file_exists(backup_paths[index]):
			continue
		_cleanup_file(final_paths[index])
		_rename_file(backup_paths[index], final_paths[index])


static func _cleanup_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _success(values: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": true,
		"error": OK,
		"message": "",
	}
	result.merge(values, true)
	return result


static func _failure(error: Error, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"message": message,
	}
