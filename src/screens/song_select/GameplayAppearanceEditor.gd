extends Control

class_name GameplayAppearanceEditor

signal close_requested
signal appearance_changed

const GAMEPLAY_PREVIEW := preload(
	"res://src/screens/song_select/GameplayProfilePreview.gd"
)

const DEFAULT_CUSTOM_APPEARANCE := {
	"lane_fill": "#091525",
	"lane_divider": "#38d8f2",
	"lane_accent": "#ff62be",
	"left_rail": "#9977ff",
	"note_colors": ["#22ddff", "#ff56c7", "#ffd166", "#72e39a"],
	"note_border": "#f5f8ff",
	"note_shape": "rectangle",
	"note_size": 1.0,
	"lane_inset": 92.0,
	"lane_shape": "rectangle",
	"outline_width": 2,
}

const COLOR_FIELDS := [
	{"key": "lane_fill", "label": "FONDO DEL CARRIL"},
	{"key": "lane_divider", "label": "DIVISORES"},
	{"key": "lane_accent", "label": "BORDE / ACENTO"},
	{"key": "left_rail", "label": "BORDE EXTERIOR"},
	{"key": "note_border", "label": "CONTORNO DE NOTA"},
	{"key": "note_0", "label": "NOTA DEL CARRIL 1"},
	{"key": "note_1", "label": "NOTA DEL CARRIL 2"},
	{"key": "note_2", "label": "NOTA DEL CARRIL 3"},
	{"key": "note_3", "label": "NOTA DEL CARRIL 4"},
]

var settings_manager: SettingsManager
var input_manager: InputManager
var preview: Control
var color_pickers: Dictionary = {}
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var shape_option: OptionButton
var lane_shape_option: OptionButton


func setup(manager: SettingsManager, input: InputManager) -> void:
	settings_manager = manager
	input_manager = input

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var shade := ColorRect.new()
	AuroraUi.fill(shade)
	shade.color = Color(0.004, 0.006, 0.016, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "CustomAppearanceEditorPanel"
	panel.anchor_left = 0.04
	panel.anchor_top = 0.03
	panel.anchor_right = 0.96
	panel.anchor_bottom = 0.97
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 18)
	margins.add_theme_constant_override("margin_top", 14)
	margins.add_theme_constant_override("margin_right", 18)
	margins.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margins)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margins.add_child(layout)
	_add_header(layout)

	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 2.0
	divider.color = Color(0.16, 0.78, 0.88, 0.72)
	layout.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	layout.add_child(body)
	_add_controls_column(body)
	_add_preview_column(body)
	_add_footer(layout)
	_refresh_preview()


func _add_controls_column(parent: HBoxContainer) -> void:
	var compact_layout := get_viewport_rect().size.x < 1450.0 or get_viewport_rect().size.y < 800.0
	var controls_panel := PanelContainer.new()
	controls_panel.name = "CustomAppearanceControlsPanel"
	controls_panel.custom_minimum_size.x = 520.0 if compact_layout else 690.0
	controls_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_panel.size_flags_stretch_ratio = 0.95
	controls_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_panel.add_theme_stylebox_override("panel", _panel_style())
	parent.add_child(controls_panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 14)
	margins.add_theme_constant_override("margin_top", 12)
	margins.add_theme_constant_override("margin_right", 14)
	margins.add_theme_constant_override("margin_bottom", 12)
	controls_panel.add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margins.add_child(column)
	column.add_child(AuroraUi.make_pixel_label(AuroraLocale.text("CONTROLES"), 11, AuroraUi.GOLD))

	var colors_heading := AuroraUi.make_label(
		AuroraLocale.text("COLORES DEL CARRIL Y LAS NOTAS"),
		9,
		AuroraUi.TEXT
	)
	column.add_child(colors_heading)

	var colors := GridContainer.new()
	colors.name = "AppearanceColorControls"
	colors.columns = 1 if compact_layout else 2
	colors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colors.add_theme_constant_override("h_separation", 12)
	colors.add_theme_constant_override("v_separation", 5)
	column.add_child(colors)
	for field in COLOR_FIELDS:
		_add_color_control(colors, str(field["key"]), str(field["label"]))

	var options_heading := AuroraUi.make_label(
		AuroraLocale.text("FORMAS Y TAMAÑOS"),
		9,
		AuroraUi.TEXT
	)
	options_heading.custom_minimum_size.y = 20.0
	column.add_child(options_heading)

	var options := GridContainer.new()
	options.name = "AppearanceShapeControls"
	options.columns = 1 if compact_layout else 2
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("h_separation", 12)
	options.add_theme_constant_override("v_separation", 5)
	column.add_child(options)
	_add_slider_control(options, "ANCHO DEL CARRIL", "lane_inset", 48.0, 150.0, 1.0, 0)
	_add_slider_control(options, "TAMAÑO DE TECLAS", "note_size", 0.8, 1.5, 0.05, 2)
	_add_slider_control(options, "GROSOR DE CONTORNO", "outline_width", 0.0, 5.0, 1.0, 0)
	_add_shape_control(options)
	_add_lane_shape_control(options)


func _add_preview_column(parent: HBoxContainer) -> void:
	var compact_layout := get_viewport_rect().size.x < 1450.0 or get_viewport_rect().size.y < 800.0
	var column := VBoxContainer.new()
	column.name = "CustomAppearancePreviewColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.15
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)

	column.add_child(AuroraUi.make_pixel_label(
		AuroraLocale.text("VISTA PREVIA EN JUEGO"),
		11,
		AuroraUi.GOLD
	))
	var preview_panel := PanelContainer.new()
	preview_panel.name = "CustomAppearancePreviewPanel"
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _panel_style())
	column.add_child(preview_panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 10)
	margins.add_theme_constant_override("margin_top", 10)
	margins.add_theme_constant_override("margin_right", 10)
	margins.add_theme_constant_override("margin_bottom", 10)
	preview_panel.add_child(margins)
	preview = GAMEPLAY_PREVIEW.new() as Control
	preview.name = "CustomAppearanceGameplayPreview"
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(390.0, 360.0) if compact_layout else Vector2(560.0, 540.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_child(preview)

	var caption := AuroraUi.make_label(
		AuroraLocale.text("MUESTRA VISUAL 4K // HUD ILUSTRATIVO"),
		9,
		AuroraUi.MUTED
	)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)


func _add_footer(parent: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	parent.add_child(footer)
	var hint := AuroraUi.make_label(
		AuroraLocale.text("LOS CAMBIOS SE GUARDAN Y SE VEN EN LA VISTA PREVIA"),
		9,
		AuroraUi.MUTED
	)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(hint)
	var reset_button := _make_action_button(AuroraLocale.text("RESTABLECER"), AuroraUi.MUTED)
	reset_button.name = "ResetCustomAppearanceButton"
	reset_button.pressed.connect(_reset_appearance)
	footer.add_child(reset_button)
	var done_button := _make_action_button(AuroraLocale.text("LISTO"), AuroraUi.GOLD)
	done_button.name = "DoneCustomAppearanceButton"
	done_button.pressed.connect(func() -> void: close_requested.emit())
	footer.add_child(done_button)

func _add_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 4)
	row.add_child(stack)
	stack.add_child(AuroraUi.make_pixel_label(AuroraLocale.text("CREA TU CARRIL Y TUS TECLAS"), 17))
	stack.add_child(AuroraUi.make_label(
		AuroraLocale.text("PALETA Y FORMAS VISUALES · EL MAPA DE TECLAS NO CAMBIA"),
		10,
		AuroraUi.MUTED
	))
	var badge := AuroraUi.make_pixel_label(AuroraLocale.text("DISEÑO PROPIO"), 10, AuroraUi.GOLD)
	badge.custom_minimum_size = Vector2(176.0, 28.0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(badge)

func _add_color_control(parent: GridContainer, key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 34.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := AuroraUi.make_label(AuroraLocale.text(label_text), 8, AuroraUi.TEXT)
	label.custom_minimum_size.x = 154.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(52.0, 30.0)
	picker.color = _get_color(key)
	picker.color_changed.connect(_on_color_changed.bind(key))
	color_pickers[key] = picker
	row.add_child(picker)

func _add_slider_control(
	parent: GridContainer,
	title: String,
	key: String,
	minimum: float,
	maximum: float,
	step: float,
	decimals: int
) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 38.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)
	var label := AuroraUi.make_label(AuroraLocale.text(title), 8, AuroraUi.TEXT)
	label.custom_minimum_size.x = 136.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 72.0
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = _get_number(key)
	slider.value_changed.connect(_on_number_changed.bind(key, decimals))
	sliders[key] = slider
	row.add_child(slider)
	var value_label := AuroraUi.make_label("", 8, AuroraUi.GOLD)
	value_label.custom_minimum_size.x = 42.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_labels[key] = value_label
	row.add_child(value_label)
	_update_value_label(key, decimals)

func _add_shape_control(parent: GridContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 38.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := AuroraUi.make_label(AuroraLocale.text("FORMA DE TECLAS"), 8, AuroraUi.TEXT)
	label.custom_minimum_size.x = 132.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	shape_option = OptionButton.new()
	shape_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shape_option.custom_minimum_size.x = 140.0
	for pair in [["RECTANGULAR", "rectangle"], ["REDONDA", "rounded"], ["CÁPSULA", "pill"]]:
		shape_option.add_item(AuroraLocale.text(str(pair[0])))
		shape_option.set_item_metadata(shape_option.item_count - 1, str(pair[1]))
	var shape := str(_get_appearance().get("note_shape", "rectangle"))
	for index in range(shape_option.item_count):
		if str(shape_option.get_item_metadata(index)) == shape:
			shape_option.select(index)
			break
	shape_option.item_selected.connect(_on_shape_selected)
	row.add_child(shape_option)

func _add_lane_shape_control(parent: GridContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 38.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := AuroraUi.make_label(AuroraLocale.text("FORMA DEL CARRIL"), 8, AuroraUi.TEXT)
	label.custom_minimum_size.x = 132.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	lane_shape_option = OptionButton.new()
	lane_shape_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_shape_option.custom_minimum_size.x = 140.0
	for pair in [["RECTANGULAR", "rectangle"], ["REDONDO", "rounded"]]:
		lane_shape_option.add_item(AuroraLocale.text(str(pair[0])))
		lane_shape_option.set_item_metadata(lane_shape_option.item_count - 1, str(pair[1]))
	var shape := str(_get_appearance().get("lane_shape", "rectangle"))
	for index in range(lane_shape_option.item_count):
		if str(lane_shape_option.get_item_metadata(index)) == shape:
			lane_shape_option.select(index)
			break
	lane_shape_option.item_selected.connect(_on_lane_shape_selected)
	row.add_child(lane_shape_option)

func _on_lane_shape_selected(index: int) -> void:
	if lane_shape_option == null or index < 0:
		return
	var appearance := _get_appearance()
	appearance["lane_shape"] = str(lane_shape_option.get_item_metadata(index))
	_save_appearance(appearance)


func _get_appearance() -> Dictionary:
	if settings_manager == null:
		return DEFAULT_CUSTOM_APPEARANCE.duplicate(true)
	var value = settings_manager.get_setting("custom_gameplay_appearance", DEFAULT_CUSTOM_APPEARANCE)
	return value.duplicate(true) if value is Dictionary else DEFAULT_CUSTOM_APPEARANCE.duplicate(true)


func _get_color(key: String) -> Color:
	var appearance := _get_appearance()
	var color_value: String = ""
	if key.begins_with("note_"):
		var index := int(key.get_slice("_", 1))
		var palette: Array = appearance.get("note_colors", DEFAULT_CUSTOM_APPEARANCE["note_colors"])
		if index >= 0 and index < palette.size():
			color_value = str(palette[index])
	else:
		color_value = str(appearance.get(key, DEFAULT_CUSTOM_APPEARANCE.get(key, "#ffffff")))
	return Color.from_string(color_value, Color.WHITE)


func _get_number(key: String) -> float:
	var appearance := _get_appearance()
	return float(appearance.get(key, DEFAULT_CUSTOM_APPEARANCE.get(key, 0.0)))


func _on_color_changed(color: Color, key: String) -> void:
	var appearance := _get_appearance()
	if key.begins_with("note_"):
		var index := int(key.get_slice("_", 1))
		var palette: Array = appearance.get("note_colors", DEFAULT_CUSTOM_APPEARANCE["note_colors"]).duplicate()
		while palette.size() < 4:
			palette.append(DEFAULT_CUSTOM_APPEARANCE["note_colors"][palette.size()])
		palette[index] = color.to_html(false)
		appearance["note_colors"] = palette
	else:
		appearance[key] = color.to_html(false)
	_save_appearance(appearance)


func _on_number_changed(value: float, key: String, decimals: int) -> void:
	var appearance := _get_appearance()
	appearance[key] = roundf(value) if decimals == 0 else snappedf(value, 0.05)
	_save_appearance(appearance)
	_update_value_label(key, decimals)


func _on_shape_selected(index: int) -> void:
	if shape_option == null or index < 0:
		return
	var appearance := _get_appearance()
	appearance["note_shape"] = str(shape_option.get_item_metadata(index))
	_save_appearance(appearance)


func _save_appearance(appearance: Dictionary) -> void:
	if settings_manager != null:
		settings_manager.set_setting("custom_gameplay_appearance", appearance)
	_refresh_preview()
	appearance_changed.emit()

func _reset_appearance() -> void:
	if settings_manager != null:
		settings_manager.set_setting("custom_gameplay_appearance", DEFAULT_CUSTOM_APPEARANCE.duplicate(true))
	_refresh_controls()
	_refresh_preview()
	appearance_changed.emit()


func _refresh_preview() -> void:
	if preview == null or not is_instance_valid(preview):
		return
	var key_labels: Array[String] = []
	if input_manager != null:
		for keycode in input_manager.get_mode_keycodes(4):
			key_labels.append(input_manager.get_key_label(keycode))
	preview.call(
		"configure",
		"custom",
		1.0,
		float(settings_manager.get_setting("lane_opacity", 0.82)),
		float(settings_manager.get_setting("note_speed", 5.5)),
		int(settings_manager.get_setting("timing_offset_ms", 0)),
		bool(settings_manager.get_setting("show_lane_labels", true)),
		key_labels,
		_get_appearance()
	)

func _refresh_controls() -> void:
	var appearance := _get_appearance()
	for key in color_pickers:
		var picker := color_pickers[key] as ColorPickerButton
		if str(key).begins_with("note_"):
			var index := int(str(key).get_slice("_", 1))
			picker.color = Color.from_string(str(appearance["note_colors"][index]), Color.WHITE)
		else:
			picker.color = Color.from_string(str(appearance.get(key, "#ffffff")), Color.WHITE)
	for key in sliders:
		var slider := sliders[key] as HSlider
		slider.value = float(appearance.get(key, 0.0))
	_update_value_label("lane_inset", 0)
	_update_value_label("note_size", 2)
	_update_value_label("outline_width", 0)
	shape_option.select(0)
	lane_shape_option.select(0)
	for index in range(lane_shape_option.item_count):
		if str(lane_shape_option.get_item_metadata(index)) == str(appearance.get("lane_shape", "rectangle")):
			lane_shape_option.select(index)
			break
	for index in range(shape_option.item_count):
		if str(shape_option.get_item_metadata(index)) == str(appearance.get("note_shape", "rectangle")):
			shape_option.select(index)
			break


func _update_value_label(key: String, decimals: int) -> void:
	if not value_labels.has(key):
		return
	var value := float(_get_number(key))
	value_labels[key].text = ("%.*f" % [decimals, value]) if decimals > 0 else str(roundi(value))


func _make_action_button(label: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(118.0, 36.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	AuroraUi.apply_pixel_font(button, 9)
	button.add_theme_color_override("font_color", AuroraUi.TEXT)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_stylebox_override("normal", _button_style(accent, false))
	button.add_theme_stylebox_override("hover", _button_style(accent, true))
	button.add_theme_stylebox_override("focus", _button_style(accent, true))
	return button


func _button_style(accent: Color, highlighted: bool) -> StyleBoxFlat:
	return AuroraUi.make_style(
		Color(accent.r, accent.g, accent.b, 0.12 if highlighted else 0.045),
		Color(accent.r, accent.g, accent.b, 0.88 if highlighted else 0.4),
		0
	)


func _panel_style() -> StyleBoxFlat:
	var style := AuroraUi.make_style(Color(0.075, 0.073, 0.069, 0.995), Color(0.32, 0.31, 0.29, 1.0), 0)
	style.set_border_width_all(2)
	return style
