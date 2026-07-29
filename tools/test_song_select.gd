extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app_scene := load("res://src/App.tscn") as PackedScene
	_expect(app_scene != null, "App se puede cargar")
	if app_scene == null:
		_finish()
		return
	var app := app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame

	var scene_manager := app.get_node("Managers/SceneManager") as SceneManager
	var song_manager := app.get_node("Managers/SongManager") as SongManager
	var settings_manager := app.get_node("Managers/SettingsManager") as SettingsManager
	var game_manager := app.get_node("Managers/GameManager") as GameManager
	var alpha := _make_song("alpha", "Aurora Lights", "Navi")
	var beta := _make_song("beta", "Night Drive", "Neon Avenue")
	var gamma := _make_song("gamma", "Pulse Grid", "Vector Bloom")
	song_manager.songs = [alpha, beta, gamma]
	settings_manager.settings["favorite_song_ids"] = ["beta"]
	settings_manager.settings["recent_song_ids"] = ["gamma", "alpha"]
	scene_manager.load_scene("song_select")
	await process_frame
	await process_frame

	var screen := scene_manager.current_scene as SongSelect
	_expect(screen != null, "Biblioteca se abre")
	if screen == null:
		_finish()
		return
	_expect(screen.songs.size() == 3, "Muestra toda la biblioteca por defecto")
	_expect(
		screen.search_field != null
		and screen.filter_option != null
		and screen.favorite_button != null
		and screen.edit_button != null,
		"Incluye búsqueda, filtros, favoritos y edición"
	)

	screen.search_field.text = "night"
	screen._on_search_changed(screen.search_field.text)
	await process_frame
	_expect(
		screen.songs.size() == 1 and screen.songs[0].song_id == &"beta",
		"Busca por título sin distinguir mayúsculas"
	)
	screen.search_field.text = "vector"
	screen._on_search_changed(screen.search_field.text)
	await process_frame
	_expect(
		screen.songs.size() == 1 and screen.songs[0].song_id == &"gamma",
		"Busca también por artista"
	)
	screen.search_field.text = ""
	screen._on_search_changed(screen.search_field.text)
	screen.filter_option.select(1)
	screen._on_filter_selected(1)
	await process_frame
	_expect(
		screen.songs.size() == 1 and screen.songs[0].song_id == &"beta",
		"El filtro de favoritos usa la lista guardada"
	)
	screen.filter_option.select(2)
	screen._on_filter_selected(2)
	await process_frame
	_expect(
		screen.songs.size() == 2
		and screen.songs[0].song_id == &"gamma"
		and screen.songs[1].song_id == &"alpha",
		"Recientes conserva el orden de reproducción"
	)

	screen.filter_option.select(0)
	screen._on_filter_selected(0)
	await process_frame
	screen._select_song(1, false)
	screen.favorite_button.grab_focus()
	await process_frame
	_expect(
		screen.song_buttons[1].button_pressed,
		"La canción seleccionada conserva su borde al mover el foco al panel derecho"
	)

	screen.search_field.text = "sin coincidencias"
	screen._on_search_changed(screen.search_field.text)
	await process_frame
	_expect(
		screen.songs.is_empty()
		and screen.preview_title.text == AuroraLocale.text("SIN RESULTADOS")
		and screen.favorite_button.disabled
		and screen.edit_button.disabled,
		"Una búsqueda vacía distingue SIN RESULTADOS y desactiva acciones"
	)

	game_manager.request_editor_project("user://aurora_editor/probe/project.json")
	_expect(
		game_manager.take_requested_editor_project_path()
		== "user://aurora_editor/probe/project.json"
		and game_manager.take_requested_editor_project_path().is_empty(),
		"La solicitud EDITAR se consume una sola vez"
	)
	_finish()


func _make_song(song_id: String, title: String, artist: String) -> SongData:
	var chart := ChartData.new()
	chart.key_count = 4
	chart.difficulty_name = "NORMAL"
	chart.difficulty_level = 4
	var song := SongData.new()
	song.song_id = StringName(song_id)
	song.title = title
	song.artist = artist
	song.duration_seconds = 90.0
	song.bpm = 128.0
	song.charts = [chart]
	return song


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		printerr("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("SONG SELECT TESTS PASSED")
		quit(0)
	else:
		printerr("SONG SELECT TESTS FAILED: %s" % ", ".join(failures))
		quit(1)
