extends SceneTree

const Store = preload("res://src/screens/editor/EditorProjectStore.gd")
const Exporter = preload("res://src/screens/editor/EditorPackageExporter.gd")
const Packages = preload("res://src/packages/SongPackageService.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	AudioServer.set_bus_mute(0, true)
	var path := "user://auto_side_flow/project.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_8_BITS
	wave.mix_rate = 8000
	var silence := PackedByteArray()
	silence.resize(80000)
	wave.data = silence
	var audio_path := "user://auto_side_flow/audio.wav"
	_expect(wave.save_to_wav(audio_path) == OK, "Crea audio de prueba aislado")
	var normal := [{"time": 1.0, "lane": 0, "duration": 0.0}, {"time": 2.0, "lane": 3, "duration": 0.75}]
	var sides := [{"time": 1.0, "side": 0, "duration": 0.5}, {"time": 2.0, "side": 1, "duration": 1.0}]
	var project := {"version": 3, "type": Store.PROJECT_TYPE, "package_id": "auto-side-fixture", "package_version": "1.0.0",
		"metadata": {"title": "Prueba lateral", "artist": "Aurora Tests", "key_count": 4, "difficulty": "NORMAL", "difficulty_level": 4,
			"bpm": 120.0, "duration_seconds": 10.0, "creation_mode": "manual"},
		"media": {"audio_path": audio_path}, "chart_path": "chart.json"}
	_expect(Store.save_bundle(path, project, ChartData.make_chart_document(normal, 4, 0.0, sides)).ok, "Prepara chart con laterales")
	var app := (load("res://src/App.tscn") as PackedScene).instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	var scenes := app.get_node("Managers/SceneManager") as SceneManager
	var game := app.get_node("Managers/GameManager") as GameManager
	var songs := app.get_node("Managers/SongManager") as SongManager
	scenes.load_scene("editor")
	await process_frame
	await process_frame
	var editor := scenes.current_scene as Editor
	editor._load_project(path)
	await process_frame
	await process_frame
	_expect(editor.side_notes == sides, "Editor abre los laterales importados")
	editor.title_edit.text = "Prueba lateral editada"
	_expect(editor._save_project(), "Editor permite editar metadatos y guardar")
	_expect(Store.load_bundle(path).get("side_notes", []) == sides, "Editar no elimina los laterales")
	var package_path := "user://auto_side_flow/fixture.aurora"
	var exported: Dictionary = Exporter.new().export_saved_project(path, package_path)
	_expect(exported.get("ok", false), "Exporta .aurora con laterales")
	var checked: Dictionary = Packages.new().validate_package(package_path)
	_expect(checked.get("ok", false), "El paquete pasa la validación íntegra")
	var zip := ZIPReader.new()
	if zip.open(package_path) == OK:
		var chart_doc: Dictionary = JSON.parse_string(zip.read_file("charts/chart.json").get_string_from_utf8())
		_expect(ChartData.normalize_side_notes(chart_doc.get("side_notes", [])) == sides, "El archivo compartible conserva las notas especiales")
		zip.close()
	else:
		_expect(false, "Abre ZIP exportado")
	var installed: Dictionary = songs.import_song_package(package_path)
	_expect(installed.get("ok", false), "Instala el paquete en el perfil de prueba")
	var song: SongData
	for candidate in songs.songs:
		if str(candidate.song_id) == "package_auto-side-fixture":
			song = candidate
	_expect(song != null, "La biblioteca descubre el paquete instalado")
	if song == null:
		quit(1)
		return
	var chart := song.charts[0]
	var editable_copy := songs.prepare_song_for_editor(song, chart)
	_expect(editable_copy.get("ok", false), "Abre una copia editable desde biblioteca")
	_expect(Store.load_bundle(editable_copy.get("project_path", "")).get("side_notes", []) == sides, "La copia editable conserva los laterales")
	_expect(game.start_editor_test(song, chart, path), "Inicia prueba del nivel importado")
	editor.suppress_dirty_tracking = true
	scenes.load_scene("gameplay")
	await process_frame
	await process_frame
	await process_frame
	var gameplay := scenes.current_scene as Gameplay
	gameplay.set_process(false)
	gameplay.start_gate_active = false
	gameplay.start_gate_panel.hide()
	gameplay.preparation_blackout.hide()
	gameplay.gameplay_time = 0.8
	gameplay._spawn_upcoming_notes()
	gameplay._update_active_notes()
	for track in gameplay.side_tracks:
		track.set_playback_time(0.8, gameplay._get_note_travel_time())
	_expect(gameplay.lane_panels.size() == 4 and gameplay.side_tracks.size() == 2, "Mantiene cuatro teclas con dos indicadores automáticos")
	var left_rect := gameplay.side_tracks[0].get_global_rect()
	var right_rect := gameplay.side_tracks[1].get_global_rect()
	_expect(left_rect.end.x <= gameplay.lane_panels[0].get_global_rect().position.x
		and right_rect.position.x >= gameplay.lane_panels[3].get_global_rect().end.x, "Los laterales no invaden carriles jugables")
	var before := gameplay._build_result_data()
	for track in gameplay.side_tracks:
		track.set_playback_time(5.0, gameplay._get_note_travel_time())
	_expect(gameplay._build_result_data() == before and before.total_notes == 2, "Resolver laterales no modifica score, precisión, combo ni total jugable")
	for track in gameplay.side_tracks:
		track.set_playback_time(0.8, gameplay._get_note_travel_time())
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := "E:/Juego_Musica_Assets/DJMAX/Metadata/auto_side_playfield.png"
		_expect(root.get_texture().get_image().save_png(output) == OK, "Guarda evidencia visual fuera del proyecto")
	if OS.get_cmdline_user_args().has("--inspect"):
		await create_timer(25.0).timeout
	current_scene = null
	app.queue_free()
	await process_frame
	await process_frame
	print("AUTO SIDE FLOW %s" % ("PASSED" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: %s" % label)
	else:
		print("PASS: %s" % label)
