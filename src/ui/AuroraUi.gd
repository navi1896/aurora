extends RefCounted

class_name AuroraUi

const BG := Color(0.045, 0.055, 0.085)
const SURFACE := Color(0.095, 0.105, 0.145, 0.92)
const SURFACE_ALT := Color(0.13, 0.14, 0.19, 0.94)
const BORDER := Color(1.0, 1.0, 1.0, 0.10)
const TEXT := Color(0.94, 0.95, 0.98)
const MUTED := Color(0.62, 0.66, 0.76)
const TEAL := Color(0.18, 0.82, 0.82)
const CORAL := Color(1.0, 0.42, 0.36)
const GOLD := Color(1.0, 0.76, 0.32)
const VIOLET := Color(0.54, 0.43, 0.96)
const PIXEL_FONT := preload("res://assets/menu/fonts/PressStart2P-Regular.ttf")


static func fill(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


static func clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


static func add_background(parent: Control) -> void:
	var base := ColorRect.new()
	fill(base)
	base.color = BG
	parent.add_child(base)

	var top_band := ColorRect.new()
	top_band.anchor_right = 1.0
	top_band.offset_bottom = 96.0
	top_band.color = Color(TEAL.r, TEAL.g, TEAL.b, 0.08)
	parent.add_child(top_band)

	var bottom_band := ColorRect.new()
	bottom_band.anchor_top = 1.0
	bottom_band.anchor_right = 1.0
	bottom_band.anchor_bottom = 1.0
	bottom_band.offset_top = -128.0
	bottom_band.color = Color(CORAL.r, CORAL.g, CORAL.b, 0.08)
	parent.add_child(bottom_band)


static func make_style(bg: Color, border: Color = BORDER, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 18.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 14.0
	return style


static func make_panel(bg: Color = SURFACE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_style(bg))
	return panel


static func make_label(text: String, font_size: int = 18, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func make_pixel_label(text: String, font_size: int = 18, color: Color = TEXT) -> Label:
	var label := make_label(text, font_size, color)
	label.add_theme_font_override("font", PIXEL_FONT)
	return label


static func apply_pixel_font(control: Control, font_size: int = 0) -> void:
	control.add_theme_font_override("font", PIXEL_FONT)
	if font_size > 0:
		control.add_theme_font_size_override("font_size", font_size)


static func update_stepper_buttons(
	decrease_button: Button,
	increase_button: Button,
	value: float,
	minimum: float,
	maximum: float
) -> void:
	decrease_button.disabled = value <= minimum or is_equal_approx(value, minimum)
	increase_button.disabled = value >= maximum or is_equal_approx(value, maximum)


static func make_button(text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(240.0, 52.0)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_focus_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)

	var normal_color := Color(0.13, 0.16, 0.21, 0.96)
	var pressed_color := Color(0.11, 0.13, 0.18, 1.0)
	var border_color := BORDER
	if primary:
		normal_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.24)
		pressed_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.18)
		border_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.54)
	var selected_border := Color(TEAL.r, TEAL.g, TEAL.b, 0.96)

	button.add_theme_stylebox_override("normal", make_style(normal_color, border_color))
	button.add_theme_stylebox_override("hover", make_style(normal_color, selected_border))
	button.add_theme_stylebox_override("pressed", make_style(pressed_color, border_color))
	button.add_theme_stylebox_override(
		"focus",
		make_style(normal_color, selected_border)
	)
	return button


static func make_margin(left: int = 56, top: int = 44, right: int = 56, bottom: int = 44) -> MarginContainer:
	var margin := MarginContainer.new()
	fill(margin)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


static func spacer(height: int) -> Control:
	var control := Control.new()
	control.custom_minimum_size = Vector2(1.0, height)
	return control
