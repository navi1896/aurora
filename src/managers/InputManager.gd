extends Node

class_name InputManager

signal button_pressed(button_name: String)
signal bindings_changed(mode: int)
signal controller_bindings_changed(mode: int)
signal input_device_changed(using_controller: bool)
signal controller_connection_changed(connected: bool, device: int)

const SUPPORTED_MODES: Array[int] = [4, 6, 8]
const CONTROLLER_ACTIONS: Array[String] = [
	"confirm",
	"back",
	"pause",
	"preview",
	"delete",
]

var settings_manager: SettingsManager
var using_controller := false
var active_controller_device := -1


func _ready() -> void:
	settings_manager = get_parent().get_node_or_null("SettingsManager") as SettingsManager
	_ensure_controller_ui_actions()
	refresh_lane_actions()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if settings_manager != null:
		settings_manager.setting_changed.connect(_on_setting_changed)
		settings_manager.settings_reset.connect(_on_settings_reset)


func refresh_lane_actions() -> void:
	for mode in SUPPORTED_MODES:
		var keycodes := get_mode_keycodes(mode)
		for lane_index in range(mode):
			var action := get_lane_action(mode, lane_index)
			if not InputMap.has_action(action):
				InputMap.add_action(action)
			InputMap.action_erase_events(action)
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycodes[lane_index] as Key
			InputMap.action_add_event(action, key_event)
			var joy_event := InputEventJoypadButton.new()
			joy_event.device = -1
			joy_event.button_index = get_mode_joy_buttons(mode)[lane_index]
			InputMap.action_add_event(action, joy_event)


func get_mode_keycodes(mode: int) -> Array[int]:
	var safe_mode := mode if mode in SUPPORTED_MODES else 4
	var defaults: Dictionary = SettingsManager.DEFAULT_SETTINGS["lane_bindings"]
	var bindings: Dictionary = defaults
	if settings_manager != null:
		var stored = settings_manager.get_setting("lane_bindings", defaults)
		if stored is Dictionary:
			bindings = stored

	var raw_values = bindings.get(str(safe_mode), defaults[str(safe_mode)])
	var result: Array[int] = []
	if raw_values is Array:
		for value in raw_values:
			result.append(int(value))
	if result.size() != safe_mode:
		result.clear()
		for value in defaults[str(safe_mode)]:
			result.append(int(value))
	return result


func set_mode_keycode(mode: int, lane_index: int, keycode: int) -> void:
	if mode not in SUPPORTED_MODES or lane_index < 0 or lane_index >= mode:
		return
	var bindings: Dictionary = SettingsManager.DEFAULT_SETTINGS["lane_bindings"].duplicate(true)
	if settings_manager != null:
		var stored = settings_manager.get_setting("lane_bindings", bindings)
		if stored is Dictionary:
			bindings = stored.duplicate(true)
	var mode_values: Array = bindings.get(str(mode), []).duplicate()
	if mode_values.size() != mode:
		mode_values = SettingsManager.DEFAULT_SETTINGS["lane_bindings"][str(mode)].duplicate()
	mode_values = _assign_unique_keycode(mode_values, lane_index, keycode)
	bindings[str(mode)] = mode_values
	if settings_manager != null:
		settings_manager.set_setting("lane_bindings", bindings, false)
	refresh_lane_actions()
	bindings_changed.emit(mode)


func _assign_unique_keycode(values: Array, lane_index: int, keycode: int) -> Array:
	var updated := values.duplicate()
	if lane_index < 0 or lane_index >= updated.size():
		return updated
	var previous_keycode := int(updated[lane_index])
	var duplicate_index := updated.find(keycode)
	if duplicate_index >= 0 and duplicate_index != lane_index:
		updated[duplicate_index] = previous_keycode
	updated[lane_index] = keycode
	return updated


func reset_bindings(mode: int = 0) -> void:
	if settings_manager == null:
		return
	var bindings: Dictionary = settings_manager.get_setting(
		"lane_bindings",
		SettingsManager.DEFAULT_SETTINGS["lane_bindings"]
	).duplicate(true)
	if mode in SUPPORTED_MODES:
		bindings[str(mode)] = SettingsManager.DEFAULT_SETTINGS["lane_bindings"][str(mode)].duplicate()
	else:
		bindings = SettingsManager.DEFAULT_SETTINGS["lane_bindings"].duplicate(true)
	settings_manager.set_setting("lane_bindings", bindings, false)
	refresh_lane_actions()
	bindings_changed.emit(mode)


func get_lane_action(mode: int, lane_index: int) -> StringName:
	return StringName("lane_%dk_%d" % [mode, lane_index + 1])


func get_mode_joy_buttons(mode: int) -> Array[int]:
	var safe_mode := mode if mode in SUPPORTED_MODES else 4
	var defaults: Dictionary = SettingsManager.DEFAULT_SETTINGS["controller_bindings"]
	var bindings: Dictionary = defaults
	if settings_manager != null:
		var stored = settings_manager.get_setting("controller_bindings", defaults)
		if stored is Dictionary:
			bindings = stored

	var raw_values = bindings.get(str(safe_mode), defaults[str(safe_mode)])
	var result: Array[int] = []
	if raw_values is Array:
		for button in raw_values:
			result.append(int(button))
	if result.size() != safe_mode:
		result.clear()
		for button in defaults[str(safe_mode)]:
			result.append(int(button))
	return result


func set_mode_joy_button(mode: int, lane_index: int, joy_button: int) -> void:
	if mode not in SUPPORTED_MODES or lane_index < 0 or lane_index >= mode:
		return
	var defaults: Dictionary = SettingsManager.DEFAULT_SETTINGS["controller_bindings"]
	var bindings: Dictionary = defaults.duplicate(true)
	if settings_manager != null:
		var stored = settings_manager.get_setting("controller_bindings", defaults)
		if stored is Dictionary:
			bindings = stored.duplicate(true)
	var mode_values: Array = bindings.get(str(mode), defaults[str(mode)]).duplicate()
	if mode_values.size() != mode:
		mode_values = defaults[str(mode)].duplicate()
	mode_values = _assign_unique_keycode(mode_values, lane_index, joy_button)
	bindings[str(mode)] = mode_values
	if settings_manager != null:
		settings_manager.set_setting("controller_bindings", bindings, false)
	refresh_lane_actions()
	controller_bindings_changed.emit(mode)


func get_controller_action_button(action_name: String) -> int:
	var defaults: Dictionary = SettingsManager.DEFAULT_SETTINGS["controller_bindings"]
	var default_actions: Dictionary = defaults["actions"]
	if action_name not in CONTROLLER_ACTIONS:
		return int(default_actions["confirm"])
	if settings_manager == null:
		return int(default_actions[action_name])
	var stored = settings_manager.get_setting("controller_bindings", defaults)
	if not (stored is Dictionary):
		return int(default_actions[action_name])
	var actions = stored.get("actions", default_actions)
	if not (actions is Dictionary):
		return int(default_actions[action_name])
	return int(actions.get(action_name, default_actions[action_name]))


func set_controller_action_button(action_name: String, joy_button: int) -> void:
	if action_name not in CONTROLLER_ACTIONS:
		return
	var defaults: Dictionary = SettingsManager.DEFAULT_SETTINGS["controller_bindings"]
	var bindings: Dictionary = defaults.duplicate(true)
	if settings_manager != null:
		var stored = settings_manager.get_setting("controller_bindings", defaults)
		if stored is Dictionary:
			bindings = stored.duplicate(true)
	var actions: Dictionary = bindings.get("actions", defaults["actions"]).duplicate(true)
	var previous_button := int(actions.get(action_name, defaults["actions"][action_name]))
	var duplicate_action := ""
	for candidate in CONTROLLER_ACTIONS:
		if candidate != action_name and int(actions.get(candidate, -1)) == joy_button:
			duplicate_action = candidate
			break
	if not duplicate_action.is_empty():
		actions[duplicate_action] = previous_button
	actions[action_name] = joy_button
	bindings["actions"] = actions
	if settings_manager != null:
		settings_manager.set_setting("controller_bindings", bindings, false)
	_refresh_controller_ui_actions()
	controller_bindings_changed.emit(0)


func reset_controller_bindings(mode: int = 0, include_actions: bool = false) -> void:
	if settings_manager == null:
		return
	var defaults: Dictionary = SettingsManager.DEFAULT_SETTINGS["controller_bindings"]
	var bindings = settings_manager.get_setting("controller_bindings", defaults)
	if not (bindings is Dictionary):
		bindings = defaults.duplicate(true)
	else:
		bindings = bindings.duplicate(true)
	if mode in SUPPORTED_MODES:
		bindings[str(mode)] = defaults[str(mode)].duplicate()
	else:
		for supported_mode in SUPPORTED_MODES:
			bindings[str(supported_mode)] = defaults[str(supported_mode)].duplicate()
	if include_actions:
		bindings["actions"] = defaults["actions"].duplicate(true)
	settings_manager.set_setting("controller_bindings", bindings, false)
	refresh_lane_actions()
	_refresh_controller_ui_actions()
	controller_bindings_changed.emit(mode)


func controller_event_matches(event: InputEvent, action_name: String) -> bool:
	return (
		event is InputEventJoypadButton
		and event.pressed
		and int(event.button_index) == get_controller_action_button(action_name)
	)


func get_controller_action_label(action_name: String, family: String = "auto") -> String:
	return get_controller_button_label(get_controller_action_button(action_name), family)


func get_lane_input_label(mode: int, lane_index: int, keycode: int) -> String:
	if using_controller:
		var buttons := get_mode_joy_buttons(mode)
		if lane_index >= 0 and lane_index < buttons.size():
			return get_controller_button_label(buttons[lane_index])
	return get_key_label(keycode)


func get_controller_layout_text(mode: int, family: String = "auto") -> String:
	var labels: PackedStringArray = []
	for button in get_mode_joy_buttons(mode):
		labels.append(get_controller_button_label(button, family))
	return "  ".join(labels)


func get_controller_button_label(button: int, family: String = "auto") -> String:
	var resolved_family := family
	if resolved_family == "auto":
		resolved_family = "playstation" if is_playstation_controller() else "xbox"
	match button:
		JOY_BUTTON_DPAD_LEFT:
			return "←"
		JOY_BUTTON_DPAD_UP:
			return "↑"
		JOY_BUTTON_DPAD_RIGHT:
			return "→"
		JOY_BUTTON_DPAD_DOWN:
			return "↓"
		JOY_BUTTON_LEFT_SHOULDER:
			return "L1" if resolved_family == "playstation" else "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "R1" if resolved_family == "playstation" else "RB"
		JOY_BUTTON_A:
			return "CROSS" if resolved_family == "playstation" else "A"
		JOY_BUTTON_B:
			return "CIR" if resolved_family == "playstation" else "B"
		JOY_BUTTON_X:
			return "SQR" if resolved_family == "playstation" else "X"
		JOY_BUTTON_Y:
			return "TRI" if resolved_family == "playstation" else "Y"
		JOY_BUTTON_START:
			return "OPTIONS" if resolved_family == "playstation" else "MENU"
		JOY_BUTTON_BACK:
			return "SHARE" if resolved_family == "playstation" else "VIEW"
		JOY_BUTTON_LEFT_STICK:
			return "L3" if resolved_family == "playstation" else "LS"
		JOY_BUTTON_RIGHT_STICK:
			return "R3" if resolved_family == "playstation" else "RS"
	return "BTN"


func get_controller_name() -> String:
	var device := active_controller_device
	var connected := Input.get_connected_joypads()
	if device not in connected and not connected.is_empty():
		device = connected[0]
	if device < 0:
		return ""
	return Input.get_joy_name(device)


func is_playstation_controller(device: int = -1) -> bool:
	var controller_name := ""
	if device >= 0:
		controller_name = Input.get_joy_name(device)
	else:
		controller_name = get_controller_name()
	var normalized := controller_name.to_lower()
	return (
		"playstation" in normalized
		or "dualshock" in normalized
		or "dualsense" in normalized
		or "sony" in normalized
		or "ps4" in normalized
		or "ps5" in normalized
	)


func get_key_label(keycode: int) -> String:
	var label := OS.get_keycode_string(keycode)
	if label.is_empty():
		return "?"
	match label.to_lower():
		"semicolon":
			return ";"
		"apostrophe":
			return "'"
		"comma":
			return ","
		"period":
			return "."
		"slash":
			return "/"
		"backslash":
			return "\\"
		"bracketleft", "bracket left":
			return "["
		"bracketright", "bracket right":
			return "]"
		"minus":
			return "-"
		"equal":
			return "="
		"space":
			return "SPC"
		"backspace":
			return "BKSP"
		"pageup", "page up":
			return "PG↑"
		"pagedown", "page down":
			return "PG↓"
	return label.to_upper()


func _on_setting_changed(key: String, _value) -> void:
	if key == "lane_bindings":
		refresh_lane_actions()
	elif key == "controller_bindings":
		refresh_lane_actions()
		_refresh_controller_ui_actions()


func _on_settings_reset() -> void:
	refresh_lane_actions()
	_refresh_controller_ui_actions()


func _ensure_controller_ui_actions() -> void:
	_refresh_controller_ui_actions()
	_ensure_joy_button_action(&"ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_joy_button_action(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_joy_button_action(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_joy_button_action(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy_axis_action(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis_action(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_ensure_joy_axis_action(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis_action(&"ui_right", JOY_AXIS_LEFT_X, 1.0)


func _refresh_controller_ui_actions() -> void:
	_replace_joy_button_action(&"ui_accept", get_controller_action_button("confirm"))
	_replace_joy_button_action(&"ui_cancel", get_controller_action_button("back"))


func _replace_joy_button_action(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton:
			InputMap.action_erase_event(action, existing)
	var joy_event := InputEventJoypadButton.new()
	joy_event.device = -1
	joy_event.button_index = button
	InputMap.action_add_event(action, joy_event)


func _ensure_joy_button_action(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and int(existing.button_index) == button:
			return
	var joy_event := InputEventJoypadButton.new()
	joy_event.device = -1
	joy_event.button_index = button
	InputMap.action_add_event(action, joy_event)


func _ensure_joy_axis_action(action: StringName, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if (
			existing is InputEventJoypadMotion
			and int(existing.axis) == axis
			and signf(existing.axis_value) == signf(axis_value)
		):
			return
	var joy_event := InputEventJoypadMotion.new()
	joy_event.device = -1
	joy_event.axis = axis
	joy_event.axis_value = axis_value
	InputMap.action_add_event(action, joy_event)


func _set_input_device(controller_active: bool, device: int = -1) -> void:
	if controller_active and device >= 0:
		active_controller_device = device
	if using_controller == controller_active:
		return
	using_controller = controller_active
	input_device_changed.emit(using_controller)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		active_controller_device = device
	elif active_controller_device == device:
		active_controller_device = -1
		if using_controller:
			_set_input_device(false)
	controller_connection_changed.emit(connected, device)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_set_input_device(false)
		match event.keycode:
			KEY_ESCAPE:
				emit_signal("button_pressed", "back")
			KEY_ENTER, KEY_KP_ENTER:
				emit_signal("button_pressed", "confirm")
			KEY_UP:
				emit_signal("button_pressed", "up")
			KEY_DOWN:
				emit_signal("button_pressed", "down")
			KEY_LEFT:
				emit_signal("button_pressed", "left")
			KEY_RIGHT:
				emit_signal("button_pressed", "right")
	elif event is InputEventJoypadButton and event.pressed:
		_set_input_device(true, event.device)
		if controller_event_matches(event, "confirm"):
			button_pressed.emit("confirm")
		elif controller_event_matches(event, "back"):
			button_pressed.emit("back")
		elif controller_event_matches(event, "pause"):
			button_pressed.emit("pause")
		else:
			match event.button_index:
				JOY_BUTTON_DPAD_UP:
					button_pressed.emit("up")
				JOY_BUTTON_DPAD_DOWN:
					button_pressed.emit("down")
				JOY_BUTTON_DPAD_LEFT:
					button_pressed.emit("left")
				JOY_BUTTON_DPAD_RIGHT:
					button_pressed.emit("right")
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.55:
		_set_input_device(true, event.device)
