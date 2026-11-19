extends RefCounted

class_name LocalPackageShareService

const EDITOR_EXPORTER_TYPE := preload(
	"res://src/screens/editor/EditorPackageExporter.gd"
)
const PACKAGE_SERVICE_TYPE := preload(
	"res://src/packages/SongPackageService.gd"
)


func export_descriptor(descriptor: Dictionary, output_path: String) -> Dictionary:
	var kind := str(descriptor.get("kind", ""))
	match kind:
		"editor":
			var exporter = EDITOR_EXPORTER_TYPE.new()
			return exporter.export_saved_project(
				str(descriptor.get("project_path", "")),
				output_path,
				str(descriptor.get("package_id", ""))
			)
		"installed_package":
			return _export_installed_package(
				str(descriptor.get("package_root", "")),
				output_path
			)
		_:
			return _failure(
				ERR_INVALID_PARAMETER,
				"La canción seleccionada no se puede compartir como paquete local."
			)


func export_batch(entries: Array[Dictionary], smart_upload: bool = false) -> Dictionary:
	var results: Array[Dictionary] = []
	var exported := 0
	var skipped := 0
	var uploaded_titles: PackedStringArray = []
	var skipped_titles: PackedStringArray = []
	var service = PACKAGE_SERVICE_TYPE.new()
	for entry in entries:
		var output_path := str(entry.get("path", ""))
		var title := str(entry.get("title", output_path.get_file().get_basename()))
		var descriptor: Dictionary = entry.get("descriptor", {})
		var result: Dictionary
		if FileAccess.file_exists(output_path):
			if smart_upload and _needs_upload_update(descriptor, output_path, service):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(output_path))
				result = export_descriptor(descriptor, output_path)
			else:
				result = _failure(ERR_ALREADY_EXISTS, "Ya está al día; no hizo falta subirlo.")
				result["error_code"] = "destination_exists"
		else:
			result = export_descriptor(descriptor, output_path)
		if bool(result.get("ok", false)):
			exported += 1
			uploaded_titles.append(title)
		elif str(result.get("error_code", "")) == "destination_exists":
			skipped += 1
			skipped_titles.append(title)
		results.append({
			"path": output_path,
			"title": title,
			"result": result,
		})
	return {
		"ok": true,
		"batch": true,
		"smart_upload": smart_upload,
		"exported": exported,
		"skipped": skipped,
		"failed": entries.size() - exported - skipped,
		"uploaded_titles": uploaded_titles,
		"skipped_titles": skipped_titles,
		"results": results,
	}


func _needs_upload_update(descriptor: Dictionary, existing_path: String, service) -> bool:
	if str(descriptor.get("kind", "")) == "editor":
		return true
	var existing_check: Dictionary = service.validate_package_manifest(existing_path)
	if not bool(existing_check.get("ok", false)):
		return true
	var package_root := str(descriptor.get("package_root", ""))
	var local_check: Dictionary = service.validate_staging(package_root, false)
	if not bool(local_check.get("ok", false)):
		return false
	var existing_ver := str(existing_check.get("manifest", {}).get("package_version", "1.0.0"))
	var local_ver := str(local_check.get("manifest", {}).get("package_version", "1.0.0"))
	if PACKAGE_SERVICE_TYPE.compare_package_versions(local_ver, existing_ver) > 0:
		return true
	var existing_mtime := int(FileAccess.get_modified_time(existing_path))
	var local_manifest_mtime := int(
		FileAccess.get_modified_time(package_root.path_join(PACKAGE_SERVICE_TYPE.MANIFEST_PATH))
	)
	return local_manifest_mtime > existing_mtime


func _export_installed_package(
	package_root: String,
	output_path: String
) -> Dictionary:
	if package_root.is_empty():
		return _failure(
			ERR_INVALID_PARAMETER,
			"No se encontró la instalación local del nivel."
		)
	var output_directory := output_path.get_base_dir()
	if output_directory.is_empty():
		output_directory = "."
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(output_directory)
	)
	if directory_error != OK:
		return _failure(
			directory_error,
			"No se pudo preparar la carpeta de destino."
		)
	var service = PACKAGE_SERVICE_TYPE.new()
	var validation: Dictionary = service.validate_staging(package_root, true)
	if not bool(validation.get("ok", false)):
		return validation
	var result: Dictionary = service.export_package(
		package_root,
		validation.get("manifest", {}),
		output_path
	)
	if bool(result.get("ok", false)):
		result["package_path"] = output_path
	return result


func _failure(error: int, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"message": message,
	}
