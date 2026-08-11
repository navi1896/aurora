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
