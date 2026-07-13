extends Node

class_name SceneManager

const SCENES = {
	"main_menu": "res://src/screens/MainMenu.tscn",
	"song_select": "res://src/screens/SongSelect.tscn",
	"gameplay": "res://src/screens/Gameplay.tscn",
	"results": "res://src/screens/Results.tscn",
	"editor": "res://src/screens/Editor.tscn",
	"settings": "res://src/screens/Settings.tscn",
}

var current_scene: Node = null
var scene_container: Node = null


func _ready() -> void:
	scene_container = get_parent()
	load_scene("main_menu")


func load_scene(scene_name: String) -> void:
	if not SCENES.has(scene_name):
		push_error("Escena no encontrada: %s" % scene_name)
		return
	
	if current_scene:
		current_scene.queue_free()
	
	var scene_path = SCENES[scene_name]
	var scene = load(scene_path).instantiate()
	scene_container.add_child(scene)
	current_scene = scene
