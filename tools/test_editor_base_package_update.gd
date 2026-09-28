extends SceneTree

const Packages = preload("res://src/packages/SongPackageService.gd")
const Store = preload("res://src/screens/editor/EditorProjectStore.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := Packages.new()
	var fixture_id := "editor-base-fixture-%d" % Time.get_ticks_msec()
	var fixture_root := "user://editor_base_update_fixture_%d" % Time.get_ticks_msec()
	var source_root := fixture_root.path_join("source")
	var package_path := fixture_root.path_join("fixture.aurora")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root.path_join("audio")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root.path_join("charts")))
	var audio_path := source_root.path_join("audio/fixture.wav")
	var chart_path := source_root.path_join("charts/normal.json")
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = 8000
	var silence := PackedByteArray()
	silence.resize(8000)
	audio.data = silence
	_expect(audio.save_to_wav(audio_path) == OK, "Crea audio aislado")
	var initial_notes := [{"time": 1.0, "lane": 0, "duration": 0.0}]
	_expect(
		_write_bytes(
			chart_path,
			JSON.stringify(ChartData.make_chart_document(initial_notes, 4), "\t", true).to_utf8_buffer()
		) == OK,
		"Crea chart base"
	)
	var manifest := {
		"type": Packages.PACKAGE_TYPE,
		"format_version": Packages.FORMAT_VERSION,
		"package_id": fixture_id,
		"package_version": "1.0.0",
		"song": {
			"song_id": fixture_id,
			"title": "Base fixture",
			"artist": "Aurora Tests",
			"bpm": 120.0,
			"duration_seconds": 8.0,
			"preview_start_seconds": 0.0,
			"preview_duration_seconds": 5.0,
			"media": {"audio": {"path": "audio/fixture.wav"}},
			"charts": [{
				"chart_id": "normal-04",
				"path": "charts/normal.json",
				"key_count": 4,
				"difficulty": "NORMAL",
				"difficulty_level": 4,
			}],
		},
	}
	var exported: Dictionary = service.export_package(source_root, manifest, package_path)
	_expect(exported.get("ok", false), "Crea paquete base verificable")
	if failures > 0:
		_finish()
		return
	var manager := SongManager.new()
	root.add_child(manager)
	await process_frame
	var installed: Dictionary = manager.import_song_package(package_path)
	_expect(installed.get("ok", false), "Instala paquete base")
	var base_song := _find_song(manager, "package_%s" % fixture_id)
	_expect(base_song != null, "Descubre la canción base")
	if base_song == null:
		_finish()
		return
	var base_chart := base_song.charts[0]
	var editor_result: Dictionary = manager.prepare_song_for_editor(base_song, base_chart)
	_expect(editor_result.get("ok", false), "Abre borrador de edición")
	var project_path := str(editor_result.get("project_path", ""))
	var bundle: Dictionary = Store.load_bundle(project_path)
	_expect(bundle.get("ok", false), "Lee borrador de edición")
	if not bool(bundle.get("ok", false)):
		_finish()
		return
	var project: Dictionary = bundle.get("project", {}).duplicate(true)
	var media: Dictionary = project.get("media", {})
	_expect(
		str(media.get("audio_path", "")) == str(
			manager.package_media_by_song_id["package_%s" % fixture_id].get("audio_path", "")
		),
		"El borrador reutiliza el audio base sin duplicarlo"
	)
	var metadata: Dictionary = project.get("metadata", {}).duplicate(true)
	metadata["title"] = "Base actualizada"
	metadata["audio_gain_db"] = 4.5
	project["metadata"] = metadata
	var cover_source_path := fixture_root.path_join("loading_cover.png")
	var cover_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	cover_image.fill(Color(0.12, 0.75, 0.95, 1.0))
	_expect(
		cover_image.save_png(ProjectSettings.globalize_path(cover_source_path)) == OK,
		"Crea portada aislada"
	)
	media["cover_path"] = cover_source_path
	project["media"] = media
	var new_notes := [
		{"time": 1.0, "lane": 0, "duration": 0.0},
		{"time": 2.0, "lane": 3, "duration": 0.5},
	]
	_expect(
		Store.save_bundle(
			project_path,
			project,
			ChartData.make_chart_document(new_notes, 4)
		).get("ok", false),
		"Guarda el cambio del editor"
	)
	var updated: Dictionary = manager.update_package_from_editor_project(project_path)
	_expect(updated.get("ok", false) and updated.get("updated_base", false), "Actualiza el paquete base")
	manager.load_songs()
	var refreshed := _find_song(manager, "package_%s" % fixture_id)
	_expect(refreshed != null and refreshed.title == "Base actualizada", "La biblioteca muestra el título actualizado")
	if refreshed != null:
		_expect(is_equal_approx(refreshed.audio_gain_db, 4.5), "La biblioteca conserva el volumen ajustado")
		_expect(refreshed.package_version == "1.0.1", "Incrementa versión de contenido")
		_expect(refreshed.charts[0].load_notes(120.0, 8.0).size() == 2, "La base usa las notas editadas")
		_expect(
			FileAccess.file_exists(str(
				manager.package_media_by_song_id["package_%s" % fixture_id].get("cover_path", "")
			)),
			"La base recibe la portada de carga"
		)
		var refreshed_root := str(
			manager.package_roots_by_song_id.get("package_%s" % fixture_id, "")
		)
		var refreshed_manifest: Dictionary = service.validate_staging(refreshed_root, true).get("manifest", {})
		_expect(
			str(refreshed_manifest.get("song", {}).get("media", {}).get("cover", {}).get("path", ""))
			== "media/cover.png",
			"El manifiesto declara la portada actualizada"
		)
		_expect(
			is_equal_approx(float(refreshed_manifest.get("song", {}).get("audio_gain_db", 0.0)), 4.5),
			"El manifiesto declara el volumen actualizado"
		)
	var copies_of_this_fixture := 0
	var editable_id := str(editor_result.get("editor_song_id", ""))
	for candidate in manager.songs:
		if str(candidate.song_id) in ["package_%s" % fixture_id, editable_id]:
			copies_of_this_fixture += 1
	_expect(copies_of_this_fixture == 1, "El borrador no crea una segunda canción en la biblioteca")
	_finish()


func _write_bytes(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	return file.get_error()


func _find_song(manager: SongManager, song_id: String) -> SongData:
	for candidate in manager.songs:
		if str(candidate.song_id) == song_id:
			return candidate
	return null


func _expect(ok: bool, label: String) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)


func _finish() -> void:
	print("EDITOR BASE PACKAGE UPDATE %s" % ("PASSED" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)
