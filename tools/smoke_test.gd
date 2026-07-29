extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var app_scene := load("res://src/App.tscn") as PackedScene
	_expect(app_scene != null, "App.tscn se puede cargar")
	if app_scene == null:
		_finish()
		return

	var app := app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame

	var managers := app.get_node_or_null("Managers")
	var scene_manager := app.get_node_or_null("Managers/SceneManager")
	var game_manager := app.get_node_or_null("Managers/GameManager")
	var song_manager := app.get_node_or_null("Managers/SongManager")
	var input_manager := app.get_node_or_null("Managers/InputManager")
	var settings_manager := app.get_node_or_null("Managers/SettingsManager")
	var menu_music_manager := app.get_node_or_null("Managers/MenuMusicManager")
	_expect(managers != null, "Los managers existen")
	_expect(scene_manager != null, "SceneManager existe")
	_expect(game_manager != null, "GameManager existe")
	_expect(song_manager != null, "SongManager existe")
	_expect(input_manager != null, "InputManager existe")
	_expect(settings_manager != null, "SettingsManager existe")
	_expect(menu_music_manager != null, "MenuMusicManager existe")
	if (
		scene_manager == null
		or game_manager == null
		or song_manager == null
		or input_manager == null
		or settings_manager == null
		or menu_music_manager == null
	):
		_finish()
		return

	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_expect(AuroraLocale.text("INICIAR") == "START", "La interfaz ofrece traducción al inglés")
	TranslationServer.set_locale("es")
	_expect(AuroraLocale.text("INICIAR") == "INICIAR", "La interfaz conserva los textos en español")
	TranslationServer.set_locale(original_locale)

	var swapped_keys: Array = input_manager._assign_unique_keycode(
		[KEY_D, KEY_F, KEY_J, KEY_K],
		0,
		KEY_F
	)
	_expect(
		swapped_keys == [KEY_F, KEY_D, KEY_J, KEY_K],
		"Reasignar una tecla usada intercambia los carriles"
	)
	_expect(
		input_manager.get_mode_joy_buttons(4)
		== [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_X, JOY_BUTTON_B],
		"El mando usa una distribución simétrica de cuatro carriles"
	)
	_expect(
		input_manager.get_mode_joy_buttons(6)
		== [
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_RIGHT,
			JOY_BUTTON_X,
			JOY_BUTTON_Y,
			JOY_BUTTON_B,
		],
		"El mando amplía la distribución correctamente a 6K"
	)
	var controller_8k: Array[int] = input_manager.get_mode_joy_buttons(8)
	_expect(
		controller_8k.size() == 8
		and controller_8k.front() == JOY_BUTTON_LEFT_SHOULDER
		and controller_8k.back() == JOY_BUTTON_RIGHT_SHOULDER,
		"El modo 8K reserva los botones superiores para los carriles exteriores"
	)
	_expect(
		input_manager.get_controller_action_button("confirm") == JOY_BUTTON_A
		and input_manager.get_controller_action_button("pause") == JOY_BUTTON_START,
		"Las acciones generales del mando tienen una asignación configurable"
	)
	_expect(
		input_manager._assign_unique_keycode(
			[JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_X, JOY_BUTTON_B],
			0,
			JOY_BUTTON_X
		)
		== [JOY_BUTTON_X, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_B],
		"Reasignar un botón de mando intercambia los carriles repetidos"
	)
	_expect(
		menu_music_manager.player != null
		and menu_music_manager.player.stream is AudioStreamWAV
		and menu_music_manager.player.bus == "MenuMusic"
		and AudioServer.get_bus_index("MenuMusic") >= 0,
		"El menú usa una pieza original con volumen independiente"
	)
	var original_menu_volume := float(
		settings_manager.get_setting("menu_music_volume", 0.72)
	)
	var original_song_volume := float(settings_manager.get_setting("music_volume", 0.85))
	settings_manager.settings["menu_music_volume"] = 0.30
	settings_manager.settings["music_volume"] = 0.80
	settings_manager.apply_audio_settings()
	_expect(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MenuMusic"))
		< AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),
		"El mezclador controla el menú aparte de las canciones"
	)
	settings_manager.settings["menu_music_volume"] = original_menu_volume
	settings_manager.settings["music_volume"] = original_song_volume
	settings_manager.apply_audio_settings()
	for lane_index in range(4):
		var lane_action: StringName = input_manager.get_lane_action(4, lane_index)
		var expected_button: int = input_manager.get_mode_joy_buttons(4)[lane_index]
		var has_controller_event := false
		for input_event in InputMap.action_get_events(lane_action):
			if (
				input_event is InputEventJoypadButton
				and int(input_event.button_index) == expected_button
			):
				has_controller_event = true
				break
		_expect(
			has_controller_event,
			"El carril 4K %d acepta una entrada de mando" % (lane_index + 1)
		)
	input_manager._set_input_device(true, 0)
	_expect(
		input_manager.get_lane_input_label(4, 2, KEY_J) == "X",
		"Gameplay muestra botones cuando se usa un mando Xbox"
	)
	input_manager._set_input_device(false)
	_expect(
		input_manager.get_lane_input_label(4, 2, KEY_J) == "J",
		"Gameplay vuelve a mostrar teclas al detectar el teclado"
	)

	var outline_button := AuroraUi.make_button("PRUEBA")
	var normal_style := outline_button.get_theme_stylebox("normal") as StyleBoxFlat
	var hover_style := outline_button.get_theme_stylebox("hover") as StyleBoxFlat
	var focus_style := outline_button.get_theme_stylebox("focus") as StyleBoxFlat
	_expect(
		normal_style.bg_color.is_equal_approx(hover_style.bg_color)
		and normal_style.bg_color.is_equal_approx(focus_style.bg_color),
		"Los botones seleccionados conservan el mismo relleno"
	)
	_expect(
		hover_style.border_color.is_equal_approx(focus_style.border_color)
		and hover_style.border_color.b > hover_style.border_color.r,
		"El foco de los botones se indica con borde azul"
	)
	outline_button.free()

	_expect(song_manager.songs.is_empty(), "La versión pública inicia sin canciones de prueba")
	var demo_chart := ChartData.new()
	demo_chart.key_count = 4
	demo_chart.difficulty_name = "NORMAL"
	demo_chart.difficulty_level = 4
	var demo_song := SongData.new()
	demo_song.title = "Prueba interna"
	demo_song.artist = "Aurora"
	demo_song.duration_seconds = 30.0
	demo_song.bpm = 128.0
	demo_song.charts = [demo_chart]

	var editor_fixture_directory := "user://aurora_smoke_tests/audio_only_library"
	var editor_fixture_absolute := ProjectSettings.globalize_path(editor_fixture_directory)
	DirAccess.make_dir_recursive_absolute(editor_fixture_absolute)
	var fixture_audio_path := "%s/audio_only_probe.wav" % editor_fixture_directory
	var fixture_chart_path := "%s/chart.json" % editor_fixture_directory
	var fixture_project_path := "%s/project.json" % editor_fixture_directory
	var fixture_wave := AudioStreamWAV.new()
	fixture_wave.format = AudioStreamWAV.FORMAT_8_BITS
	fixture_wave.mix_rate = 8000
	fixture_wave.stereo = false
	fixture_wave.data.resize(800)
	fixture_wave.data.fill(128)
	var fixture_audio_saved := fixture_wave.save_to_wav(fixture_audio_path) == OK
	var fixture_chart_file := FileAccess.open(fixture_chart_path, FileAccess.WRITE)
	if fixture_chart_file != null:
		fixture_chart_file.store_string(
			JSON.stringify(
				ChartData.make_chart_document(
					[{"time": 1.0, "lane": 0, "duration": 0.0}],
					4
				)
			)
		)
		fixture_chart_file.close()
	var fixture_project_file := FileAccess.open(fixture_project_path, FileAccess.WRITE)
	if fixture_project_file != null:
		fixture_project_file.store_string(
			JSON.stringify(
				{
					"type": "aurora_editor_project",
					"metadata": {
						"title": "Audio Only Probe",
						"artist": "Aurora Smoke",
						"bpm": 128.0,
						"duration_seconds": 8.0,
						"key_count": 4,
						"difficulty": "NORMAL",
						"difficulty_level": 1,
					},
					"media": {
						"video_path": "",
						"audio_path": fixture_audio_path,
					},
					"chart_path": fixture_chart_path,
				}
			)
		)
		fixture_project_file.close()
	var editor_song_count_before_fixture: int = song_manager.songs.size()
	if fixture_audio_saved:
		song_manager._load_editor_project(fixture_project_path)
	_expect(
		fixture_audio_saved
		and song_manager.songs.size() == editor_song_count_before_fixture + 1
		and song_manager.songs[-1].audio != null
		and song_manager.songs[-1].background_video == null,
		"Un proyecto del editor con solo audio aparece en la biblioteca"
	)
	if song_manager.songs.size() > editor_song_count_before_fixture:
		song_manager.songs.pop_back()

	fixture_chart_file = FileAccess.open(fixture_chart_path, FileAccess.WRITE)
	if fixture_chart_file != null:
		fixture_chart_file.store_string(
			JSON.stringify(ChartData.make_chart_document([], 4))
		)
		fixture_chart_file.close()
	var empty_file_chart := ChartData.new()
	empty_file_chart.key_count = 4
	empty_file_chart.chart_path = fixture_chart_path
	_expect(
		empty_file_chart.load_notes(128.0, 8.0).is_empty()
		and not empty_file_chart.has_valid_file_chart(),
		"Un chart vacío no se sustituye por notas de práctica"
	)
	song_manager._load_editor_project(fixture_project_path)
	_expect(
		song_manager.songs.size() == editor_song_count_before_fixture,
		"Un proyecto con chart vacío no se publica en la biblioteca"
	)
	for fixture_path in [
		fixture_project_path,
		fixture_chart_path,
		fixture_audio_path,
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	DirAccess.remove_absolute(editor_fixture_absolute)

	await _check_screen(scene_manager, "main_menu", "MainMenu")
	var main_menu = scene_manager.current_scene
	if main_menu != null and main_menu.name == "MainMenu":
		var character_idle = main_menu.get_node_or_null(
			"MenuMargins/PageLayout/MenuBody/CharacterShowcase/IdleRig"
		)
		_expect(character_idle != null, "El personaje del menú incluye una animación idle")
		if character_idle != null:
			_expect(
				character_idle.has_blink_frame(),
				"El parpadeo conserva el tamaño del sprite aprobado"
			)
			_expect(
				character_idle.uses_pixel_safe_motion(),
				"El idle usa movimiento entero y filtrado nearest"
			)
			_expect(
				character_idle.has_interactive_headphone_pulse(),
				"Los audífonos incluyen una respuesta visual al cambiar de opción"
			)
			character_idle.trigger_selection_pulse(&"settings")
			_expect(
				character_idle.headphone_pulse.visible
				and character_idle.selection_pulse_remaining_seconds > 0.0,
				"Seleccionar una opción activa el pulso de los audífonos"
			)
			settings_manager.settings["reduced_motion"] = true
			character_idle._process(0.5)
			_expect(
				character_idle.scale.is_equal_approx(character_idle.rest_scale)
				and character_idle.character.position.is_equal_approx(
					character_idle.rest_character_position
				)
				and character_idle.character.texture == character_idle.original_texture,
				"Reducir movimiento devuelve al personaje a su pose estática"
			)
			character_idle.trigger_selection_pulse(&"editor")
			_expect(
				not character_idle.headphone_pulse.visible,
				"Reducir movimiento también desactiva la respuesta de los audífonos"
			)
			settings_manager.settings["reduced_motion"] = false
	await _check_screen(scene_manager, "song_select", "SongSelect")
	var song_select = scene_manager.current_scene
	if song_select != null and song_select.name == "SongSelect":
		_expect(song_select.preview_video != null, "La biblioteca incluye vista previa de video")
		_expect(song_select.preview_button != null, "La vista previa tiene un control visible")
		_expect(song_select.delete_button != null, "La biblioteca incluye el botón de borrar")
		_expect(song_select.delete_modal != null, "Borrar abre una confirmación integrada")
		_expect(
			song_select.delete_dialog_message != null
			and song_select.delete_confirm_button != null
			and song_select.delete_cancel_button != null,
			"La confirmación de borrado ofrece mensaje, cancelar y mover a Papelera"
		)
		_expect(
			song_select.delete_button.disabled,
			"Sin canciones, la acción de borrado permanece desactivada"
		)
		var editor_song_probe := SongData.new()
		editor_song_probe.editor_project_path = "user://aurora_editor/probe/project.json"
		_expect(
			not song_manager.is_editor_song(editor_song_probe),
			"Un proyecto inexistente no puede borrarse por accidente"
		)

	game_manager.start_song(demo_song, demo_song.charts[0])
	scene_manager.load_scene("gameplay")
	await process_frame
	await process_frame
	var gameplay = scene_manager.current_scene
	_expect(gameplay != null and gameplay.name == "Gameplay", "Gameplay abre")
	if gameplay != null:
		_expect(
			gameplay.get_node_or_null("BackgroundVideo") == null,
			"Gameplay funciona sin incluir un video de demostración"
		)
		if gameplay.background_video_player != null:
			_expect(
				not gameplay.background_video_player.loop,
				"El video de gameplay termina con la canción y no se repite sin notas"
			)
			gameplay.background_video_player.paused = false
			gameplay.settings_manager.settings["background_animation_enabled"] = false
			gameplay._apply_visual_settings()
			_expect(
				not gameplay.background_video_player.visible
				and not gameplay.background_video_player.paused,
				"Ocultar el fondo no detiene la música ni el reloj del video"
			)
			gameplay.settings_manager.settings["background_animation_enabled"] = true
			gameplay._apply_visual_settings()
		_expect(gameplay.get_node_or_null("PlayfieldFrame") != null, "Gameplay crea el playfield central")
		_expect(
			not gameplay.start_gate_active and not gameplay.start_gate_panel.visible,
			"Una partida normal comienza sin pedir Espacio ni A/Cross"
		)
		_expect(gameplay.lane_panels.size() == 4, "Gameplay crea cuatro carriles")
		_expect(gameplay.lane_labels[0].text.length() <= 4, "Las etiquetas de teclas son compactas")
		_expect(gameplay.hit_line != null, "Gameplay crea una línea de impacto independiente")
		_expect(gameplay.control_deck != null, "Gameplay crea una plataforma inferior compacta")
		if gameplay.hit_line != null and gameplay.control_deck != null:
			var receptor_center_y: float = (
				gameplay.lane_receptors[0].global_position.y
				+ gameplay.lane_receptors[0].size.y * 0.5
			)
			var hit_line_center_y: float = (
				gameplay.hit_line.global_position.y
				+ gameplay.hit_line.size.y * 0.5
			)
			var line_to_receptor_gap: float = (
				gameplay.lane_receptors[0].global_position.y
				- hit_line_center_y
			)
			_expect(
				receptor_center_y > hit_line_center_y,
				"Los indicadores de carril están debajo de la línea de impacto"
			)
			_expect(
				line_to_receptor_gap >= 18.0 and line_to_receptor_gap <= 42.0,
				"La línea deja entre una y dos notas de espacio antes de los receptores"
			)
			_expect(
				gameplay.hit_line.size.y >= 36.0 and gameplay.hit_line.size.y <= 44.0,
				"La zona de impacto tiene aproximadamente tres cuartos de tecla"
			)
			_expect(
				gameplay.control_deck.size.y <= 170.0,
				"La plataforma inferior no roba espacio al área de notas"
			)
		_expect(
			gameplay.get_node_or_null("KeySound01") == null,
			"Gameplay no crea ni reproduce sonidos al pulsar carriles"
		)
		_expect(
			gameplay._get_judgment_for_error(0.060) == "PERFECT",
			"Una desviación de 60 ms todavía obtiene PERFECT"
		)
		_expect(
			gameplay._get_judgment_for_error(0.105) == "GREAT",
			"Una desviación de 105 ms todavía obtiene GREAT"
		)
		_expect(
			gameplay._get_judgment_for_error(0.155) == "GOOD",
			"Las pulsaciones cercanas conservan un juicio válido"
		)
		_expect(
			gameplay._get_judgment_for_error(0.230) == "MISS",
			"Las pulsaciones claramente fuera de tiempo siguen fallando"
		)
		var miss_count_before_ignored_notes: int = gameplay.miss_count
		var judged_count_before_ignored_notes: int = gameplay.judged_count
		var ignored_note_entries: Array[Dictionary] = []
		for ignored_duration in [0.0, 0.8]:
			var ignored_note_node := PanelContainer.new()
			gameplay.lane_note_layers[0].add_child(ignored_note_node)
			var ignored_note_entry: Dictionary = {
				"time": gameplay.gameplay_time - 0.230,
				"lane": 0,
				"duration": ignored_duration,
				"node": ignored_note_node,
				"holding": false,
			}
			ignored_note_entries.append(ignored_note_entry)
			gameplay.active_notes.append(ignored_note_entry)
		gameplay._update_active_notes()
		_expect(
			not gameplay.active_notes.has(ignored_note_entries[0])
			and gameplay.miss_count == miss_count_before_ignored_notes + 2,
			"Un tap ignorado recibe MISS y sale de las notas activas"
		)
		_expect(
			not gameplay.active_notes.has(ignored_note_entries[1])
			and gameplay.judged_count == judged_count_before_ignored_notes + 2,
			"Una nota sostenida no iniciada también recibe MISS"
		)
		gameplay.miss_count = miss_count_before_ignored_notes
		gameplay.judged_count = judged_count_before_ignored_notes
		gameplay._refresh_score_display()
		gameplay._refresh_progress()
		_expect(
			gameplay._get_hold_release_result(0.49, -0.2)["judgment"] == "MISS",
			"Soltar una nota sostenida antes de la mitad cuenta como fallo"
		)
		_expect(
			gameplay._get_hold_release_result(0.65, -0.3)["accuracy"] == 0.25,
			"Superar la mitad de una nota sostenida conserva el puntaje mínimo"
		)
		_expect(
			gameplay._get_hold_release_result(1.0, 0.0)["judgment"] == "PERFECT",
			"Soltar una nota sostenida al final obtiene PERFECT"
		)
		_expect(
			gameplay._get_hold_release_result(1.0, 0.09)["judgment"] == "GREAT",
			"Una liberación sostenida un poco tarde obtiene GREAT"
		)
		_expect(gameplay.combo_label.text.length() >= 3, "El combo usa un contador legible de tres dígitos")
		_expect(gameplay.timing_feedback_label != null, "Gameplay muestra feedback de sincronización")
		gameplay._show_timing_feedback(-0.024)
		_expect(gameplay.timing_feedback_label.text.begins_with("EARLY"), "El feedback detecta una pulsación temprana")
		gameplay._show_timing_feedback(0.031)
		_expect(gameplay.timing_feedback_label.text.begins_with("LATE"), "El feedback detecta una pulsación tardía")
		gameplay._show_miss_timing_feedback()
		_expect(
			gameplay.timing_feedback_label.text == "NO INPUT",
			"Un MISS limpia el valor de sincronización anterior"
		)
		gameplay._record_timing_sample(-0.024)
		gameplay._record_timing_sample(0.004)
		var timing_result: Dictionary = gameplay._build_result_data()
		_expect(int(timing_result.get("timing_samples", 0)) == 2, "Gameplay registra muestras de sincronización")
		_expect(int(timing_result.get("average_timing_ms", 0)) == -10, "Gameplay calcula el sesgo promedio")
		_expect(int(timing_result.get("early_hits", 0)) == 1, "Gameplay cuenta pulsaciones tempranas")
		_expect(int(timing_result.get("on_time_hits", 0)) == 1, "Gameplay cuenta pulsaciones a tiempo")
		_expect(gameplay._is_combo_milestone(10), "Gameplay reconoce hitos de combo")
		_expect(not gameplay._is_combo_milestone(9), "Gameplay evita falsos hitos de combo")
		var previous_hit_effects = gameplay.settings_manager.settings.get("show_hit_effects", true)
		gameplay.settings_manager.settings["show_hit_effects"] = true
		gameplay.miss_feedback_duration = 0.01
		gameplay._play_miss_effect(0)
		_expect(
			gameplay.lane_receptors[0].modulate.r > gameplay.lane_receptors[0].modulate.g,
			"Un MISS identifica visualmente el carril responsable"
		)
		await create_timer(0.05, true).timeout
		_expect(
			gameplay.lane_receptors[0].modulate.is_equal_approx(Color.WHITE),
			"El destello de MISS se limpia automáticamente"
		)
		gameplay.settings_manager.settings["show_hit_effects"] = previous_hit_effects
		_expect(
			gameplay.miss_sound_player != null and gameplay.miss_sound_player.stream != null,
			"Gameplay prepara un sonido propio para los fallos"
		)
		gameplay._play_miss_sound()
		_expect(gameplay.miss_sound_player.playing, "Un MISS activa el feedback sonoro")
		_expect(gameplay.pause_menu != null, "El menú de pausa está integrado")
		if gameplay.pause_menu != null:
			_expect(
				gameplay.pause_menu.track_title_label.text == demo_song.title.to_upper(),
				"La pausa identifica la canción actual"
			)
			_expect(
				gameplay.pause_menu.track_meta_label.text.contains(
					game_manager.current_chart.get_mode_label()
				),
				"La pausa muestra el modo de teclas actual"
			)
			_expect(
				gameplay.pause_menu.track_meta_label.text.contains(
					game_manager.current_chart.get_difficulty_label().to_upper()
				),
				"La pausa muestra la dificultad actual"
			)
			gameplay.pause_menu.set_playback_progress(65.0, 130.0)
			_expect(
				is_equal_approx(gameplay.pause_menu.track_progress.value, 0.5),
				"La pausa representa el avance de la canción"
			)
			_expect(
				gameplay.pause_menu.track_time_label.text == "01:05 / 02:10",
				"La pausa muestra el tiempo transcurrido y total"
			)
			AuroraUi.update_stepper_buttons(gameplay.pause_menu.speed_down, gameplay.pause_menu.speed_up, 1.0, 1.0, 10.0)
			_expect(gameplay.pause_menu.speed_down.disabled, "El control de velocidad bloquea el límite mínimo")
			_expect(not gameplay.pause_menu.speed_up.disabled, "El control de velocidad permite subir desde el mínimo")
			AuroraUi.update_stepper_buttons(gameplay.pause_menu.speed_down, gameplay.pause_menu.speed_up, 10.0, 1.0, 10.0)
			_expect(gameplay.pause_menu.speed_up.disabled, "El control de velocidad bloquea el límite máximo")
			gameplay.pause_menu._refresh_controls()
			var controller_pause := InputEventJoypadButton.new()
			controller_pause.button_index = JOY_BUTTON_START
			controller_pause.pressed = true
			gameplay._input(controller_pause)
			_expect(paused, "La pausa detiene el árbol")
			_expect(gameplay.pause_menu.visible, "Menu/Options abre el menú de pausa")
			gameplay.pause_menu.resume_countdown_step_seconds = 0.01
			var controller_back := InputEventJoypadButton.new()
			controller_back.button_index = JOY_BUTTON_B
			controller_back.pressed = true
			gameplay.pause_menu._input(controller_back)
			_expect(paused, "La cuenta regresiva mantiene el juego pausado")
			_expect(
				gameplay.pause_menu.resume_in_progress,
				"B/Circle continúa e inicia la cuenta regresiva"
			)
			_expect(gameplay.pause_menu.resume_countdown_label.visible, "La cuenta regresiva es visible")
			await create_timer(0.15, true).timeout
			_expect(not paused, "El juego se reanuda al terminar la cuenta regresiva")
			_expect(not gameplay.pause_menu.visible, "El menú se oculta después de continuar")

	for chart_index in range(1, mini(demo_song.charts.size(), 3)):
		var chart = demo_song.charts[chart_index]
		game_manager.start_song(demo_song, chart)
		scene_manager.load_scene("gameplay")
		await process_frame
		await process_frame
		var mode_gameplay = scene_manager.current_scene
		_expect(
			mode_gameplay != null and mode_gameplay.lane_panels.size() == chart.key_count,
			"Gameplay adapta el playfield al modo %dK" % chart.key_count
		)
		if mode_gameplay != null and not mode_gameplay.lane_receptors.is_empty():
			var mode_receptor_center_y: float = (
				mode_gameplay.lane_receptors[0].global_position.y
				+ mode_gameplay.lane_receptors[0].size.y * 0.5
			)
			_expect(
				mode_receptor_center_y > mode_gameplay.hit_line.global_position.y,
				"El modo %dK mantiene los receptores bajo la línea" % chart.key_count
			)

	game_manager.complete_song({
		"score": 123456,
		"accuracy": 96.42,
		"max_combo": 54,
		"perfect": 42,
		"great": 9,
		"good": 2,
		"miss": 1,
		"total_notes": 54,
		"mode": "4K",
		"average_timing_ms": -12,
		"timing_samples": 53,
		"early_hits": 31,
		"late_hits": 14,
		"on_time_hits": 8,
	})
	scene_manager.load_scene("results")
	await process_frame
	await process_frame
	var results = scene_manager.current_scene
	_expect(results != null and results.name == "Results", "Resultados abre")
	if results != null:
		_expect(results.buttons.size() == 3, "Resultados ofrece tres acciones")
		_expect(
			results._get_clear_status({"total_notes": 60, "perfect": 60, "miss": 0})
			== AuroraLocale.text("PARTIDA PERFECTA"),
			"Resultados reconoce una partida perfecta"
		)
		_expect(
			results._get_clear_status({"total_notes": 60, "perfect": 52, "miss": 0})
			== AuroraLocale.text("COMBO COMPLETO"),
			"Resultados reconoce un full combo"
		)
		_expect(
			results._get_clear_status({"total_notes": 60, "perfect": 52, "miss": 1})
			== AuroraLocale.text("PISTA COMPLETADA"),
			"Resultados conserva el cierre normal cuando hay fallos"
		)
		_expect(
			results._format_timing_distribution({
				"early_hits": 31,
				"on_time_hits": 8,
				"late_hits": 14,
			}) == "31 / 8 / 14",
			"Resultados muestra la distribución de sincronización"
		)

	await _check_screen(scene_manager, "settings", "Settings")
	var settings_screen = scene_manager.current_scene
	if settings_screen != null and settings_screen.name == "Settings":
		_expect(settings_screen.category_buttons.size() == 6, "Configuración muestra seis categorías")
		_expect(
			settings_screen.header_title_label.text
			== AuroraLocale.text("CONFIGURACIÓN // %s") % AuroraLocale.text("GENERAL"),
			"Configuración integra la categoría en el encabezado"
		)
		_expect(
			settings_screen.content_scroll.size.x < 5000.0,
			"El contenido de Configuración mantiene un ancho estable"
		)
		settings_screen._arm_reset_confirmation()
		_expect(
			settings_screen.reset_confirmation_active
			and settings_screen.reset_button.text == AuroraLocale.text("CONFIRMAR"),
			"Restablecer requiere una segunda confirmación"
		)
		settings_screen.reset_confirmation_active = false
		settings_screen.reset_confirmation_token += 1
		settings_screen._show_category("controls")
		_expect(
			settings_screen.controller_status_label != null,
			"Configuración muestra el estado del mando"
		)
		_expect(
			input_manager.get_controller_layout_text(8, "playstation").begins_with("L1"),
			"Configuración presenta una distribución específica para PlayStation"
		)
		_expect(
			settings_screen.capture_kind.is_empty()
			and input_manager.get_controller_action_label("back").length() > 0,
			"Configuración permite preparar capturas de carriles y acciones del mando"
		)
		settings_screen._show_category("credits")
		var complete_licenses: String = settings_screen._build_complete_license_text()
		_expect(
			settings_screen.category_buttons.has("credits"),
			"Configuración incluye Créditos y licencias"
		)
		_expect(
			"GODOT ENGINE // MIT" in complete_licenses
			and (
				"FFMPEG 6.1.6 // GNU LGPL 2.1 O POSTERIOR"
				in complete_licenses
			)
			and "FFMPEG // BIBLIOTECAS EXTERNAS Y FUENTES" in complete_licenses
			and "PRESS START 2P // SIL OFL 1.1" in complete_licenses,
			"Créditos permite consultar las licencias completas incluidas"
		)
	await _check_screen(scene_manager, "editor", "Editor")
	var editor = scene_manager.current_scene
	if editor != null and editor.name == "Editor":
		_expect(editor.video_player != null, "El editor prepara una vista previa de video")
		_expect(
			editor._get_video_import_mode("music_video.mp4") == "convert",
			"El editor acepta MP4 mediante conversión automática"
		)
		_expect(
			editor._get_video_import_mode("native_video.ogv") == "direct",
			"El editor conserva la carga directa de OGV"
		)
		_expect(
			"libtheora" in Array(editor._build_ffmpeg_arguments("input.mp4", "output.ogv")),
			"La conversión genera un video Ogg Theora compatible con Godot"
		)
		var conversion_arguments := Array(
			editor._build_ffmpeg_arguments("input.mp4", "output.ogv")
		)
		_expect(
			"fps=30,scale=w='min(1280,iw)':h=-2:flags=lanczos,format=yuv420p"
			in conversion_arguments,
			"La conversión limita el video a 720p y 30 fps para evitar corrupción"
		)
		_expect(
			"-speed_level" not in conversion_arguments,
			"La conversión usa opciones aceptadas por el FFmpeg LGPL incluido"
		)
		var required_encoder_probe: Array[String] = ["libtheora", "libvorbis"]
		_expect(
			editor._ffmpeg_listing_has_all(
				" V..... libtheora Theora\n A..... libvorbis Vorbis",
				required_encoder_probe
			)
			and not editor._ffmpeg_listing_has_all(
				" V..... libtheora Theora",
				required_encoder_probe
			),
			"El editor acepta el conversor por capacidades reales, no por número de versión"
		)
		var audio_only_probe := AudioStreamGenerator.new()
		editor.audio_player.stream = audio_only_probe
		editor._refresh_editor_state()
		_expect(editor._has_media(), "El editor acepta proyectos que solo usan audio")
		_expect(not editor.record_button.disabled, "Un MP3 permite grabar notas sin video")
		editor.audio_player.stream = null
		editor._refresh_editor_state()
		_expect(editor.timeline != null, "El editor incluye una línea de tiempo interactiva")
		_expect(editor.record_button != null, "El editor ofrece grabación manual de notas")
		_expect(
			editor.creation_mode_switch != null
			and editor.manual_mode_label != null
			and editor.automatic_mode_label != null,
			"Manual y Automática se distinguen con un interruptor"
		)
		_expect(
			editor.test_button.get_parent() == editor.record_button.get_parent(),
			"Probar chart permanece visible junto a las herramientas principales"
		)
		_expect(
			editor.recording_countdown_label != null,
			"La grabación manual prepara una cuenta regresiva visible"
		)
		var generated_notes: Array[Dictionary] = editor._build_automatic_notes(128.0, 20.0, 4, 1)
		_expect(not generated_notes.is_empty(), "El editor genera un patrón automático por BPM")
		_expect(
			generated_notes.any(
				func(note: Dictionary) -> bool: return float(note.get("duration", 0.0)) >= 0.18
			),
			"La generación automática también crea notas sostenidas"
		)
		_expect(
			editor.size.y <= 1080.0 and editor.timeline.global_position.y < 1080.0,
			"El editor mantiene sus controles principales dentro de 1920x1080"
		)
		game_manager.start_editor_test(
			demo_song,
			demo_song.charts[0],
			"user://aurora_editor/test_return/project.json"
		)
		_expect(
			game_manager.editor_test_active
			and game_manager.editor_test_project_path.ends_with("project.json"),
			"Una prueba de chart recuerda el proyecto de origen"
		)
		scene_manager.load_scene("gameplay")
		await process_frame
		await process_frame
		var editor_test_gameplay = scene_manager.current_scene
		_expect(
			editor_test_gameplay != null
			and editor_test_gameplay.start_gate_active
			and editor_test_gameplay.start_gate_panel.visible,
			"Solo las pruebas del editor esperan la orden de inicio"
		)
		if editor_test_gameplay != null:
			editor_test_gameplay.start_countdown_step_seconds = 0.01
			var controller_start := InputEventJoypadButton.new()
			controller_start.button_index = input_manager.get_controller_action_button("confirm")
			controller_start.pressed = true
			editor_test_gameplay._input(controller_start)
			_expect(
				editor_test_gameplay.start_countdown_active,
				"El botón Confirmar configurado inicia la prueba del editor"
			)
			await create_timer(0.32, true).timeout
			_expect(
				not editor_test_gameplay.start_gate_active,
				"La prueba del editor arranca correctamente desde el mando"
			)
		var editor_return_path: String = game_manager.take_editor_test_project_path()
		_expect(
			editor_return_path.ends_with("project.json") and not game_manager.editor_test_active,
			"Volver al editor consume la ruta sin dejar una prueba atascada"
		)
	_finish()


func _check_screen(scene_manager: Node, route: String, expected_name: String) -> void:
	scene_manager.load_scene(route)
	await process_frame
	await process_frame
	var screen = scene_manager.current_scene
	_expect(screen != null and screen.name == expected_name, "%s abre" % expected_name)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("OK  ", description)
	else:
		failures.append(description)
		push_error("FAIL  %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
	else:
		print("SMOKE TEST FAILED: ", ", ".join(failures))
		quit(1)
