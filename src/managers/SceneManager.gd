extends Node

class_name SceneManager

signal scene_loaded(scene_name: String)

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
var current_scene_name := ""


func _ready() -> void:
	var app := get_tree().current_scene
	if app and app.has_node("CanvasLayer/ScreenContainer"):
		scene_container = app.get_node("CanvasLayer/ScreenContainer")
	else:
		scene_container = get_parent()
	call_deferred("load_scene", "main_menu")


func load_scene(scene_name: String) -> void:
	if not SCENES.has(scene_name):
		push_error("Escena no encontrada: %s" % scene_name)
		return

	if current_scene:
		scene_container.remove_child(current_scene)
		current_scene.queue_free()
		current_scene = null

	var scene_path = SCENES[scene_name]
	if not ResourceLoader.exists(scene_path):
		push_error("Archivo de escena no encontrado: %s" % scene_path)
		return

	var scene = load(scene_path).instantiate()
	scene_container.add_child(scene)
	current_scene = scene
	current_scene_name = scene_name
	scene_loaded.emit(scene_name)
