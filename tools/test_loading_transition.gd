extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app := (load("res://src/App.tscn") as PackedScene).instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	var scenes := app.get_node_or_null("Managers/SceneManager") as SceneManager
	var loading = app.get_node_or_null("Managers/LoadingTransitionManager") as LoadingTransitionManager
	var popup_layer := app.get_node_or_null("PopupLayer")
	_expect(scenes != null and scenes.current_scene_name == "main_menu", "Inicia desde el menú")
	_expect(
		scenes != null and not scenes.loading_transitions_enabled,
		"La verificación sin ventana mantiene las transiciones inmediatas"
	)
	_expect(loading != null, "Carga el gestor de transiciones")
	if scenes != null and loading != null:
		_expect(
			loading.request_transition("settings", Callable(scenes, "_load_scene_immediately")),
			"Solicita la transición breve de configuración"
		)
		_expect(
			loading.active_display_seconds == LoadingTransitionManager.SETTINGS_COVER_SECONDS
			and popup_layer != null
			and popup_layer.get_node_or_null("LoadingTransition/SettingsTransitionCard") != null,
			"Configuración usa su transición visual breve"
		)
		loading._process(LoadingTransitionManager.SETTINGS_COVER_SECONDS + 0.01)
		await process_frame
		_expect(
			scenes.current_scene_name == "settings",
			"La transición breve abre configuración"
		)
		await create_timer(LoadingTransitionManager.SETTINGS_REVEAL_SECONDS + 0.1).timeout
		await process_frame
		_expect(
			popup_layer != null and popup_layer.get_node_or_null("LoadingTransition") == null,
			"Retira la transición breve al terminar"
		)

		var game_manager := app.get_node_or_null("Managers/GameManager") as GameManager
		var cover_image := Image.create(16, 9, false, Image.FORMAT_RGBA8)
		cover_image.fill(Color(0.1, 0.8, 0.95, 1.0))
		var cover_song := SongData.new()
		cover_song.title = "Portada completa"
		cover_song.cover = ImageTexture.create_from_image(cover_image)
		if game_manager != null:
			game_manager.current_song = cover_song
		_expect(
			loading.request_transition("gameplay", Callable(scenes, "_load_scene_immediately")),
			"Solicita la carga de juego con portada"
		)
		await process_frame
		var cover_view := popup_layer.get_node_or_null("LoadingTransition/LoadingCover") as TextureRect
		_expect(
			cover_view != null
			and cover_view.get_global_rect().size.x >= float(root.size.x) * 0.99
			and cover_view.get_global_rect().size.y >= float(root.size.y) * 0.99,
			"La portada ocupa la pantalla completa durante la carga"
		)
		loading._process(LoadingTransitionManager.DISPLAY_SECONDS * 0.5)
		await process_frame
		_expect(
			loading.progress_track != null
			and loading.progress_fill != null
			and loading.progress_track.get_global_rect().encloses(
				loading.progress_fill.get_global_rect()
			)
			and loading.progress_fill.size.x > 0.0
			and loading.progress_fill.size.x < loading.progress_track.size.x,
			"La transición de juego contiene la barra y refleja el avance"
		)
		loading._process(LoadingTransitionManager.DISPLAY_SECONDS + 0.01)
		await process_frame
		_expect(scenes.current_scene_name == "gameplay", "Abre el juego al completar la transición")
		_expect(
			popup_layer.get_node_or_null("LoadingTransition") == null,
			"Retira la transición de juego al terminar"
		)
	if failures.is_empty():
		print("LOADING TRANSITION TEST PASSED")
		quit(0)
	else:
		push_error("LOADING TRANSITION TEST FAILED:\n" + "\n".join(failures))
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
