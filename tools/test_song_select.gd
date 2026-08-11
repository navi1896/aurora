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
	var input_manager := app.get_node("Managers/InputManager") as InputManager
	var alpha := _make_song("alpha", "Aurora Lights", "Navi")
	var alpha_hard := ChartData.new()
	alpha_hard.key_count = 6
	alpha_hard.difficulty_name = "HARD"
	alpha_hard.difficulty_level = 8
	alpha.charts.append(alpha_hard)
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
	_expect(
		screen.share_package_button != null
		and screen.share_package_button.get_parent().name == "ActionButtons"
		and screen.share_package_button.get_global_rect().end.x <= float(
			ProjectSettings.get_setting("display/window/size/viewport_width", 1920)
		),
		"COMPARTIR NIVEL queda visible en la biblioteca a 1280x720"
	)
	_expect(
		screen.import_package_button.text == AuroraLocale.text("INSTALAR NIVEL")
		and "USB" in screen.import_package_button.tooltip_text
		and screen.share_package_button.text == AuroraLocale.text("COMPARTIR NIVEL"),
		"La biblioteca separa con claridad instalar y compartir archivos .aurora"
	)
	screen._open_local_package_share()
	await process_frame
	_expect(
		screen.share_panel != null
		and screen.share_panel.song_selector != null
		and screen.share_panel.export_button != null
		and screen.share_panel.save_dialog.use_native_dialog,
		"COMPARTIR NIVEL abre el flujo local dentro del juego"
	)
	screen._close_local_package_share()
	await process_frame
	var package_preview := {
		"package_id": "123e4567-e89b-12d3-a456-426614174000",
		"package_version": "1.2.0",
		"song": {
			"title": "Nivel recibido",
			"artist": "Amistad Aurora",
			"duration_seconds": 75.0,
			"charts": [{
				"key_count": 4,
				"difficulty": "NORMAL",
				"difficulty_level": 5,
			}],
		},
	}
	screen._open_package_install_confirmation(
		"C:/nivel_recibido.aurora",
		package_preview
	)
	await process_frame
	_expect(
		screen.package_install_panel != null
		and screen.package_install_panel.install_button.text
		== AuroraLocale.text("INSTALAR NIVEL"),
		"Instalar muestra una confirmación con los datos del paquete antes de escribir"
	)
	screen._close_package_install_confirmation()
	await process_frame
	_expect(screen.songs.size() == 3, "Muestra toda la biblioteca por defecto")
	_expect(
		screen.search_field != null
		and screen.filter_option != null
		and screen.favorite_button != null
		and screen.edit_button != null,
		"Incluye búsqueda, filtros, favoritos y edición"
	)
	_expect(
		screen.preview_audio.bus == &"Music",
		"La preescucha de audio usa el volumen de música"
	)
	screen.preview_request_token += 1
	screen._start_preview(alpha)
	await process_frame
	_expect(
		screen.preview_loop_song == alpha
		and screen.preview_finish_timer.time_left > 0.0
		and screen.preview_status.text == AuroraLocale.text("PREESCUCHA EN BUCLE")
		and screen.preview_audio.volume_db < -20.0,
		"La preescucha inicia en bucle desde silencio sin cortar la selección"
	)
	await create_timer(0.55).timeout
	_expect(
		screen.preview_cover.modulate.r > 0.9
		and screen.preview_audio.volume_db > -1.0,
		"La entrada de la preescucha sube imagen y audio suavemente"
	)
	screen.preview_fade_timer.stop()
	screen.preview_finish_timer.stop()
	screen._begin_preview_fade_out()
	await create_timer(0.55).timeout
	_expect(
		screen.preview_cover.modulate.r < 0.1
		and screen.preview_audio.volume_db < -40.0,
		"La salida de la preescucha oscurece y baja el audio antes de repetir"
	)
	screen._stop_preview()
	_expect(
		"ENTER" in screen.controls_label.text
		and "ESC" in screen.controls_label.text,
		"La ayuda inferior muestra teclado cuando se usa teclado"
	)
	input_manager._set_input_device(true, 0)
	_expect(
		input_manager.get_controller_action_label("confirm")
		in screen.controls_label.text
		and "D-PAD" in screen.controls_label.text,
		"La ayuda inferior cambia a Xbox o PlayStation al usar mando"
	)
	input_manager._set_input_device(false)

	screen._select_song(0, false)
	screen.selected_chart_index = 0
	screen._update_chart_selection()
	screen.favorite_button.grab_focus()
	await process_frame
	var dpad_right := InputEventJoypadButton.new()
	dpad_right.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad_right.pressed = true
	screen._input(dpad_right)
	_expect(
		screen.selected_chart_index == 0
		and screen.get_viewport().gui_get_focus_owner() == screen.favorite_button,
		"El D-pad respeta los controles del panel derecho"
	)
	var focused_enter := InputEventKey.new()
	focused_enter.keycode = KEY_ENTER
	focused_enter.pressed = true
	screen._input(focused_enter)
	_expect(
		scene_manager.current_scene == screen and not game_manager.is_playing,
		"Enter no fuerza Jugar cuando otro control tiene foco"
	)
	screen.song_buttons[0].grab_focus()
	screen._input(dpad_right)
	_expect(
		screen.selected_chart_index == 1,
		"El atajo de dificultad se conserva con foco en la lista"
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

	screen.search_field.text = ""
	screen.filter_option.select(0)
	screen._on_filter_selected(0)
	screen._select_song(0, false)
	screen.song_buttons[0].grab_focus()
	screen._input(focused_enter)
	_expect(
		scene_manager.current_scene_name == "gameplay" and game_manager.is_playing,
		"Enter conserva Jugar cuando el foco está en la lista"
	)

	game_manager.stop_song()
	song_manager.songs = []
	scene_manager.load_scene("song_select")
	await process_frame
	await process_frame
	var empty_screen := scene_manager.current_scene as SongSelect
	_expect(
		empty_screen != null
		and empty_screen.get_viewport().gui_get_focus_owner()
		== empty_screen.import_package_button,
		"La biblioteca vacía enfoca Importar"
	)
	_expect(
		empty_screen != null
		and not empty_screen.edit_button.disabled
		and empty_screen.edit_button.text
		== AuroraLocale.text("CREAR NIVEL"),
		"La biblioteca vacía ofrece crear un nivel directamente"
	)
	empty_screen._edit_selected_song()
	await process_frame
	await process_frame
	_expect(
		scene_manager.current_scene_name == "editor",
		"Crear nivel abre el editor sin depender de contenido previo"
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
	song.preview_duration_seconds = 1.2
	song.audio = _make_preview_audio()
	song.charts = [chart]
	return song


func _make_preview_audio() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var silence := PackedByteArray()
	silence.resize(22050 * 2 * 2)
	stream.data = silence
	return stream


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
