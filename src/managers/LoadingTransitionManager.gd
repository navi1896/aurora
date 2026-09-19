extends Node

class_name LoadingTransitionManager

signal transition_started(target_scene: String)
signal transition_finished(target_scene: String)

const DISPLAY_SECONDS := 5.0
const GAMEPLAY_TIPS := [
	"AJUSTA LA VELOCIDAD DE NOTAS DESDE OPCIONES.",
	"LAS NOTAS ESPECIALES PIDEN DOS CARRILES A LA VEZ.",
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
var active := false
var pending_scene := ""
var completion := Callable()


func _ready() -> void:
	set_process(false)


func request_transition(target_scene: String, on_ready: Callable) -> bool:
	if active or not on_ready.is_valid():
		return false
	pending_scene = target_scene
	completion = on_ready
	elapsed = 0.0
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
	elapsed = minf(elapsed + delta, DISPLAY_SECONDS)
	var progress := clampf(elapsed / DISPLAY_SECONDS, 0.0, 1.0)
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
