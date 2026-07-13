extends Node

class_name GameManager

var is_playing: bool = false
var current_song: String = ""


func _ready() -> void:
	pass


func start_song(song_path: String) -> void:
	current_song = song_path
	is_playing = true


func stop_song() -> void:
	is_playing = false
	current_song = ""
