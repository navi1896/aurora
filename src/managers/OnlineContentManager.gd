extends Node

class_name OnlineContentManager

signal catalog_received(result: Dictionary)
signal package_download_progress(downloaded: int, total: int)
signal package_download_finished(result: Dictionary)
signal update_checked(result: Dictionary)
signal update_download_progress(downloaded: int, total: int)
signal update_download_finished(result: Dictionary)

const MANIFEST_SERVICE = preload("res://src/online/OnlineManifestService.gd")
const CATALOG_URL := (
	"https://raw.githubusercontent.com/navi1896/aurora/main/community/catalog.json"
)
const LATEST_RELEASE_URL := (
	"https://api.github.com/repos/navi1896/aurora/releases/latest"
)
const DOWNLOAD_DIRECTORY := "user://aurora_downloads"
const UPDATE_DIRECTORY := "user://aurora_updates"
var catalog_request: HTTPRequest
var package_request: HTTPRequest
var release_request: HTTPRequest
var update_request: HTTPRequest
var catalog_entries: Array[Dictionary] = []
var latest_release: Dictionary = {}
var downloaded_update_path := ""
var has_checked_latest := false
var _package_download_entry: Dictionary = {}
var _package_part_path := ""
var _update_part_path := ""
var request_headers := PackedStringArray([
	"Accept: application/vnd.github+json",
	"X-GitHub-Api-Version: 2026-03-10",
	"User-Agent: Aurora-Rhythm-Game",
])


func _ready() -> void:
	catalog_request = _make_request("CatalogRequest", _on_catalog_request_completed)
	package_request = _make_request("PackageRequest", _on_package_request_completed)
	release_request = _make_request("ReleaseRequest", _on_release_request_completed)
	update_request = _make_request("UpdateRequest", _on_update_request_completed)


func request_catalog() -> Error:
	if catalog_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return ERR_BUSY
	catalog_request.body_size_limit = MANIFEST_SERVICE.MAX_CATALOG_BYTES
	var error := catalog_request.request(CATALOG_URL, request_headers)
	if error != OK:
		catalog_received.emit(_failure("catalog_start", "No se pudo iniciar la consulta del catálogo."))
	return error


func download_package(entry: Dictionary) -> Error:
	if package_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return ERR_BUSY
	var validation: Dictionary = MANIFEST_SERVICE.validate_catalog_entry(entry)
	if not bool(validation.get("ok", false)):
		package_download_finished.emit(validation)
		return ERR_INVALID_DATA
	_package_download_entry = validation.get("entry", {})
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DOWNLOAD_DIRECTORY)
	)
	if directory_error != OK:
		package_download_finished.emit(_failure("download_directory", "No se pudo preparar la carpeta de descargas."))
		return directory_error
	var file_name := "%s-v%s.aurora" % [
		str(_package_download_entry.get("package_id", "package")),
		str(_package_download_entry.get("package_version", "1.0.0")),
	]
	var final_path := DOWNLOAD_DIRECTORY.path_join(file_name)
	if FileAccess.file_exists(final_path) and _verify_file(final_path, _package_download_entry):
		call_deferred("_emit_cached_package", final_path)
		return OK
	_package_part_path = final_path + ".part"
	_remove_file(_package_part_path)
	package_request.download_file = _package_part_path
	package_request.body_size_limit = int(_package_download_entry.get("size_bytes", 0)) + 1
	var error := package_request.request(
		str(_package_download_entry.get("download_url", "")),
		request_headers
	)
	if error != OK:
		package_request.download_file = ""
		_package_part_path = ""
		package_download_finished.emit(_failure("download_start", "No se pudo iniciar la descarga."))
	return error


func request_latest_release() -> Error:
	if release_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return ERR_BUSY
	release_request.body_size_limit = MANIFEST_SERVICE.MAX_CATALOG_BYTES
	var error := release_request.request(LATEST_RELEASE_URL, request_headers)
	if error != OK:
		update_checked.emit(_failure("release_start", "No se pudo consultar la versión más reciente."))
	return error


func download_latest_update() -> Error:
	if update_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return ERR_BUSY
	if not bool(latest_release.get("download_available", false)):
		update_download_finished.emit(_failure("update_unavailable", "La versión no tiene una descarga verificada para Windows."))
		return ERR_UNAVAILABLE
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(UPDATE_DIRECTORY)
	)
	if directory_error != OK:
		update_download_finished.emit(_failure("update_directory", "No se pudo preparar la carpeta de actualización."))
		return directory_error
	var asset_name := str(latest_release.get("asset_name", "Aurora-Windows.zip")).get_file()
	var final_path := UPDATE_DIRECTORY.path_join(asset_name)
	if FileAccess.file_exists(final_path) and _verify_file(final_path, latest_release):
		downloaded_update_path = final_path
		call_deferred("_emit_cached_update", final_path)
		return OK
	_update_part_path = final_path + ".part"
	_remove_file(_update_part_path)
	update_request.download_file = _update_part_path
	update_request.body_size_limit = int(latest_release.get("size_bytes", 0)) + 1
	var error := update_request.request(
		str(latest_release.get("download_url", "")),
		request_headers
	)
	if error != OK:
		update_request.download_file = ""
		_update_part_path = ""
		update_download_finished.emit(_failure("update_start", "No se pudo iniciar la descarga de la actualización."))
	return error


func open_release_page() -> Error:
	var url := str(latest_release.get("html_url", MANIFEST_SERVICE.REPOSITORY_URL + "/releases"))
	return OS.shell_open(url)


func apply_downloaded_update() -> Dictionary:
	if downloaded_update_path.is_empty() or not FileAccess.file_exists(downloaded_update_path):
		return _failure("update_missing", "La actualización todavía no se ha descargado.")
	if OS.get_name() != "Windows" or OS.has_feature("editor"):
		return _failure("update_environment", "La instalación automática solo se activa en la versión exportada para Windows.")
	if not _verify_file(downloaded_update_path, latest_release):
		return _failure("update_hash", "La actualización descargada no superó la verificación SHA-256.")
	var executable_path := OS.get_executable_path()
	var install_directory := executable_path.get_base_dir()
	if not FileAccess.file_exists(executable_path):
		return _failure("install_directory", "No se pudo identificar la instalación actual.")
	var script_result := _write_update_scripts(
		ProjectSettings.globalize_path(downloaded_update_path),
		install_directory,
		executable_path
	)
	if not bool(script_result.get("ok", false)):
		return script_result
	var process_id := OS.create_process(
		"powershell.exe",
		PackedStringArray([
			"-NoProfile",
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			str(script_result.get("script_path", "")),
		]),
		false
	)
	if process_id <= 0:
		return _failure("updater_launch", "No se pudo iniciar el instalador de la actualización.")
	get_tree().quit()
	return _success({"launched": true})


func _process(_delta: float) -> void:
	if package_request != null and package_request.get_downloaded_bytes() > 0:
		package_download_progress.emit(
			package_request.get_downloaded_bytes(),
			int(_package_download_entry.get("size_bytes", 0))
		)
	if update_request != null and update_request.get_downloaded_bytes() > 0:
		update_download_progress.emit(
			update_request.get_downloaded_bytes(),
			int(latest_release.get("size_bytes", 0))
		)


func _make_request(request_name: String, callback: Callable) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.name = request_name
	request.timeout = 25.0
	request.max_redirects = 4
	request.use_threads = true
	request.request_completed.connect(callback)
	add_child(request)
	return request


func _on_catalog_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var fallback := _load_bundled_catalog()
		if bool(fallback.get("ok", false)):
			fallback["offline_fallback"] = true
			catalog_entries.assign(fallback.get("entries", []))
			catalog_received.emit(fallback)
		else:
			catalog_received.emit(_http_failure("catalog_http", response_code, "No se pudo cargar el catálogo comunitario."))
		return
	var parsed: Dictionary = MANIFEST_SERVICE.parse_catalog_bytes(body)
	if bool(parsed.get("ok", false)):
		catalog_entries.assign(parsed.get("entries", []))
	catalog_received.emit(parsed)


func _on_package_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	package_request.download_file = ""
	var part_path := _package_part_path
	_package_part_path = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_remove_file(part_path)
		package_download_finished.emit(_http_failure("package_http", response_code, "No se pudo descargar la canción."))
		return
	if not _verify_file(part_path, _package_download_entry):
		_remove_file(part_path)
		package_download_finished.emit(_failure("package_integrity", "La descarga no coincide con su tamaño o SHA-256."))
		return
	var final_path := part_path.trim_suffix(".part")
	_remove_file(final_path)
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(part_path),
		ProjectSettings.globalize_path(final_path)
	)
	if rename_error != OK:
		_remove_file(part_path)
		package_download_finished.emit(_failure("package_store", "La descarga terminó, pero no se pudo guardar."))
		return
	package_download_finished.emit(_success({
		"package_path": final_path,
		"entry": _package_download_entry,
		"cached": false,
	}))


func _on_release_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	has_checked_latest = true
	if response_code == 404:
		latest_release = {}
		update_checked.emit(_success({"no_public_release": true, "update_available": false}))
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		update_checked.emit(_http_failure("release_http", response_code, "No se pudo comprobar si hay actualizaciones."))
		return
	var current_version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var parsed: Dictionary = MANIFEST_SERVICE.parse_latest_release_bytes(body, current_version)
	if bool(parsed.get("ok", false)):
		latest_release = parsed.duplicate(true)
	update_checked.emit(parsed)


func _on_update_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	update_request.download_file = ""
	var part_path := _update_part_path
	_update_part_path = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_remove_file(part_path)
		update_download_finished.emit(_http_failure("update_http", response_code, "No se pudo descargar la actualización."))
		return
	if not _verify_file(part_path, latest_release):
		_remove_file(part_path)
		update_download_finished.emit(_failure("update_integrity", "La actualización no coincide con su tamaño o SHA-256."))
		return
	var final_path := part_path.trim_suffix(".part")
	_remove_file(final_path)
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(part_path),
		ProjectSettings.globalize_path(final_path)
	)
	if rename_error != OK:
		_remove_file(part_path)
		update_download_finished.emit(_failure("update_store", "No se pudo guardar la actualización."))
		return
	downloaded_update_path = final_path
	update_download_finished.emit(_success({"update_path": final_path, "cached": false}))


func _emit_cached_package(path: String) -> void:
	package_download_finished.emit(_success({
		"package_path": path,
		"entry": _package_download_entry,
		"cached": true,
	}))


func _emit_cached_update(path: String) -> void:
	update_download_finished.emit(_success({"update_path": path, "cached": true}))


func _verify_file(path: String, descriptor: Dictionary) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var expected_size := int(descriptor.get("size_bytes", 0))
	var actual_size := file.get_length()
	file.close()
	return (
		actual_size == expected_size
		and FileAccess.get_sha256(path).to_lower() == str(descriptor.get("sha256", "")).to_lower()
	)


func _write_update_scripts(zip_path: String, install_directory: String, executable_path: String) -> Dictionary:
	var directory_absolute := ProjectSettings.globalize_path(UPDATE_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory_absolute)
	if directory_error != OK:
		return _failure("script_directory", "No se pudo preparar el instalador.")
	var power_shell_path := directory_absolute.path_join("apply_update.ps1")
	var stage_name := "AuroraUpdate-%d" % Time.get_unix_time_from_system()
	var power_shell_source := "\n".join([
		"$ErrorActionPreference = 'Stop'",
		"$processId = %d" % OS.get_process_id(),
		"$zipPath = '%s'" % _escape_power_shell(zip_path),
		"$installDirectory = '%s'" % _escape_power_shell(install_directory),
		"$executablePath = '%s'" % _escape_power_shell(executable_path),
		"$stage = Join-Path $env:TEMP '%s'" % stage_name,
		"while (Get-Process -Id $processId -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 250 }",
		"if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }",
		"New-Item -ItemType Directory -Path $stage -Force | Out-Null",
		"Expand-Archive -LiteralPath $zipPath -DestinationPath $stage -Force",
		"$source = $stage",
		"if (-not (Test-Path -LiteralPath (Join-Path $source 'Aurora.exe'))) {",
		"  $folders = @(Get-ChildItem -LiteralPath $stage -Directory)",
		"  if ($folders.Count -ne 1 -or -not (Test-Path -LiteralPath (Join-Path $folders[0].FullName 'Aurora.exe'))) { throw 'El ZIP no contiene una distribución válida de Aurora.' }",
		"  $source = $folders[0].FullName",
		"}",
		"Get-ChildItem -LiteralPath $source -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $installDirectory -Recurse -Force }",
		"Remove-Item -LiteralPath $stage -Recurse -Force",
		"Start-Process -FilePath $executablePath -WorkingDirectory $installDirectory",
	]) + "\n"
	var ps_file := FileAccess.open(power_shell_path, FileAccess.WRITE)
	if ps_file == null:
		return _failure("script_write", "No se pudo crear el instalador de actualización.")
	ps_file.store_string(power_shell_source)
	ps_file.close()
	return _success({"script_path": power_shell_path})


func _load_bundled_catalog() -> Dictionary:
	var file := FileAccess.open("res://community/catalog.json", FileAccess.READ)
	if file == null:
		return _failure("catalog_fallback", "No existe un catálogo local de respaldo.")
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return MANIFEST_SERVICE.parse_catalog_bytes(bytes)


func _escape_power_shell(value: String) -> String:
	return value.replace("'", "''")


func _remove_file(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _http_failure(error_code: String, response_code: int, message: String) -> Dictionary:
	return _failure(error_code, "%s (HTTP %d)" % [message, response_code])


func _success(values: Dictionary = {}) -> Dictionary:
	var result := values.duplicate(true)
	result["ok"] = true
	return result


func _failure(error_code: String, message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "message": message}
