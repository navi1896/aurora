extends Control

class_name Settings

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

var content_scroll: ScrollContainer
var content_frame: MarginContainer
var content_host: VBoxContainer
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


func _ready() -> void:
	AuroraUi.fill(self)
	var managers := get_tree().current_scene.get_node("Managers")
	scene_manager = managers.get_node("SceneManager") as SceneManager
	settings_manager = managers.get_node("SettingsManager") as SettingsManager
	input_manager = managers.get_node("InputManager") as InputManager
	input_manager.controller_connection_changed.connect(_on_controller_connection_changed)
	setup_ui()


func setup_ui() -> void:
	AuroraUi.clear(self)
	AuroraUi.add_background(self)
	_build_terminal_ambient()

	var ambient := ColorRect.new()
	AuroraUi.fill(ambient)
	ambient.color = Color(0.002, 0.006, 0.024, 0.48)
	ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ambient)

	var margin := AuroraUi.make_margin(48, 28, 48, 28)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	_build_header(page)

	var neon_line := ColorRect.new()
	neon_line.custom_minimum_size.y = 2.0
	neon_line.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.62)
	page.add_child(neon_line)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	_build_sidebar(body)
	_build_content_area(body)
	_build_footer(page)
	_show_category(current_category)


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
		vertical.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.022)
		grid.add_child(vertical)
	for index in range(1, 7):
		var horizontal := ColorRect.new()
		horizontal.anchor_top = float(index) / 7.0
		horizontal.anchor_right = 1.0
		horizontal.anchor_bottom = horizontal.anchor_top
		horizontal.offset_bottom = 1.0
		horizontal.color = Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.020)
		grid.add_child(horizontal)

	var spectrum := HBoxContainer.new()
	spectrum.anchor_left = 0.78
	spectrum.anchor_top = 0.72
	spectrum.anchor_right = 0.97
	spectrum.anchor_bottom = 0.91
	spectrum.alignment = BoxContainer.ALIGNMENT_END
	spectrum.add_theme_constant_override("separation", 5)
	spectrum.modulate = Color(1.0, 1.0, 1.0, 0.16)
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
			Color(0.012, 0.020, 0.052, 0.94),
			Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.42)
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
			Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.10),
			Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.50)
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
			Color(0.006, 0.012, 0.038, 0.92),
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.30)
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
	var available := maxf(size.x - 410.0, 720.0)
	var target := clampf(available - 48.0, 720.0, 1180.0)
	var gutter := maxf((available - target) * 0.5, 18.0)
	content_frame.custom_minimum_size.x = available
	content_frame.add_theme_constant_override("margin_left", roundi(gutter))
	content_frame.add_theme_constant_override("margin_right", roundi(gutter))
	content_frame.add_theme_constant_override("margin_top", 16)
	content_frame.add_theme_constant_override("margin_bottom", 18)
	content_host.custom_minimum_size.x = target


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
	_clear_binding_capture()
	reset_confirmation_active = false
	reset_confirmation_token += 1
	for id in category_buttons:
		var button := category_buttons[id] as Button
		button.button_pressed = str(id) == category
	if header_title_label != null:
		header_title_label.text = AuroraLocale.text("CONFIGURACIÓN // %s") % _get_category_label(category)

	AuroraUi.clear(content_host)
	match category:
		"audio":
			_build_audio_settings()
		"gameplay":
			_build_gameplay_settings()
		"graphics":
			_build_graphics_settings()
		"controls":
			_build_control_settings()
		"credits":
			_build_credits_settings()
		_:
			_build_general_settings()


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
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	return style


func _apply_category_button_style(button: Button) -> void:
	var base := Color(0.055, 0.070, 0.110, 0.94)
	var selected_border := Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.96)
	button.add_theme_stylebox_override("normal", _make_terminal_style(base, AuroraUi.BORDER))
	button.add_theme_stylebox_override("hover", _make_terminal_style(base, selected_border, 2))
	button.add_theme_stylebox_override("focus", _make_terminal_style(base, selected_border, 2))
	button.add_theme_stylebox_override(
		"pressed",
		_make_terminal_style(Color(0.040, 0.085, 0.120, 0.96), selected_border, 2)
	)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _apply_segment_button_style(button: Button) -> void:
	var base := Color(0.020, 0.028, 0.060, 0.98)
	var selected := Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.24)
	var selected_border := Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.94)
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
		Color(0.035, 0.045, 0.095, 0.88),
		Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.36)
	)
	section_style.border_width_left = 3
	section_style.border_color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.48)
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


func _build_audio_settings() -> void:
	_add_page_intro(
		"SONIDO",
		"Controla por separado el menú, las canciones y los efectos.",
		AuroraUi.CORAL
	)

	var mix := _add_section("MEZCLADOR", "Los buses disponibles se actualizan en tiempo real.")
	_add_slider_row(mix, "Volumen maestro", "master_volume", 0.0, 1.0, 0.01, "percent")
	_add_slider_row(mix, "Música del menú", "menu_music_volume", 0.0, 1.0, 0.01, "percent")
	_add_slider_row(mix, "Música de canciones", "music_volume", 0.0, 1.0, 0.01, "percent")
	_add_slider_row(mix, "Efectos", "sfx_volume", 0.0, 1.0, 0.01, "percent")


func _build_gameplay_settings() -> void:
	_add_page_intro("JUGABILIDAD", "Lectura de notas, pista y calibración.", AuroraUi.GOLD)

	var notes := _add_section("LECTURA DE NOTAS", "Estos cambios también estarán disponibles desde la pausa.")
	_add_slider_row(notes, "Velocidad de notas", "note_speed", 1.0, 10.0, 0.1, "speed")
	_add_slider_row(notes, "Opacidad de la pista", "lane_opacity", 0.25, 1.0, 0.05, "percent")
	_add_slider_row(notes, "Oscurecer fondo", "background_dim", 0.0, 0.9, 0.05, "percent")
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
	action_grid.columns = 5
	action_grid.add_theme_constant_override("h_separation", 12)
	action_grid.add_theme_constant_override("v_separation", 12)
	interface_actions.add_child(action_grid)
	var action_labels := {
		"confirm": "CONFIRMAR",
		"back": "VOLVER",
		"pause": "PAUSA / REPRODUCIR",
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
		"Composición procedural original de Aurora",
		"Generada localmente por el juego; no utiliza una grabación externa.",
		AuroraUi.CORAL
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
		"FFmpeg 6.1.6 // GNU LGPL 2.1 o posterior",
		(
			"Conversor independiente incluido para importar video. "
			+ "Licencia, receta y fuentes: licenses/FFmpeg/. "
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
				"AuroraDevTools/ffmpeg-minimal-build/package/licenses/FFmpeg/LICENSE.txt"
			),
			local_app_data.path_join(
				"AuroraDevTools/ffmpeg-minimal-build/src/"
				+ "ffmpeg-6.1.6/COPYING.LGPLv2.1"
			),
		]
	)
	if not ffmpeg_license.is_empty():
		sections.append(
			"FFMPEG 6.1.6 // GNU LGPL 2.1 O POSTERIOR\n\n%s"
			% ffmpeg_license
		)
	else:
		sections.append(
			"FFMPEG 6.1.6 // GNU LGPL 2.1 O POSTERIOR\n\n"
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


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
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
