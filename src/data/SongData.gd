extends Resource

class_name SongData

const COLLECTION_DJMAX_ARCHIVE := "djmax_archive"
const COLLECTION_AURORA_MIX := "aurora_mix"

@export var song_id: StringName
@export var package_version := "1.0.0"
@export var title := ""
@export var artist := ""
@export var collection_id := COLLECTION_AURORA_MIX
@export var cover: Texture2D
@export var audio: AudioStream
@export var background_video: VideoStream
@export_range(-18.0, 12.0, 0.5) var audio_gain_db := 0.0
@export_range(0.0, 3600.0, 0.1) var background_video_start_seconds := 0.0
@export_range(0.0, 3600.0, 1.0) var duration_seconds := 0.0
@export_range(1.0, 400.0, 0.1) var bpm := 120.0
@export_range(0.0, 3600.0, 0.1) var preview_start_seconds := 0.0
@export_range(1.0, 120.0, 0.1) var preview_duration_seconds := 15.0
@export var charts: Array[ChartData] = []
var editor_project_path := ""


static func resolve_collection_id(value: String, package_id: String = "") -> String:
	var normalized := value.strip_edges().to_lower().replace(" ", "_")
	if not normalized.is_empty():
		var identifier_pattern := RegEx.new()
		identifier_pattern.compile("^[a-z0-9][a-z0-9_-]{0,47}$")
		if identifier_pattern.search(normalized) != null:
			return normalized
	var normalized_package_id := package_id.strip_edges().to_lower()
	if normalized_package_id.begins_with("djmax-"):
		return COLLECTION_DJMAX_ARCHIVE
	return COLLECTION_AURORA_MIX


static func collection_label(value: String) -> String:
	match value.strip_edges().to_lower():
		COLLECTION_DJMAX_ARCHIVE:
			return "ARCHIVO DJMAX"
		COLLECTION_AURORA_MIX:
			return "AURORA MIX"
		_:
			return value.strip_edges().replace("_", " ").replace("-", " ").to_upper()


func get_duration_text() -> String:
	var total_seconds := maxi(0, roundi(duration_seconds))
	return "%02d:%02d" % [floori(float(total_seconds) / 60.0), total_seconds % 60]


func get_available_modes_text() -> String:
	var modes: PackedStringArray = []
	for chart in charts:
		modes.append(chart.get_mode_label())
	return "  ".join(modes)
