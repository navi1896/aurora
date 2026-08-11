extends SceneTree

const PACKAGE_SERVICE_TYPE := preload(
	"res://src/packages/SongPackageService.gd"
)
const SHARE_SERVICE_TYPE := preload(
	"res://src/screens/song_select/LocalPackageShareService.gd"
)
const TEST_ROOT := "user://aurora_test_local_package_share"

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
	var staging := TEST_ROOT.path_join("source_staging")
	_write_text(
		staging.path_join("media/song.ogg"),
		"OggS-Aurora-local-share-fixture"
	)
	_write_text(
		staging.path_join("charts/chart.json"),
		JSON.stringify(
			ChartData.make_chart_document(
				[
					{"time": 1.0, "lane": 0, "duration": 0.0},
					{"time": 2.0, "lane": 3, "duration": 0.75},
				],
				4
			)
		)
	)
	var manifest := {
		"type": PACKAGE_SERVICE_TYPE.PACKAGE_TYPE,
		"format_version": PACKAGE_SERVICE_TYPE.FORMAT_VERSION,
		"package_version": "1.0.0",
		"package_id": "29fa3f47-286a-4278-bc06-9c5b737be224",
		"song": {
			"song_id": "local-share-fixture",
			"title": "Nivel local",
			"artist": "Aurora Tests",
			"bpm": 128.0,
			"duration_seconds": 30.0,
			"preview_start_seconds": 0.0,
			"preview_duration_seconds": 15.0,
			"media": {
				"audio": {"path": "media/song.ogg"},
			},
			"charts": [{
				"chart_id": "4k-normal-04",
				"key_count": 4,
				"difficulty": "NORMAL",
				"difficulty_level": 4,
				"path": "charts/chart.json",
			}],
		},
	}
	var service = PACKAGE_SERVICE_TYPE.new()
	var original_package := TEST_ROOT.path_join("original.aurora")
	var original_result: Dictionary = service.export_package(
		staging,
		manifest,
		original_package
	)
	_expect(bool(original_result.get("ok", false)), "Crea el paquete base de prueba")
	var installed_root := TEST_ROOT.path_join("installed")
	var install_result: Dictionary = service.import_package(
		original_package,
		installed_root
	)
	_expect(bool(install_result.get("ok", false)), "Instala el paquete base en staging local")

	var shared_package := TEST_ROOT.path_join("shared-copy.aurora")
	var share_service = SHARE_SERVICE_TYPE.new()
	var share_result: Dictionary = share_service.export_descriptor(
		{
			"kind": "installed_package",
			"package_root": installed_root,
		},
		shared_package
	)
	var validation: Dictionary = service.validate_package(shared_package)
	var shared_manifest: Dictionary = validation.get("manifest", {})
	var shared_song: Dictionary = shared_manifest.get("song", {})
	_expect(
		bool(share_result.get("ok", false))
		and bool(validation.get("ok", false)),
		"Reexporta un nivel instalado como un único .aurora válido"
	)
	_expect(
		str(shared_song.get("title", "")) == "Nivel local"
		and str(shared_manifest.get("package_version", "")) == "1.0.0",
		"La copia conserva título y versión del paquete"
	)
	_expect(
		FileAccess.file_exists(installed_root.path_join("charts/chart.json"))
		and FileAccess.file_exists(original_package),
		"Compartir no modifica ni elimina la instalación ni el archivo original"
	)

	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
	if failures.is_empty():
		print("LOCAL PACKAGE SHARE TESTS PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _write_text(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append("FAIL: %s" % description)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry not in [".", ".."]:
			var child := path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
