extends Control

class_name MainMenu

@onready var scene_manager: SceneManager = get_tree().root.get_node("App/SceneManager")

var buttons: Array[Button] = []
var selected_button: int = 0


func _ready() -> void:
	setup_ui()
	update_button_selection()


func setup_ui() -> void:
	var title = Label.new()
	title.text = "AURORA"
	title.anchor_left = 0.5
	title.anchor_top = 0.2
	title.offset_left = -50
	title.offset_top = -20
	add_child(title)
	
	var button_data = [
		{"text": "Jugar", "action": "play"},
		{"text": "Editor", "action": "editor"},
		{"text": "Configuración", "action": "settings"},
		{"text": "Salir", "action": "quit"},
	]
	
	var start_y = 300
	var button_height = 50
	var spacing = 20
	
	for i in range(button_data.size()):
		var btn = Button.new()
		btn.text = button_data[i]["text"]
		btn.custom_minimum_size = Vector2(200, button_height)
		btn.anchor_left = 0.5
		btn.anchor_top = 0.5
		btn.offset_left = -100
		btn.offset_top = start_y + (i * (button_height + spacing)) - 150
		btn.pressed.connect(_on_button_pressed.bind(button_data[i]["action"]))
		add_child(btn)
		buttons.append(btn)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				selected_button = max(0, selected_button - 1)
				update_button_selection()
				get_tree().root.set_input_as_handled()
			KEY_DOWN:
				selected_button = min(buttons.size() - 1, selected_button + 1)
				update_button_selection()
				get_tree().root.set_input_as_handled()
			KEY_ENTER:
				buttons[selected_button].emit_signal("pressed")
				get_tree().root.set_input_as_handled()


func update_button_selection() -> void:
	for i in range(buttons.size()):
		buttons[i].modulate = Color.WHITE if i == selected_button else Color.GRAY


func _on_button_pressed(action: String) -> void:
	match action:
		"play":
			scene_manager.load_scene("song_select")
		"editor":
			scene_manager.load_scene("editor")
		"settings":
			scene_manager.load_scene("settings")
		"quit":
			get_tree().quit()
