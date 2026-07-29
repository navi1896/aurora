extends Node

class_name SongManager

const SONGS_DIRECTORY := "res://songs"
const EDITOR_DIRECTORY := "user://aurora_editor"
const PACKAGES_DIRECTORY := "user://aurora_packages"
const PACKAGE_SERVICE_TYPE := preload(
	"res://src/packages/SongPackageService.gd"
)

var songs: Array[SongData] = []
var package_roots_by_song_id: Dictionary = {}
var package_media_by_song_id: Dictionary = {}
var package_service = PACKAGE_SERVICE_TYPE.new()


func _ready() -> void:
	load_songs()


func load_songs() -> void:
	# Song resources remain editable in Godot and can be grouped in folders.
	songs.clear()
	package_roots_by_song_id.clear()
	package_media_by_song_id.clear()
	_scan_directory(SONGS_DIRECTORY)
	_scan_editor_directory(EDITOR_DIRECTORY)
	_scan_package_directory(PACKAGES_DIRECTORY)
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


func import_song_package(package_path: String) -> Dictionary:
	var inspection: Dictionary = package_service.validate_package_manifest(
		package_path
	)
	if not bool(inspection.get("ok", false)):
		return inspection
	var manifest: Dictionary = inspection.get("manifest", {})
	var package_id := str(
		manifest.get("package_id", "")
	).strip_edges()
	var destination := PACKAGES_DIRECTORY.path_join(package_id)
	var result: Dictionary = package_service.import_package(
		package_path,
		destination
	)
	if not bool(result.get("ok", false)):
		return result
	load_songs()
	result["song_id"] = "package_%s" % package_id
	result["package_root"] = destination
	return result


func _scan_package_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if (
			not entry_name.begins_with(".")
			and directory.current_is_dir()
			and not entry_name.ends_with(
				PACKAGE_SERVICE_TYPE.IMPORT_TEMP_SUFFIX
			)
		):
			_load_package_staging(
				directory_path.path_join(entry_name)
			)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _load_package_staging(package_root: String) -> void:
	var validation: Dictionary = package_service.validate_staging(
		package_root,
		false
	)
	if not bool(validation.get("ok", false)):
		return
	var manifest: Dictionary = validation.get("manifest", {})
	var package_id := str(
		manifest.get("package_id", "")
	).strip_edges()
	var song_document: Dictionary = manifest.get("song", {})
	var song_id := "package_%s" % package_id
	if package_roots_by_song_id.has(song_id):
		return

	var charts: Array[ChartData] = []
	for chart_value in song_document.get("charts", []):
		if not (chart_value is Dictionary):
			return
		var chart_document: Dictionary = chart_value
		var chart := ChartData.new()
		chart.key_count = int(chart_document.get("key_count", 4))
		chart.difficulty_name = str(
			chart_document.get("difficulty", "NORMAL")
		).to_upper()
		chart.difficulty_level = clampi(
			int(chart_document.get("difficulty_level", 4)),
			1,
			20
		)
		chart.chart_path = package_root.path_join(
			str(chart_document.get("path", ""))
		)
		if not chart.has_valid_file_chart():
			return
		charts.append(chart)
	if charts.is_empty():
		return

	var song := SongData.new()
	song.song_id = StringName(song_id)
	song.title = str(song_document.get("title", "Paquete Aurora"))
	song.artist = str(song_document.get("artist", "Aurora Creator"))
	song.bpm = clampf(
		float(song_document.get("bpm", 128.0)),
		1.0,
		400.0
	)
	song.duration_seconds = maxf(
		float(song_document.get("duration_seconds", 0.0)),
		0.0
	)
	song.preview_start_seconds = clampf(
		float(song_document.get("preview_start_seconds", 0.0)),
		0.0,
		song.duration_seconds
	)
	song.preview_duration_seconds = clampf(
		float(song_document.get("preview_duration_seconds", 15.0)),
		1.0,
		120.0
	)
	song.background_video_start_seconds = maxf(
		float(
			song_document.get(
				"background_video_start_seconds",
				0.0
			)
		),
		0.0
	)
	song.charts = charts

	var media_document: Dictionary = song_document.get("media", {})
	var media_paths := {
		"audio_path": _package_media_path(
			package_root,
			media_document,
			"audio"
		),
		"video_path": _package_media_path(
			package_root,
			media_document,
			"video"
		),
		"cover_path": _package_media_path(
			package_root,
			media_document,
			"cover"
		),
	}
	package_roots_by_song_id[song_id] = package_root
	package_media_by_song_id[song_id] = media_paths
	songs.append(song)


func _package_media_path(
	package_root: String,
	media_document: Dictionary,
	media_kind: String
) -> String:
	if not media_document.has(media_kind):
		return ""
	var descriptor_value: Variant = media_document.get(media_kind)
	if not (descriptor_value is Dictionary):
		return ""
	var descriptor: Dictionary = descriptor_value
	return package_root.path_join(str(descriptor.get("path", "")))


func has_available_media(song: SongData) -> bool:
	if song == null:
		return false
	if song.audio != null or song.background_video != null:
		return true
	var media: Dictionary = package_media_by_song_id.get(
		str(song.song_id),
		{}
	)
	return (
		not str(media.get("audio_path", "")).is_empty()
		or not str(media.get("video_path", "")).is_empty()
	)


func ensure_song_cover_loaded(song: SongData) -> void:
	if song == null or song.cover != null:
		return
	var media: Dictionary = package_media_by_song_id.get(
		str(song.song_id),
		{}
	)
	var cover_path := str(media.get("cover_path", ""))
	if cover_path.is_empty() or not FileAccess.file_exists(cover_path):
		return
	var image := Image.load_from_file(
		ProjectSettings.globalize_path(cover_path)
	)
	if image != null and not image.is_empty():
		song.cover = ImageTexture.create_from_image(image)


func ensure_song_media_loaded(song: SongData) -> bool:
	if song == null:
		return false
	ensure_song_cover_loaded(song)
	var media: Dictionary = package_media_by_song_id.get(
		str(song.song_id),
		{}
	)
	if media.is_empty():
		return song.audio != null or song.background_video != null
	if song.audio == null:
		var audio_path := str(media.get("audio_path", ""))
		if not audio_path.is_empty() and FileAccess.file_exists(audio_path):
			song.audio = _load_audio_stream(audio_path)
	if song.background_video == null:
		var video_path := str(media.get("video_path", ""))
		if not video_path.is_empty() and FileAccess.file_exists(video_path):
			var loaded_video := load(video_path)
			if loaded_video is VideoStream:
				song.background_video = loaded_video as VideoStream
	return song.audio != null or song.background_video != null


func release_unselected_package_media(selected_song: SongData) -> void:
	for candidate in songs:
		if (
			candidate == selected_song
			or not is_local_package_song(candidate)
		):
			continue
		candidate.audio = null
		candidate.background_video = null


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


func is_local_package_song(song: SongData) -> bool:
	if song == null:
		return false
	var package_root := str(
		package_roots_by_song_id.get(str(song.song_id), "")
	).simplify_path()
	if package_root.is_empty():
		return false
	var packages_absolute := _normalized_absolute_path(
		PACKAGES_DIRECTORY
	).trim_suffix("/")
	var package_absolute := _normalized_absolute_path(
		package_root
	).trim_suffix("/")
	return (
		package_absolute.begins_with(packages_absolute + "/")
		and package_absolute.get_base_dir() == packages_absolute
		and FileAccess.file_exists(
			package_root.path_join(
				PACKAGE_SERVICE_TYPE.MANIFEST_PATH
			)
		)
	)


func is_removable_local_song(song: SongData) -> bool:
	return is_editor_song(song) or is_local_package_song(song)


func move_editor_song_to_trash(song: SongData) -> Error:
	if not is_editor_song(song):
		return ERR_UNAUTHORIZED
	return _move_local_directory_to_trash(
		song.editor_project_path.get_base_dir().simplify_path(),
		EDITOR_DIRECTORY,
		"project.json",
		false
	)


func move_local_song_to_trash(song: SongData) -> Error:
	if is_editor_song(song):
		return move_editor_song_to_trash(song)
	if not is_local_package_song(song):
		return ERR_UNAUTHORIZED
	var package_root := str(
		package_roots_by_song_id.get(str(song.song_id), "")
	)
	return _move_local_directory_to_trash(
		package_root,
		PACKAGES_DIRECTORY,
		PACKAGE_SERVICE_TYPE.MANIFEST_PATH,
		true
	)


func _move_local_directory_to_trash(
	content_directory: String,
	allowed_root: String,
	required_file_name: String,
	require_immediate_child: bool
) -> Error:
	var content_absolute := _normalized_absolute_path(
		content_directory
	).trim_suffix("/")
	var root_absolute := _normalized_absolute_path(
		allowed_root
	).trim_suffix("/")
	if (
		content_absolute == root_absolute
		or not content_absolute.begins_with(root_absolute + "/")
		or (
			require_immediate_child
			and content_absolute.get_base_dir() != root_absolute
		)
		or not DirAccess.dir_exists_absolute(content_absolute)
		or not FileAccess.file_exists(
			content_directory.path_join(required_file_name)
		)
	):
		return ERR_INVALID_PARAMETER
	var move_error := OS.move_to_trash(content_absolute)
	if move_error == OK:
		load_songs()
	return move_error


func _normalized_absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(
		path
	).simplify_path().replace("\\", "/")


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
