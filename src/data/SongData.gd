extends Resource

class_name SongData

@export var song_id: StringName
@export var package_version := "1.0.0"
@export var title := ""
@export var artist := ""
@export var cover: Texture2D
@export var audio: AudioStream
@export var background_video: VideoStream
@export_range(0.0, 3600.0, 0.1) var background_video_start_seconds := 0.0
@export_range(0.0, 3600.0, 1.0) var duration_seconds := 0.0
@export_range(1.0, 400.0, 0.1) var bpm := 120.0
@export_range(0.0, 3600.0, 0.1) var preview_start_seconds := 0.0
@export_range(1.0, 120.0, 0.1) var preview_duration_seconds := 15.0
@export var charts: Array[ChartData] = []
var editor_project_path := ""


func get_duration_text() -> String:
	var total_seconds := maxi(0, roundi(duration_seconds))
	return "%02d:%02d" % [floori(float(total_seconds) / 60.0), total_seconds % 60]


func get_available_modes_text() -> String:
	var modes: PackedStringArray = []
	for chart in charts:
		modes.append(chart.get_mode_label())
	return "  ".join(modes)
