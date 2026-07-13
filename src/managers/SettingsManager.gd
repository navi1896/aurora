extends Node

class_name SettingsManager

var settings: Dictionary = {
	"language": "es",
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	# TODO: Cargar desde archivo de configuración
	pass


func save_settings() -> void:
	# TODO: Guardar a archivo de configuración
	pass


func get_setting(key: String, default = null):
	return settings.get(key, default)


func set_setting(key: String, value) -> void:
	settings[key] = value
