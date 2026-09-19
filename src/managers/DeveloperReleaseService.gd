extends RefCounted

class_name DeveloperReleaseService

const CONFIG_PATH := "user://aurora_developer.json"
const RESULT_PATH := "user://aurora_developer_publish_result.json"

var _config: Dictionary = {}
var _last_result_fingerprint := ""


func refresh() -> Dictionary:
	_config = {}
	if not FileAccess.file_exists(CONFIG_PATH):
		return {"enabled": false, "message": ""}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {"enabled": false, "message": "No se pudo leer el perfil de desarrollador."}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"enabled": false, "message": "El perfil de desarrollador no es válido."}
	var project_root := str(parsed.get("project_root", "")).strip_edges()
	var publish_script := str(parsed.get("publish_script", "")).strip_edges()
	var godot_executable := str(parsed.get("godot_executable", "")).strip_edges()
	var repository := str(parsed.get("repository", "")).strip_edges()
	if (
		not bool(parsed.get("developer_mode", false))
		or project_root.is_empty()
		or publish_script.is_empty()
		or godot_executable.is_empty()
		or repository.is_empty()
		or not FileAccess.file_exists(project_root.path_join("project.godot"))
		or not FileAccess.file_exists(publish_script)
		or not FileAccess.file_exists(godot_executable)
	):
		return {
			"enabled": false,
			"message": "El perfil de desarrollador está incompleto.",
		}
	_config = parsed.duplicate(true)
	return {"enabled": true, "message": ""}


func is_enabled() -> bool:
	return not _config.is_empty()


func get_publisher_name() -> String:
	return str(_config.get("publisher_name", "Aurora Project")).strip_edges()


func start_publish(version: String) -> Dictionary:
	if not is_enabled():
		return _failure("La publicación local no está habilitada en este equipo.")
	var clean_version := version.strip_edges()
	if not _is_semantic_version(clean_version):
		return _failure("La versión actual no tiene el formato MAYOR.MENOR.PARCHE.")
	var powershell := OS.get_environment("SystemRoot").path_join(
		"System32/WindowsPowerShell/v1.0/powershell.exe"
	)
	if not FileAccess.file_exists(powershell):
		return _failure("No se encontró PowerShell para preparar la publicación.")
	var result_absolute := ProjectSettings.globalize_path(RESULT_PATH)
	if FileAccess.file_exists(result_absolute):
		DirAccess.remove_absolute(result_absolute)
	_last_result_fingerprint = ""
	var arguments := PackedStringArray([
		"-NoProfile",
		"-WindowStyle",
		"Hidden",
		"-ExecutionPolicy",
		"RemoteSigned",
		"-File",
		str(_config.get("publish_script", "")),
		"-ProjectRoot",
		str(_config.get("project_root", "")),
		"-Repository",
		str(_config.get("repository", "")),
		"-GodotExecutable",
		str(_config.get("godot_executable", "")),
		"-Version",
		clean_version,
		"-ResultPath",
		result_absolute,
	])
	var process_id := OS.create_process(powershell, arguments, false)
	if process_id <= 0:
		return _failure("No se pudo iniciar la publicación local.")
	return {
		"ok": true,
		"process_id": process_id,
		"message": "Publicación iniciada.",
	}


func poll_result() -> Dictionary:
	var result_absolute := ProjectSettings.globalize_path(RESULT_PATH)
	if not FileAccess.file_exists(result_absolute):
		return {}
	var file := FileAccess.open(result_absolute, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	var fingerprint := text.sha256_text()
	if fingerprint == _last_result_fingerprint:
		return {}
	_last_result_fingerprint = fingerprint
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {"ok": false, "message": "La publicación terminó sin un informe válido."}


func _is_semantic_version(value: String) -> bool:
	var parts := value.split(".", false)
	if parts.size() != 3:
		return false
	for part in parts:
		if part.is_empty() or not part.is_valid_int() or int(part) < 0:
			return false
	return true


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
