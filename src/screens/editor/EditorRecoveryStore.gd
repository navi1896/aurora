extends RefCounted

class_name EditorRecoveryStore

const RECOVERY_VERSION := 1
const RECOVERY_TYPE := "aurora_editor_recovery"
const TEMP_SUFFIX := ".aurora-tmp"
const BACKUP_SUFFIX := ".aurora-backup"


static func save_snapshot(
	recovery_path: String,
	project_document: Dictionary,
	raw_notes: Array,
	source_project_path: String
) -> Dictionary:
	var normalized_path := recovery_path.simplify_path()
	if normalized_path.is_empty() or normalized_path.get_extension().to_lower() != "json":
		return _failure(ERR_INVALID_PARAMETER, "La ruta de recuperación no es válida.")

	var metadata_value: Variant = project_document.get("metadata", {})
	var media_value: Variant = project_document.get("media", {})
	if not (metadata_value is Dictionary) or not (media_value is Dictionary):
		return _failure(ERR_INVALID_DATA, "El proyecto no contiene metadatos válidos.")
	var metadata: Dictionary = metadata_value
	var key_count := clampi(int(metadata.get("key_count", 4)), 1, 16)
	var normalized_notes := ChartData.normalize_notes(raw_notes, key_count)
	if normalized_notes.size() != raw_notes.size():
		return _failure(ERR_INVALID_DATA, "El chart contiene notas que no se pueden recuperar.")

	var snapshot := {
		"version": RECOVERY_VERSION,
		"type": RECOVERY_TYPE,
		"saved_unix": Time.get_unix_time_from_system(),
		"source_project_path": source_project_path.simplify_path(),
		"project": project_document.duplicate(true),
		"chart": ChartData.make_chart_document(normalized_notes, key_count),
	}
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(normalized_path.get_base_dir())
	)
	if directory_error != OK:
		return _failure(directory_error, "No se pudo crear la carpeta de recuperación.")

	var temp_path := normalized_path + TEMP_SUFFIX
	var backup_path := normalized_path + BACKUP_SUFFIX
	_recover_or_clean_artifacts(normalized_path, temp_path, backup_path)
	var write_error := _write_json(temp_path, snapshot)
	if write_error != OK:
		_cleanup_file(temp_path)
		return _failure(write_error, "No se pudo escribir el borrador de recuperación.")
	var staged = _read_json(temp_path)
	if not _is_valid_snapshot(staged):
		_cleanup_file(temp_path)
		return _failure(ERR_INVALID_DATA, "El borrador temporal no superó la validación.")

	var had_original := FileAccess.file_exists(normalized_path)
	if had_original:
		var backup_error := _rename_file(normalized_path, backup_path)
		if backup_error != OK:
			_cleanup_file(temp_path)
			return _failure(backup_error, "No se pudo proteger el borrador anterior.")
	var install_error := _rename_file(temp_path, normalized_path)
	if install_error != OK:
		if had_original and FileAccess.file_exists(backup_path):
			_rename_file(backup_path, normalized_path)
		_cleanup_file(temp_path)
		return _failure(install_error, "No se pudo publicar el borrador de recuperación.")
	if not _is_valid_snapshot(_read_json(normalized_path)):
		_cleanup_file(normalized_path)
		if had_original and FileAccess.file_exists(backup_path):
			_rename_file(backup_path, normalized_path)
		return _failure(ERR_INVALID_DATA, "El borrador final no superó la validación.")
	_cleanup_file(backup_path)
	return _success({"path": normalized_path, "snapshot": snapshot})


static func load_snapshot(recovery_path: String) -> Dictionary:
	var normalized_path := recovery_path.simplify_path()
	if not FileAccess.file_exists(normalized_path):
		return _failure(ERR_FILE_NOT_FOUND, "No existe un borrador de recuperación.")
	var snapshot_value = _read_json(normalized_path)
	if not _is_valid_snapshot(snapshot_value):
		return _failure(ERR_INVALID_DATA, "El borrador de recuperación está dañado.")
	var snapshot: Dictionary = snapshot_value
	var chart: Dictionary = snapshot["chart"]
	return _success({
		"path": normalized_path,
		"source_project_path": str(snapshot.get("source_project_path", "")),
		"saved_unix": float(snapshot.get("saved_unix", 0.0)),
		"project": (snapshot["project"] as Dictionary).duplicate(true),
		"chart": chart.duplicate(true),
		"notes": ChartData.normalize_notes(
			chart.get("notes", []),
			int(chart.get("key_count", 4))
		),
	})


static func discard_snapshot(recovery_path: String) -> Error:
	var normalized_path := recovery_path.simplify_path()
	for path in [
		normalized_path,
		normalized_path + TEMP_SUFFIX,
		normalized_path + BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				return error
	return OK


static func has_valid_snapshot(recovery_path: String) -> bool:
	return bool(load_snapshot(recovery_path).get("ok", false))


static func _is_valid_snapshot(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var snapshot: Dictionary = value
	if (
		int(snapshot.get("version", 0)) != RECOVERY_VERSION
		or str(snapshot.get("type", "")) != RECOVERY_TYPE
		or not (snapshot.get("project", null) is Dictionary)
		or not (snapshot.get("chart", null) is Dictionary)
	):
		return false
	var project: Dictionary = snapshot["project"]
	var chart: Dictionary = snapshot["chart"]
	if (
		not (project.get("metadata", null) is Dictionary)
		or not (project.get("media", null) is Dictionary)
		or not (chart.get("notes", null) is Array)
	):
		return false
	var key_count := int(chart.get("key_count", 0))
	if key_count < 1 or key_count > 16:
		return false
	var notes: Array = chart["notes"]
	return ChartData.normalize_notes(notes, key_count).size() == notes.size()


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


static func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _success(values: Dictionary = {}) -> Dictionary:
	var result := {"ok": true, "error": OK, "message": ""}
	result.merge(values, true)
	return result


static func _failure(error: Error, message: String) -> Dictionary:
	return {"ok": false, "error": error, "message": message}
