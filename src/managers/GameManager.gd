extends Node

class_name GameManager

var is_playing := false
var current_song: SongData
var current_chart: ChartData
var last_result: Dictionary = {}
var editor_test_active := false
var editor_test_project_path := ""
var requested_editor_project_path := ""


func start_song(song: SongData, chart: ChartData) -> bool:
	if not can_start_song(song, chart):
		stop_song()
		return false
	current_song = song
	current_chart = chart
	is_playing = true
	last_result.clear()
	editor_test_active = false
	editor_test_project_path = ""
	return true


func start_editor_test(song: SongData, chart: ChartData, project_path: String) -> bool:
	if not start_song(song, chart):
		return false
	editor_test_active = true
	editor_test_project_path = project_path
	return true


func can_start_song(song: SongData, chart: ChartData) -> bool:
	if song == null or chart == null:
		return false
	if not chart.chart_path.is_empty() and not chart.has_valid_file_chart():
		return false
	return not chart.load_notes(song.bpm, song.duration_seconds).is_empty()


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


func request_editor_project(project_path: String) -> void:
	requested_editor_project_path = project_path


func take_requested_editor_project_path() -> String:
	var project_path := requested_editor_project_path
	requested_editor_project_path = ""
	return project_path
