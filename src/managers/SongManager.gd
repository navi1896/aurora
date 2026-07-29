extends Node

class_name SongManager

const SONGS_DIRECTORY := "res://songs"
const EDITOR_DIRECTORY := "user://aurora_editor"

var songs: Array[SongData] = []


func _ready() -> void:
	load_songs()


func load_songs() -> void:
	# Song resources remain editable in Godot and can be grouped in folders.
	songs.clear()
	_scan_directory(SONGS_DIRECTORY)
	_scan_editor_directory(EDITOR_DIRECTORY)
	songs.sort_custom(_sort_songs)


func _scan_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var resource_path := "%s/%s" % [directory_path, file_name]
			if directory.current_is_dir():
				_scan_directory(resource_path)
			elif file_name.get_extension().to_lower() == "tres":
				var resource := load(resource_path)
				if resource is SongData:
					songs.append(resource)
		file_name = directory.get_next()
	directory.list_dir_end()


func get_song(index: int) -> SongData:
	if index < 0 or index >= songs.size():
		return null
	return songs[index]


func get_all_songs() -> Array[SongData]:
	return songs


func _scan_editor_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var entry_path := "%s/%s" % [directory_path, file_name]
			if directory.current_is_dir():
				_scan_editor_directory(entry_path)
			elif file_name == "project.json":
				_load_editor_project(entry_path)
		file_name = directory.get_next()
	directory.list_dir_end()


func _load_editor_project(project_path: String) -> void:
	var file := FileAccess.open(project_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or str(parsed.get("type", "")) != "aurora_editor_project":
		return
	var metadata_value: Variant = parsed.get("metadata", {})
	var media_value: Variant = parsed.get("media", {})
	if not (metadata_value is Dictionary) or not (media_value is Dictionary):
		return
	var metadata: Dictionary = metadata_value
	var media: Dictionary = media_value
	var chart_path := str(parsed.get("chart_path", "")).strip_edges()
	if chart_path.is_empty() or not FileAccess.file_exists(chart_path):
		return

	var chart := ChartData.new()
	chart.key_count = int(metadata.get("key_count", 4))
	if chart.key_count not in [4, 6, 8]:
		chart.key_count = 4
	chart.difficulty_name = str(metadata.get("difficulty", "NORMAL")).to_upper()
	chart.difficulty_level = clampi(int(metadata.get("difficulty_level", 4)), 1, 20)
	chart.chart_path = chart_path
	if not chart.has_valid_file_chart():
		return

	var video_resource: VideoStream
	var video_path := str(media.get("video_path", "")).strip_edges()
	if not video_path.is_empty() and FileAccess.file_exists(video_path):
		var loaded_video := load(video_path)
		if loaded_video is VideoStream:
			video_resource = loaded_video as VideoStream

	var audio_resource: AudioStream
	var audio_path := str(media.get("audio_path", "")).strip_edges()
	if not audio_path.is_empty() and FileAccess.file_exists(audio_path):
		audio_resource = _load_audio_stream(audio_path)
	if video_resource == null and audio_resource == null:
		return

	var song := SongData.new()
	var folder_name := project_path.get_base_dir().get_file()
	song.song_id = StringName("editor_%s" % folder_name)
	song.title = str(metadata.get("title", "Nuevo nivel"))
	song.artist = str(metadata.get("artist", "Aurora Creator"))
	song.bpm = clampf(float(metadata.get("bpm", 128.0)), 1.0, 400.0)
	song.duration_seconds = maxf(float(metadata.get("duration_seconds", 0.0)), 0.0)
	song.background_video = video_resource
	song.audio = audio_resource
	song.editor_project_path = project_path
	song.charts = [chart]
	songs.append(song)


func is_editor_song(song: SongData) -> bool:
	if song == null or song.editor_project_path.is_empty():
		return false
	var project_path := song.editor_project_path.simplify_path()
	return (
		project_path.begins_with(EDITOR_DIRECTORY + "/")
		and project_path.get_file() == "project.json"
		and FileAccess.file_exists(project_path)
	)


func move_editor_song_to_trash(song: SongData) -> Error:
	if not is_editor_song(song):
		return ERR_UNAUTHORIZED
	var project_directory := song.editor_project_path.get_base_dir().simplify_path()
	var editor_root_absolute := ProjectSettings.globalize_path(EDITOR_DIRECTORY).simplify_path()
	var project_absolute := ProjectSettings.globalize_path(project_directory).simplify_path()
	var normalized_root := editor_root_absolute.replace("\\", "/").trim_suffix("/")
	var normalized_project := project_absolute.replace("\\", "/").trim_suffix("/")
	if (
		normalized_project == normalized_root
		or not normalized_project.begins_with(normalized_root + "/")
		or not DirAccess.dir_exists_absolute(project_absolute)
	):
		return ERR_INVALID_PARAMETER
	var move_error := OS.move_to_trash(project_absolute)
	if move_error == OK:
		load_songs()
	return move_error


func _load_audio_stream(path: String) -> AudioStream:
	if path.begins_with("res://"):
		var imported_resource := load(path)
		if imported_resource is AudioStream:
			return imported_resource as AudioStream
	var filesystem_path := ProjectSettings.globalize_path(path)
	match path.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_file(filesystem_path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(filesystem_path)
		"wav":
			return AudioStreamWAV.load_from_file(filesystem_path)
	return null


func _sort_songs(a: SongData, b: SongData) -> bool:
	return a.title.naturalnocasecmp_to(b.title) < 0
