extends Node

class_name GameManager

const PERSONAL_RECORDS_PATH := "user://personal_records.json"
const PERSONAL_RECORDS_VERSION := 1

var is_playing := false
var current_song: SongData
var current_chart: ChartData
var last_result: Dictionary = {}
var last_record_update: Dictionary = {}
var personal_records: Dictionary = {}
var editor_test_active := false
var editor_test_project_path := ""
var requested_editor_project_path := ""


func _ready() -> void:
	_load_personal_records()


func start_song(song: SongData, chart: ChartData) -> bool:
	if not can_start_song(song, chart):
		stop_song()
		return false
	current_song = song
	current_chart = chart
	is_playing = true
	last_result.clear()
	last_record_update.clear()
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


func complete_song(result: Dictionary, save_personal_record: bool = true) -> void:
	last_result = result.duplicate(true)
	last_record_update.clear()
	if save_personal_record and not editor_test_active:
		last_record_update = record_personal_result(
			current_song,
			current_chart,
			last_result
		)
	is_playing = false


func stop_song() -> void:
	is_playing = false
	current_song = null
	current_chart = null
	last_result.clear()
	last_record_update.clear()
	editor_test_active = false
	editor_test_project_path = ""


func take_editor_test_project_path() -> String:
	var project_path := editor_test_project_path
	is_playing = false
	current_song = null
	current_chart = null
	last_result.clear()
	last_record_update.clear()
	editor_test_active = false
	editor_test_project_path = ""
	return project_path


func request_editor_project(project_path: String) -> void:
	requested_editor_project_path = project_path


func take_requested_editor_project_path() -> String:
	var project_path := requested_editor_project_path
	requested_editor_project_path = ""
	return project_path


func get_personal_record(song: SongData, chart: ChartData) -> Dictionary:
	var record_key := make_personal_record_key(song, chart)
	if record_key.is_empty():
		return {}
	var record_value = personal_records.get(record_key, {})
	return record_value.duplicate(true) if record_value is Dictionary else {}


func record_personal_result(
	song: SongData,
	chart: ChartData,
	result: Dictionary,
	persist: bool = true
) -> Dictionary:
	var record_key := make_personal_record_key(song, chart)
	if record_key.is_empty() or result.is_empty():
		return {}

	var previous := get_personal_record(song, chart)
	var score := maxi(int(result.get("score", 0)), 0)
	var accuracy := clampf(float(result.get("accuracy", 0.0)), 0.0, 100.0)
	var max_combo := maxi(int(result.get("max_combo", 0)), 0)
	var previous_score := int(previous.get("best_score", 0))
	var previous_accuracy := float(previous.get("best_accuracy", 0.0))
	var previous_combo := int(previous.get("best_max_combo", 0))
	var is_first_result := previous.is_empty()
	var is_new_score := is_first_result or score > previous_score
	var is_new_accuracy := is_first_result or accuracy > previous_accuracy + 0.0005
	var is_new_combo := is_first_result or max_combo > previous_combo
	var current_rank := get_rank(accuracy, int(result.get("miss", 0)))
	var previous_rank := str(previous.get("best_rank", ""))

	var record := {
		"best_score": maxi(previous_score, score),
		"best_accuracy": maxf(previous_accuracy, accuracy),
		"best_max_combo": maxi(previous_combo, max_combo),
		"best_rank": (
			current_rank
			if _rank_value(current_rank) > _rank_value(previous_rank)
			else previous_rank
		),
		"play_count": maxi(int(previous.get("play_count", 0)), 0) + 1,
		"last_played_unix": int(Time.get_unix_time_from_system()),
	}
	personal_records[record_key] = record
	if persist:
		_save_personal_records()
	return {
		"record_key": record_key,
		"record": record.duplicate(true),
		"previous": previous,
		"is_first_result": is_first_result,
		"is_new_score": is_new_score,
		"is_new_accuracy": is_new_accuracy,
		"is_new_combo": is_new_combo,
		"is_new_record": is_new_score or is_new_accuracy or is_new_combo,
	}


static func make_personal_record_key(song: SongData, chart: ChartData) -> String:
	if song == null or chart == null:
		return ""
	var song_id := str(song.song_id).strip_edges()
	if song_id.is_empty():
		return ""
	return "%s::%d|%s|%d" % [
		song_id,
		chart.key_count,
		chart.difficulty_name.strip_edges().to_upper(),
		chart.difficulty_level,
	]


static func get_rank(accuracy: float, misses: int) -> String:
	if accuracy >= 99.0 and misses == 0:
		return "S+"
	if accuracy >= 95.0:
		return "S"
	if accuracy >= 88.0:
		return "A"
	if accuracy >= 78.0:
		return "B"
	if accuracy >= 65.0:
		return "C"
	return "D"


static func _rank_value(rank: String) -> int:
	match rank:
		"S+":
			return 6
		"S":
			return 5
		"A":
			return 4
		"B":
			return 3
		"C":
			return 2
		"D":
			return 1
	return 0


func _load_personal_records() -> void:
	personal_records.clear()
	if not FileAccess.file_exists(PERSONAL_RECORDS_PATH):
		return
	var file := FileAccess.open(PERSONAL_RECORDS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var source = parsed.get("records", {})
	if not (source is Dictionary):
		return
	for raw_key in source.keys():
		var record_key := str(raw_key).strip_edges()
		var record_value = source[raw_key]
		if record_key.is_empty() or not (record_value is Dictionary):
			continue
		personal_records[record_key] = _normalize_personal_record(record_value)


func _save_personal_records() -> void:
	var file := FileAccess.open(PERSONAL_RECORDS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"version": PERSONAL_RECORDS_VERSION,
		"records": personal_records,
	}, "\t"))
	file.flush()


func _normalize_personal_record(record: Dictionary) -> Dictionary:
	return {
		"best_score": maxi(int(record.get("best_score", 0)), 0),
		"best_accuracy": clampf(
			float(record.get("best_accuracy", 0.0)),
			0.0,
			100.0
		),
		"best_max_combo": maxi(int(record.get("best_max_combo", 0)), 0),
		"best_rank": str(record.get("best_rank", "D")),
		"play_count": maxi(int(record.get("play_count", 0)), 0),
		"last_played_unix": maxi(int(record.get("last_played_unix", 0)), 0),
	}
