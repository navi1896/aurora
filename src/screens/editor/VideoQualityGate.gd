extends RefCounted

class_name VideoQualityGate

const MINIMUM_SSIM := 0.90
const MINIMUM_PSNR_DB := 25.0
const MINIMUM_FRAME_SAMPLES := 10
const DEFAULT_SAMPLE_SECONDS := 8.0


func build_ffmpeg_arguments(
	source_absolute: String,
	converted_absolute: String,
	ssim_stats_absolute: String,
	psnr_stats_absolute: String,
	sample_seconds: float = DEFAULT_SAMPLE_SECONDS
) -> PackedStringArray:
	var safe_seconds := clampf(sample_seconds, 1.0, 20.0)
	var source_filter := (
		"fps=30,"
		+ "scale=w='min(1280,iw)':h=-2:flags=lanczos,"
		+ "format=yuv420p,setpts=PTS-STARTPTS,split=2"
	)
	var converted_filter := source_filter
	var filter_complex := (
		"[0:v]%s[reference_ssim][reference_psnr];"
		+ "[1:v]%s[converted_ssim][converted_psnr];"
		+ "[reference_ssim][converted_ssim]"
		+ "ssim=stats_file='%s'[ssim_output];"
		+ "[reference_psnr][converted_psnr]"
		+ "psnr=stats_file='%s'[psnr_output]"
	) % [
		source_filter,
		converted_filter,
		_escape_filter_path(ssim_stats_absolute),
		_escape_filter_path(psnr_stats_absolute),
	]
	return PackedStringArray(
		[
			"-hide_banner",
			"-loglevel",
			"error",
			"-nostats",
			"-i",
			source_absolute,
			"-i",
			converted_absolute,
			"-filter_complex",
			filter_complex,
			"-map",
			"[ssim_output]",
			"-map",
			"[psnr_output]",
			"-t",
			"%.3f" % safe_seconds,
			"-f",
			"null",
			"-",
		]
	)


func evaluate_stats_files(
	ssim_stats_path: String,
	psnr_stats_path: String
) -> Dictionary:
	if (
		not FileAccess.file_exists(ssim_stats_path)
		or not FileAccess.file_exists(psnr_stats_path)
	):
		return _invalid_result("missing_stats")
	var ssim_file := FileAccess.open(ssim_stats_path, FileAccess.READ)
	var psnr_file := FileAccess.open(psnr_stats_path, FileAccess.READ)
	if ssim_file == null or psnr_file == null:
		return _invalid_result("unreadable_stats")
	return evaluate_stats_text(
		ssim_file.get_as_text(),
		psnr_file.get_as_text()
	)


func evaluate_stats_text(ssim_text: String, psnr_text: String) -> Dictionary:
	var ssim_values := _extract_metric_values(ssim_text, "All:")
	var psnr_values := _extract_metric_values(psnr_text, "psnr_avg:")
	var frame_samples := mini(ssim_values.size(), psnr_values.size())
	if frame_samples < MINIMUM_FRAME_SAMPLES:
		return _invalid_result(
			"insufficient_samples",
			frame_samples
		)
	ssim_values.resize(frame_samples)
	psnr_values.resize(frame_samples)
	var average_ssim := _average(ssim_values)
	var average_psnr := _average(psnr_values)
	var passed := (
		average_ssim >= MINIMUM_SSIM
		and average_psnr >= MINIMUM_PSNR_DB
	)
	return {
		"valid": true,
		"passed": passed,
		"frame_samples": frame_samples,
		"average_ssim": average_ssim,
		"average_psnr_db": average_psnr,
		"minimum_ssim": MINIMUM_SSIM,
		"minimum_psnr_db": MINIMUM_PSNR_DB,
		"error_code": "" if passed else "quality_below_threshold",
	}


func _extract_metric_values(text: String, marker: String) -> Array[float]:
	var values: Array[float] = []
	for line in text.split("\n", false):
		var marker_index := line.find(marker)
		if marker_index < 0:
			continue
		var value_start := marker_index + marker.length()
		var value_end := line.find(" ", value_start)
		if value_end < 0:
			value_end = line.length()
		var raw_value := line.substr(
			value_start,
			value_end - value_start
		).strip_edges().to_lower()
		if raw_value in ["inf", "+inf", "infinity"]:
			values.append(100.0)
		elif raw_value.is_valid_float():
			var numeric_value := float(raw_value)
			if not is_nan(numeric_value) and not is_inf(numeric_value):
				values.append(numeric_value)
	return values


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _escape_filter_path(path: String) -> String:
	return (
		path.replace("\\", "/")
		.replace(":", "\\:")
		.replace("'", "\\'")
	)


func _invalid_result(
	error_code: String,
	frame_samples: int = 0
) -> Dictionary:
	return {
		"valid": false,
		"passed": false,
		"frame_samples": frame_samples,
		"average_ssim": 0.0,
		"average_psnr_db": 0.0,
		"minimum_ssim": MINIMUM_SSIM,
		"minimum_psnr_db": MINIMUM_PSNR_DB,
		"error_code": error_code,
	}
