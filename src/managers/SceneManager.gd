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

	if scene_container == null or not is_instance_valid(scene_container):
		push_error("No hay un contenedor válido para cargar la escena: %s" % scene_name)
		return

	var scene_path: String = SCENES[scene_name]
	if not ResourceLoader.exists(scene_path):
		push_error("Archivo de escena no encontrado: %s" % scene_path)
		return

	var packed_scene := ResourceLoader.load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("No se pudo cargar la escena: %s" % scene_path)
		return

	var next_scene := packed_scene.instantiate()
	if next_scene == null:
		push_error("No se pudo crear la escena: %s" % scene_path)
		return

	var previous_scene := current_scene
	if previous_scene != null and is_instance_valid(previous_scene):
		if previous_scene.get_parent() == scene_container:
			scene_container.remove_child(previous_scene)

	scene_container.add_child(next_scene)
	if next_scene.get_parent() != scene_container:
		if previous_scene != null and is_instance_valid(previous_scene):
			scene_container.add_child(previous_scene)
		next_scene.queue_free()
		push_error("No se pudo insertar la escena en su contenedor: %s" % scene_path)
		return

	current_scene = next_scene
	current_scene_name = scene_name

	if previous_scene != null and is_instance_valid(previous_scene):
		previous_scene.queue_free()

	scene_loaded.emit(scene_name)
