extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app_scene := load("res://src/App.tscn") as PackedScene
	_expect(app_scene != null, "App.tscn se puede cargar")
	if app_scene == null:
		_finish()
		return

	var app := app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame

	var scene_manager := app.get_node("Managers/SceneManager") as SceneManager
	var input_manager := app.get_node("Managers/InputManager") as InputManager
	scene_manager.load_scene("settings")
	await process_frame
	await process_frame
	await process_frame

	var settings := scene_manager.current_scene as Settings
	_expect(settings != null, "Configuración abre")
	if settings == null:
		_finish()
		return

	var expected_focus := settings.category_buttons.get("general") as Button
	_expect(
		settings.get_viewport().gui_get_focus_owner() == expected_focus,
		"Configuración enfoca la categoría actual al entrar"
	)

	settings._show_category("controls")
	await process_frame
	var action_labels: Array[String] = []
	if settings.cabinet_columns.size() >= 3:
		_collect_button_labels(settings.cabinet_columns[2], action_labels)
	var actions_present := settings.cabinet_columns.size() == 3
	for action_name in InputManager.CONTROLLER_ACTIONS:
		actions_present = actions_present and (
			input_manager.get_controller_action_label(action_name) in action_labels
		)
	_expect(
		actions_present
		and settings.cabinet_column_scrolls.size() == 3
		and settings.cabinet_column_scrolls[2].get_global_rect().end.x
		<= settings.get_viewport_rect().end.x + 1.0,
		"Las acciones del mando aparecen dentro de la vista de controles"
	)

	var bindings_before := input_manager.get_mode_joy_buttons(4).duplicate()
	var capture_button := Button.new()
	settings.add_child(capture_button)
	settings._start_controller_lane_capture(0, capture_button)
	var back_event := InputEventJoypadButton.new()
	back_event.button_index = input_manager.get_controller_action_button("back")
	back_event.pressed = true
	settings._input(back_event)
	_expect(
		settings.capture_kind.is_empty()
		and input_manager.get_mode_joy_buttons(4) == bindings_before,
		"B/Circle cancela la captura sin reasignar el carril"
	)

	capture_button.queue_free()
	current_scene = null
	app.queue_free()
	await process_frame
	await process_frame
	_finish()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("SETTINGS ACCESSIBILITY TESTS PASSED")
		quit(0)
	else:
		print("SETTINGS ACCESSIBILITY TESTS FAILED: %s" % ", ".join(failures))
		quit(1)


func _collect_button_labels(node: Node, labels: Array[String]) -> void:
	if node is Button:
		labels.append((node as Button).text)
	for child in node.get_children():
		_collect_button_labels(child, labels)
