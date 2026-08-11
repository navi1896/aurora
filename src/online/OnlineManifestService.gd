extends RefCounted

class_name OnlineManifestService

const CATALOG_TYPE := "aurora_community_catalog"
const CATALOG_FORMAT_VERSION := 1
const MAX_CATALOG_BYTES := 2 * 1024 * 1024
const MAX_CATALOG_ENTRIES := 256
const MAX_PACKAGE_BYTES := 512 * 1024 * 1024
const MAX_UPDATE_BYTES := 2 * 1024 * 1024 * 1024
const REPOSITORY_URL := "https://github.com/navi1896/aurora"
const RELEASE_DOWNLOAD_PREFIX := REPOSITORY_URL + "/releases/download/"
const RAW_REPOSITORY_PREFIX := (
	"https://raw.githubusercontent.com/navi1896/aurora/"
)


static func parse_catalog_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_CATALOG_BYTES:
		return _failure("catalog_size", "El catálogo está vacío o supera el límite permitido.")
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		return _failure("catalog_json", "El catálogo no contiene JSON válido.")
	var document: Dictionary = parsed
	if str(document.get("type", "")) != CATALOG_TYPE:
		return _failure("catalog_type", "El archivo no es un catálogo de Aurora.")
	if int(document.get("format_version", 0)) != CATALOG_FORMAT_VERSION:
		return _failure("catalog_version", "La versión del catálogo no es compatible.")
	var packages_value: Variant = document.get("packages", null)
	if not (packages_value is Array):
		return _failure("catalog_packages", "El catálogo no contiene una lista de paquetes.")
	var packages: Array = packages_value
	if packages.size() > MAX_CATALOG_ENTRIES:
		return _failure("catalog_entries", "El catálogo contiene demasiadas entradas.")

	var entries: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for value in packages:
		var result := validate_catalog_entry(value)
		if not bool(result.get("ok", false)):
			return result
		var entry: Dictionary = result.get("entry", {})
		var package_id := str(entry.get("package_id", ""))
		if seen_ids.has(package_id):
			return _failure("duplicate_package", "El catálogo repite el identificador %s." % package_id)
		seen_ids[package_id] = true
		entries.append(entry)
	entries.sort_custom(_sort_catalog_entries)
	return _success({
		"entries": entries,
		"updated_at": str(document.get("updated_at", "")),
	})


static func validate_catalog_entry(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _failure("entry_type", "Una entrada del catálogo no es válida.")
	var entry: Dictionary = value.duplicate(true)
	var package_id := str(entry.get("package_id", "")).strip_edges()
	if not _is_safe_identifier(package_id):
		return _failure("entry_id", "Una canción tiene un identificador no válido.")
	var version := str(entry.get("package_version", "")).strip_edges()
	if not _is_semantic_version(version):
		return _failure("entry_version", "La versión de %s no usa MAYOR.MENOR.PARCHE." % package_id)
	var title := str(entry.get("title", "")).strip_edges()
	var artist := str(entry.get("artist", "")).strip_edges()
	var author := str(entry.get("author", "")).strip_edges()
	if title.is_empty() or artist.is_empty() or author.is_empty():
		return _failure("entry_metadata", "La entrada %s no tiene título, artista o creador." % package_id)
	if title.length() > 120 or artist.length() > 120 or author.length() > 80:
		return _failure("entry_metadata_length", "Los datos de %s son demasiado largos." % package_id)
	var download_url := str(entry.get("download_url", "")).strip_edges()
	if not is_trusted_download_url(download_url, ".aurora"):
		return _failure("entry_url", "La descarga de %s no usa una ubicación autorizada." % package_id)
	var sha256 := str(entry.get("sha256", "")).strip_edges().to_lower()
	if not _is_sha256(sha256):
		return _failure("entry_hash", "La descarga de %s no declara un SHA-256 válido." % package_id)
	var size_bytes := int(entry.get("size_bytes", 0))
	if size_bytes <= 0 or size_bytes > MAX_PACKAGE_BYTES:
		return _failure("entry_size", "El tamaño declarado de %s no es válido." % package_id)

	entry["package_id"] = package_id
	entry["package_version"] = version
	entry["title"] = title
	entry["artist"] = artist
	entry["author"] = author
	entry["download_url"] = download_url
	entry["sha256"] = sha256
	entry["size_bytes"] = size_bytes
	return _success({"entry": entry})


static func parse_latest_release_bytes(
	bytes: PackedByteArray,
	current_version: String
) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_CATALOG_BYTES:
		return _failure("release_size", "La respuesta de actualización no es válida.")
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		return _failure("release_json", "GitHub no devolvió una versión válida.")
	var release: Dictionary = parsed
	if bool(release.get("draft", false)) or bool(release.get("prerelease", false)):
		return _failure("release_unpublished", "La versión encontrada todavía no es pública.")
	var version := str(release.get("tag_name", "")).strip_edges().trim_prefix("v")
	if not _is_semantic_version(version):
		return _failure("release_version", "La versión publicada no usa MAYOR.MENOR.PARCHE.")
	var html_url := str(release.get("html_url", "")).strip_edges()
	if not html_url.begins_with(REPOSITORY_URL + "/releases/"):
		return _failure("release_url", "La página de la versión no pertenece a Aurora.")
	var asset: Dictionary = {}
	var assets_value: Variant = release.get("assets", [])
	if assets_value is Array:
		for asset_value in assets_value:
			if not (asset_value is Dictionary):
				continue
			var candidate: Dictionary = asset_value
			var name := str(candidate.get("name", ""))
			if (
				name.to_lower().ends_with(".zip")
				and name.to_lower().contains("aurora")
				and name.to_lower().contains("windows")
			):
				asset = candidate
				break
	var result := {
		"version": version,
		"name": str(release.get("name", "Aurora v%s" % version)),
		"notes": str(release.get("body", "")),
		"html_url": html_url,
		"update_available": compare_versions(version, current_version) > 0,
		"download_available": false,
	}
	if asset.is_empty():
		return _success(result)
	var download_url := str(asset.get("browser_download_url", "")).strip_edges()
	var size_bytes := int(asset.get("size", 0))
	var digest := str(asset.get("digest", "")).strip_edges().to_lower()
	var sha256 := digest.trim_prefix("sha256:") if digest.begins_with("sha256:") else ""
	if (
		is_trusted_download_url(download_url, ".zip")
		and size_bytes > 0
		and size_bytes <= MAX_UPDATE_BYTES
		and _is_sha256(sha256)
	):
		result["download_available"] = true
		result["download_url"] = download_url
		result["size_bytes"] = size_bytes
		result["sha256"] = sha256
		result["asset_name"] = str(asset.get("name", "Aurora-Windows.zip"))
	return _success(result)


static func compare_versions(left: String, right: String) -> int:
	var left_parts := _normalized_version_parts(left)
	var right_parts := _normalized_version_parts(right)
	for index in range(3):
		if left_parts[index] < right_parts[index]:
			return -1
		if left_parts[index] > right_parts[index]:
			return 1
	return 0


static func is_trusted_download_url(url: String, extension: String) -> bool:
	var normalized := url.strip_edges()
	if not normalized.to_lower().ends_with(extension.to_lower()):
		return false
	return (
		normalized.begins_with(RELEASE_DOWNLOAD_PREFIX)
		or normalized.begins_with(RAW_REPOSITORY_PREFIX)
	)


static func _sort_catalog_entries(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("title", "")).naturalnocasecmp_to(str(right.get("title", ""))) < 0


static func _is_safe_identifier(value: String) -> bool:
	if value.length() < 3 or value.length() > 80:
		return false
	for index in range(value.length()):
		var character := value.substr(index, 1)
		if not (
			character >= "a" and character <= "z"
			or character >= "A" and character <= "Z"
			or character >= "0" and character <= "9"
			or character in ["-", "_"]
		):
			return false
	return true


static func _is_semantic_version(value: String) -> bool:
	var parts := value.strip_edges().split(".", false)
	if parts.size() != 3:
		return false
	for part in parts:
		if part.is_empty() or not part.is_valid_int() or int(part) < 0:
			return false
	return true


static func _normalized_version_parts(value: String) -> Array[int]:
	var normalized := value.strip_edges().trim_prefix("v")
	if not _is_semantic_version(normalized):
		return [0, 0, 0]
	var parts := normalized.split(".", false)
	return [int(parts[0]), int(parts[1]), int(parts[2])]


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var character := value.substr(index, 1).to_lower()
		if not (character >= "0" and character <= "9" or character >= "a" and character <= "f"):
			return false
	return true


static func _success(values: Dictionary = {}) -> Dictionary:
	var result := values.duplicate(true)
	result["ok"] = true
	return result


static func _failure(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"message": message,
	}
