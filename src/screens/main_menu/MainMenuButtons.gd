extends VBoxContainer

class_name MainMenuButtons

signal action_selected(action: StringName)
signal focus_changed(action: StringName)

const ACTION_BY_BUTTON := {
	&"BtnStart": &"play",
	&"BtnOptions": &"settings",
	&"BtnLevelEditor": &"editor",
	&"BtnExit": &"quit",
}

const LABEL_BY_BUTTON := {
	&"BtnStart": "INICIAR",
	&"BtnOptions": "OPCIONES",
	&"BtnLevelEditor": "EDITOR DE NIVELES",
	&"BtnExit": "SALIR",
}

@export_group("Editable layout")
@export var button_size := Vector2(620.0, 96.0)
@export_range(0, 64, 1) var button_spacing := 18
@export_range(12, 64, 1) var button_font_size := 28
@export_range(0, 16, 1) var default_button_index := 0

@export_group("Editable colors")
@export var text_color := Color(0.94, 0.96, 1.0)
@export var selected_text_color := Color.WHITE

var menu_buttons: Array[Button] = []


func _ready() -> void:
	# Direct Button children are discovered automatically after scene edits.
	_collect_buttons()
	_apply_editable_presentation()
	_connect_button_behavior()


func focus_default_button() -> void:
	# Selects the configured starting option without activating it.
	if menu_buttons.is_empty():
		return
	var safe_index := clampi(default_button_index, 0, menu_buttons.size() - 1)
	menu_buttons[safe_index].grab_focus()


func _collect_buttons() -> void:
	menu_buttons.clear()
	for child in get_children():
		if child is Button and ACTION_BY_BUTTON.has(child.name):
			menu_buttons.append(child)


func _apply_editable_presentation() -> void:
	# These values can be changed from the MainButtons Inspector.
	add_theme_constant_override("separation", button_spacing)
	for button in menu_buttons:
		button.text = AuroraLocale.text(str(LABEL_BY_BUTTON.get(button.name, button.text)))
		button.custom_minimum_size = button_size
		button.add_theme_font_size_override("font_size", button_font_size)
		button.add_theme_color_override("font_color", text_color)
		button.add_theme_color_override("font_hover_color", selected_text_color)
		button.add_theme_color_override("font_focus_color", selected_text_color)
		button.add_theme_color_override("font_pressed_color", selected_text_color)


func _connect_button_behavior() -> void:
	# Hover follows keyboard focus and pressed emits a stable menu action.
	for button in menu_buttons:
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(_emit_focus_change.bind(button))
		button.pressed.connect(_emit_button_action.bind(button))


func _emit_focus_change(button: Button) -> void:
	var action: StringName = ACTION_BY_BUTTON.get(button.name, StringName())
	if action != &"":
		focus_changed.emit(action)


func _emit_button_action(button: Button) -> void:
	var action: StringName = ACTION_BY_BUTTON.get(button.name, StringName())
	if action != &"":
		action_selected.emit(action)
