extends Control

class_name GameplayAppearanceInventory

const GAMEPLAY_PREVIEW := preload(
	"res://src/screens/song_select/GameplayProfilePreview.gd"
)
const CARD_PREVIEW := preload(
	"res://src/screens/song_select/GameplayAppearanceCardPreview.gd"
)
const CUSTOM_EDITOR := preload(
	"res://src/screens/song_select/GameplayAppearanceEditor.gd"
)

signal close_requested

const PROFILES := [
	{
		"id": "aurora",
		"title": "AURORA\nORIGINAL",
		"description": "Carril Aurora, notas con brillo y lectura original de partida.",
		"features": "CARRIL ORIGINAL\nNOTAS CON BRILLO\nCOMBO + RATE",
		"accent": Color(0.04, 0.86, 1.0),
		"count": "01",
	},
	{
		"id": "djmax",
		"title": "DJMAX\nCENTRAL",
		"description": "Pista central 4K con color por carril y lectura de COMBO / RATE.",
		"features": "PISTA CENTRAL 4K\nCOLOR POR CARRIL\nCOMBO + RATE",
		"accent": Color("#ff5c9f"),
		"count": "02",
	},
	{
		"id": "quaver",
		"title": "QUAVER\nNÍTIDO",
		"description": "Separación clara, notas rectangulares y lectura de ACCURACY.",
		"features": "DIVISIONES NÍTIDAS\nNOTAS RECTANGULARES\nCOMBO + ACCURACY",
		"accent": Color("#60e38c"),
		"count": "03",
	},
	{
		"id": "fnf",
		"title": "FNF\nFUNKIN'",
		"description": "Flechas direccionales clásicas, receptores huecos y brillo al acertar.",
		"features": "FLECHAS CLÁSICAS\nCOLOR POR DIRECCIÓN\nCOMBO + RATE",
		"accent": Color("#24ef58"),
		"count": "04",
	},
	{
		"id": "custom",
		"title": "PERSONALIZADO\nPROPIO",
		"description": "Diseña tu carril y tus teclas con vista previa en vivo.",
		"features": "CARRIL A TU GUSTO\nFORMA Y COLOR DE NOTAS\nHOLDS PERSONALIZADOS",
		"accent": Color("#ffd166"),
		"count": "05",
	},
]

var settings_manager: SettingsManager
var input_manager: InputManager
var selected_profile := "aurora"
var preview: Control
var selected_name_label: Label
var equipped_label: Label
var counter_label: Label
var equip_button: Button
var close_button: Button
var customize_button: Button
var profile_buttons: Dictionary = {}
var profile_group := ButtonGroup.new()
var custom_editor: Control


func setup(settings: SettingsManager, input: InputManager) -> void:
	settings_manager = settings
	input_manager = input
	selected_profile = str(settings_manager.get_setting("gameplay_visual_profile", "aurora"))
	if selected_profile not in ["aurora", "djmax", "quaver", "fnf", "custom"]:
		selected_profile = "aurora"
	profile_group.allow_unpress = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	var selected_button := profile_buttons.get(selected_profile) as Button
	if selected_button != null:
		selected_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_requested.emit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if equip_button != null and not equip_button.disabled:
				_equip_selected_profile()
				get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var shade := ColorRect.new()
	AuroraUi.fill(shade)
	shade.color = Color(0.005, 0.007, 0.018, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var compact_layout := get_viewport_rect().size.x < 1280.0 or get_viewport_rect().size.y < 720.0
	var panel := PanelContainer.new()
	panel.name = "AppearanceInventoryPanel"
	panel.anchor_left = 0.02 if compact_layout else 0.035
	panel.anchor_top = 0.025 if compact_layout else 0.065
	panel.anchor_right = 0.98 if compact_layout else 0.965
	panel.anchor_bottom = 0.975 if compact_layout else 0.935
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 14 if compact_layout else 20)
	margins.add_theme_constant_override("margin_top", 12 if compact_layout else 18)
	margins.add_theme_constant_override("margin_right", 14 if compact_layout else 20)
	margins.add_theme_constant_override("margin_bottom", 10 if compact_layout else 16)
	panel.add_child(margins)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8 if compact_layout else 14)
	margins.add_child(layout)
	_add_header(layout)

	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 2.0
	divider.color = Color(0.16, 0.78, 0.88, 0.68)
	layout.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14 if compact_layout else 16)
	layout.add_child(body)
	_add_preview_column(body)
	_add_items_column(body)
	_add_footer(layout)
	_refresh_preview()


func _add_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 5)
	row.add_child(title_stack)
	var title := AuroraUi.make_pixel_label(AuroraLocale.text("INVENTARIO DE ASPECTOS"), 21)
	title_stack.add_child(title)
	var subtitle := AuroraUi.make_label(
		AuroraLocale.text("VISTA PREVIA DE CARRILES, NOTAS Y LECTURA DE PARTIDA"),
		12,
		AuroraUi.MUTED
	)
	title_stack.add_child(subtitle)

	counter_label = AuroraUi.make_pixel_label("01 / 05", 12, AuroraUi.GOLD)
	counter_label.custom_minimum_size = Vector2(84.0, 28.0)
	counter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(counter_label)


func _add_preview_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	var compact_layout := get_viewport_rect().size.x < 1280.0 or get_viewport_rect().size.y < 720.0
	column.custom_minimum_size.x = 250.0 if compact_layout else 390.0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	var heading := AuroraUi.make_pixel_label(AuroraLocale.text("VISTA PREVIA"), 11, AuroraUi.GOLD)
	column.add_child(heading)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", AuroraUi.make_style(Color(0.012, 0.015, 0.025, 0.96), Color(0.34, 0.33, 0.31, 0.92), 0))
	column.add_child(preview_panel)
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 8)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 8)
	preview_panel.add_child(preview_margin)
	preview = GAMEPLAY_PREVIEW.new() as Control
	preview.name = "InventoryGameplayPreview"
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(220.0, 190.0) if compact_layout else Vector2(350.0, 300.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_margin.add_child(preview)

	selected_name_label = AuroraUi.make_pixel_label("", 12, AuroraUi.TEXT)
	column.add_child(selected_name_label)
	equipped_label = AuroraUi.make_label("", 10, AuroraUi.MUTED)
	column.add_child(equipped_label)


func _add_items_column(parent: HBoxContainer) -> void:
	var compact_layout := get_viewport_rect().size.x < 1280.0 or get_viewport_rect().size.y < 720.0
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.56 if compact_layout else 1.62
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10 if compact_layout else 12)
	parent.add_child(column)

	var heading_row := HBoxContainer.new()
	column.add_child(heading_row)
	var heading := AuroraUi.make_pixel_label(AuroraLocale.text("ASPECTOS DISPONIBLES"), 11, AuroraUi.TEXT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	var filter := AuroraUi.make_label(AuroraLocale.text("5 ASPECTOS"), 9, AuroraUi.GOLD)
	filter.custom_minimum_size.x = 104.0
	filter.autowrap_mode = TextServer.AUTOWRAP_OFF
	filter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading_row.add_child(filter)

	var grid := GridContainer.new()
	grid.columns = 3 if compact_layout else 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for profile in PROFILES:
		_add_profile_card(grid, profile)

	var notice := AuroraUi.make_label(
		AuroraLocale.text("EQUIPAR CAMBIA SOLO EL ASPECTO; LAS TECLAS ASIGNADAS NO CAMBIAN."),
		10,
		AuroraUi.MUTED
	)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)


## Draws a mini playfield in each selectable profile card.
func _add_profile_card(parent: GridContainer, profile: Dictionary) -> void:
	var profile_id := str(profile["id"])
	var accent: Color = profile["accent"]
	var card := Button.new()
	card.name = "AppearanceItem_%s" % profile_id
	var compact_layout := get_viewport_rect().size.x < 1280.0 or get_viewport_rect().size.y < 720.0
	card.custom_minimum_size = Vector2(140.0, 150.0) if compact_layout else Vector2(118.0, 240.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.toggle_mode = true
	card.button_group = profile_group
	card.button_pressed = profile_id == selected_profile
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("normal", _card_style(accent, false))
	card.add_theme_stylebox_override("hover", _card_style(accent, true))
	card.add_theme_stylebox_override("pressed", _card_style(accent, true))
	card.add_theme_stylebox_override("hover_pressed", _card_style(accent, true))
	card.add_theme_stylebox_override("focus", _card_style(accent, true))
	card.pressed.connect(_select_profile.bind(profile_id))
	parent.add_child(card)
	profile_buttons[profile_id] = card

	var card_root := VBoxContainer.new()
	card_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_root.add_theme_constant_override("separation", 0)
	card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_root)
	var top := ColorRect.new()
	top.custom_minimum_size.y = 4.0
	top.color = accent
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(top)
	var card_margin := MarginContainer.new()
	card_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_margin.add_theme_constant_override("margin_left", 6 if compact_layout else 7)
	card_margin.add_theme_constant_override("margin_top", 4 if compact_layout else 6)
	card_margin.add_theme_constant_override("margin_right", 6 if compact_layout else 7)
	card_margin.add_theme_constant_override("margin_bottom", 6 if compact_layout else 9)
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(card_margin)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 4 if compact_layout else 7)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_margin.add_child(contents)
	var index := AuroraUi.make_pixel_label(str(profile["count"]), 9 if compact_layout else 10, accent)
	index.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	index.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(index)
	var card_preview := CARD_PREVIEW.new() as Control
	card_preview.name = "AppearanceCardPreview_%s" % profile_id
	card_preview.custom_minimum_size = Vector2(96.0, 68.0) if compact_layout else Vector2(104.0, 128.0)
	card_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_preview.call(
		"configure",
		profile_id,
		settings_manager.get_setting("custom_gameplay_appearance", {})
	)
	contents.add_child(card_preview)

	var title := AuroraUi.make_pixel_label(AuroraLocale.text(str(profile["title"])), 8 if compact_layout else 9, AuroraUi.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(title)

	var features := AuroraUi.make_label(AuroraLocale.text(str(profile["features"])), 7, accent)
	features.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	features.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	features.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(features)

	if not compact_layout:
		var description := AuroraUi.make_label(AuroraLocale.text(str(profile["description"])), 8, AuroraUi.MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(description)


func _add_footer(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var hint := AuroraUi.make_label(AuroraLocale.text("FLECHAS  SELECCIONAR      ESC  SALIR"), 10, AuroraUi.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)
	customize_button = _make_action_button(AuroraLocale.text("PERSONALIZAR"), AuroraUi.GOLD)
	customize_button.pressed.connect(_open_custom_editor)
	customize_button.visible = selected_profile == "custom"
	row.add_child(customize_button)
	close_button = _make_action_button(AuroraLocale.text("CANCELAR"), AuroraUi.MUTED)
	close_button.pressed.connect(_request_close)
	row.add_child(close_button)
	equip_button = _make_action_button(AuroraLocale.text("EQUIPAR"), AuroraUi.GOLD)
	equip_button.pressed.connect(_equip_selected_profile)
	row.add_child(equip_button)


func _select_profile(profile_id: String) -> void:
	selected_profile = profile_id
	_refresh_preview()


func _open_custom_editor() -> void:
	if custom_editor != null and is_instance_valid(custom_editor):
		return
	custom_editor = CUSTOM_EDITOR.new() as Control
	if custom_editor == null:
		return
	custom_editor.name = "GameplayAppearanceEditor"
	custom_editor.call("setup", settings_manager, input_manager)
	custom_editor.connect("close_requested", _close_custom_editor)
	custom_editor.connect("appearance_changed", _refresh_preview)
	add_child(custom_editor)


func is_custom_editor_open() -> bool:
	return custom_editor != null and is_instance_valid(custom_editor)


func _close_custom_editor() -> void:
	if custom_editor != null and is_instance_valid(custom_editor):
		custom_editor.queue_free()
	custom_editor = null

func _refresh_preview() -> void:
	if preview == null or not is_instance_valid(preview):
		return
	var profile := _profile_for(selected_profile)
	var key_labels: Array[String] = []
	if input_manager != null:
		for keycode in input_manager.get_mode_keycodes(4):
			key_labels.append(input_manager.get_key_label(keycode))
	preview.call(
		"configure",
		selected_profile,
		1.0,
		float(settings_manager.get_setting("lane_opacity", 0.82)),
		float(settings_manager.get_setting("note_speed", 5.5)),
		int(settings_manager.get_setting("timing_offset_ms", 0)),
		bool(settings_manager.get_setting("show_lane_labels", true)),
		key_labels,
		settings_manager.get_setting("custom_gameplay_appearance", {})
	)
	var selected_name := str(profile["title"]).replace("\n", "  //  ")
	selected_name_label.text = AuroraLocale.text(selected_name)
	if counter_label != null:
		counter_label.text = "%02d / %02d" % [_profile_index(selected_profile) + 1, PROFILES.size()]
	var is_equipped := str(settings_manager.get_setting("gameplay_visual_profile", "aurora")) == selected_profile
	equipped_label.text = AuroraLocale.text("EQUIPADO" if is_equipped else "VISTA PREVIA DEL ASPECTO")
	equip_button.disabled = is_equipped
	if customize_button != null:
		customize_button.visible = selected_profile == "custom"
	var custom_appearance = settings_manager.get_setting("custom_gameplay_appearance", {})
	for profile_id in profile_buttons:
		var button := profile_buttons[profile_id] as Button
		button.button_pressed = str(profile_id) == selected_profile
		var card_preview := button.find_child("AppearanceCardPreview_%s" % str(profile_id), true, false) as Control
		if card_preview != null:
			card_preview.call("configure", str(profile_id), custom_appearance)


func _profile_index(profile_id: String) -> int:
	for index in range(PROFILES.size()):
		if str(PROFILES[index]["id"]) == profile_id:
			return index
	return 0


func _equip_selected_profile() -> void:
	if settings_manager != null:
		settings_manager.set_setting("gameplay_visual_profile", selected_profile)
	close_requested.emit()


func _request_close() -> void:
	close_requested.emit()


func _profile_for(profile_id: String) -> Dictionary:
	for profile in PROFILES:
		if str(profile["id"]) == profile_id:
			return profile
	return PROFILES[0]


func _make_action_button(label: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(140.0, 42.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	AuroraUi.apply_pixel_font(button, 10)
	button.add_theme_color_override("font_color", AuroraUi.TEXT)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_focus_color", accent)
	button.add_theme_stylebox_override("normal", _card_style(accent, false))
	button.add_theme_stylebox_override("hover", _card_style(accent, true))
	button.add_theme_stylebox_override("focus", _card_style(accent, true))
	return button


func _card_style(accent: Color, highlighted: bool) -> StyleBoxFlat:
	var fill := Color(accent.r, accent.g, accent.b, 0.16 if highlighted else 0.055)
	var border := Color(accent.r, accent.g, accent.b, 0.95 if highlighted else 0.44)
	return AuroraUi.make_style(fill, border, 0)


func _panel_style() -> StyleBoxFlat:
	var style := AuroraUi.make_style(Color(0.075, 0.073, 0.069, 0.99), Color(0.32, 0.31, 0.29, 1.0), 0)
	style.set_border_width_all(2)
	return style
