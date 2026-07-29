extends Node

class_name GameManager

var is_playing := false
var current_song: SongData
var current_chart: ChartData
var last_result: Dictionary = {}
var editor_test_active := false
var editor_test_project_path := ""


func start_song(song: SongData, chart: ChartData) -> void:
	current_song = song
	current_chart = chart
	is_playing = song != null and chart != null
	last_result.clear()
	editor_test_active = false
	editor_test_project_path = ""


func start_editor_test(song: SongData, chart: ChartData, project_path: String) -> void:
	start_song(song, chart)
	editor_test_active = true
	editor_test_project_path = project_path


func complete_song(result: Dictionary) -> void:
	last_result = result.duplicate(true)
	is_playing = false


func stop_song() -> void:
	is_playing = false
	current_song = null
	current_chart = null
	last_result.clear()
	editor_test_active = false
	editor_test_project_path = ""


func take_editor_test_project_path() -> String:
	var project_path := editor_test_project_path
	is_playing = false
	current_song = null
	current_chart = null
	last_result.clear()
	editor_test_active = false
	editor_test_project_path = ""
	return project_path
