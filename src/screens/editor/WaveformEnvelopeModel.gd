extends RefCounted

class_name WaveformEnvelopeModel

const CACHE_VERSION := 1
const DEFAULT_CACHE_DIRECTORY := "user://aurora_editor/waveform_cache"
const MIN_BUCKET_COUNT := 1
const MAX_BUCKET_COUNT := 8192

var cache_directory := DEFAULT_CACHE_DIRECTORY

var _memory_cache: Dictionary = {}
var _memory_source_keys: Dictionary = {}


func _init(next_cache_directory: String = DEFAULT_CACHE_DIRECTORY) -> void:
	cache_directory = next_cache_directory.strip_edges()
	if cache_directory.is_empty():
		cache_directory = DEFAULT_CACHE_DIRECTORY
	while cache_directory.ends_with("/") or cache_directory.ends_with("\\"):
		cache_directory = cache_directory.left(-1)


func get_or_build(
	source_key: String,
	pcm_samples: Variant,
	channel_count: int = 1,
	requested_bucket_count: int = 512,
	sample_rate: int = 44100
) -> Dictionary:
	var validation_error := _validate_request(
		source_key,
		pcm_samples,
		channel_count,
		requested_bucket_count,
		sample_rate
	)
	if not validation_error.is_empty():
		return _invalid_result(source_key, validation_error)

	var sample_count := int(pcm_samples.size())
	var memory_key := _make_memory_key(
		source_key,
		sample_count,
		channel_count,
		requested_bucket_count,
		sample_rate
	)
	if _memory_cache.has(memory_key):
		var memory_result: Dictionary = _memory_cache[memory_key].duplicate(true)
		memory_result["from_cache"] = true
		memory_result["cache_layer"] = "memory"
		return memory_result

	var cached_result := _load_cache_document(
		source_key,
		sample_count,
		channel_count,
		requested_bucket_count,
		sample_rate
	)
	if bool(cached_result.get("valid", false)):
		cached_result["from_cache"] = true
		cached_result["cache_layer"] = "disk"
		_remember(memory_key, source_key, cached_result)
		return cached_result.duplicate(true)

	var envelope := build_envelope(
		source_key,
		pcm_samples,
		channel_count,
		requested_bucket_count,
		sample_rate
	)
	if not bool(envelope.get("valid", false)):
		return envelope

	var cache_error := _write_cache_document(
		source_key,
		sample_count,
		channel_count,
		requested_bucket_count,
		sample_rate,
		envelope
	)
	envelope["cache_saved"] = cache_error == OK
	envelope["cache_error"] = int(cache_error)
	envelope["from_cache"] = false
	envelope["cache_layer"] = "generated"
	_remember(memory_key, source_key, envelope)
	return envelope.duplicate(true)


func build_envelope(
	source_key: String,
	pcm_samples: Variant,
	channel_count: int = 1,
	requested_bucket_count: int = 512,
	sample_rate: int = 44100
) -> Dictionary:
	var validation_error := _validate_request(
		source_key,
		pcm_samples,
		channel_count,
		requested_bucket_count,
		sample_rate
	)
	if not validation_error.is_empty():
		return _invalid_result(source_key, validation_error)

	var sample_count := int(pcm_samples.size())
	var frame_count := floori(float(sample_count) / float(channel_count))
	var bucket_count := clampi(
		requested_bucket_count,
		MIN_BUCKET_COUNT,
		mini(MAX_BUCKET_COUNT, frame_count)
	)
	var minimum_values: Array[float] = []
	var maximum_values: Array[float] = []
	var rms_values: Array[float] = []
	var invalid_sample_count := 0

	for bucket_index in range(bucket_count):
		var start_frame := floori(
			float(bucket_index) * float(frame_count) / float(bucket_count)
		)
		var end_frame := ceili(
			float(bucket_index + 1) * float(frame_count) / float(bucket_count)
		)
		end_frame = clampi(end_frame, start_frame + 1, frame_count)
		var minimum_sample := INF
		var maximum_sample := -INF
		var squared_sample_total := 0.0
		var bucket_sample_count := 0
		for frame_index in range(start_frame, end_frame):
			for channel_index in range(channel_count):
				var sample_index := frame_index * channel_count + channel_index
				var sample := float(pcm_samples[sample_index])
				if is_nan(sample) or is_inf(sample):
					sample = 0.0
					invalid_sample_count += 1
				minimum_sample = minf(minimum_sample, sample)
				maximum_sample = maxf(maximum_sample, sample)
				squared_sample_total += sample * sample
				bucket_sample_count += 1
		minimum_values.append(minimum_sample)
		maximum_values.append(maximum_sample)
		rms_values.append(
			sqrt(squared_sample_total / maxf(float(bucket_sample_count), 1.0))
		)

	return {
		"valid": true,
		"source_key": source_key,
		"sample_count": sample_count,
		"frame_count": frame_count,
		"channel_count": channel_count,
		"sample_rate": sample_rate,
		"duration_seconds": snappedf(
			float(frame_count) / float(sample_rate),
			0.000001
		),
		"requested_bucket_count": requested_bucket_count,
		"bucket_count": bucket_count,
		"frames_per_bucket": float(frame_count) / float(bucket_count),
		"minimums": minimum_values,
		"maximums": maximum_values,
		"rms": rms_values,
		"invalid_sample_count": invalid_sample_count,
		"from_cache": false,
		"cache_layer": "none",
		"cache_saved": false,
		"cache_error": int(OK),
	}


func invalidate_source(source_key: String) -> Error:
	var memory_keys_to_remove: Array[String] = []
	for memory_key in _memory_source_keys:
		if str(_memory_source_keys[memory_key]) == source_key:
			memory_keys_to_remove.append(str(memory_key))
	for memory_key in memory_keys_to_remove:
		_memory_cache.erase(memory_key)
		_memory_source_keys.erase(memory_key)

	var cache_path := get_cache_path_for_source(source_key)
	var result := _remove_file(cache_path)
	var backup_error := _remove_file(cache_path + ".bak")
	if result == OK:
		result = backup_error
	return result


func clear_memory_cache() -> void:
	_memory_cache.clear()
	_memory_source_keys.clear()


func get_cache_path_for_source(source_key: String) -> String:
	return "%s/%s.waveform.json" % [cache_directory, source_key.sha256_text()]


func _remember(memory_key: String, source_key: String, envelope: Dictionary) -> void:
	_memory_cache[memory_key] = envelope.duplicate(true)
	_memory_source_keys[memory_key] = source_key


func _load_cache_document(
	source_key: String,
	sample_count: int,
	channel_count: int,
	requested_bucket_count: int,
	sample_rate: int
) -> Dictionary:
	var path := get_cache_path_for_source(source_key)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = parser.data
	if not (parsed is Dictionary):
		return {}
	var document: Dictionary = parsed
	if (
		int(document.get("version", 0)) != CACHE_VERSION
		or str(document.get("source_key", "")) != source_key
		or int(document.get("sample_count", -1)) != sample_count
		or int(document.get("channel_count", -1)) != channel_count
		or int(document.get("requested_bucket_count", -1)) != requested_bucket_count
		or int(document.get("sample_rate", -1)) != sample_rate
		or not (document.get("envelope", null) is Dictionary)
	):
		return {}
	var envelope: Dictionary = document["envelope"]
	if not _is_valid_envelope(envelope):
		return {}
	envelope["cache_saved"] = true
	envelope["cache_error"] = int(OK)
	return envelope


func _write_cache_document(
	source_key: String,
	sample_count: int,
	channel_count: int,
	requested_bucket_count: int,
	sample_rate: int,
	envelope: Dictionary
) -> Error:
	var clean_envelope := envelope.duplicate(true)
	clean_envelope.erase("from_cache")
	clean_envelope.erase("cache_layer")
	clean_envelope.erase("cache_saved")
	clean_envelope.erase("cache_error")
	var document := {
		"version": CACHE_VERSION,
		"source_key": source_key,
		"sample_count": sample_count,
		"channel_count": channel_count,
		"requested_bucket_count": requested_bucket_count,
		"sample_rate": sample_rate,
		"envelope": clean_envelope,
	}
	return _write_json_atomically(get_cache_path_for_source(source_key), document)


func _write_json_atomically(target_path: String, document: Dictionary) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(
		_absolute_path(target_path.get_base_dir())
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error

	var temporary_path := "%s.tmp.%d.%d" % [
		target_path,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]
	var backup_path := target_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document))
	file.flush()
	file.close()

	var had_target := FileAccess.file_exists(target_path)
	if had_target:
		var stale_backup_error := _remove_file(backup_path)
		if stale_backup_error != OK:
			_remove_file(temporary_path)
			return stale_backup_error
		var backup_error := _rename_file(target_path, backup_path)
		if backup_error != OK:
			_remove_file(temporary_path)
			return backup_error

	var publish_error := _rename_file(temporary_path, target_path)
	if publish_error != OK:
		_remove_file(temporary_path)
		if had_target and FileAccess.file_exists(backup_path):
			_rename_file(backup_path, target_path)
		return publish_error

	_remove_file(backup_path)
	return OK


func _validate_request(
	source_key: String,
	pcm_samples: Variant,
	channel_count: int,
	requested_bucket_count: int,
	sample_rate: int
) -> String:
	if source_key.strip_edges().is_empty():
		return "missing_source_key"
	if not (
		pcm_samples is Array
		or pcm_samples is PackedFloat32Array
		or pcm_samples is PackedFloat64Array
	):
		return "unsupported_pcm_samples"
	if channel_count <= 0:
		return "invalid_channel_count"
	if sample_rate <= 0:
		return "invalid_sample_rate"
	if requested_bucket_count <= 0:
		return "invalid_bucket_count"
	if int(pcm_samples.size()) < channel_count:
		return "insufficient_pcm_samples"
	return ""


func _is_valid_envelope(envelope: Dictionary) -> bool:
	var bucket_count := int(envelope.get("bucket_count", 0))
	return (
		bool(envelope.get("valid", false))
		and bucket_count > 0
		and envelope.get("minimums", null) is Array
		and envelope.get("maximums", null) is Array
		and envelope.get("rms", null) is Array
		and (envelope["minimums"] as Array).size() == bucket_count
		and (envelope["maximums"] as Array).size() == bucket_count
		and (envelope["rms"] as Array).size() == bucket_count
	)


func _make_memory_key(
	source_key: String,
	sample_count: int,
	channel_count: int,
	requested_bucket_count: int,
	sample_rate: int
) -> String:
	return JSON.stringify(
		[
			source_key,
			sample_count,
			channel_count,
			requested_bucket_count,
			sample_rate,
		]
	).sha256_text()


func _invalid_result(source_key: String, error: String) -> Dictionary:
	return {
		"valid": false,
		"source_key": source_key,
		"error": error,
		"from_cache": false,
		"cache_saved": false,
	}


func _remove_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(_absolute_path(path))


func _rename_file(source_path: String, target_path: String) -> Error:
	return DirAccess.rename_absolute(
		_absolute_path(source_path),
		_absolute_path(target_path)
	)


func _absolute_path(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path(path)
