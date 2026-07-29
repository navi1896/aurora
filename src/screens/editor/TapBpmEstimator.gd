extends RefCounted

class_name TapBpmEstimator

const MAX_TAPS := 64
const MIN_INTERVAL_SECONDS := 0.15
const PAUSE_INTERVAL_SECONDS := 2.5
const OUTLIER_ABSOLUTE_TOLERANCE := 0.05
const OUTLIER_RELATIVE_TOLERANCE := 0.20
const MIN_SUGGESTED_BPM := 20.0
const MAX_SUGGESTED_BPM := 400.0

var _tap_times: Array[float] = []


func clear() -> void:
	_tap_times.clear()


func register_tap(timestamp_seconds: float) -> bool:
	if is_nan(timestamp_seconds) or is_inf(timestamp_seconds) or timestamp_seconds < 0.0:
		return false
	if not _tap_times.is_empty() and timestamp_seconds <= _tap_times.back():
		return false
	_tap_times.append(timestamp_seconds)
	while _tap_times.size() > MAX_TAPS:
		_tap_times.pop_front()
	return true


func get_tap_count() -> int:
	return _tap_times.size()


func get_tap_times() -> Array[float]:
	return _tap_times.duplicate()


func estimate() -> Dictionary:
	if _tap_times.size() < 2:
		return _empty_result()

	var candidate_intervals: Array[float] = []
	var pause_count := 0
	var invalid_interval_count := 0
	for index in range(1, _tap_times.size()):
		var interval := _tap_times[index] - _tap_times[index - 1]
		if interval > PAUSE_INTERVAL_SECONDS:
			pause_count += 1
		elif interval < MIN_INTERVAL_SECONDS:
			invalid_interval_count += 1
		else:
			candidate_intervals.append(interval)

	if candidate_intervals.is_empty():
		var no_candidate_result := _empty_result()
		no_candidate_result["pause_count"] = pause_count
		no_candidate_result["invalid_interval_count"] = invalid_interval_count
		return no_candidate_result

	var median_interval := _median(candidate_intervals)
	var tolerance := maxf(
		OUTLIER_ABSOLUTE_TOLERANCE,
		median_interval * OUTLIER_RELATIVE_TOLERANCE
	)
	var used_intervals: Array[float] = []
	for interval in candidate_intervals:
		if absf(interval - median_interval) <= tolerance:
			used_intervals.append(interval)

	if used_intervals.is_empty():
		used_intervals.append(median_interval)

	var mean_interval := _mean(used_intervals)
	var standard_deviation := _standard_deviation(used_intervals, mean_interval)
	var primary_bpm := 60.0 / mean_interval
	var stability := clampf(
		1.0 - standard_deviation / maxf(mean_interval * 0.12, 0.0001),
		0.0,
		1.0
	)
	var sample_confidence := clampf(float(used_intervals.size()) / 7.0, 0.15, 1.0)
	var interval_coverage := (
		float(used_intervals.size()) / float(candidate_intervals.size())
	)
	var confidence := snappedf(
		stability * sample_confidence * interval_coverage,
		0.001
	)
	primary_bpm = snappedf(primary_bpm, 0.01)

	return {
		"valid": true,
		"primary_bpm": primary_bpm,
		"confidence": confidence,
		"tap_count": _tap_times.size(),
		"interval_count": _tap_times.size() - 1,
		"used_interval_count": used_intervals.size(),
		"discarded_outlier_count": (
			candidate_intervals.size() - used_intervals.size()
		),
		"pause_count": pause_count,
		"invalid_interval_count": invalid_interval_count,
		"median_interval_seconds": snappedf(median_interval, 0.0001),
		"mean_interval_seconds": snappedf(mean_interval, 0.0001),
		"interval_standard_deviation": snappedf(standard_deviation, 0.0001),
		"suggestions": _build_suggestions(primary_bpm),
		"requires_confirmation": true,
	}


func _build_suggestions(primary_bpm: float) -> Array[Dictionary]:
	var suggestions: Array[Dictionary] = [
		{
			"bpm": snappedf(primary_bpm, 0.01),
			"relationship": "tapped",
		},
	]
	var half_time := primary_bpm * 0.5
	if half_time >= MIN_SUGGESTED_BPM:
		suggestions.append(
			{
				"bpm": snappedf(half_time, 0.01),
				"relationship": "half_time",
			}
		)
	var double_time := primary_bpm * 2.0
	if double_time <= MAX_SUGGESTED_BPM:
		suggestions.append(
			{
				"bpm": snappedf(double_time, 0.01),
				"relationship": "double_time",
			}
		)
	return suggestions


func _empty_result() -> Dictionary:
	return {
		"valid": false,
		"primary_bpm": 0.0,
		"confidence": 0.0,
		"tap_count": _tap_times.size(),
		"interval_count": maxi(_tap_times.size() - 1, 0),
		"used_interval_count": 0,
		"discarded_outlier_count": 0,
		"pause_count": 0,
		"invalid_interval_count": 0,
		"median_interval_seconds": 0.0,
		"mean_interval_seconds": 0.0,
		"interval_standard_deviation": 0.0,
		"suggestions": [],
		"requires_confirmation": true,
	}


func _median(values: Array[float]) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	var middle := floori(float(ordered.size()) / 2.0)
	if ordered.size() % 2 == 1:
		return ordered[middle]
	return (ordered[middle - 1] + ordered[middle]) * 0.5


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(float(values.size()), 1.0)


func _standard_deviation(values: Array[float], mean_value: float) -> float:
	if values.size() < 2:
		return 0.0
	var squared_error_sum := 0.0
	for value in values:
		var difference := value - mean_value
		squared_error_sum += difference * difference
	return sqrt(squared_error_sum / float(values.size()))
