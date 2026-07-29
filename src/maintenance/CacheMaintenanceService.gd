extends RefCounted

class_name CacheMaintenanceService

const DEFAULT_EDITOR_ROOT := "user://aurora_editor"
const DEFAULT_MEDIA_ROOT := "user://aurora_editor/media"
const DEFAULT_WAVEFORM_ROOT := "user://aurora_editor/waveform_cache"
const DEFAULT_RECOVERY_PATH := "user://aurora_editor/.recovery/recovery.json"


func build_cleanup_plan(
	editor_root: String = DEFAULT_EDITOR_ROOT,
	media_root: String = DEFAULT_MEDIA_ROOT,
	waveform_root: String = DEFAULT_WAVEFORM_ROOT,
	recovery_path: String = DEFAULT_RECOVERY_PATH
) -> Dictionary:
	var normalized_media_root := _normalized_absolute(media_root)
	var normalized_waveform_root := _normalized_absolute(waveform_root)
	if (
		normalized_media_root.is_empty()
		or normalized_waveform_root.is_empty()
		or normalized_media_root == normalized_waveform_root
	):
		return _failure("invalid_cache_roots", ERR_INVALID_PARAMETER)

	var protected_paths: Dictionary = {}
	for document_path in _find_editor_documents(editor_root, recovery_path):
		var document: Variant = _read_json_document(document_path)
		if document != null:
			_collect_referenced_cache_paths(
				document,
				normalized_media_root,
				protected_paths
			)

	var removable_files: Array[Dictionary] = []
	for file_path in _list_direct_files(media_root):
		var normalized_path := _normalized_absolute(file_path)
		if protected_paths.has(normalized_path):
			continue
		if _is_manifest_for_protected_media(normalized_path, protected_paths):
			continue
		removable_files.append(_file_record(normalized_path, "media"))

	for file_path in _list_direct_files(waveform_root):
		var normalized_path := _normalized_absolute(file_path)
		removable_files.append(_file_record(normalized_path, "waveform"))

	removable_files.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("path", "")) < str(right.get("path", ""))
	)
	var total_bytes := 0
	for record in removable_files:
		total_bytes += int(record.get("size_bytes", 0))
	return {
		"ok": true,
		"files": removable_files,
		"file_count": removable_files.size(),
		"total_bytes": total_bytes,
		"protected_file_count": protected_paths.size(),
		"allowed_roots": [
			normalized_media_root,
			normalized_waveform_root,
		],
	}


func execute_cleanup_plan(plan: Dictionary) -> Dictionary:
	if not bool(plan.get("ok", false)):
		return _failure("invalid_plan", ERR_INVALID_PARAMETER)
	var allowed_roots_value: Variant = plan.get("allowed_roots", null)
	var files_value: Variant = plan.get("files", null)
	if not (allowed_roots_value is Array) or not (files_value is Array):
		return _failure("invalid_plan", ERR_INVALID_PARAMETER)

	var allowed_roots: Array[String] = []
	for root_value in allowed_roots_value:
		var root := _normalized_absolute(str(root_value)).trim_suffix("/")
		if root.is_empty():
			return _failure("invalid_plan_root", ERR_INVALID_PARAMETER)
		allowed_roots.append(root)

	var deleted_count := 0
	var deleted_bytes := 0
	var skipped_count := 0
	var failures: Array[Dictionary] = []
	for record_value in files_value:
		if not (record_value is Dictionary):
			failures.append({"path": "", "error": int(ERR_INVALID_DATA)})
			continue
		var record: Dictionary = record_value
		var path := _normalized_absolute(str(record.get("path", "")))
		if not _is_direct_child_of_any(path, allowed_roots):
			failures.append({"path": path, "error": int(ERR_UNAUTHORIZED)})
			continue
		if not FileAccess.file_exists(path):
			skipped_count += 1
			continue
		var size_before := _file_size(path)
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			failures.append({"path": path, "error": int(remove_error)})
			continue
		deleted_count += 1
		deleted_bytes += maxi(size_before, 0)

	return {
		"ok": failures.is_empty(),
		"deleted_count": deleted_count,
		"deleted_bytes": deleted_bytes,
		"skipped_count": skipped_count,
		"failures": failures,
	}


func _find_editor_documents(editor_root: String, recovery_path: String) -> Array[String]:
	var paths: Array[String] = []
	var root := DirAccess.open(editor_root)
	if root != null:
		root.list_dir_begin()
		var entry := root.get_next()
		while not entry.is_empty():
			if not entry.begins_with("."):
				var candidate := editor_root.path_join(entry)
				if root.current_is_dir():
					var project_path := candidate.path_join("project.json")
					if FileAccess.file_exists(project_path):
						paths.append(project_path)
				elif entry.get_extension().to_lower() == "json":
					paths.append(candidate)
			entry = root.get_next()
		root.list_dir_end()
	if FileAccess.file_exists(recovery_path):
		paths.append(recovery_path)
	return paths


func _read_json_document(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data


func _collect_referenced_cache_paths(
	value: Variant,
	media_root: String,
	output: Dictionary
) -> void:
	if value is Dictionary:
		for child in (value as Dictionary).values():
			_collect_referenced_cache_paths(child, media_root, output)
		return
	if value is Array:
		for child in value:
			_collect_referenced_cache_paths(child, media_root, output)
		return
	if not (value is String) and not (value is StringName):
		return
	var candidate := _normalized_absolute(str(value))
	if _is_direct_child(candidate, media_root):
		output[candidate] = true


func _list_direct_files(root_path: String) -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return paths
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with(".") and not directory.current_is_dir():
			paths.append(root_path.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()
	return paths


func _is_manifest_for_protected_media(
	path: String,
	protected_paths: Dictionary
) -> bool:
	if not path.ends_with(".manifest.json"):
		return false
	var output_base := path.trim_suffix(".manifest.json")
	for protected_path_value in protected_paths:
		var protected_path := str(protected_path_value)
		if protected_path.get_basename() == output_base:
			return true
	return false


func _file_record(path: String, kind: String) -> Dictionary:
	return {
		"path": path,
		"kind": kind,
		"size_bytes": maxi(_file_size(path), 0),
	}


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	return file.get_length()


func _is_direct_child_of_any(path: String, roots: Array[String]) -> bool:
	for root in roots:
		if _is_direct_child(path, root):
			return true
	return false


func _is_direct_child(path: String, root: String) -> bool:
	var normalized_path := _normalized_absolute(path).trim_suffix("/")
	var normalized_root := _normalized_absolute(root).trim_suffix("/")
	return (
		not normalized_path.is_empty()
		and not normalized_root.is_empty()
		and normalized_path != normalized_root
		and normalized_path.get_base_dir() == normalized_root
	)


func _normalized_absolute(path: String) -> String:
	var stripped := path.strip_edges()
	if stripped.is_empty():
		return ""
	return ProjectSettings.globalize_path(
		stripped
	).simplify_path().replace("\\", "/")


func _failure(error_code: String, error: Error) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"error": int(error),
	}
