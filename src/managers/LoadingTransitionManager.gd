extends Node

class_name LoadingTransitionManager

signal transition_started(target_scene: String)
signal transition_finished(target_scene: String)

const DISPLAY_SECONDS := 5.0
const SETTINGS_COVER_SECONDS := 0.18
const SETTINGS_REVEAL_SECONDS := 0.42
const LIBRARY_COVER_SECONDS := 0.24
const LIBRARY_REVEAL_SECONDS := 0.42
const GAMEPLAY_TIPS := [
	"AJUSTA LA VELOCIDAD DE NOTAS DESDE OPCIONES.",
	"LAS NOTAS ESPECIALES PIDEN DOS CARRILES A LA VEZ.",
	"LOS RIELES LATERALES SE JUEGAN CON SHIFT IZQUIERDO Y DERECHO.",
	"PUEDES PAUSAR EN CUALQUIER MOMENTO DESDE EL JUEGO.",
	"UN HOLD SE TERMINA AL SOLTARLO CERCA DE SU FINAL.",
]
const GENERAL_TIPS := [
	"AURORA GUARDA LOS CAMBIOS DEL EDITOR EN TU CANCION BASE.",
	"PUEDES CAMBIAR LOS CONTROLES DESDE OPCIONES.",
	"LAS PORTADAS HACEN QUE CADA CARGA TENGA SU PROPIA IDENTIDAD.",
]

var overlay: Control
var progress_fill: ColorRect
var progress_track: Panel
var status_label: Label
var progress_label: Label
var elapsed := 0.0
var active_display_seconds := DISPLAY_SECONDS
var active := false
var pending_scene := ""
var completion := Callable()
var settings_reveal_started := false
var settings_scan_line: ColorRect
var library_reveal_started := false
var library_top_shutter: Panel
var library_bottom_shutter: Panel
var library_title: Label


func _ready() -> void:
	set_process(false)


func request_transition(target_scene: String, on_ready: Callable) -> bool:
	if active or not on_ready.is_valid():
		return false
	pending_scene = target_scene
	completion = on_ready
	elapsed = 0.0
	settings_reveal_started = false
	library_reveal_started = false
	active_display_seconds = (
		SETTINGS_COVER_SECONDS
		if target_scene == "settings"
		else LIBRARY_COVER_SECONDS
		if target_scene in ["song_select", "main_menu"]
		else DISPLAY_SECONDS
	)
	active = true
	_build_overlay(target_scene)
	set_process(true)
	transition_started.emit(target_scene)
	var feedback = get_parent().get_node_or_null("UiFeedbackManager")
	if feedback != null:
		feedback.play_loading()
	return true


func _process(delta: float) -> void:
	if not active:
		set_process(false)
		return
	elapsed = minf(elapsed + delta, active_display_seconds)
	var progress := clampf(elapsed / active_display_seconds, 0.0, 1.0)
	if pending_scene == "settings":
		if overlay != null and is_instance_valid(overlay):
			overlay.modulate.a = progress
			_update_settings_scan_line(progress)
		if progress >= 1.0:
			_begin_settings_reveal()
		return
	if pending_scene in ["song_select", "main_menu"]:
		if _reduced_motion_enabled():
			if overlay != null and is_instance_valid(overlay):
				overlay.modulate.a = progress
		else:
			_update_library_shutters(progress)
		if progress >= 1.0:
			_begin_library_reveal()
		return
	_update_progress_bar(progress)
	if progress_label != null:
		progress_label.text = "%03d%%" % roundi(progress * 100.0)
	if status_label != null:
		status_label.text = (
			"PREPARANDO ESCENA..."
			if progress < 0.42
			else "SINCRONIZANDO MEDIOS..."
			if progress < 0.82
			else "LISTO"
		)
	if progress < 1.0:
		return
	_complete_transition()


func _begin_settings_reveal() -> void:
	if settings_reveal_started:
		return
	settings_reveal_started = true
	var scene_name := pending_scene
	var next_action := completion
	completion = Callable()
	set_process(false)
	if next_action.is_valid():
		next_action.call(scene_name)
	if overlay == null or not is_instance_valid(overlay):
		_finish_settings_reveal(scene_name)
		return
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE)
	reveal.set_ease(Tween.EASE_OUT)
	reveal.tween_property(overlay, "modulate:a", 0.0, SETTINGS_REVEAL_SECONDS)
	reveal.finished.connect(_finish_settings_reveal.bind(scene_name))


func _finish_settings_reveal(scene_name: String) -> void:
	active = false
	pending_scene = ""
	settings_reveal_started = false
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	settings_scan_line = null
	transition_finished.emit(scene_name)


func _begin_library_reveal() -> void:
	if library_reveal_started:
		return
	library_reveal_started = true
	var scene_name := pending_scene
	var next_action := completion
	completion = Callable()
	set_process(false)
	if next_action.is_valid():
		next_action.call(scene_name)
	if overlay == null or not is_instance_valid(overlay):
		_finish_library_reveal(scene_name)
		return
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE)
	reveal.set_ease(Tween.EASE_OUT)
	reveal.set_parallel(true)
	if _reduced_motion_enabled():
		reveal.tween_property(overlay, "modulate:a", 0.0, 0.20)
	else:
		if library_top_shutter != null and is_instance_valid(library_top_shutter):
			reveal.tween_property(library_top_shutter, "offset_bottom", 0.0, LIBRARY_REVEAL_SECONDS)
		if library_bottom_shutter != null and is_instance_valid(library_bottom_shutter):
			reveal.tween_property(library_bottom_shutter, "offset_top", 0.0, LIBRARY_REVEAL_SECONDS)
		if library_title != null and is_instance_valid(library_title):
			reveal.tween_property(library_title, "modulate:a", 0.0, LIBRARY_REVEAL_SECONDS * 0.55)
	reveal.finished.connect(_finish_library_reveal.bind(scene_name))


func _finish_library_reveal(scene_name: String) -> void:
	active = false
	pending_scene = ""
	library_reveal_started = false
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	library_top_shutter = null
	library_bottom_shutter = null
	library_title = null
	transition_finished.emit(scene_name)


func _complete_transition() -> void:
	var scene_name := pending_scene
	var next_action := completion
	active = false
	pending_scene = ""
	completion = Callable()
	set_process(false)
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	if next_action.is_valid():
		next_action.call(scene_name)
	transition_finished.emit(scene_name)


func _build_overlay(target_scene: String) -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	var app := get_tree().current_scene
	if app == null:
		return
	var popup_layer := app.get_node_or_null("PopupLayer")
	if popup_layer == null:
		return
	overlay = Control.new()
	overlay.name = "LoadingTransition"
	AuroraUi.fill(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_layer.add_child(overlay)
	if target_scene == "settings":
		_build_settings_transition()
		return
	if target_scene in ["song_select", "main_menu"]:
		_build_library_transition(target_scene)
		return

	var backdrop := ColorRect.new()
	AuroraUi.fill(backdrop)
	backdrop.color = Color(0.003, 0.006, 0.020, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(backdrop)
	var song: Variant = _get_song_for_scene(target_scene)
	var cover := _get_song_cover(song)
	if cover != null:
		var cover_view := TextureRect.new()
		cover_view.name = "LoadingCover"
		cover_view.texture = cover
		AuroraUi.fill(cover_view)
		cover_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cover_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(cover_view)
		var cover_shade := ColorRect.new()
		AuroraUi.fill(cover_shade)
		cover_shade.color = Color(0.008, 0.010, 0.034, 0.27)
		cover_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(cover_shade)
	else:
		var upper_glow := ColorRect.new()
		upper_glow.anchor_right = 1.0
		upper_glow.offset_bottom = 220.0
		upper_glow.color = Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.18)
		upper_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(upper_glow)
		var lower_glow := ColorRect.new()
		lower_glow.anchor_top = 1.0
		lower_glow.anchor_right = 1.0
		lower_glow.anchor_bottom = 1.0
		lower_glow.offset_top = -260.0
		lower_glow.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.16)
		lower_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(lower_glow)
		var automatic_card := PanelContainer.new()
		automatic_card.anchor_left = 0.5
		automatic_card.anchor_top = 0.5
		automatic_card.anchor_right = 0.5
		automatic_card.anchor_bottom = 0.5
		automatic_card.offset_left = -250.0
		automatic_card.offset_top = -90.0
		automatic_card.offset_right = 250.0
		automatic_card.offset_bottom = 90.0
		automatic_card.add_theme_stylebox_override(
			"panel",
			AuroraUi.make_style(
				Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.14),
				Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.72),
				6
			)
		)
		overlay.add_child(automatic_card)
		var automatic_title := AuroraUi.make_pixel_label(
			_get_loading_title(song, target_scene),
			18,
			AuroraUi.TEAL
		)
		automatic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		automatic_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		automatic_card.add_child(automatic_title)

	var heading := AuroraUi.make_pixel_label("AURORA // CARGANDO", 14, AuroraUi.TEXT)
	heading.anchor_left = 0.5
	heading.anchor_right = 0.5
	heading.offset_left = -320.0
	heading.offset_right = 320.0
	heading.offset_top = 36.0
	heading.offset_bottom = 68.0
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(heading)

	var information := VBoxContainer.new()
	information.anchor_left = 0.08
	information.anchor_top = 1.0
	information.anchor_right = 0.92
	information.anchor_bottom = 1.0
	information.offset_top = -198.0
	information.offset_bottom = -84.0
	information.add_theme_constant_override("separation", 6)
	information.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(information)
	var title := AuroraUi.make_pixel_label(_get_loading_title(song, target_scene), 12, AuroraUi.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.add_child(title)
	var artist := AuroraUi.make_label(_get_loading_subtitle(song, target_scene), 13, AuroraUi.MUTED)
	artist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	information.add_child(artist)
	status_label = AuroraUi.make_pixel_label("PREPARANDO ESCENA...", 8, AuroraUi.GOLD)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	information.add_child(status_label)
	var tip := AuroraUi.make_label(_get_tip(target_scene), 11, AuroraUi.TEXT)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.add_child(tip)

	progress_track = Panel.new()
	progress_track.anchor_left = 0.06
	progress_track.anchor_top = 1.0
	progress_track.anchor_right = 0.94
	progress_track.anchor_bottom = 1.0
	progress_track.offset_top = -57.0
	progress_track.offset_bottom = -29.0
	progress_track.add_theme_stylebox_override(
		"panel",
		AuroraUi.make_style(Color(0.004, 0.006, 0.018, 0.94), AuroraUi.VIOLET, 2)
	)
	overlay.add_child(progress_track)
	progress_fill = ColorRect.new()
	progress_fill.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.88)
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(progress_fill)
	progress_label = AuroraUi.make_pixel_label("000%", 8, AuroraUi.TEXT)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	AuroraUi.fill(progress_label)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(progress_label)
	call_deferred("_update_progress_bar", 0.0)


func _build_settings_transition() -> void:
	var background := TextureRect.new()
	background.name = "SettingsTransitionArtwork"
	background.texture = load("res://assets/menu/background/cabina_aurora_menu.png") as Texture2D
	AuroraUi.fill(background)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)

	var shade := ColorRect.new()
	AuroraUi.fill(shade)
	shade.color = Color(0.002, 0.006, 0.024, 0.70)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)

	var card := PanelContainer.new()
	card.name = "SettingsTransitionCard"
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -330.0
	card.offset_top = -76.0
	card.offset_right = 330.0
	card.offset_bottom = 76.0
	card.add_theme_stylebox_override(
		"panel",
		AuroraUi.make_style(
			Color(0.003, 0.014, 0.042, 0.94),
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.90),
			0
		)
	)
	overlay.add_child(card)
	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 12)
	card.add_child(card_content)
	var title := AuroraUi.make_pixel_label("CABINA AURORA // OPCIONES", 14, AuroraUi.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_content.add_child(title)
	var subtitle := AuroraUi.make_pixel_label("ABRIENDO CONSOLA DE MEZCLA", 8, AuroraUi.TEAL)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_content.add_child(subtitle)

	settings_scan_line = ColorRect.new()
	settings_scan_line.name = "SettingsTransitionScanLine"
	settings_scan_line.anchor_right = 1.0
	settings_scan_line.anchor_top = 0.18
	settings_scan_line.anchor_bottom = 0.18
	settings_scan_line.offset_bottom = 2.0
	settings_scan_line.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.58)
	settings_scan_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(settings_scan_line)


func _build_library_transition(target_scene: String) -> void:
	library_top_shutter = Panel.new()
	library_top_shutter.name = "LibraryTopShutter"
	library_top_shutter.anchor_right = 1.0
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.002, 0.006, 0.026, 0.98)
	top_style.border_color = AuroraUi.TEAL
	top_style.border_width_bottom = 4
	library_top_shutter.add_theme_stylebox_override("panel", top_style)
	library_top_shutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(library_top_shutter)

	library_bottom_shutter = Panel.new()
	library_bottom_shutter.name = "LibraryBottomShutter"
	library_bottom_shutter.anchor_top = 1.0
	library_bottom_shutter.anchor_right = 1.0
	library_bottom_shutter.anchor_bottom = 1.0
	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color(0.002, 0.006, 0.026, 0.98)
	bottom_style.border_color = AuroraUi.VIOLET
	bottom_style.border_width_top = 4
	library_bottom_shutter.add_theme_stylebox_override("panel", bottom_style)
	library_bottom_shutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(library_bottom_shutter)

	library_title = AuroraUi.make_pixel_label("CABINA  //  MENÚ PRINCIPAL" if target_scene == "main_menu" else "AURORA  //  BIBLIOTECA DE CANCIONES", 17, AuroraUi.TEXT)
	library_title.name = "LibraryTransitionTitle"
	library_title.anchor_left = 0.5
	library_title.anchor_top = 0.5
	library_title.anchor_right = 0.5
	library_title.anchor_bottom = 0.5
	library_title.offset_left = -390.0
	library_title.offset_top = -30.0
	library_title.offset_right = 390.0
	library_title.offset_bottom = 30.0
	library_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	library_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	library_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(library_title)
	if _reduced_motion_enabled():
		_update_library_shutters(1.0)
		overlay.modulate.a = 0.0
	else:
		_update_library_shutters(0.0)


func _update_library_shutters(progress: float) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	var half_height := overlay.size.y * 0.5
	var eased := 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 2.0)
	if library_top_shutter != null and is_instance_valid(library_top_shutter):
		library_top_shutter.offset_bottom = half_height * eased
	if library_bottom_shutter != null and is_instance_valid(library_bottom_shutter):
		library_bottom_shutter.offset_top = -half_height * eased
	if library_title != null and is_instance_valid(library_title):
		library_title.modulate.a = clampf((progress - 0.55) / 0.45, 0.0, 1.0)


func _reduced_motion_enabled() -> bool:
	var manager = get_parent().get_node_or_null("SettingsManager")
	return manager != null and bool(manager.get_setting("reduced_motion", false))


func _update_settings_scan_line(progress: float) -> void:
	if settings_scan_line == null or not is_instance_valid(settings_scan_line):
		return
	var position := lerpf(0.18, 0.82, clampf(progress, 0.0, 1.0))
	settings_scan_line.anchor_top = position
	settings_scan_line.anchor_bottom = position


func _update_progress_bar(progress: float) -> void:
	if progress_fill == null or progress_track == null:
		return
	var horizontal_padding := 4.0
	var vertical_padding := 4.0
	var available_width := maxf(
		progress_track.size.x - horizontal_padding * 2.0,
		0.0
	)
	var available_height := maxf(
		progress_track.size.y - vertical_padding * 2.0,
		0.0
	)
	progress_fill.position = Vector2(horizontal_padding, vertical_padding)
	progress_fill.size = Vector2(
		available_width * clampf(progress, 0.0, 1.0),
		available_height
	)


func _get_song_for_scene(target_scene: String):
	if target_scene != "gameplay":
		return null
	var game_manager = get_parent().get_node_or_null("GameManager")
	return game_manager.current_song if game_manager != null else null


func _get_song_cover(song) -> Texture2D:
	if song == null:
		return null
	var song_manager = get_parent().get_node_or_null("SongManager")
	if song_manager != null:
		song_manager.ensure_song_cover_loaded(song)
	return song.cover


func _get_loading_title(song, target_scene: String) -> String:
	if song != null and not str(song.title).strip_edges().is_empty():
		return str(song.title).to_upper()
	match target_scene:
		"editor":
			return "EDITOR DE NIVELES"
		"settings":
			return "OPCIONES"
	return "AURORA"


func _get_loading_subtitle(song, target_scene: String) -> String:
	if song != null and not str(song.artist).strip_edges().is_empty():
		return str(song.artist).to_upper()
	match target_scene:
		"editor":
			return "PREPARANDO HERRAMIENTAS"
		"settings":
			return "CARGANDO CONFIGURACION"
	return "PREPARANDO EXPERIENCIA"


func _get_tip(target_scene: String) -> String:
	var tips := GAMEPLAY_TIPS if target_scene == "gameplay" else GENERAL_TIPS
	return "CONSEJO // %s" % str(tips[Time.get_ticks_msec() % tips.size()])
