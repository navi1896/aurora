extends Control

class_name MainMenu

@onready var main_buttons: MainMenuButtons = $MenuMargins/PageLayout/MenuBody/MainButtons
@onready var character_idle: CharacterIdleRig = (
	$MenuMargins/PageLayout/MenuBody/CharacterShowcase/IdleRig
)

var scene_manager: SceneManager


func _ready() -> void:
	# Connects presentation actions to the application's navigation layer.
	var app := get_tree().current_scene
	if app != null and app.has_node("Managers/SceneManager"):
		scene_manager = app.get_node("Managers/SceneManager")
	main_buttons.action_selected.connect(_on_menu_action_selected)
	main_buttons.focus_changed.connect(character_idle.trigger_selection_pulse)
	main_buttons.focus_default_button()


func _on_menu_action_selected(action: StringName) -> void:
	match action:
		&"play":
			_load_screen(&"song_select")
		&"settings":
			_load_screen(&"settings")
		&"editor":
			_load_screen(&"editor")
		&"quit":
			get_tree().quit()


func _load_screen(screen_name: StringName) -> void:
	if scene_manager != null:
		scene_manager.load_scene(String(screen_name))
