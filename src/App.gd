extends Node

class_name App

const SINGLE_INSTANCE_PORT := 47889

var _instance_lock_server: TCPServer


func _enter_tree() -> void:
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return
	_instance_lock_server = TCPServer.new()
	if _instance_lock_server.listen(SINGLE_INSTANCE_PORT, "127.0.0.1") != OK:
		_instance_lock_server = null
		get_tree().quit()


func _ready() -> void:
	pass


func _exit_tree() -> void:
	if _instance_lock_server != null:
		_instance_lock_server.stop()
		_instance_lock_server = null
