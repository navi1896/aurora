extends Node

class_name SongManager

var songs: Array = []


func _ready() -> void:
	load_songs()


func load_songs() -> void:
	# TODO: Implementar carga de canciones desde directorio
	pass


func get_song(index: int) -> Dictionary:
	if index < 0 or index >= songs.size():
		return {}
	return songs[index]


func get_all_songs() -> Array:
	return songs
