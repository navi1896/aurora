extends Control

signal action_selected(action: StringName)

const TRACK_CARD_RECT := Rect2(0.362, 0.298, 0.276, 0.212)
const SELECTOR_ARROW := preload("res://assets/menu/ui/selector_arrow.png")
const CABINET_ART := preload("res://assets/menu/background/cabina_aurora_menu.png")
const ARROW_ART_RECTS := [
	Rect2(563.0, 314.0, 44.0, 80.0),
	Rect2(1064.0, 314.0, 44.0, 80.0),
]
const AMBIENT_GLOW_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float upper = step(0.36, UV.x) * step(UV.x, 0.66) * step(0.20, UV.y) * step(UV.y, 0.29);
	float console = step(0.35, UV.x) * step(UV.x, 0.67) * step(0.50, UV.y) * step(UV.y, 0.72);
	float sides = (step(0.33, UV.x) * step(UV.x, 0.37) + step(0.63, UV.x) * step(UV.x, 0.67))
		* step(0.30, UV.y) * step(UV.y, 0.51);
	float lit = smoothstep(0.20, 0.63, max(source.r, max(source.g, source.b)));
	float pulse = 0.48 + 0.52 * sin(TIME * 1.35);
	float alpha = source.a * lit * (upper * 0.10 + console * 0.08 + sides * 0.17) * pulse;
	COLOR = vec4(source.rgb, alpha);
}
"""
const ARROW_GLOW_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add;

uniform float left_strength = 0.12;
uniform float right_strength = 0.12;
uniform float animate = 1.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float left = step(0.337, UV.x) * step(UV.x, 0.363) * step(0.334, UV.y) * step(UV.y, 0.419);
	float right = step(0.636, UV.x) * step(UV.x, 0.663) * step(0.334, UV.y) * step(UV.y, 0.419);
	float brightness = max(source.r, max(source.g, source.b));
	float pink = max(source.r - source.g * 0.7, 0.0);
	float lit = smoothstep(0.13, 0.42, pink) * smoothstep(0.24, 0.68, brightness);
	float pulse = mix(1.0, 0.86 + 0.14 * sin(TIME * 2.1), animate);
	float alpha = source.a * lit * (left * left_strength + right * right_strength) * pulse;
	COLOR = vec4(source.rgb, alpha);
}
"""
const HOTSPOTS: Array[Dictionary] = [
	{
		"name": &"BtnStart",
		"action": &"play",
		"label": "JUGAR",
		"rect": Rect2(0.35, 0.56, 0.30, 0.16),
		"glow_rect": Rect2(0.347, 0.542, 0.308, 0.163),
		"glow_corner": Vector2(0.075, 0.24),
	},
	{
		"name": &"BtnLevelEditor",
		"action": &"editor",
		"label": "CREAR",
		"rect": Rect2(0.758, 0.37, 0.22, 0.108),
		"glow_rect": Rect2(0.762, 0.367, 0.218, 0.110),
		"glow_corner": Vector2(0.065, 0.20),
	},
	{
		"name": &"BtnOptions",
		"action": &"settings",
		"label": "OPCIONES",
		"rect": Rect2(0.758, 0.493, 0.22, 0.108),
		"glow_rect": Rect2(0.762, 0.484, 0.218, 0.113),
		"glow_corner": Vector2(0.065, 0.20),
	},
	{
		"name": &"BtnExit",
		"action": &"quit",
		"label": "SALIR",
		"rect": Rect2(0.758, 0.608, 0.22, 0.108),
		"glow_rect": Rect2(0.762, 0.600, 0.218, 0.115),
		"glow_corner": Vector2(0.065, 0.20),
	},
]
const SPECTRUM_COLORS := [AuroraUi.TEAL, Color(1.0, 0.22, 0.87, 1.0)]
const BUTTON_GLOW_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_region = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 corner_size = vec2(0.075, 0.20);
uniform float glow_strength = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 local = (UV - glow_region.xy) / max(glow_region.zw, vec2(0.0001));
	float inside = step(0.0, local.x) * step(local.x, 1.0)
		* step(0.0, local.y) * step(local.y, 1.0);
	float corners = step(1.0, local.x / corner_size.x + local.y / corner_size.y)
		* step(1.0, (1.0 - local.x) / corner_size.x + local.y / corner_size.y)
		* step(1.0, local.x / corner_size.x + (1.0 - local.y) / corner_size.y)
		* step(1.0, (1.0 - local.x) / corner_size.x + (1.0 - local.y) / corner_size.y);
	float brightness = max(source.r, max(source.g, source.b));
	float lit_pixels = smoothstep(0.40, 0.82, brightness);
	float pulse = 0.92 + 0.08 * sin(TIME * 4.6);
	float alpha = source.a * inside * corners * lit_pixels * glow_strength * pulse;
	COLOR = vec4(source.rgb, alpha);
}
"""

static var remembered_action: StringName = &"play"

var song_manager: SongManager
var menu_music_manager: MenuMusicManager
var ui_feedback: UiFeedbackManager
var settings_manager: SettingsManager
var song_catalog: Array[SongData] = []
var song_index := 0
var displayed_song: SongData
var spectrum_elapsed := 0.0
var track_card: PanelContainer
var track_card_background: Polygon2D
var cover_image: TextureRect
var cover_placeholder: Label
var title_label: Label
var artist_label: Label
var modes_label: Label
var position_label: Label
var song_content: HBoxContainer
var spectrum_bars: Array[ColorRect] = []
var progress_track: ColorRect
var progress_fill: ColorRect
var arrow_buttons: Array[Button] = []
var arrow_down := [false, false]
var arrow_glow_material: ShaderMaterial
var card_tween: Tween
var buttons_by_action: Dictionary = {}
var hovered_action: StringName = &""
var ui_scale := 1.0
var focus_glow: TextureRect
var glow_material: ShaderMaterial
var glow_tween: Tween
var current_glow_strength := 0.0
var action_selector: TextureRect
var selector_base_position := Vector2.ZERO


func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	ui_scale = clampf(
		minf(viewport_size.x / 1672.0, viewport_size.y / 953.0),
		0.45,
		1.35
	)
	var app := get_tree().current_scene
	if app != null:
		settings_manager = app.get_node_or_null("Managers/SettingsManager") as SettingsManager
		ui_feedback = app.get_node_or_null("Managers/UiFeedbackManager") as UiFeedbackManager
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interaction_glow()
	_build_ambient_light()
	_build_arrow_glow()
	_build_track_card()
	_build_action_selector()
	_build_song_arrows()
	_build_hotspots()
	_connect_song_arrow_focus()
	_load_song_catalog()
	call_deferred("focus_default_button")
	set_process(true)


func _process(delta: float) -> void:
	_update_song_progress()
	if settings_manager != null and bool(settings_manager.get_setting("reduced_motion", false)):
		if action_selector != null:
			action_selector.position = selector_base_position
			action_selector.modulate.a = 1.0
		return
	spectrum_elapsed += delta
	_update_spectrum(delta)


func focus_default_button() -> void:
	var button := buttons_by_action.get(remembered_action) as Button
	if button == null and buttons_by_action.has(&"play"):
		button = buttons_by_action[&"play"] as Button
	if button != null:
		button.grab_focus()


func _build_ambient_light() -> void:
	var background := get_parent().get_node_or_null("Background") as TextureRect
	if background == null or background.texture == null:
		return
	var ambient := TextureRect.new()
	ambient.name = "CabinetAmbientLight"
	AuroraUi.fill(ambient)
	ambient.texture = background.texture
	ambient.expand_mode = background.expand_mode
	ambient.stretch_mode = background.stretch_mode
	ambient.texture_filter = background.texture_filter
	ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = AMBIENT_GLOW_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	ambient.material = material
	ambient.visible = settings_manager == null or not bool(settings_manager.get_setting("reduced_motion", false))
	add_child(ambient)
	move_child(ambient, 0)


func _build_arrow_glow() -> void:
	var background := get_parent().get_node_or_null("Background") as TextureRect
	if background == null or background.texture == null:
		return
	var overlay := TextureRect.new()
	overlay.name = "CabinetArrowGlow"
	AuroraUi.fill(overlay)
	overlay.texture = background.texture
	overlay.expand_mode = background.expand_mode
	overlay.stretch_mode = background.stretch_mode
	overlay.texture_filter = background.texture_filter
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = ARROW_GLOW_SHADER_CODE
	arrow_glow_material = ShaderMaterial.new()
	arrow_glow_material.shader = shader
	arrow_glow_material.set_shader_parameter("animate", 0.0 if settings_manager != null and bool(settings_manager.get_setting("reduced_motion", false)) else 1.0)
	overlay.material = arrow_glow_material
	add_child(overlay)


func _build_song_arrows() -> void:
	var art_size := Vector2(CABINET_ART.get_size())
	for index in range(ARROW_ART_RECTS.size()):
		var direction := -1 if index == 0 else 1
		var art_rect: Rect2 = ARROW_ART_RECTS[index]
		var button := Button.new()
		button.name = "PreviousSong" if direction < 0 else "NextSong"
		button.tooltip_text = AuroraLocale.text("CANCIÓN ANTERIOR" if direction < 0 else "SIGUIENTE CANCIÓN")
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		_set_normalized_rect(button, Rect2(art_rect.position / art_size, art_rect.size / art_size))
		add_child(button)
		button.mouse_entered.connect(_set_arrow_highlight.bind(index))
		button.mouse_exited.connect(_set_arrow_highlight.bind(index))
		button.focus_entered.connect(_set_arrow_highlight.bind(index))
		button.focus_exited.connect(_set_arrow_highlight.bind(index))
		button.button_down.connect(_set_arrow_pressed_visual.bind(index, true))
		button.button_up.connect(_set_arrow_pressed_visual.bind(index, false))
		button.pressed.connect(_on_song_arrow_pressed.bind(direction))
		arrow_buttons.append(button)


func _set_arrow_pressed_visual(index: int, pressed: bool) -> void:
	if index < 0 or index >= arrow_buttons.size():
		return
	arrow_down[index] = pressed
	_set_arrow_highlight(index)


func _set_arrow_highlight(index: int) -> void:
	if index < 0 or index >= arrow_buttons.size():
		return
	var highlighted := arrow_buttons[index].has_focus() or arrow_buttons[index].is_hovered()
	var strength := 0.22 if arrow_down[index] else (1.15 if highlighted else 0.12)
	if arrow_glow_material != null:
		arrow_glow_material.set_shader_parameter("left_strength" if index == 0 else "right_strength", strength)


func _on_song_arrow_pressed(direction: int) -> void:
	if ui_feedback != null:
		ui_feedback.play_cabinet_click()
	if menu_music_manager != null:
		menu_music_manager.choose_relative_song(direction)


func _connect_song_arrow_focus() -> void:
	if arrow_buttons.size() < 2:
		return
	var play_button := buttons_by_action.get(&"play") as Button
	if play_button == null:
		return
	play_button.focus_neighbor_left = play_button.get_path_to(arrow_buttons[0])
	play_button.focus_neighbor_right = play_button.get_path_to(arrow_buttons[1])
	arrow_buttons[0].focus_neighbor_right = arrow_buttons[0].get_path_to(play_button)
	arrow_buttons[1].focus_neighbor_left = arrow_buttons[1].get_path_to(play_button)


func _build_track_card() -> void:
	var scaled_cover_size := maxf(58.0, 116.0 * ui_scale)
	track_card = PanelContainer.new()
	track_card.name = "FeaturedSongCard"
	_set_normalized_rect(track_card, TRACK_CARD_RECT)
	track_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	glass.content_margin_left = 28.0 * ui_scale
	glass.content_margin_top = 10.0 * ui_scale
	glass.content_margin_right = 28.0 * ui_scale
	glass.content_margin_bottom = 10.0 * ui_scale
	track_card.add_theme_stylebox_override("panel", glass)
	add_child(track_card)
	track_card_background = Polygon2D.new()
	track_card_background.name = "ScreenInset"
	track_card_background.color = Color(0.003, 0.010, 0.030, 1.0)
	track_card.add_child(track_card_background)
	track_card.resized.connect(_update_track_card_shape)
	call_deferred("_update_track_card_shape")

	var content_clip := Control.new()
	content_clip.name = "TrackCardContentClip"
	content_clip.clip_contents = true
	content_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_card.add_child(content_clip)
	song_content = HBoxContainer.new()
	AuroraUi.fill(song_content)
	song_content.add_theme_constant_override("separation", roundi(14.0 * ui_scale))
	song_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_clip.add_child(song_content)

	var cover_frame := PanelContainer.new()
	cover_frame.custom_minimum_size = Vector2.ONE * scaled_cover_size
	cover_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	song_content.add_child(cover_frame)

	var cover_holder := Control.new()
	var cover_inset := maxf(5.0, 10.0 * ui_scale)
	cover_holder.custom_minimum_size = Vector2.ONE * (scaled_cover_size - cover_inset)
	cover_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_frame.add_child(cover_holder)
	cover_image = TextureRect.new()
	AuroraUi.fill(cover_image)
	cover_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cover_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_holder.add_child(cover_image)
	cover_placeholder = AuroraUi.make_pixel_label(
		"♪",
		maxi(27, roundi(54.0 * ui_scale)),
		AuroraUi.VIOLET
	)
	AuroraUi.fill(cover_placeholder)
	cover_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_holder.add_child(cover_placeholder)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_theme_constant_override("separation", maxi(2, roundi(5.0 * ui_scale)))
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song_content.add_child(details)

	var kicker := AuroraUi.make_pixel_label(
		"EN LA CABINA · GALERÍA",
		maxi(7, roundi(9.0 * ui_scale)),
		AuroraUi.TEAL
	)
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	details.add_child(kicker)
	title_label = AuroraUi.make_pixel_label("", maxi(10, roundi(21.0 * ui_scale)), AuroraUi.TEXT)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(title_label)
	artist_label = AuroraUi.make_pixel_label(
		"",
		maxi(8, roundi(13.0 * ui_scale)),
		Color(0.77, 0.81, 1.0, 1.0)
	)
	artist_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	details.add_child(artist_label)

	var metadata := HBoxContainer.new()
	metadata.add_theme_constant_override("separation", maxi(4, roundi(12.0 * ui_scale)))
	metadata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(metadata)
	modes_label = AuroraUi.make_pixel_label("", maxi(7, roundi(8.0 * ui_scale)), AuroraUi.TEAL)
	modes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	modes_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	metadata.add_child(modes_label)
	position_label = AuroraUi.make_pixel_label("", maxi(7, roundi(8.0 * ui_scale)), AuroraUi.MUTED)
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	position_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	metadata.add_child(position_label)

	var spectrum := Control.new()
	spectrum.name = "MenuSpectrum"
	spectrum.custom_minimum_size = Vector2(100.0 * ui_scale, 16.0 * ui_scale)
	spectrum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(spectrum)
	for index in range(12):
		var bar := ColorRect.new()
		bar.position = Vector2(float(index * 8) * ui_scale, 8.0 * ui_scale)
		bar.size = Vector2(4.0 * ui_scale, 8.0 * ui_scale)
		bar.color = SPECTRUM_COLORS[index % SPECTRUM_COLORS.size()]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spectrum.add_child(bar)
		spectrum_bars.append(bar)
	progress_track = ColorRect.new()
	progress_track.name = "SongProgressTrack"
	progress_track.custom_minimum_size.y = maxf(2.0, 3.0 * ui_scale)
	progress_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_track.color = Color(0.08, 0.20, 0.30, 0.78)
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(progress_track)
	progress_fill = ColorRect.new()
	progress_fill.name = "SongProgressFill"
	progress_fill.color = AuroraUi.TEAL
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(progress_fill)


func _update_track_card_shape() -> void:
	if track_card_background == null or track_card == null:
		return
	var card_size := track_card.size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		return
	var top_inset_x := card_size.x * 0.045
	var bottom_inset_x := card_size.x * 0.008
	var top_inset_y := card_size.y * 0.015
	var bottom_inset_y := card_size.y * 0.025
	track_card_background.polygon = PackedVector2Array([
		Vector2(top_inset_x, top_inset_y),
		Vector2(card_size.x - top_inset_x, top_inset_y),
		Vector2(card_size.x - bottom_inset_x, card_size.y - bottom_inset_y),
		Vector2(bottom_inset_x, card_size.y - bottom_inset_y),
	])


func _build_hotspots() -> void:
	buttons_by_action.clear()
	for hotspot in HOTSPOTS:
		var action: StringName = hotspot["action"]
		var label_text := str(hotspot["label"])
		var button := Button.new()
		button.name = str(hotspot["name"])
		button.text = label_text
		button.tooltip_text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font", AuroraUi.PIXEL_FONT)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.0))
		button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 0.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.0))
		button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 1.0, 1.0, 0.0))
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover_pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		_set_normalized_rect(button, hotspot["rect"])
		button.mouse_entered.connect(_on_hotspot_mouse_entered.bind(action, button))
		button.mouse_exited.connect(_on_hotspot_mouse_exited.bind(action, button))
		button.focus_entered.connect(_on_hotspot_focus_entered.bind(action))
		button.focus_exited.connect(_on_hotspot_focus_exited.bind(action, button))
		button.button_down.connect(_flash_hotspot.bind(action))
		button.pressed.connect(_emit_action.bind(action))
		add_child(button)
		buttons_by_action[action] = button

	_set_vertical_focus_neighbors(&"play", &"quit", &"editor")
	_set_vertical_focus_neighbors(&"editor", &"play", &"settings")
	_set_vertical_focus_neighbors(&"settings", &"editor", &"quit")
	_set_vertical_focus_neighbors(&"quit", &"settings", &"play")


func _set_vertical_focus_neighbors(
	action: StringName,
	top_action: StringName,
	bottom_action: StringName
) -> void:
	var button := buttons_by_action.get(action) as Button
	var top_button := buttons_by_action.get(top_action) as Button
	var bottom_button := buttons_by_action.get(bottom_action) as Button
	if button == null or top_button == null or bottom_button == null:
		return
	button.focus_neighbor_top = button.get_path_to(top_button)
	button.focus_neighbor_bottom = button.get_path_to(bottom_button)


func _load_song_catalog() -> void:
	var app := get_tree().current_scene
	if app == null:
		return
	song_manager = app.get_node_or_null("Managers/SongManager") as SongManager
	menu_music_manager = app.get_node_or_null(
		"Managers/MenuMusicManager"
	) as MenuMusicManager
	if menu_music_manager != null:
		menu_music_manager.featured_song_changed.connect(_on_featured_song_changed)
		song_catalog = menu_music_manager.get_menu_songs()
		menu_music_manager.ensure_featured_song()
		_on_featured_song_changed(menu_music_manager.featured_song, menu_music_manager.featured_audio_available)
	else:
		_render_song()


func _on_featured_song_changed(song: SongData, _has_audio: bool) -> void:
	if menu_music_manager == null:
		return
	song_catalog = menu_music_manager.get_menu_songs()
	for button in arrow_buttons:
		button.disabled = song_catalog.size() < 2
	var changed := displayed_song != song
	song_index = song_catalog.find(song)
	_render_song()
	if changed:
		_animate_song_card()


func _render_song() -> void:
	if song_catalog.is_empty() or song_index < 0:
		displayed_song = null
		cover_image.texture = null
		cover_image.hide()
		cover_placeholder.show()
		title_label.text = AuroraLocale.text("SIN CANCIONES")
		artist_label.text = AuroraLocale.text("IMPORTA CANCIONES")
		modes_label.text = ""
		position_label.text = ""
		return

	var song := song_catalog[song_index]
	displayed_song = song
	if song_manager != null:
		song_manager.ensure_song_cover_loaded(song)
	cover_image.texture = song.cover
	cover_image.visible = song.cover != null
	cover_placeholder.visible = song.cover == null
	title_label.text = str(song.title).strip_edges().to_upper()
	artist_label.text = str(song.artist).strip_edges()
	var modes := song.get_available_modes_text().strip_edges().to_upper()
	modes_label.text = modes if not modes.is_empty() else AuroraLocale.text("EN ROTACIÓN")
	var duration := menu_music_manager.get_featured_duration_seconds() if menu_music_manager != null else song.duration_seconds
	var duration_text := "--:--"
	if duration > 0.0:
		var seconds := roundi(duration)
		duration_text = "%02d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]
	position_label.text = "%02d / %02d · %s" % [song_index + 1, song_catalog.size(), duration_text]


func _animate_song_card() -> void:
	if card_tween != null and card_tween.is_running():
		card_tween.kill()
	if settings_manager != null and bool(settings_manager.get_setting("reduced_motion", false)):
		song_content.modulate.a = 1.0
		return
	song_content.modulate.a = 0.35
	card_tween = create_tween()
	card_tween.set_trans(Tween.TRANS_SINE)
	card_tween.set_ease(Tween.EASE_OUT)
	card_tween.tween_property(song_content, "modulate:a", 1.0, 0.45)


func _update_song_progress() -> void:
	if progress_track == null or progress_fill == null:
		return
	var ratio := 0.0
	if menu_music_manager != null:
		var duration := menu_music_manager.get_featured_duration_seconds()
		if duration > 0.0:
			ratio = clampf(menu_music_manager.get_playback_position_seconds() / duration, 0.0, 1.0)
	progress_fill.size = Vector2(progress_track.size.x * ratio, progress_track.size.y)


func _update_spectrum(delta: float) -> void:
	var audio_level := 0.0
	var menu_bus := AudioServer.get_bus_index("MenuMusic")
	if menu_bus >= 0:
		var left_db := AudioServer.get_bus_peak_volume_left_db(menu_bus, 0)
		var right_db := AudioServer.get_bus_peak_volume_right_db(menu_bus, 0)
		audio_level = clampf((maxf(left_db, right_db) + 42.0) / 42.0, 0.0, 1.0)
	for index in range(spectrum_bars.size()):
		var bar := spectrum_bars[index]
		var wave_shape := 0.18 + absf(
			sin(spectrum_elapsed * 4.4 + float(index) * 0.73)
		) * 0.82
		var idle_motion := 1.2 if audio_level < 0.015 else 0.0
		var target_height := ui_scale * (
			2.4 + idle_motion + audio_level * (2.5 + wave_shape * 15.0)
		)
		var current_height := bar.size.y / ui_scale
		var response_speed := 18.0 if target_height > current_height else 7.0
		var height := ui_scale * lerpf(
			current_height,
			target_height / ui_scale,
			clampf(delta * response_speed, 0.0, 1.0)
		)
		bar.position.y = 16.0 * ui_scale - height
		bar.size.y = height
	if action_selector != null and action_selector.visible:
		action_selector.position = selector_base_position + Vector2(
			sin(spectrum_elapsed * 4.2) * 2.0 * ui_scale,
			0.0
		)
		action_selector.modulate.a = 0.82 + absf(sin(spectrum_elapsed * 3.0)) * 0.18


func _build_action_selector() -> void:
	action_selector = TextureRect.new()
	action_selector.name = "ActionSelector"
	action_selector.texture = SELECTOR_ARROW
	action_selector.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	action_selector.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	action_selector.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	action_selector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_selector.focus_mode = Control.FOCUS_NONE
	action_selector.visible = false
	var arrow_size := 22.0 * ui_scale
	action_selector.size = Vector2.ONE * arrow_size
	add_child(action_selector)


func _build_interaction_glow() -> void:
	var background := get_parent().get_node_or_null("Background") as TextureRect
	if background == null or background.texture == null:
		return
	focus_glow = TextureRect.new()
	focus_glow.name = "ButtonArtworkGlow"
	AuroraUi.fill(focus_glow)
	focus_glow.texture = background.texture
	focus_glow.expand_mode = background.expand_mode
	focus_glow.stretch_mode = background.stretch_mode
	focus_glow.texture_filter = background.texture_filter
	focus_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BUTTON_GLOW_SHADER_CODE
	glow_material = ShaderMaterial.new()
	glow_material.shader = shader
	focus_glow.material = glow_material
	add_child(focus_glow)
	move_child(focus_glow, 0)


func _on_hotspot_mouse_entered(action: StringName, button: Button) -> void:
	hovered_action = action
	button.grab_focus()
	_set_action_selector(action)
	_show_hotspot_glow(action, 0.95)


func _on_hotspot_mouse_exited(action: StringName, button: Button) -> void:
	if hovered_action == action:
		hovered_action = &""
	if not button.has_focus():
		_clear_hotspot_glow()


func _on_hotspot_focus_entered(action: StringName) -> void:
	remembered_action = action
	_set_action_selector(action)
	_show_hotspot_glow(action, 0.95)


func _on_hotspot_focus_exited(action: StringName, button: Button) -> void:
	if remembered_action == action and not button.has_focus():
		if hovered_action != action:
			_clear_hotspot_glow()


func _flash_hotspot(action: StringName) -> void:
	if glow_material == null:
		return
	_set_action_selector(action)
	_set_hotspot_glow_region(action)
	if glow_tween != null and glow_tween.is_running():
		glow_tween.kill()
	glow_tween = create_tween()
	glow_tween.set_trans(Tween.TRANS_SINE)
	glow_tween.set_ease(Tween.EASE_OUT)
	glow_tween.tween_method(
		_set_glow_strength,
		current_glow_strength,
		1.35,
		0.08
	)
	glow_tween.tween_interval(0.08)
	glow_tween.tween_method(_set_glow_strength, 1.35, 0.95, 0.16)


func _show_hotspot_glow(action: StringName, strength: float) -> void:
	if glow_material == null:
		return
	_set_hotspot_glow_region(action)
	if glow_tween != null and glow_tween.is_running():
		glow_tween.kill()
	glow_tween = create_tween()
	glow_tween.set_trans(Tween.TRANS_SINE)
	glow_tween.set_ease(Tween.EASE_OUT)
	glow_tween.tween_method(_set_glow_strength, current_glow_strength, strength, 0.14)


func _set_hotspot_glow_region(action: StringName) -> void:
	for hotspot in HOTSPOTS:
		if hotspot["action"] != action:
			continue
		var rect: Rect2 = hotspot["glow_rect"]
		var corner: Vector2 = hotspot["glow_corner"]
		glow_material.set_shader_parameter(
			"glow_region",
			Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
		)
		glow_material.set_shader_parameter("corner_size", corner)
		return


func _set_action_selector(action: StringName) -> void:
	if action_selector == null:
		return
	for hotspot in HOTSPOTS:
		if hotspot["action"] != action:
			continue
		var rect: Rect2 = hotspot["rect"]
		var arrow_size := 22.0 * ui_scale
		selector_base_position = Vector2(
			(rect.position.x - 0.036) * size.x,
			(rect.position.y + rect.size.y * 0.5) * size.y - arrow_size * 0.5
		)
		action_selector.size = Vector2.ONE * arrow_size
		action_selector.position = selector_base_position
		action_selector.visible = true
		return


func _clear_hotspot_glow() -> void:
	if glow_material == null:
		return
	if action_selector != null:
		action_selector.hide()
	if glow_tween != null and glow_tween.is_running():
		glow_tween.kill()
	glow_tween = create_tween()
	glow_tween.set_trans(Tween.TRANS_SINE)
	glow_tween.set_ease(Tween.EASE_OUT)
	glow_tween.tween_method(_set_glow_strength, current_glow_strength, 0.0, 0.18)


func _set_glow_strength(value: float) -> void:
	current_glow_strength = value
	if glow_material != null:
		glow_material.set_shader_parameter("glow_strength", value)


func _emit_action(action: StringName) -> void:
	action_selected.emit(action)


func _set_normalized_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
