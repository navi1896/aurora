extends Control

class_name Settings

const CACHE_MAINTENANCE_SERVICE := preload(
	"res://src/maintenance/CacheMaintenanceService.gd"
)
const CABINA_BACKGROUND := preload("res://assets/menu/background/cabina_aurora_menu.png")
const CABINET_PLATE := preload("res://assets/menu/background/settings_cabina_plate.png")
const CABINET_ART_SIZE := Vector2(1671.0, 939.0)
const CABINET_BACK_GLOW_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add;

uniform float glow_strength = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float inside = step(0.157, UV.x) * step(UV.x, 0.334)
		* step(0.770, UV.y) * step(UV.y, 0.854);
	float brightness = max(source.r, max(source.g, source.b));
	float lit = smoothstep(0.42, 0.82, brightness);
	float pulse = 0.94 + 0.06 * sin(TIME * 4.0);
	COLOR = vec4(source.rgb, source.a * inside * lit * glow_strength * pulse);
}
"""
const FFMPEG_VERSION_LABEL := "n8.1.2-31-g8c9502e9b0-20260729"
const FFMPEG_LOCAL_PREPARATION := (
	"AuroraDevTools/btbn-ffmpeg-n8.1-win64-lgpl-20260729"
)
const CATEGORIES := [
	{"id": "general", "label": "GENERAL", "icon": "◆"},
	{"id": "audio", "label": "SONIDO", "icon": "♫"},
	{"id": "gameplay", "label": "JUGABILIDAD", "icon": "▣"},
	{"id": "graphics", "label": "PANTALLA", "icon": "◇"},
	{"id": "controls", "label": "CONTROLES", "icon": "⌨"},
	{"id": "credits", "label": "CRÉDITOS", "icon": "★"},
]

var scene_manager: SceneManager
var settings_manager: SettingsManager
var input_manager: InputManager
var song_manager: SongManager
var menu_music_manager: MenuMusicManager

var content_scroll: ScrollContainer
var content_frame: MarginContainer
var content_host: VBoxContainer
var cabinet_column_scrolls: Array[ScrollContainer] = []
var cabinet_columns: Array[VBoxContainer] = []
var cabinet_page_tween: Tween
var category_buttons: Dictionary = {}
var header_title_label: Label
var header_subtitle_label: Label
var current_category := "general"
var binding_mode := 4
var capture_lane := -1
var capture_button: Button
var capture_kind := ""
var capture_action_name := ""
var reset_button: Button
var reset_confirmation_active := false
var reset_confirmation_token := 0
var controller_status_label: Label
var cache_maintenance
var cache_cleanup_plan: Dictionary = {}
var cache_button: Button
var cache_summary_label: Label
var cache_confirmation_active := false
var cache_confirmation_token := 0
var featured_cover: TextureRect
var featured_title_label: Label
var featured_artist_label: Label
var featured_status_label: Label
var audio_meter_bars: Dictionary = {}
var audio_meter_accents: Dictionary = {}
var music_volume_controls: Array[Dictionary] = []
var cabinet_status_label: Label
var cabinet_back_button: Button
var cabinet_back_glow_material: ShaderMaterial
var cabinet_back_pressed := false


func _ready() -> void:
	AuroraUi.fill(self)
	var managers := get_tree().current_scene.get_node("Managers")
	scene_manager = managers.get_node("SceneManager") as SceneManager
	settings_manager = managers.get_node("SettingsManager") as SettingsManager
	input_manager = managers.get_node("InputManager") as InputManager
	song_manager = managers.get_node_or_null("SongManager") as SongManager
	menu_music_manager = managers.get_node_or_null("MenuMusicManager") as MenuMusicManager
	cache_maintenance = CACHE_MAINTENANCE_SERVICE.new()
	input_manager.controller_connection_changed.connect(_on_controller_connection_changed)
	settings_manager.setting_changed.connect(_on_setting_changed)
	if menu_music_manager != null:
		menu_music_manager.featured_song_changed.connect(_on_featured_song_changed)
	setup_ui()
	set_process(true)


func setup_ui() -> void:
	audio_meter_bars.clear()
	audio_meter_accents.clear()
	music_volume_controls.clear()
	header_title_label = null
	header_subtitle_label = null
	featured_cover = null
	featured_title_label = null
	featured_artist_label = null
	featured_status_label = null
	cabinet_back_button = null
	cabinet_back_glow_material = null
	cabinet_back_pressed = false
	category_buttons.clear()
	cabinet_column_scrolls.clear()
	cabinet_columns.clear()
	if cabinet_page_tween != null and cabinet_page_tween.is_running():
		cabinet_page_tween.kill()
	AuroraUi.clear(self)
	var plate := TextureRect.new()
	plate.name = "SettingsCabinetPlate"
	plate.texture = CABINET_PLATE
	AuroraUi.fill(plate)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	var interface := Control.new()
	interface.name = "SettingsCabinetControls"
	AuroraUi.fill(interface)
	add_child(interface)
	_build_cabinet_back_glow(interface)
	_build_cabinet_navigation(interface)
	_build_cabinet_content(interface)
	_build_cabinet_status_label(interface)
	_show_category(current_category)
	if bool(settings_manager.get_setting("reduced_motion", false)):
		interface.modulate.a = 1.0
	else:
		interface.modulate.a = 0.0
		var intro := create_tween()
		intro.set_trans(Tween.TRANS_SINE)
		intro.set_ease(Tween.EASE_OUT)
		intro.tween_property(interface, "modulate:a", 1.0, 0.34)
	call_deferred("_focus_current_category")


func _place_on_cabinet(control: Control, art_rect: Rect2) -> void:
	control.anchor_left = art_rect.position.x / CABINET_ART_SIZE.x
	control.anchor_top = art_rect.position.y / CABINET_ART_SIZE.y
	control.anchor_right = art_rect.end.x / CABINET_ART_SIZE.x
	control.anchor_bottom = art_rect.end.y / CABINET_ART_SIZE.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _cabinet_button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 13.0
	style.content_margin_right = 8.0
	return style


func _cabinet_fader_handle(accent: Color) -> Texture2D:
	var pixels := Image.create_empty(72, 20, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	pixels.fill_rect(Rect2i(0, 0, 72, 20), Color(accent.r, accent.g, accent.b, 0.20))
	pixels.fill_rect(Rect2i(2, 2, 68, 16), Color(accent.r, accent.g, accent.b, 0.82))
	pixels.fill_rect(Rect2i(5, 5, 62, 10), Color(0.08, 0.12, 0.23, 1.0))
	pixels.fill_rect(Rect2i(8, 7, 56, 6), Color(0.88, 0.97, 1.0, 1.0))
	return ImageTexture.create_from_image(pixels)


func _build_cabinet_back_glow(parent: Control) -> void:
	var glow := TextureRect.new()
	glow.name = "CabinetBackArtworkGlow"
	AuroraUi.fill(glow)
	glow.texture = CABINET_PLATE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = CABINET_BACK_GLOW_SHADER_CODE
	cabinet_back_glow_material = ShaderMaterial.new()
	cabinet_back_glow_material.shader = shader
	glow.material = cabinet_back_glow_material
	parent.add_child(glow)


func _build_cabinet_navigation(parent: Control) -> void:
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for index in range(CATEGORIES.size()):
		var category: Dictionary = CATEGORIES[index]
		var button := Button.new()
		button.name = "Category_%s" % str(category["id"])
		button.text = "%s  %s" % [str(category["icon"]), AuroraLocale.text(str(category["label"]))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = ""
		button.focus_mode = Control.FOCUS_ALL
		AuroraUi.apply_pixel_font(button, 17)
		button.add_theme_color_override("font_color", AuroraUi.TEXT)
		button.add_theme_color_override("font_hover_color", AuroraUi.TEAL)
		button.add_theme_color_override("font_pressed_color", AuroraUi.TEAL)
		button.add_theme_color_override("font_focus_color", AuroraUi.TEAL)
		button.add_theme_stylebox_override("normal", _cabinet_button_style(Color.TRANSPARENT, Color.TRANSPARENT))
		button.add_theme_stylebox_override("hover", _cabinet_button_style(Color(0.0, 0.22, 0.31, 0.30), Color.TRANSPARENT))
		button.add_theme_stylebox_override("pressed", _cabinet_button_style(Color(0.0, 0.32, 0.40, 0.32), Color.TRANSPARENT))
		button.add_theme_stylebox_override("hover_pressed", _cabinet_button_style(Color(0.0, 0.40, 0.48, 0.39), Color.TRANSPARENT))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_place_on_cabinet(button, Rect2(302.0, 256.0 + float(index) * 74.0, 256.0, 70.0))
		button.pressed.connect(_show_category.bind(str(category["id"])))
		button.focus_entered.connect(_refresh_cabinet_navigation)
		button.focus_exited.connect(_refresh_cabinet_navigation)
		parent.add_child(button)
		category_buttons[category["id"]] = button

	var back := Button.new()
	cabinet_back_button = back
	back.name = "CabinetBackButton"
	back.text = AuroraLocale.text("◀  VOLVER")
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.tooltip_text = ""
	back.focus_mode = Control.FOCUS_ALL
	AuroraUi.apply_pixel_font(back, 17)
	back.add_theme_color_override("font_color", AuroraUi.TEXT)
	back.add_theme_color_override("font_hover_color", AuroraUi.TEAL)
	back.add_theme_color_override("font_focus_color", AuroraUi.TEAL)
	back.add_theme_color_override("font_pressed_color", AuroraUi.TEAL)
	back.add_theme_color_override("font_hover_pressed_color", AuroraUi.TEAL)
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		back.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_place_on_cabinet(back, Rect2(280.0, 735.0, 274.0, 61.0))
	back.mouse_entered.connect(_refresh_cabinet_back_highlight)
	back.mouse_exited.connect(_refresh_cabinet_back_highlight)
	back.focus_entered.connect(_refresh_cabinet_back_highlight)
	back.focus_exited.connect(_refresh_cabinet_back_highlight)
	back.button_down.connect(_set_cabinet_back_pressed.bind(true))
	back.button_up.connect(_set_cabinet_back_pressed.bind(false))
	back.pressed.connect(Callable(scene_manager, "load_scene").bind("main_menu"))
	parent.add_child(back)


func _set_cabinet_back_pressed(pressed: bool) -> void:
	cabinet_back_pressed = pressed
	_refresh_cabinet_back_highlight()


func _refresh_cabinet_back_highlight() -> void:
	if cabinet_back_button == null or not is_instance_valid(cabinet_back_button):
		return
	var highlighted := cabinet_back_button.is_hovered() or cabinet_back_button.has_focus()
	var outline := Color(0.10, 0.80, 0.96, 0.80) if highlighted else Color.TRANSPARENT
	cabinet_back_button.add_theme_color_override("font_color", AuroraUi.TEAL if highlighted else AuroraUi.TEXT)
	cabinet_back_button.add_theme_color_override("font_outline_color", outline)
	cabinet_back_button.add_theme_constant_override("outline_size", 2 if highlighted else 0)
	if cabinet_back_glow_material != null:
		var strength := 0.22 if cabinet_back_pressed else (1.05 if highlighted else 0.0)
		cabinet_back_glow_material.set_shader_parameter("glow_strength", strength)


func _build_cabinet_content(parent: Control) -> void:
	content_scroll = ScrollContainer.new()
	content_scroll.name = "CabinetContentScroll"
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_scroll.resized.connect(_sync_content_width)
	_place_on_cabinet(content_scroll, Rect2(597.0, 245.0, 792.0, 474.0))
	parent.add_child(content_scroll)
	content_frame = MarginContainer.new()
	content_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content_frame)
	content_host = VBoxContainer.new()
	content_host.add_theme_constant_override("separation", 12)
	content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_frame.add_child(content_host)
	call_deferred("_sync_content_width")
	var panel_rects := [
		Rect2(615.0, 279.0, 216.0, 416.0),
		Rect2(870.0, 279.0, 213.0, 416.0),
		Rect2(1118.0, 279.0, 218.0, 416.0),
	]
	for index in range(panel_rects.size()):
		var column_scroll := ScrollContainer.new()
		column_scroll.name = "CabinetColumnScroll_%d" % index
		column_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		column_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_place_on_cabinet(column_scroll, panel_rects[index])
		parent.add_child(column_scroll)
		var margin := MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_theme_constant_override("margin_left", 5)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_bottom", 8)
		column_scroll.add_child(margin)
		var column := VBoxContainer.new()
		column.name = "CabinetColumn_%d" % index
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 13)
		margin.add_child(column)
		cabinet_column_scrolls.append(column_scroll)
		cabinet_columns.append(column)


func _add_settings_backdrop() -> void:
	var artwork := TextureRect.new()
	artwork.name = "SettingsCabinaArtwork"
	artwork.texture = CABINA_BACKGROUND
	AuroraUi.fill(artwork)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.modulate = Color(0.56, 0.66, 0.95, 0.36)
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)


func _build_cabinet_status_label(parent: Control) -> void:
	cabinet_status_label = AuroraUi.make_pixel_label("", 12, AuroraUi.TEAL)
	cabinet_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cabinet_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place_on_cabinet(cabinet_status_label, Rect2(690.0, 755.0, 640.0, 46.0))
	parent.add_child(cabinet_status_label)


func _focus_current_category() -> void:
	var button := category_buttons.get(current_category) as Button
	if button != null and is_instance_valid(button):
		button.grab_focus()
		_refresh_cabinet_navigation()


func _refresh_cabinet_navigation() -> void:
	for entry in CATEGORIES:
		var id := str(entry["id"])
		var button := category_buttons.get(id) as Button
		if button == null or not is_instance_valid(button):
			continue
		var selected := id == current_category
		var highlighted := selected or button.has_focus()
		button.text = "%s  %s" % [
			"▶" if selected else str(entry["icon"]),
			AuroraLocale.text(str(entry["label"])),
		]
		button.add_theme_color_override("font_color", AuroraUi.TEAL if highlighted else AuroraUi.TEXT)
		button.add_theme_color_override("font_outline_color", Color(0.0, 0.72, 0.90, 0.90) if highlighted else Color.TRANSPARENT)
		button.add_theme_constant_override("outline_size", 2 if highlighted else 0)


func _build_terminal_ambient() -> void:
	var grid := Control.new()
	AuroraUi.fill(grid)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)

	for index in range(1, 12):
		var vertical := ColorRect.new()
		vertical.anchor_left = float(index) / 12.0
		vertical.anchor_right = vertical.anchor_left
		vertical.anchor_bottom = 1.0
		vertical.offset_right = 1.0
		vertical.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.032)
		grid.add_child(vertical)
	for index in range(1, 7):
		var horizontal := ColorRect.new()
		horizontal.anchor_top = float(index) / 7.0
		horizontal.anchor_right = 1.0
		horizontal.anchor_bottom = horizontal.anchor_top
		horizontal.offset_bottom = 1.0
		horizontal.color = Color(1.0, 0.20, 0.86, 0.026)
		grid.add_child(horizontal)

	var spectrum := HBoxContainer.new()
	spectrum.anchor_left = 0.78
	spectrum.anchor_top = 0.72
	spectrum.anchor_right = 0.97
	spectrum.anchor_bottom = 0.91
	spectrum.alignment = BoxContainer.ALIGNMENT_END
	spectrum.add_theme_constant_override("separation", 5)
	spectrum.modulate = Color(1.0, 1.0, 1.0, 0.22)
	grid.add_child(spectrum)
	var heights := [0.22, 0.48, 0.34, 0.72, 0.56, 0.88, 0.40, 0.66, 0.30, 0.78, 0.52, 0.26]
	for height in heights:
		var slot := Control.new()
		slot.custom_minimum_size.x = 10.0
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spectrum.add_child(slot)
		var bar := ColorRect.new()
		bar.anchor_top = 1.0 - float(height)
		bar.anchor_right = 1.0
		bar.anchor_bottom = 1.0
		bar.color = AuroraUi.TEAL if spectrum.get_child_count() % 2 == 0 else AuroraUi.VIOLET
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(bar)


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 62.0
	header.add_theme_constant_override("separation", 16)
	parent.add_child(header)

	var back := AuroraUi.make_button(AuroraLocale.text("◀  VOLVER"))
	back.custom_minimum_size = Vector2(172, 54)
	AuroraUi.apply_pixel_font(back, 11)
	back.pressed.connect(Callable(scene_manager, "load_scene").bind("main_menu"))
	header.add_child(back)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	header_title_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("CONFIGURACIÓN // %s") % _get_category_label(current_category),
		20,
		AuroraUi.TEXT
	)
	header_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_box.add_child(header_title_label)
	header_subtitle_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("PERFIL LOCAL // GUARDADO AUTOMÁTICO"),
		8,
		AuroraUi.TEAL
	)
	header_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_box.add_child(header_subtitle_label)

	var version := AuroraUi.make_pixel_label(
		"AURORA // %s"
		% str(ProjectSettings.get_setting("application/config/version", "1.0.0")),
		8,
		AuroraUi.MUTED
	)
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.custom_minimum_size.x = 210.0
	header.add_child(version)


func _build_sidebar(parent: HBoxContainer) -> void:
	var sidebar := PanelContainer.new()
	sidebar.add_theme_stylebox_override(
		"panel",
		_make_terminal_style(
			Color(0.004, 0.010, 0.030, 0.97),
			Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.62)
		)
	)
	sidebar.custom_minimum_size.x = 250.0
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sidebar)

	var navigation := VBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	sidebar.add_child(navigation)

	var nav_title := AuroraUi.make_pixel_label(AuroraLocale.text("CATEGORÍAS"), 9, AuroraUi.VIOLET)
	navigation.add_child(nav_title)
	navigation.add_child(AuroraUi.spacer(2))

	category_buttons.clear()
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for category in CATEGORIES:
		var button := AuroraUi.make_button(
			"%s   %s" % [category["icon"], AuroraLocale.text(str(category["label"]))]
		)
		button.custom_minimum_size = Vector2(216, 50)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		AuroraUi.apply_pixel_font(button, 10)
		_apply_category_button_style(button)
		button.pressed.connect(_show_category.bind(str(category["id"])))
		navigation.add_child(button)
		category_buttons[category["id"]] = button

	var flexible := Control.new()
	flexible.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.add_child(flexible)

	var profile := PanelContainer.new()
	profile.custom_minimum_size.y = 68.0
	profile.add_theme_stylebox_override(
		"panel",
		_make_terminal_style(
			Color(0.015, 0.028, 0.064, 0.92),
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.62)
		)
	)
	navigation.add_child(profile)
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 10)
	profile.add_child(profile_row)
	var status_dot := AuroraUi.make_pixel_label("●", 10, AuroraUi.TEAL)
	status_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	profile_row.add_child(status_dot)
	var profile_text := VBoxContainer.new()
	profile_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_row.add_child(profile_text)
	profile_text.add_child(AuroraUi.make_pixel_label("LOCAL PLAYER", 9, AuroraUi.TEXT))
	profile_text.add_child(
		AuroraUi.make_label(AuroraLocale.text("Perfil activo // guardado"), 11, AuroraUi.MUTED)
	)


func _build_content_area(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_make_terminal_style(
			Color(0.003, 0.008, 0.024, 0.96),
			Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.48)
		)
	)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.resized.connect(_sync_content_width)
	panel.add_child(content_scroll)

	content_frame = MarginContainer.new()
	content_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content_frame)

	content_host = VBoxContainer.new()
	content_host.add_theme_constant_override("separation", 16)
	content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_host.custom_minimum_size.x = 920.0
	content_frame.add_child(content_host)
	call_deferred("_sync_content_width")


func _sync_content_width() -> void:
	if content_scroll == null or content_frame == null or content_host == null:
		return
	content_frame.custom_minimum_size.x = 0.0
	content_host.custom_minimum_size.x = 0.0
	content_frame.add_theme_constant_override("margin_left", 18)
	content_frame.add_theme_constant_override("margin_right", 18)
	content_frame.add_theme_constant_override("margin_top", 24)
	content_frame.add_theme_constant_override("margin_bottom", 12)


func _build_footer(parent: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	parent.add_child(footer)
	var autosave := AuroraUi.make_pixel_label(
		AuroraLocale.text("●  CAMBIOS GUARDADOS AUTOMÁTICAMENTE"),
		8,
		AuroraUi.TEAL
	)
	autosave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	autosave.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer.add_child(autosave)
	var escape_hint := AuroraUi.make_pixel_label(
		AuroraLocale.text("ESC / %s  VOLVER")
		% input_manager.get_controller_action_label("back"),
		8,
		AuroraUi.MUTED
	)
	escape_hint.custom_minimum_size.x = 230.0
	escape_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	escape_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(escape_hint)


func _show_category(category: String) -> void:
	current_category = category
	if cabinet_page_tween != null and cabinet_page_tween.is_running():
		cabinet_page_tween.kill()
	audio_meter_bars.clear()
	audio_meter_accents.clear()
	_clear_binding_capture()
	reset_confirmation_active = false
	reset_confirmation_token += 1
	cache_confirmation_active = false
	cache_confirmation_token += 1
	for id in category_buttons:
		var button := category_buttons[id] as Button
		button.button_pressed = str(id) == category
	_refresh_cabinet_navigation()
	if header_title_label != null and is_instance_valid(header_title_label):
		header_title_label.text = AuroraLocale.text("CONFIGURACIÓN // %s") % _get_category_label(category)

	AuroraUi.clear(content_host)
	content_scroll.scroll_vertical = 0
	content_scroll.visible = category == "audio"
	for index in range(cabinet_columns.size()):
		AuroraUi.clear(cabinet_columns[index])
		cabinet_column_scrolls[index].scroll_vertical = 0
		cabinet_column_scrolls[index].visible = category != "audio"
	cabinet_status_label.visible = category != "audio"
	cabinet_status_label.text = AuroraLocale.text("%s  //  AJUSTES GUARDADOS AUTOMÁTICAMENTE") % _get_category_label(category)
	match category:
		"audio":
			_build_cabinet_audio_settings()
		"gameplay":
			_build_cabinet_gameplay_settings()
		"graphics":
			_build_cabinet_graphics_settings()
		"controls":
			_build_cabinet_control_settings()
		"credits":
			_build_cabinet_credits_settings()
		_:
			_build_cabinet_general_settings()
	if not bool(settings_manager.get_setting("reduced_motion", false)):
		cabinet_page_tween = create_tween()
		cabinet_page_tween.set_parallel(true)
		if category == "audio":
			content_scroll.modulate.a = 0.0
			cabinet_page_tween.tween_property(content_scroll, "modulate:a", 1.0, 0.18)
		else:
			for index in range(cabinet_column_scrolls.size()):
				var column_scroll := cabinet_column_scrolls[index]
				column_scroll.modulate.a = 0.0
				cabinet_page_tween.tween_property(column_scroll, "modulate:a", 1.0, 0.18).set_delay(float(index) * 0.035)
	else:
		content_scroll.modulate.a = 1.0
		for column_scroll in cabinet_column_scrolls:
			column_scroll.modulate.a = 1.0


func _get_category_label(category: String) -> String:
	for entry in CATEGORIES:
		if str(entry["id"]) == category:
			return AuroraLocale.text(str(entry["label"]))
	return AuroraLocale.text("GENERAL")


func _make_terminal_style(
	background: Color,
	border: Color,
	border_width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	return style


func _apply_category_button_style(button: Button) -> void:
	var base := Color(0.008, 0.016, 0.041, 0.97)
	var selected_border := Color(1.0, 0.24, 0.86, 0.98)
	button.add_theme_stylebox_override("normal", _make_terminal_style(base, AuroraUi.BORDER))
	button.add_theme_stylebox_override("hover", _make_terminal_style(base, selected_border, 2))
	button.add_theme_stylebox_override("focus", _make_terminal_style(base, selected_border, 2))
	button.add_theme_stylebox_override(
		"pressed",
		_make_terminal_style(Color(0.020, 0.085, 0.118, 0.98), selected_border, 2)
	)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _apply_segment_button_style(button: Button) -> void:
	var base := Color(0.005, 0.012, 0.036, 0.98)
	var selected := Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.22)
	var selected_border := Color(1.0, 0.24, 0.86, 0.96)
	button.add_theme_stylebox_override("normal", _make_terminal_style(base, AuroraUi.BORDER))
	button.add_theme_stylebox_override("hover", _make_terminal_style(base, selected_border))
	button.add_theme_stylebox_override("focus", _make_terminal_style(base, selected_border, 2))
	button.add_theme_stylebox_override("pressed", _make_terminal_style(selected, selected_border, 2))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _add_page_intro(title: String, subtitle: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 66.0
	row.add_theme_constant_override("separation", 12)
	content_host.add_child(row)

	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(4, 58)
	marker.color = color
	row.add_child(marker)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var title_label := AuroraUi.make_pixel_label(AuroraLocale.text(title), 16, AuroraUi.TEXT)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_box.add_child(title_label)
	var subtitle_label := AuroraUi.make_label(AuroraLocale.text(subtitle), 12, AuroraUi.MUTED)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_box.add_child(subtitle_label)


func _add_section(title: String, subtitle: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	var section_style := _make_terminal_style(
		Color(0.008, 0.016, 0.044, 0.94),
		Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.56)
	)
	section_style.border_width_left = 3
	section_style.border_color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.72)
	section_style.content_margin_left = 20.0
	section_style.content_margin_top = 18.0
	section_style.content_margin_right = 20.0
	section_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", section_style)
	content_host.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(AuroraUi.make_pixel_label(AuroraLocale.text(title), 10, AuroraUi.TEAL))
	if not subtitle.is_empty():
		box.add_child(AuroraUi.make_label(AuroraLocale.text(subtitle), 11, AuroraUi.MUTED))
	var separator := HSeparator.new()
	separator.modulate = Color(0.2, 0.85, 1.0, 0.34)
	box.add_child(separator)
	return box


func _cabinet_column_heading(index: int, title: String, subtitle: String, accent: Color) -> VBoxContainer:
	var column := cabinet_columns[index]
	var heading := AuroraUi.make_pixel_label(AuroraLocale.text(title), 14, accent)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.y = 29.0
	column.add_child(heading)
	if not subtitle.is_empty():
		_cabinet_copy(column, subtitle, AuroraUi.MUTED, 11)
	var divider := HSeparator.new()
	divider.modulate = Color(accent.r, accent.g, accent.b, 0.60)
	column.add_child(divider)
	return column


func _cabinet_copy(parent: Container, copy: String, color: Color = AuroraUi.TEXT, font_size: int = 12) -> Label:
	var label := AuroraUi.make_label(AuroraLocale.text(copy), font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _cabinet_action_button(parent: Container, title: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = AuroraLocale.text(title)
	button.clip_text = true
	button.custom_minimum_size.y = 38.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	AuroraUi.apply_pixel_font(button, 11)
	button.add_theme_color_override("font_color", AuroraUi.TEXT)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_stylebox_override("normal", _cabinet_button_style(Color(0.006, 0.016, 0.044, 0.86), Color(accent.r, accent.g, accent.b, 0.48)))
	button.add_theme_stylebox_override("hover", _cabinet_button_style(Color(accent.r, accent.g, accent.b, 0.13), accent))
	button.add_theme_stylebox_override("pressed", _cabinet_button_style(Color(accent.r, accent.g, accent.b, 0.24), accent))
	button.add_theme_stylebox_override("hover_pressed", _cabinet_button_style(Color(accent.r, accent.g, accent.b, 0.30), accent))
	button.add_theme_stylebox_override("focus", _cabinet_button_style(Color.TRANSPARENT, Color(accent.r, accent.g, accent.b, 0.68)))
	parent.add_child(button)
	return button


func _cabinet_option(parent: VBoxContainer, title: String, key: String, labels: Array, values: Array, accent: Color, description: String = "") -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	parent.add_child(group)
	_cabinet_copy(group, title, AuroraUi.TEXT, 13)
	if not description.is_empty():
		_cabinet_copy(group, description, AuroraUi.MUTED, 10)
	var option := OptionButton.new()
	option.name = "Option_%s" % key
	option.custom_minimum_size.y = 38.0
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	AuroraUi.apply_pixel_font(option, 10)
	option.add_theme_stylebox_override("normal", _cabinet_button_style(Color(0.006, 0.016, 0.044, 0.94), Color(accent.r, accent.g, accent.b, 0.64)))
	option.add_theme_stylebox_override("hover", _cabinet_button_style(Color(accent.r, accent.g, accent.b, 0.17), accent))
	option.add_theme_stylebox_override("focus", _cabinet_button_style(Color.TRANSPARENT, accent))
	for label in labels:
		option.add_item(AuroraLocale.text(str(label)))
	option.selected = maxi(values.find(settings_manager.get_setting(key, values[0])), 0)
	option.item_selected.connect(_on_option_changed.bind(key, values))
	group.add_child(option)


func _cabinet_slider(parent: VBoxContainer, title: String, key: String, minimum: float, maximum: float, step: float, format: String, accent: Color, description: String = "") -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	parent.add_child(group)
	var header := HBoxContainer.new()
	group.add_child(header)
	var title_label := AuroraUi.make_label(AuroraLocale.text(title), 12, AuroraUi.TEXT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title_label)
	var current := float(settings_manager.get_setting(key, minimum))
	var value_label := AuroraUi.make_label(_format_value(current, format), 12, accent)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 58.0
	header.add_child(value_label)
	if not description.is_empty():
		_cabinet_copy(group, description, AuroraUi.MUTED, 10)
	var slider := HSlider.new()
	slider.name = "Slider_%s" % key
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = current
	slider.custom_minimum_size.y = 29.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := _cabinet_button_style(Color(0.004, 0.018, 0.045, 0.92), Color(accent.r, accent.g, accent.b, 0.45))
	var active := _cabinet_button_style(Color(accent.r, accent.g, accent.b, 0.76), Color.TRANSPARENT)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", active)
	slider.add_theme_stylebox_override("grabber_area_highlight", active)
	slider.value_changed.connect(_on_slider_changed.bind(key, value_label, format))
	group.add_child(slider)


func _cabinet_toggle(parent: VBoxContainer, title: String, key: String, accent: Color, description: String = "") -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	parent.add_child(group)
	_cabinet_copy(group, title, AuroraUi.TEXT, 12)
	if not description.is_empty():
		_cabinet_copy(group, description, AuroraUi.MUTED, 10)
	var button := _cabinet_action_button(group, "", accent)
	button.name = "Toggle_%s" % key
	button.toggle_mode = true
	button.button_pressed = bool(settings_manager.get_setting(key, false))
	button.text = AuroraLocale.text("ACTIVADO" if button.button_pressed else "DESACTIVADO")
	button.toggled.connect(_on_cabinet_toggle_toggled.bind(key, button))


func _on_cabinet_toggle_toggled(enabled: bool, key: String, button: Button) -> void:
	button.text = AuroraLocale.text("ACTIVADO" if enabled else "DESACTIVADO")
	settings_manager.set_setting(key, enabled)


func _build_cabinet_general_settings() -> void:
	var preferences := _cabinet_column_heading(0, "PREFERENCIAS", "Idioma y accesibilidad.", AuroraUi.TEAL)
	_cabinet_option(preferences, "Idioma", "language", ["Español", "English"], ["es", "en"], AuroraUi.TEAL, "Idioma de la interfaz.")
	_cabinet_toggle(preferences, "Reducir movimiento", "reduced_motion", AuroraUi.TEAL, "Limita pulsos y transiciones intensas.")

	var data := _cabinet_column_heading(1, "DATOS LOCALES", "Los ajustes se guardan automáticamente.", AuroraUi.VIOLET)
	_cabinet_copy(data, "Restablecer configuración", AuroraUi.TEXT, 13)
	_cabinet_copy(data, "Recupera los valores y controles predeterminados.", AuroraUi.MUTED, 11)
	reset_button = _cabinet_action_button(data, "RESTABLECER TODO", AuroraUi.CORAL)
	_apply_danger_button_style(reset_button, false)
	reset_button.pressed.connect(_on_reset_settings)

	var maintenance := _cabinet_column_heading(2, "MANTENIMIENTO", "Caché regenerable del juego.", AuroraUi.GOLD)
	_cabinet_copy(maintenance, "Conserva canciones, proyectos y archivos originales.", AuroraUi.MUTED, 11)
	cache_summary_label = AuroraUi.make_pixel_label(AuroraLocale.text("CALCULANDO CACHÉ..."), 9, AuroraUi.TEAL)
	cache_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	maintenance.add_child(cache_summary_label)
	cache_button = _cabinet_action_button(maintenance, "LIMPIAR CACHÉ", AuroraUi.CORAL)
	_apply_danger_button_style(cache_button, false)
	cache_button.pressed.connect(_on_clean_cache)
	_refresh_cache_maintenance_summary()


func _build_cabinet_gameplay_settings() -> void:
	var notes := _cabinet_column_heading(0, "LECTURA DE NOTAS", "Ritmo y visibilidad de la pista.", AuroraUi.GOLD)
	_cabinet_slider(notes, "Velocidad de notas", "note_speed", 1.0, 10.0, 0.1, "speed", AuroraUi.GOLD)
	_cabinet_slider(notes, "Opacidad de la pista", "lane_opacity", 0.0, 1.0, 0.01, "percent", AuroraUi.GOLD)
	_cabinet_slider(notes, "Oscurecer fondo", "background_dim", 0.0, 1.0, 0.01, "percent", AuroraUi.GOLD)

	var effects := _cabinet_column_heading(1, "DURANTE LA PARTIDA", "Elementos que acompañan las notas.", AuroraUi.VIOLET)
	_cabinet_toggle(effects, "Tramos de cinemática", "cinematic_sections_enabled", AuroraUi.VIOLET, "La pista reaparece antes de las notas.")
	_cabinet_toggle(effects, "Teclas de carril", "show_lane_labels", AuroraUi.VIOLET)
	_cabinet_toggle(effects, "Efectos de impacto", "show_hit_effects", AuroraUi.VIOLET)

	var calibration := _cabinet_column_heading(2, "CALIBRACIÓN", "Alinea audio, pantalla y pulsación.", AuroraUi.TEAL)
	_cabinet_slider(calibration, "Desfase global", "timing_offset_ms", -200.0, 200.0, 1.0, "milliseconds", AuroraUi.TEAL)
	_cabinet_copy(calibration, "Ajusta valores pequeños hasta que la pulsación coincida con la música y la imagen.", AuroraUi.MUTED, 11)


func _build_cabinet_graphics_settings() -> void:
	var window := _cabinet_column_heading(0, "VENTANA", "Modo y tamaño de la imagen.", AuroraUi.VIOLET)
	_cabinet_option(window, "Modo de pantalla", "window_mode", ["Ventana", "Sin bordes", "Pantalla completa"], ["windowed", "borderless", "fullscreen"], AuroraUi.VIOLET)
	_cabinet_option(window, "Resolución", "resolution", ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"], ["1280x720", "1600x900", "1920x1080", "2560x1440"], AuroraUi.VIOLET)

	var fluidity := _cabinet_column_heading(1, "FLUIDEZ", "Sincronización y límite de cuadros.", AuroraUi.TEAL)
	_cabinet_toggle(fluidity, "Sincronización vertical", "vsync_enabled", AuroraUi.TEAL, "Evita cortes de imagen.")
	_cabinet_option(fluidity, "Límite de FPS", "fps_limit", ["Sin límite", "60", "120", "144", "240"], [0, 60, 120, 144, 240], AuroraUi.TEAL)

	var effects := _cabinet_column_heading(2, "EFECTOS", "Actividad visual del escenario.", AuroraUi.CORAL)
	_cabinet_option(effects, "Calidad gráfica", "graphics_quality", ["Baja", "Media", "Alta"], ["low", "medium", "high"], AuroraUi.CORAL)
	_cabinet_toggle(effects, "Fondo animado", "background_animation_enabled", AuroraUi.CORAL)
	_cabinet_slider(effects, "Intensidad del fondo", "background_animation_intensity", 1.0, 5.0, 1.0, "integer", AuroraUi.CORAL)
	_cabinet_toggle(effects, "Sacudida de pantalla", "screen_shake_enabled", AuroraUi.CORAL)


func _cabinet_binding_button(parent: VBoxContainer, title: String, value: String, accent: Color) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var label := AuroraUi.make_pixel_label(AuroraLocale.text(title), 10, AuroraUi.MUTED)
	label.custom_minimum_size.x = 79.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var button := _cabinet_action_button(row, value, accent)
	button.tooltip_text = value
	button.custom_minimum_size.y = 35.0
	return button


func _cabinet_action_binding_button(parent: VBoxContainer, title: String, value: String, accent: Color) -> Button:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	parent.add_child(block)
	var label := AuroraUi.make_pixel_label(AuroraLocale.text(title), 9, AuroraUi.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(label)
	var button := _cabinet_action_button(block, value, accent)
	button.tooltip_text = value
	button.custom_minimum_size.y = 33.0
	return button


func _build_cabinet_control_settings() -> void:
	var keyboard := _cabinet_column_heading(0, "TECLADO", "Elige 4K, 6K u 8K y asigna cada carril.", AuroraUi.TEAL)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 4)
	keyboard.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	mode_group.allow_unpress = false
	for mode in [4, 6, 8]:
		var mode_button := _cabinet_action_button(mode_row, "%dK" % mode, AuroraUi.TEAL)
		mode_button.toggle_mode = true
		mode_button.button_group = mode_group
		mode_button.button_pressed = mode == binding_mode
		mode_button.pressed.connect(_on_binding_mode_selected.bind(mode))
	var keycodes := input_manager.get_mode_keycodes(binding_mode)
	for lane_index in range(binding_mode):
		var key_name := input_manager.get_key_label(keycodes[lane_index])
		var key_button := _cabinet_binding_button(keyboard, AuroraLocale.text("CARRIL %02d") % (lane_index + 1), key_name, AuroraUi.TEAL)
		key_button.pressed.connect(_start_key_capture.bind(lane_index, key_button))
	var restore_keys := _cabinet_action_button(keyboard, AuroraLocale.text("RESTAURAR %dK") % binding_mode, AuroraUi.TEAL)
	restore_keys.pressed.connect(_reset_current_bindings)
	_cabinet_copy(keyboard, "Si una tecla se repite, intercambia su carril. ESC cancela.", AuroraUi.MUTED, 10)

	var controller := _cabinet_column_heading(1, AuroraLocale.text("MANDO %dK") % binding_mode, "Botones de carril y distribución.", AuroraUi.VIOLET)
	controller_status_label = AuroraUi.make_pixel_label("", 9, AuroraUi.TEAL)
	controller_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controller.add_child(controller_status_label)
	_refresh_controller_status()
	var joy_buttons := input_manager.get_mode_joy_buttons(binding_mode)
	for lane_index in range(binding_mode):
		var joy_name := input_manager.get_controller_button_label(joy_buttons[lane_index])
		var joy_button := _cabinet_binding_button(controller, AuroraLocale.text("CARRIL %02d") % (lane_index + 1), joy_name, AuroraUi.VIOLET)
		joy_button.pressed.connect(_start_controller_lane_capture.bind(lane_index, joy_button))
	var restore_controller := _cabinet_action_button(controller, "RESTAURAR MANDO", AuroraUi.VIOLET)
	restore_controller.pressed.connect(_reset_current_controller_bindings)
	_cabinet_copy(controller, "Xbox: %s" % input_manager.get_controller_layout_text(binding_mode, "xbox"), AuroraUi.MUTED, 10)
	_cabinet_copy(controller, "PlayStation: %s" % input_manager.get_controller_layout_text(binding_mode, "playstation"), AuroraUi.MUTED, 10)

	var actions := _cabinet_column_heading(2, "ACCIONES", "Botones del mando en menús y partida.", AuroraUi.CORAL)
	var action_labels := {
		"confirm": "CONFIRMAR",
		"back": "VOLVER",
		"pause": "PAUSA / REPRODUCIR",
		"shift_left": "SHIFT IZQUIERDO",
		"shift_right": "SHIFT DERECHO",
		"preview": "VISTA PREVIA",
		"delete": "BORRAR",
	}
	for action_name in InputManager.CONTROLLER_ACTIONS:
		var action_label := str(action_labels[action_name])
		var action_button := _cabinet_action_binding_button(actions, action_label, input_manager.get_controller_action_label(action_name), AuroraUi.CORAL)
		action_button.pressed.connect(_start_controller_action_capture.bind(action_name, action_button))
	var restore_actions := _cabinet_action_button(actions, "RESTAURAR ACCIONES", AuroraUi.CORAL)
	restore_actions.pressed.connect(_reset_controller_actions)
	_cabinet_copy(actions, "El D-pad y el stick izquierdo navegan. El teclado sigue disponible.", AuroraUi.MUTED, 10)


func _cabinet_credit_entry(parent: VBoxContainer, title: String, name: String, detail: String, accent: Color) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	parent.add_child(block)
	var label := AuroraUi.make_pixel_label(AuroraLocale.text(title), 10, accent)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(label)
	_cabinet_copy(block, name, AuroraUi.TEXT, 12)
	_cabinet_copy(block, detail, AuroraUi.MUTED, 10)
	var divider := HSeparator.new()
	divider.modulate = Color(accent.r, accent.g, accent.b, 0.30)
	parent.add_child(divider)


func _build_cabinet_credits_settings() -> void:
	var project := _cabinet_column_heading(0, "AURORA", "Proyecto y colaboración.", AuroraUi.TEAL)
	_cabinet_credit_entry(project, "DISEÑO Y DESARROLLO", "Aurora Project", "Versión %s // 2026" % str(ProjectSettings.get_setting("application/config/version", "1.0.0")), AuroraUi.TEAL)
	_cabinet_credit_entry(project, "PRUEBAS Y RETROALIMENTACIÓN", "Navi89", "Pruebas de juego y reportes visuales.", AuroraUi.VIOLET)
	_cabinet_credit_entry(project, "MÚSICA DEL MENÚ", "Previa de la canción destacada", "La cabina reproduce la pista mostrada en la galería.", AuroraUi.CORAL)
	_cabinet_credit_entry(project, "EFECTO PERFECT PLAY", "DJMAX // referencia local", "Audio de terceros; animación recreada en Aurora.", AuroraUi.TEAL)

	var technology := _cabinet_column_heading(1, "TECNOLOGÍA", "Herramientas y licencias.", AuroraUi.VIOLET)
	var engine_version := Engine.get_version_info()
	_cabinet_credit_entry(technology, "GODOT ENGINE", "%s // MIT" % str(engine_version.get("string", "Godot")), "Godot Engine contributors, Juan Linietsky y Ariel Manzur.", AuroraUi.TEAL)
	_cabinet_credit_entry(technology, "FFMPEG", "FFmpeg %s // LGPL v3+" % FFMPEG_VERSION_LABEL, "Conversor de video independiente. Receta y fuentes en licenses/FFmpeg/.", AuroraUi.GOLD)
	_cabinet_credit_entry(technology, "PRESS START 2P", "Press Start 2P Project Authors", "Tipografía pixel // SIL Open Font License 1.1.", AuroraUi.VIOLET)

	var legal := _cabinet_column_heading(2, "AVISOS LEGALES", "Licencias y contenido de terceros.", AuroraUi.CORAL)
	_cabinet_copy(legal, "Las canciones, videos y charts importados pertenecen a sus respectivos autores y no forman parte de Aurora.", AuroraUi.MUTED, 11)
	_cabinet_copy(legal, "Las licencias también acompañan al ejecutable en la carpeta licenses.", AuroraUi.MUTED, 11)
	var license_button := _cabinet_action_button(legal, "VER LICENCIAS", AuroraUi.CORAL)
	license_button.toggle_mode = true
	var license_text := RichTextLabel.new()
	license_text.custom_minimum_size.y = 270.0
	license_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	license_text.bbcode_enabled = false
	license_text.selection_enabled = true
	license_text.scroll_active = true
	license_text.text = _build_complete_license_text()
	license_text.visible = false
	license_text.add_theme_font_size_override("normal_font_size", 11)
	license_text.add_theme_color_override("default_color", AuroraUi.TEXT)
	legal.add_child(license_text)
	license_button.toggled.connect(_on_cabinet_license_toggled.bind(license_button, license_text))


func _on_cabinet_license_toggled(open: bool, button: Button, license_text: RichTextLabel) -> void:
	license_text.visible = open
	button.text = AuroraLocale.text("OCULTAR LICENCIAS" if open else "VER LICENCIAS")


func _build_general_settings() -> void:
	_add_page_intro("GENERAL", "Idioma, accesibilidad y datos locales.", AuroraUi.TEAL)

	var system := _add_section("PREFERENCIAS")
	_add_option_row(
		system,
		"Idioma",
		"language",
		["Español", "English"],
		["es", "en"],
		"Idioma utilizado por la interfaz."
	)
	_add_toggle_row(system, "Reducir movimiento", "reduced_motion", "Limita pulsos, sacudidas y transiciones intensas.")

	var data := _add_section("DATOS LOCALES", "Los ajustes se guardan automáticamente en el perfil local.")
	var reset_row := HBoxContainer.new()
	reset_row.add_theme_constant_override("separation", 16)
	data.add_child(reset_row)
	var reset_text := VBoxContainer.new()
	reset_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_row.add_child(reset_text)
	reset_text.add_child(
		AuroraUi.make_label(AuroraLocale.text("Restablecer configuración"), 16, AuroraUi.TEXT)
	)
	reset_text.add_child(
		AuroraUi.make_label(
			AuroraLocale.text("Recupera valores y controles predeterminados."),
			12,
			AuroraUi.MUTED
		)
	)
	reset_button = AuroraUi.make_button(AuroraLocale.text("RESTABLECER TODO"))
	reset_button.custom_minimum_size = Vector2(190, 46)
	AuroraUi.apply_pixel_font(reset_button, 9)
	_apply_danger_button_style(reset_button, false)
	reset_button.pressed.connect(_on_reset_settings)
	reset_row.add_child(reset_button)

	var cache_separator := HSeparator.new()
	cache_separator.modulate = Color(0.2, 0.85, 1.0, 0.24)
	data.add_child(cache_separator)
	var cache_row := HBoxContainer.new()
	cache_row.add_theme_constant_override("separation", 16)
	data.add_child(cache_row)
	var cache_text := VBoxContainer.new()
	cache_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cache_row.add_child(cache_text)
	cache_text.add_child(
		AuroraUi.make_label(
			AuroraLocale.text("Limpiar caché regenerable"),
			16,
			AuroraUi.TEXT
		)
	)
	cache_text.add_child(
		AuroraUi.make_label(
			AuroraLocale.text(
				"Elimina solo conversiones y formas de onda sin uso. "
				+ "No toca canciones, proyectos ni archivos originales."
			),
			12,
			AuroraUi.MUTED
		)
	)
	cache_summary_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("CALCULANDO CACHÉ..."),
		7,
		AuroraUi.TEAL
	)
	cache_text.add_child(cache_summary_label)
	cache_button = AuroraUi.make_button(AuroraLocale.text("LIMPIAR CACHÉ"))
	cache_button.custom_minimum_size = Vector2(190, 46)
	AuroraUi.apply_pixel_font(cache_button, 8)
	_apply_danger_button_style(cache_button, false)
	cache_button.pressed.connect(_on_clean_cache)
	cache_row.add_child(cache_button)
	_refresh_cache_maintenance_summary()


func _build_cabinet_audio_settings() -> void:
	var columns := HBoxContainer.new()
	columns.name = "CabinetMixer"
	columns.add_theme_constant_override("separation", 15)
	columns.custom_minimum_size.y = 470.0
	content_host.add_child(columns)
	_add_cabinet_fader(columns, "VOLUMEN\nGENERAL", "master_volume", "Master", AuroraUi.TEAL)
	_add_cabinet_fader(columns, "MÚSICA", "music_volume", "Music", AuroraUi.VIOLET)
	_add_cabinet_fader(columns, "EFECTOS", "sfx_volume", "SFX", AuroraUi.CORAL, true)
	if menu_music_manager != null:
		_on_featured_song_changed(menu_music_manager.featured_song, menu_music_manager.featured_audio_available)
	else:
		_on_featured_song_changed(null, false)


func _add_cabinet_fader(
	parent: HBoxContainer,
	title: String,
	key: String,
	bus_name: String,
	accent: Color,
	show_key_sounds: bool = false
) -> void:
	var column := VBoxContainer.new()
	column.name = "Fader_%s" % key
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	parent.add_child(column)
	var heading := AuroraUi.make_pixel_label(AuroraLocale.text(title), 15, accent)
	heading.custom_minimum_size.y = 54.0
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var current := float(settings_manager.get_setting(key, 0.7))
	var percentage := AuroraUi.make_pixel_label(_format_value(current, "percent"), 20, AuroraUi.TEXT)
	percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percentage.custom_minimum_size.y = 40.0
	column.add_child(percentage)
	var fader_area := HBoxContainer.new()
	fader_area.name = "FaderArea"
	fader_area.custom_minimum_size.y = 272.0
	fader_area.alignment = BoxContainer.ALIGNMENT_CENTER
	fader_area.add_theme_constant_override("separation", 13)
	column.add_child(fader_area)
	var ticks := VBoxContainer.new()
	ticks.custom_minimum_size = Vector2(23.0, 252.0)
	ticks.add_theme_constant_override("separation", 0)
	fader_area.add_child(ticks)
	for index in range(11):
		var tick := AuroraUi.make_pixel_label("─", 7, Color(accent.r, accent.g, accent.b, 0.55))
		tick.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ticks.add_child(tick)
	var slider := VSlider.new()
	slider.name = "VolumeSlider"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = current
	slider.custom_minimum_size = Vector2(43.0, 252.0)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.005, 0.02, 0.05, 0.98)
	groove.border_color = Color(accent.r, accent.g, accent.b, 0.8)
	groove.set_border_width_all(2)
	groove.set_corner_radius_all(3)
	var active := StyleBoxFlat.new()
	active.bg_color = Color(accent.r, accent.g, accent.b, 0.82)
	active.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("slider", groove)
	slider.add_theme_stylebox_override("grabber_area", active)
	slider.add_theme_stylebox_override("grabber_area_highlight", active)
	var handle := _cabinet_fader_handle(accent)
	slider.add_theme_icon_override("grabber", handle)
	slider.add_theme_icon_override("grabber_highlight", handle)
	slider.value_changed.connect(_on_slider_changed.bind(key, percentage, "percent"))
	fader_area.add_child(slider)
	if key == "music_volume":
		_register_music_volume_control(slider, percentage)
	var meter := VBoxContainer.new()
	meter.custom_minimum_size = Vector2(16.0, 252.0)
	meter.alignment = BoxContainer.ALIGNMENT_END
	meter.add_theme_constant_override("separation", 4)
	fader_area.add_child(meter)
	var bars: Array[ColorRect] = []
	for _index in range(12):
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(13.0, 12.0)
		bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bar.color = Color(accent.r, accent.g, accent.b, 0.2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.add_child(bar)
		bars.push_front(bar)
	audio_meter_bars[bus_name] = bars
	audio_meter_accents[bus_name] = accent
	var signal_label := AuroraUi.make_pixel_label(AuroraLocale.text("SEÑAL / %s") % bus_name.to_upper(), 11, accent)
	signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(signal_label)
	if show_key_sounds:
		var key_sounds := Button.new()
		key_sounds.text = AuroraLocale.text("SONIDO DE TECLAS")
		key_sounds.toggle_mode = true
		key_sounds.button_pressed = bool(settings_manager.get_setting("key_sounds_enabled", true))
		key_sounds.custom_minimum_size.y = 40.0
		AuroraUi.apply_pixel_font(key_sounds, 11)
		key_sounds.add_theme_color_override("font_color", AuroraUi.TEXT)
		key_sounds.add_theme_stylebox_override("normal", _cabinet_button_style(Color(0.01, 0.02, 0.05, 0.9), AuroraUi.BORDER))
		key_sounds.add_theme_stylebox_override("hover", _cabinet_button_style(Color(0.01, 0.10, 0.15, 0.9), accent))
		key_sounds.add_theme_stylebox_override("pressed", _cabinet_button_style(Color(accent.r, accent.g, accent.b, 0.24), accent))
		key_sounds.add_theme_stylebox_override("hover_pressed", _cabinet_button_style(Color(accent.r, accent.g, accent.b, 0.35), accent))
		key_sounds.add_theme_stylebox_override("focus", _cabinet_button_style(Color.TRANSPARENT, accent))
		key_sounds.toggled.connect(func(enabled: bool) -> void: settings_manager.set_setting("key_sounds_enabled", enabled))
		column.add_child(key_sounds)
	else:
		var auto_save := AuroraUi.make_pixel_label(AuroraLocale.text("GUARDADO AUTOMÁTICO"), 9, AuroraUi.MUTED)
		auto_save.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(auto_save)


func _build_audio_settings() -> void:
	_add_page_intro(
		"SONIDO",
		"Un solo control ajusta las canciones de partida y la pista destacada del menú.",
		AuroraUi.CORAL
	)
	_build_featured_track_card()

	var mixer_heading := HBoxContainer.new()
	mixer_heading.add_theme_constant_override("separation", 12)
	content_host.add_child(mixer_heading)
	var mixer_title := AuroraUi.make_pixel_label(
		AuroraLocale.text("MEZCLADOR DE CABINA"), 10, AuroraUi.TEAL
	)
	mixer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mixer_heading.add_child(mixer_title)
	var signal_label := AuroraUi.make_pixel_label(
		AuroraLocale.text("SEÑAL EN VIVO"), 7, AuroraUi.MUTED
	)
	signal_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	signal_label.custom_minimum_size.x = 126.0
	signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mixer_heading.add_child(signal_label)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	cards.custom_minimum_size.y = 282.0
	content_host.add_child(cards)

	var master_card := _new_audio_mixer_card(cards, "01 // SALIDA", AuroraUi.TEAL)
	_add_audio_slider(master_card, "Volumen maestro", "master_volume", AuroraUi.TEAL)
	_add_audio_meter(master_card, "Master", AuroraUi.TEAL)

	var music_card := _new_audio_mixer_card(cards, "02 // MÚSICA", AuroraUi.VIOLET)
	_add_audio_slider(music_card, "Música", "music_volume", AuroraUi.VIOLET)
	music_card.add_child(
		AuroraUi.make_label(
			AuroraLocale.text("Canciones de partida y pista destacada del menú."),
			10,
			AuroraUi.MUTED
		)
	)
	_add_audio_meter(music_card, "Music", AuroraUi.VIOLET)

	var effects_card := _new_audio_mixer_card(cards, "03 // EFECTOS", AuroraUi.CORAL)
	_add_audio_slider(effects_card, "Efectos", "sfx_volume", AuroraUi.CORAL)
	_add_audio_meter(effects_card, "SFX", AuroraUi.CORAL)
	_add_toggle_row(
		effects_card,
		"Sonido de teclas",
		"key_sounds_enabled",
		"Reproduce un tono al pulsar cada carril."
	)
	if menu_music_manager != null:
		_on_featured_song_changed(
			menu_music_manager.featured_song,
			menu_music_manager.featured_audio_available
		)
	else:
		_on_featured_song_changed(null, false)


func _build_featured_track_card() -> void:
	var panel := PanelContainer.new()
	panel.name = "FeaturedTrackCard"
	panel.custom_minimum_size.y = 126.0
	panel.add_theme_stylebox_override(
		"panel",
		_make_terminal_style(
			Color(0.003, 0.012, 0.034, 0.97),
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.70),
			2
		)
	)
	content_host.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	featured_cover = TextureRect.new()
	featured_cover.name = "FeaturedTrackCover"
	featured_cover.custom_minimum_size = Vector2(100.0, 100.0)
	featured_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	featured_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	featured_cover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(featured_cover)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 7)
	row.add_child(info)
	info.add_child(
		AuroraUi.make_pixel_label(
			AuroraLocale.text("AHORA EN CABINA  //  CANCIÓN DESTACADA"),
			8,
			AuroraUi.TEAL
		)
	)
	featured_title_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("SIN CANCIÓN"), 12, AuroraUi.TEXT
	)
	featured_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	featured_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(featured_title_label)
	featured_artist_label = AuroraUi.make_label(
		AuroraLocale.text("Galería de Aurora"), 11, AuroraUi.MUTED
	)
	featured_artist_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(featured_artist_label)
	featured_status_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("ESPERANDO PISTA"), 7, AuroraUi.GOLD
	)
	featured_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(featured_status_label)
	var preview_note := AuroraUi.make_label(
		AuroraLocale.text("El control de música del menú ajusta este audio."),
		10,
		AuroraUi.MUTED
	)
	info.add_child(preview_note)


func _new_audio_mixer_card(parent: HBoxContainer, title: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 208.0
	var style := _make_terminal_style(
		Color(0.006, 0.014, 0.039, 0.97),
		Color(accent.r, accent.g, accent.b, 0.62)
	)
	style.border_width_top = 3
	style.border_color = Color(accent.r, accent.g, accent.b, 0.88)
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 15.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var heading := AuroraUi.make_pixel_label(AuroraLocale.text(title), 8, accent)
	content.add_child(heading)
	var divider := HSeparator.new()
	divider.modulate = Color(accent.r, accent.g, accent.b, 0.40)
	content.add_child(divider)
	return content


func _add_audio_slider(parent: VBoxContainer, title: String, key: String, accent: Color) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var header := HBoxContainer.new()
	row.add_child(header)
	var label := AuroraUi.make_label(AuroraLocale.text(title), 11, AuroraUi.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var current := float(settings_manager.get_setting(key, 0.0))
	var value_label := AuroraUi.make_pixel_label(_format_value(current, "percent"), 7, accent)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.custom_minimum_size.x = 42.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = current
	slider.custom_minimum_size.y = 24.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.012, 0.025, 0.052, 1.0)
	track.border_color = Color(accent.r, accent.g, accent.b, 0.38)
	track.border_width_bottom = 1
	track.border_width_top = 1
	track.border_width_left = 1
	track.border_width_right = 1
	var active_track := StyleBoxFlat.new()
	active_track.bg_color = Color(accent.r, accent.g, accent.b, 0.78)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", active_track)
	slider.add_theme_stylebox_override("grabber_area_highlight", active_track)
	slider.value_changed.connect(_on_slider_changed.bind(key, value_label, "percent"))
	row.add_child(slider)
	if key == "music_volume":
		_register_music_volume_control(slider, value_label)


func _add_audio_meter(parent: VBoxContainer, bus_name: String, accent: Color) -> void:
	var meter_row := HBoxContainer.new()
	meter_row.add_theme_constant_override("separation", 4)
	parent.add_child(meter_row)
	var meter_label := AuroraUi.make_pixel_label(AuroraLocale.text("NIVEL"), 6, AuroraUi.MUTED)
	meter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	meter_label.custom_minimum_size.x = 38.0
	meter_row.add_child(meter_label)
	var meter := HBoxContainer.new()
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.alignment = BoxContainer.ALIGNMENT_END
	meter.add_theme_constant_override("separation", 3)
	meter_row.add_child(meter)
	var bars: Array[ColorRect] = []
	for _index in range(12):
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(5.0, 11.0)
		bar.color = Color(accent.r, accent.g, accent.b, 0.18)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.add_child(bar)
		bars.append(bar)
	audio_meter_bars[bus_name] = bars
	audio_meter_accents[bus_name] = accent


func _on_featured_song_changed(song: SongData, has_audio: bool) -> void:
	if featured_title_label == null or not is_instance_valid(featured_title_label):
		return
	if song == null:
		if featured_cover != null and is_instance_valid(featured_cover):
			featured_cover.texture = null
		featured_title_label.text = AuroraLocale.text("SIN CANCIÓN")
		if featured_artist_label != null and is_instance_valid(featured_artist_label):
			featured_artist_label.text = AuroraLocale.text("Galería de Aurora")
		if featured_status_label != null and is_instance_valid(featured_status_label):
			featured_status_label.text = AuroraLocale.text("ESPERANDO PISTA")
			featured_status_label.add_theme_color_override("font_color", AuroraUi.GOLD)
		return
	if song_manager != null and featured_cover != null and is_instance_valid(featured_cover):
		song_manager.ensure_song_cover_loaded(song)
	if featured_cover != null and is_instance_valid(featured_cover):
		featured_cover.texture = song.cover
	featured_title_label.text = str(song.title).strip_edges().to_upper()
	if featured_artist_label != null and is_instance_valid(featured_artist_label):
		featured_artist_label.text = str(song.artist).strip_edges()
	_refresh_featured_status(has_audio)


func _refresh_featured_status(has_audio: bool) -> void:
	if featured_status_label == null or not is_instance_valid(featured_status_label):
		return
	var music_volume := float(settings_manager.get_setting("music_volume", 0.85))
	if music_volume <= 0.001:
		featured_status_label.text = AuroraLocale.text("MÚSICA // SILENCIADA")
		featured_status_label.add_theme_color_override("font_color", AuroraUi.MUTED)
	elif has_audio:
		featured_status_label.text = AuroraLocale.text("PREVIA ACTIVA // CAMBIA CON EL CARRUSEL")
		featured_status_label.add_theme_color_override("font_color", AuroraUi.TEAL)
	else:
		featured_status_label.text = AuroraLocale.text("SIN AUDIO // PREVIA EN SILENCIO")
		featured_status_label.add_theme_color_override("font_color", AuroraUi.GOLD)


func _process(_delta: float) -> void:
	for bus_name_variant in audio_meter_bars:
		var bus_name := str(bus_name_variant)
		var bars: Array = audio_meter_bars[bus_name_variant]
		var accent: Color = audio_meter_accents.get(bus_name_variant, AuroraUi.TEAL)
		var level := 0.0
		var monitored_buses: Array[String] = [bus_name]
		if bus_name == "Music":
			monitored_buses.append("MenuMusic")
		for monitored_bus in monitored_buses:
			var bus_index := AudioServer.get_bus_index(monitored_bus)
			if bus_index >= 0:
				var left_db := AudioServer.get_bus_peak_volume_left_db(bus_index, 0)
				var right_db := AudioServer.get_bus_peak_volume_right_db(bus_index, 0)
				level = maxf(level, clampf((maxf(left_db, right_db) + 42.0) / 42.0, 0.0, 1.0))
		for index in range(bars.size()):
			if not is_instance_valid(bars[index]):
				continue
			var bar := bars[index] as ColorRect
			if bar == null:
				continue
			var active_bars := roundi(level * float(bars.size()))
			bar.color = (
				accent
				if index < active_bars
				else Color(accent.r, accent.g, accent.b, 0.18)
			)


func _build_gameplay_settings() -> void:
	_add_page_intro("JUGABILIDAD", "Lectura de notas, pista y calibración.", AuroraUi.GOLD)

	var notes := _add_section("LECTURA DE NOTAS", "Estos cambios también estarán disponibles desde la pausa.")
	_add_slider_row(notes, "Velocidad de notas", "note_speed", 1.0, 10.0, 0.1, "speed")
	_add_slider_row(notes, "Opacidad de la pista", "lane_opacity", 0.0, 1.0, 0.01, "percent")
	_add_slider_row(notes, "Oscurecer fondo", "background_dim", 0.0, 1.0, 0.01, "percent")
	_add_toggle_row(notes, "Tramos de cinemática", "cinematic_sections_enabled", "Oculta brevemente la pista en los tramos del nivel. Reaparece antes de las notas.")
	_add_toggle_row(notes, "Mostrar teclas de carril", "show_lane_labels", "Muestra la tecla asignada dentro de cada receptor.")
	_add_toggle_row(notes, "Efectos de impacto", "show_hit_effects", "Destello breve al pulsar una nota.")

	var calibration := _add_section("CALIBRACIÓN", "Compensa la diferencia entre audio, pantalla y pulsación.")
	_add_slider_row(calibration, "Desfase global", "timing_offset_ms", -200.0, 200.0, 1.0, "milliseconds")


func _build_graphics_settings() -> void:
	_add_page_intro("PANTALLA", "Ventana, fluidez y efectos visuales.", AuroraUi.VIOLET)

	var display := _add_section("VENTANA", "El modo y la resolución se aplican al seleccionarlos.")
	_add_option_row(
		display,
		"Modo de pantalla",
		"window_mode",
		["Ventana", "Ventana sin bordes", "Pantalla completa"],
		["windowed", "borderless", "fullscreen"]
	)
	_add_option_row(
		display,
		"Resolución",
		"resolution",
		["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"],
		["1280x720", "1600x900", "1920x1080", "2560x1440"]
	)
	_add_toggle_row(display, "Sincronización vertical", "vsync_enabled", "Evita cortes de imagen al sincronizar con el monitor.")
	_add_option_row(display, "Límite de FPS", "fps_limit", ["Sin límite", "60", "120", "144", "240"], [0, 60, 120, 144, 240])

	var effects := _add_section("EFECTOS", "Controla el nivel de actividad visual sin afectar las notas.")
	_add_option_row(effects, "Calidad gráfica", "graphics_quality", ["Baja", "Media", "Alta"], ["low", "medium", "high"])
	_add_toggle_row(effects, "Fondo animado", "background_animation_enabled", "Mantiene activos los elementos ambientales.")
	_add_slider_row(effects, "Intensidad del fondo", "background_animation_intensity", 1.0, 5.0, 1.0, "integer")
	_add_toggle_row(effects, "Sacudida de pantalla", "screen_shake_enabled", "Permite impactos sutiles en momentos destacados.")


func _build_control_settings() -> void:
	_add_page_intro(
		"CONTROLES",
		"Configura el teclado y el mando para jugar y navegar por toda la interfaz.",
		AuroraUi.TEAL
	)

	var modes := _add_section("MODO DE TECLAS", "Selecciona una distribución antes de editarla.")
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	modes.add_child(mode_row)
	for mode in [4, 6, 8]:
		var mode_button := AuroraUi.make_button("%dK" % mode, mode == binding_mode)
		mode_button.custom_minimum_size = Vector2(120, 46)
		mode_button.toggle_mode = true
		mode_button.button_pressed = mode == binding_mode
		mode_button.pressed.connect(_on_binding_mode_selected.bind(mode))
		mode_row.add_child(mode_button)

	var bindings := _add_section(
		AuroraLocale.text("TECLADO %dK") % binding_mode,
		"Selecciona un carril y pulsa la nueva tecla."
	)
	var grid := GridContainer.new()
	grid.columns = min(binding_mode, 4)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	bindings.add_child(grid)

	var keycodes := input_manager.get_mode_keycodes(binding_mode)
	for lane_index in range(binding_mode):
		var lane_box := VBoxContainer.new()
		lane_box.custom_minimum_size.x = 170.0
		lane_box.add_theme_constant_override("separation", 6)
		grid.add_child(lane_box)
		var label := AuroraUi.make_label(
			AuroraLocale.text("CARRIL %02d") % (lane_index + 1),
			12,
			AuroraUi.MUTED
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lane_box.add_child(label)
		var key_button := AuroraUi.make_button(input_manager.get_key_label(keycodes[lane_index]), true)
		key_button.custom_minimum_size = Vector2(170, 58)
		key_button.pressed.connect(_start_key_capture.bind(lane_index, key_button))
		lane_box.add_child(key_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	bindings.add_child(actions)
	var reset_mode := AuroraUi.make_button(AuroraLocale.text("RESTAURAR %dK") % binding_mode)
	reset_mode.custom_minimum_size = Vector2(190, 44)
	reset_mode.pressed.connect(_reset_current_bindings)
	actions.add_child(reset_mode)
	var help := AuroraUi.make_label(
		AuroraLocale.text("Las teclas repetidas intercambian su carril. ESC cancela."),
		12,
		AuroraUi.MUTED
	)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.autowrap_mode = TextServer.AUTOWRAP_OFF
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	actions.add_child(help)

	var controller := _add_section(
		AuroraLocale.text("MANDO %dK") % binding_mode,
		AuroraLocale.text(
			"Selecciona un carril y pulsa el nuevo botón. Xbox y PlayStation se detectan automáticamente."
		)
	)
	controller_status_label = AuroraUi.make_pixel_label("", 9, AuroraUi.TEAL)
	controller_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controller.add_child(controller_status_label)
	_refresh_controller_status()

	var controller_grid := GridContainer.new()
	controller_grid.columns = min(binding_mode, 4)
	controller_grid.add_theme_constant_override("h_separation", 12)
	controller_grid.add_theme_constant_override("v_separation", 12)
	controller.add_child(controller_grid)
	var joy_buttons := input_manager.get_mode_joy_buttons(binding_mode)
	for lane_index in range(binding_mode):
		var lane_box := VBoxContainer.new()
		lane_box.custom_minimum_size.x = 170.0
		lane_box.add_theme_constant_override("separation", 6)
		controller_grid.add_child(lane_box)
		var lane_label := AuroraUi.make_label(
			AuroraLocale.text("CARRIL %02d") % (lane_index + 1),
			12,
			AuroraUi.MUTED
		)
		lane_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lane_box.add_child(lane_label)
		var joy_button := AuroraUi.make_button(
			input_manager.get_controller_button_label(joy_buttons[lane_index]),
			true
		)
		joy_button.custom_minimum_size = Vector2(170, 58)
		joy_button.pressed.connect(
			_start_controller_lane_capture.bind(lane_index, joy_button)
		)
		lane_box.add_child(joy_button)

	var controller_actions := HBoxContainer.new()
	controller_actions.add_theme_constant_override("separation", 12)
	controller.add_child(controller_actions)
	var reset_controller := AuroraUi.make_button(
		AuroraLocale.text("RESTAURAR MANDO %dK") % binding_mode
	)
	reset_controller.custom_minimum_size = Vector2(230, 44)
	reset_controller.pressed.connect(_reset_current_controller_bindings)
	controller_actions.add_child(reset_controller)
	var controller_hint := AuroraUi.make_label(
		AuroraLocale.text("Los botones repetidos intercambian su carril. ESC cancela."),
		12,
		AuroraUi.MUTED
	)
	controller_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controller_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controller_actions.add_child(controller_hint)

	var layouts := AuroraUi.make_panel(Color(0.035, 0.045, 0.085, 0.72))
	controller.add_child(layouts)
	var layout_content := VBoxContainer.new()
	layout_content.add_theme_constant_override("separation", 10)
	layouts.add_child(layout_content)
	var xbox_layout := AuroraUi.make_pixel_label(
		"XBOX %dK   %s" % [
			binding_mode,
			input_manager.get_controller_layout_text(binding_mode, "xbox"),
		],
		11,
		AuroraUi.TEXT
	)
	xbox_layout.autowrap_mode = TextServer.AUTOWRAP_OFF
	layout_content.add_child(xbox_layout)
	var playstation_layout := AuroraUi.make_pixel_label(
		"PLAYSTATION %dK   %s" % [
			binding_mode,
			input_manager.get_controller_layout_text(binding_mode, "playstation"),
		],
		11,
		AuroraUi.TEXT
	)
	playstation_layout.autowrap_mode = TextServer.AUTOWRAP_OFF
	layout_content.add_child(playstation_layout)

	var interface_actions := _add_section(
		AuroraLocale.text("ACCIONES DEL MANDO"),
		AuroraLocale.text(
			"Estos botones funcionan en menús, biblioteca, editor, pausa y resultados."
		)
	)
	var action_grid := GridContainer.new()
	# Three columns keep every remappable action visible at 1280x720 while
	# retaining a compact two-row layout on larger windows.
	action_grid.columns = 3
	action_grid.name = "ControllerActionGrid"
	action_grid.add_theme_constant_override("h_separation", 12)
	action_grid.add_theme_constant_override("v_separation", 12)
	interface_actions.add_child(action_grid)
	var action_labels := {
		"confirm": "CONFIRMAR",
		"back": "VOLVER",
		"pause": "PAUSA / REPRODUCIR",
		"shift_left": "SHIFT IZQUIERDO",
		"shift_right": "SHIFT DERECHO",
		"preview": "VISTA PREVIA",
		"delete": "BORRAR",
	}
	for action_name in InputManager.CONTROLLER_ACTIONS:
		var action_box := VBoxContainer.new()
		action_box.custom_minimum_size.x = 170.0
		action_box.add_theme_constant_override("separation", 6)
		action_grid.add_child(action_box)
		var action_label := AuroraUi.make_label(
			AuroraLocale.text(str(action_labels[action_name])),
			11,
			AuroraUi.MUTED
		)
		action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_box.add_child(action_label)
		var action_button := AuroraUi.make_button(
			input_manager.get_controller_action_label(action_name),
			true
		)
		action_button.custom_minimum_size = Vector2(170, 54)
		action_button.pressed.connect(
			_start_controller_action_capture.bind(action_name, action_button)
		)
		action_box.add_child(action_button)

	var action_footer := HBoxContainer.new()
	action_footer.add_theme_constant_override("separation", 12)
	interface_actions.add_child(action_footer)
	var reset_actions := AuroraUi.make_button(AuroraLocale.text("RESTAURAR ACCIONES"))
	reset_actions.custom_minimum_size = Vector2(230, 44)
	reset_actions.pressed.connect(_reset_controller_actions)
	action_footer.add_child(reset_actions)
	var controller_help := AuroraUi.make_label(
		AuroraLocale.text(
			"El D-pad y el stick izquierdo siempre navegan. El teclado permanece disponible."
		),
		12,
		AuroraUi.MUTED
	)
	controller_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controller_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_footer.add_child(controller_help)


func _build_credits_settings() -> void:
	_add_page_intro(
		"CRÉDITOS Y LICENCIAS",
		"Personas, herramientas y software libre que hacen posible Aurora.",
		AuroraUi.VIOLET
	)

	var project := _add_section(
		"AURORA",
		"Juego de ritmo, biblioteca local y editor de niveles."
	)
	_add_credit_entry(
		project, "EFECTO PERFECT PLAY", "DJMAX // referencia local",
		"Audio de terceros; animación recreada en Aurora. Ver avisos de terceros.",
		AuroraUi.TEAL
	)
	_add_credit_entry(
		project,
		"DISEÑO Y DESARROLLO",
		"Aurora Project",
		"Versión %s // 2026"
		% str(ProjectSettings.get_setting("application/config/version", "1.0.0")),
		AuroraUi.TEAL
	)
	_add_credit_entry(
		project,
		"MÚSICA DEL MENÚ",
		"Previsualización de la canción destacada",
		"La cabina reproduce la pista que muestra el carrusel de la galería.",
		AuroraUi.CORAL
	)
	_add_credit_entry(
		project,
		"PRUEBAS Y RETROALIMENTACIÓN",
		"Navi89",
		"Pruebas de juego, reportes visuales y comentarios durante el desarrollo de Aurora.",
		AuroraUi.VIOLET
	)

	var technology := _add_section(
		"TECNOLOGÍA",
		"Componentes independientes incluidos y sus condiciones de distribución."
	)
	var engine_version := Engine.get_version_info()
	_add_credit_entry(
		technology,
		"GODOT ENGINE",
		"%s // Licencia MIT" % str(engine_version.get("string", "Godot")),
		"Copyright de Godot Engine contributors, Juan Linietsky y Ariel Manzur.",
		AuroraUi.TEAL
	)
	_add_credit_entry(
		technology,
		"FFMPEG",
		"FFmpeg %s // GNU LGPL v3 o posterior" % FFMPEG_VERSION_LABEL,
		(
			"Conversor independiente incluido para importar video. "
			+ "Licencia, hashes, receta y fuentes: licenses/FFmpeg/. "
			+ "FFmpeg es una marca de Fabrice Bellard."
		),
		AuroraUi.GOLD
	)
	_add_credit_entry(
		technology,
		"PRESS START 2P",
		"Press Start 2P Project Authors // SIL Open Font License 1.1",
		"Tipografía pixel utilizada por la interfaz de Aurora.",
		AuroraUi.VIOLET
	)

	var notices := _add_section(
		"AVISOS LEGALES",
		"Las licencias completas también acompañan al ejecutable dentro de la carpeta licenses."
	)
	notices.add_child(
		AuroraUi.make_label(
			AuroraLocale.text(
				"Aurora y FFmpeg son programas independientes. Las canciones, videos y charts "
				+ "importados pertenecen a sus respectivos autores y no forman parte de Aurora."
			),
			12,
			AuroraUi.MUTED
		)
	)

	var license_button := AuroraUi.make_button(
		AuroraLocale.text("VER LICENCIAS COMPLETAS")
	)
	license_button.toggle_mode = true
	license_button.custom_minimum_size = Vector2(300, 48)
	AuroraUi.apply_pixel_font(license_button, 8)
	notices.add_child(license_button)

	var license_text := TextEdit.new()
	license_text.custom_minimum_size.y = 360.0
	license_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	license_text.editable = false
	license_text.context_menu_enabled = true
	license_text.text = _build_complete_license_text()
	license_text.visible = false
	license_text.add_theme_font_size_override("font_size", 12)
	license_text.add_theme_color_override("font_color", AuroraUi.TEXT)
	license_text.add_theme_color_override("background_color", Color(0.004, 0.008, 0.026, 0.98))
	notices.add_child(license_text)
	license_button.toggled.connect(
		_on_license_visibility_toggled.bind(license_button, license_text)
	)


func _add_credit_entry(
	parent: VBoxContainer,
	title: String,
	name: String,
	detail: String,
	accent: Color
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(3, 58)
	marker.color = accent
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	copy.add_child(AuroraUi.make_pixel_label(AuroraLocale.text(title), 8, accent))
	copy.add_child(AuroraUi.make_label(AuroraLocale.text(name), 15, AuroraUi.TEXT))
	copy.add_child(AuroraUi.make_label(AuroraLocale.text(detail), 11, AuroraUi.MUTED))


func _on_license_visibility_toggled(
	visible: bool,
	button: Button,
	license_text: TextEdit
) -> void:
	license_text.visible = visible
	button.text = AuroraLocale.text(
		"OCULTAR LICENCIAS" if visible else "VER LICENCIAS COMPLETAS"
	)


func _build_complete_license_text() -> String:
	var sections: Array[String] = []
	sections.append(
		"GODOT ENGINE // MIT\n\n%s" % Engine.get_license_text().strip_edges()
	)
	sections.append(_format_godot_third_party_notices())

	var font_license := _read_first_text_file(
		[
			"res://assets/menu/fonts/OFL.txt",
			OS.get_executable_path().get_base_dir().path_join(
				"licenses/PressStart2P/OFL.txt"
			),
		]
	)
	if not font_license.is_empty():
		sections.append("PRESS START 2P // SIL OFL 1.1\n\n%s" % font_license)

	var executable_directory := OS.get_executable_path().get_base_dir()
	var local_app_data := OS.get_environment("LOCALAPPDATA")
	var ffmpeg_license := _read_first_text_file(
		[
			executable_directory.path_join("licenses/FFmpeg/LICENSE.txt"),
			local_app_data.path_join(
				"%s/package/LICENSE.txt" % FFMPEG_LOCAL_PREPARATION
			),
		]
	)
	if not ffmpeg_license.is_empty():
		sections.append(
			"FFMPEG %s // GNU LGPL V3 O POSTERIOR\n\n%s"
			% [FFMPEG_VERSION_LABEL, ffmpeg_license]
		)
	else:
		sections.append(
			"FFMPEG %s // GNU LGPL V3 O POSTERIOR\n\n"
			% FFMPEG_VERSION_LABEL
			+ "El texto completo se encuentra en licenses/FFmpeg/LICENSE.txt."
		)

	var ffmpeg_external_libraries := _read_first_text_file(
		[
			executable_directory.path_join(
				"licenses/FFmpeg/EXTERNAL_LIBRARIES.txt"
			),
			"res://legal/FFMPEG_EXTERNAL_LIBRARIES.txt",
		]
	)
	if not ffmpeg_external_libraries.is_empty():
		sections.append(
			"FFMPEG // BIBLIOTECAS EXTERNAS Y FUENTES\n\n%s"
			% ffmpeg_external_libraries
		)

	return "\n\n\n".join(sections)


func _format_godot_third_party_notices() -> String:
	var lines: Array[String] = [
		"GODOT ENGINE // COMPONENTES DE TERCEROS",
		"",
	]
	for component_value in Engine.get_copyright_info():
		var component := component_value as Dictionary
		lines.append(str(component.get("name", "Componente")))
		for part_value in component.get("parts", []):
			var part := part_value as Dictionary
			for copyright_value in part.get("copyright", []):
				lines.append("  Copyright: %s" % str(copyright_value))
			lines.append("  Licencia: %s" % str(part.get("license", "Sin especificar")))
		lines.append("")

	var license_info := Engine.get_license_info()
	var license_names: Array = license_info.keys()
	license_names.sort()
	for license_name in license_names:
		lines.append("--- %s ---" % str(license_name))
		lines.append(str(license_info[license_name]).strip_edges())
		lines.append("")
	return "\n".join(lines).strip_edges()


func _read_first_text_file(paths: Array[String]) -> String:
	for path in paths:
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			return file.get_as_text().strip_edges()
	return ""


func _refresh_controller_status() -> void:
	if controller_status_label == null or not is_instance_valid(controller_status_label):
		return
	var controller_name := input_manager.get_controller_name()
	if controller_name.is_empty():
		controller_status_label.text = AuroraLocale.text(
			"SIN MANDO CONECTADO // LISTO PARA DETECTAR"
		)
		controller_status_label.add_theme_color_override("font_color", AuroraUi.MUTED)
	else:
		controller_status_label.text = AuroraLocale.text("CONECTADO // %s") % controller_name
		controller_status_label.add_theme_color_override("font_color", AuroraUi.TEAL)


func _on_controller_connection_changed(_connected: bool, _device: int) -> void:
	_refresh_controller_status()


func _add_slider_row(
	parent: VBoxContainer,
	title: String,
	key: String,
	minimum: float,
	maximum: float,
	step: float,
	format: String
) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)

	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	var label := AuroraUi.make_label(AuroraLocale.text(title), 15, AuroraUi.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(label)
	var value := float(settings_manager.get_setting(key, minimum))
	var value_label := AuroraUi.make_label(_format_value(value, format), 15, AuroraUi.TEAL)
	value_label.custom_minimum_size.x = 120.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(key, value_label, format))
	box.add_child(slider)


func _add_toggle_row(parent: VBoxContainer, title: String, key: String, description: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size.y = 56.0
	parent.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	copy.add_child(AuroraUi.make_label(AuroraLocale.text(title), 15, AuroraUi.TEXT))
	copy.add_child(AuroraUi.make_label(AuroraLocale.text(description), 12, AuroraUi.MUTED))

	var toggle_row := HBoxContainer.new()
	toggle_row.custom_minimum_size.x = 176.0
	toggle_row.alignment = BoxContainer.ALIGNMENT_END
	toggle_row.add_theme_constant_override("separation", 4)
	row.add_child(toggle_row)

	var group := ButtonGroup.new()
	group.allow_unpress = false
	var disabled_button := Button.new()
	disabled_button.text = "OFF"
	disabled_button.toggle_mode = true
	disabled_button.button_group = group
	disabled_button.custom_minimum_size = Vector2(82, 42)
	AuroraUi.apply_pixel_font(disabled_button, 9)
	_apply_segment_button_style(disabled_button)
	toggle_row.add_child(disabled_button)

	var enabled_button := Button.new()
	enabled_button.text = "ON"
	enabled_button.toggle_mode = true
	enabled_button.button_group = group
	enabled_button.custom_minimum_size = Vector2(82, 42)
	AuroraUi.apply_pixel_font(enabled_button, 9)
	_apply_segment_button_style(enabled_button)
	toggle_row.add_child(enabled_button)

	var enabled := bool(settings_manager.get_setting(key, false))
	disabled_button.button_pressed = not enabled
	enabled_button.button_pressed = enabled
	disabled_button.pressed.connect(
		_on_segment_toggle_pressed.bind(false, key, disabled_button, enabled_button)
	)
	enabled_button.pressed.connect(
		_on_segment_toggle_pressed.bind(true, key, disabled_button, enabled_button)
	)


func _add_option_row(
	parent: VBoxContainer,
	title: String,
	key: String,
	labels: Array,
	values: Array,
	description: String = ""
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size.y = 52.0
	parent.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	copy.add_child(AuroraUi.make_label(AuroraLocale.text(title), 15, AuroraUi.TEXT))
	if not description.is_empty():
		copy.add_child(AuroraUi.make_label(AuroraLocale.text(description), 12, AuroraUi.MUTED))

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(280, 44)
	AuroraUi.apply_pixel_font(option, 9)
	var base := Color(0.020, 0.028, 0.060, 0.98)
	var focus_border := Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.94)
	option.add_theme_stylebox_override("normal", _make_terminal_style(base, AuroraUi.BORDER))
	option.add_theme_stylebox_override("hover", _make_terminal_style(base, focus_border))
	option.add_theme_stylebox_override("focus", _make_terminal_style(base, focus_border, 2))
	option.add_theme_stylebox_override("pressed", _make_terminal_style(base, focus_border, 2))
	for item_label in labels:
		option.add_item(AuroraLocale.text(str(item_label)))
	var current = settings_manager.get_setting(key, values[0])
	var selected_index := values.find(current)
	option.selected = maxi(selected_index, 0)
	option.item_selected.connect(_on_option_changed.bind(key, values))
	row.add_child(option)


func _on_slider_changed(value: float, key: String, value_label: Label, format: String) -> void:
	value_label.text = _format_value(value, format)
	var stored_value: Variant = value
	if format in ["integer", "milliseconds"]:
		stored_value = roundi(value)
	settings_manager.set_setting(key, stored_value)
	if key == "music_volume":
		var has_audio := menu_music_manager != null and menu_music_manager.featured_audio_available
		_refresh_featured_status(has_audio)


func _register_music_volume_control(slider: Range, value_label: Label) -> void:
	music_volume_controls.append({"slider": slider, "label": value_label})


func _on_setting_changed(key: String, value) -> void:
	if key != "music_volume":
		return
	var volume := float(value)
	for control in music_volume_controls:
		var slider := control.get("slider") as Range
		var value_label := control.get("label") as Label
		if is_instance_valid(slider):
			slider.set_value_no_signal(volume)
		if is_instance_valid(value_label):
			value_label.text = _format_value(volume, "percent")
	var has_audio := menu_music_manager != null and menu_music_manager.featured_audio_available
	_refresh_featured_status(has_audio)


func _on_segment_toggle_pressed(
	enabled: bool,
	key: String,
	disabled_button: Button,
	enabled_button: Button
) -> void:
	disabled_button.button_pressed = not enabled
	enabled_button.button_pressed = enabled
	settings_manager.set_setting(key, enabled)


func _on_option_changed(index: int, key: String, values: Array) -> void:
	if index >= 0 and index < values.size():
		settings_manager.set_setting(key, values[index])
		if key == "language":
			call_deferred("setup_ui")


func _format_value(value: float, format: String) -> String:
	match format:
		"percent":
			return "%d%%" % roundi(value * 100.0)
		"speed":
			return "%.1fx" % value
		"milliseconds":
			return "%+d ms" % roundi(value)
		"integer":
			return "%d" % roundi(value)
	return str(value)


func _on_binding_mode_selected(mode: int) -> void:
	binding_mode = mode
	_show_category("controls")


func _start_key_capture(lane_index: int, button: Button) -> void:
	capture_lane = lane_index
	capture_button = button
	capture_kind = "keyboard"
	capture_action_name = ""
	button.text = AuroraLocale.text("PULSA UNA TECLA...")


func _start_controller_lane_capture(lane_index: int, button: Button) -> void:
	capture_lane = lane_index
	capture_button = button
	capture_kind = "controller_lane"
	capture_action_name = ""
	button.text = AuroraLocale.text("PULSA UN BOTÓN...")


func _start_controller_action_capture(action_name: String, button: Button) -> void:
	capture_lane = -1
	capture_button = button
	capture_kind = "controller_action"
	capture_action_name = action_name
	button.text = AuroraLocale.text("PULSA UN BOTÓN...")


func _clear_binding_capture() -> void:
	capture_lane = -1
	capture_button = null
	capture_kind = ""
	capture_action_name = ""


func _reset_current_bindings() -> void:
	input_manager.reset_bindings(binding_mode)
	_show_category("controls")


func _reset_current_controller_bindings() -> void:
	input_manager.reset_controller_bindings(binding_mode)
	_show_category("controls")


func _reset_controller_actions() -> void:
	input_manager.reset_controller_bindings(binding_mode, true)
	_show_category("controls")


func _apply_danger_button_style(button: Button, armed: bool) -> void:
	var background := Color(AuroraUi.CORAL.r, AuroraUi.CORAL.g, AuroraUi.CORAL.b, 0.18 if armed else 0.06)
	var border := Color(AuroraUi.CORAL.r, AuroraUi.CORAL.g, AuroraUi.CORAL.b, 0.98 if armed else 0.62)
	button.add_theme_stylebox_override("normal", _make_terminal_style(background, border, 2 if armed else 1))
	button.add_theme_stylebox_override("hover", _make_terminal_style(background, border, 2))
	button.add_theme_stylebox_override("focus", _make_terminal_style(background, border, 2))
	button.add_theme_stylebox_override(
		"pressed",
		_make_terminal_style(
			Color(AuroraUi.CORAL.r, AuroraUi.CORAL.g, AuroraUi.CORAL.b, 0.26),
			border,
			2
		)
	)
	button.add_theme_color_override("font_color", AuroraUi.CORAL)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _on_reset_settings() -> void:
	if not reset_confirmation_active:
		var token := _arm_reset_confirmation()
		_expire_reset_confirmation(token)
		return

	reset_confirmation_active = false
	reset_confirmation_token += 1
	settings_manager.reset_to_defaults()
	binding_mode = 4
	current_category = "general"
	call_deferred("setup_ui")


func _arm_reset_confirmation() -> int:
	reset_confirmation_active = true
	reset_confirmation_token += 1
	if reset_button != null and is_instance_valid(reset_button):
		reset_button.text = AuroraLocale.text("CONFIRMAR")
		_apply_danger_button_style(reset_button, true)
	return reset_confirmation_token


func _expire_reset_confirmation(token: int) -> void:
	await get_tree().create_timer(4.0).timeout
	if token != reset_confirmation_token or not reset_confirmation_active:
		return
	reset_confirmation_active = false
	if reset_button != null and is_instance_valid(reset_button):
		reset_button.text = AuroraLocale.text("RESTABLECER TODO")
		_apply_danger_button_style(reset_button, false)


func _refresh_cache_maintenance_summary() -> void:
	if cache_maintenance == null:
		cache_cleanup_plan = {}
	else:
		cache_cleanup_plan = cache_maintenance.build_cleanup_plan()
	if cache_summary_label == null or not is_instance_valid(cache_summary_label):
		return
	if not bool(cache_cleanup_plan.get("ok", false)):
		cache_summary_label.text = AuroraLocale.text("NO SE PUDO REVISAR LA CACHÉ")
		cache_summary_label.add_theme_color_override("font_color", AuroraUi.CORAL)
		if cache_button != null:
			cache_button.disabled = true
		return
	var file_count := int(cache_cleanup_plan.get("file_count", 0))
	var total_bytes := int(cache_cleanup_plan.get("total_bytes", 0))
	cache_summary_label.add_theme_color_override("font_color", AuroraUi.TEAL)
	cache_summary_label.text = (
		AuroraLocale.text("CACHÉ LIMPIA // NADA QUE ELIMINAR")
		if file_count == 0
		else AuroraLocale.text("%d ARCHIVOS // %s RECUPERABLES")
			% [file_count, _format_storage_size(total_bytes)]
	)
	if cache_button != null:
		cache_button.disabled = file_count == 0
		cache_button.text = AuroraLocale.text("LIMPIAR CACHÉ")
		_apply_danger_button_style(cache_button, false)


func _on_clean_cache() -> void:
	if not bool(cache_cleanup_plan.get("ok", false)):
		_refresh_cache_maintenance_summary()
		return
	if int(cache_cleanup_plan.get("file_count", 0)) <= 0:
		_refresh_cache_maintenance_summary()
		return
	if not cache_confirmation_active:
		cache_confirmation_active = true
		cache_confirmation_token += 1
		var token := cache_confirmation_token
		cache_button.text = AuroraLocale.text("CONFIRMAR LIMPIEZA")
		_apply_danger_button_style(cache_button, true)
		_expire_cache_confirmation(token)
		return

	cache_confirmation_active = false
	cache_confirmation_token += 1
	var fresh_plan: Dictionary = cache_maintenance.build_cleanup_plan()
	var cleanup: Dictionary = cache_maintenance.execute_cleanup_plan(
		fresh_plan
	)
	var deleted_count := int(cleanup.get("deleted_count", 0))
	var deleted_bytes := int(cleanup.get("deleted_bytes", 0))
	_refresh_cache_maintenance_summary()
	if cache_summary_label == null or not is_instance_valid(cache_summary_label):
		return
	if bool(cleanup.get("ok", false)):
		cache_summary_label.text = AuroraLocale.text(
			"LIMPIEZA COMPLETA // %d ARCHIVOS // %s LIBERADOS"
		) % [deleted_count, _format_storage_size(deleted_bytes)]
		cache_summary_label.add_theme_color_override("font_color", AuroraUi.TEAL)
	else:
		cache_summary_label.text = AuroraLocale.text(
			"LIMPIEZA PARCIAL // REVISA LOS ARCHIVOS EN USO"
		)
		cache_summary_label.add_theme_color_override("font_color", AuroraUi.CORAL)


func _expire_cache_confirmation(token: int) -> void:
	await get_tree().create_timer(5.0).timeout
	if (
		token != cache_confirmation_token
		or not cache_confirmation_active
	):
		return
	cache_confirmation_active = false
	if cache_button != null and is_instance_valid(cache_button):
		cache_button.text = AuroraLocale.text("LIMPIAR CACHÉ")
		_apply_danger_button_style(cache_button, false)


func _format_storage_size(byte_count: int) -> String:
	var size := maxf(float(byte_count), 0.0)
	if size >= 1024.0 * 1024.0 * 1024.0:
		return "%.2f GiB" % (size / (1024.0 * 1024.0 * 1024.0))
	if size >= 1024.0 * 1024.0:
		return "%.1f MiB" % (size / (1024.0 * 1024.0))
	if size >= 1024.0:
		return "%.1f KiB" % (size / 1024.0)
	return "%d B" % byte_count


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if (
			not capture_kind.is_empty()
			and input_manager.controller_event_matches(event, "back")
		):
			_clear_binding_capture()
			_show_category("controls")
			get_viewport().set_input_as_handled()
			return
		if capture_kind == "controller_lane":
			input_manager.set_mode_joy_button(
				binding_mode,
				capture_lane,
				int(event.button_index)
			)
			_clear_binding_capture()
			_show_category("controls")
			get_viewport().set_input_as_handled()
			return
		if capture_kind == "controller_action":
			input_manager.set_controller_action_button(
				capture_action_name,
				int(event.button_index)
			)
			_clear_binding_capture()
			_show_category("controls")
			get_viewport().set_input_as_handled()
			return
		if input_manager.controller_event_matches(event, "back"):
			get_viewport().set_input_as_handled()
			if capture_kind == "keyboard":
				_clear_binding_capture()
				_show_category("controls")
			else:
				scene_manager.load_scene("main_menu")
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not capture_kind.is_empty():
			if event.keycode == KEY_ESCAPE:
				_clear_binding_capture()
				_show_category("controls")
			elif capture_kind == "keyboard":
				var keycode: int = int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
				input_manager.set_mode_keycode(binding_mode, capture_lane, keycode)
				_clear_binding_capture()
				_show_category("controls")
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			scene_manager.load_scene("main_menu")
