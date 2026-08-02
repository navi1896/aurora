extends SceneTree

const VIDEO_QUALITY_GATE := preload(
	"res://src/screens/editor/VideoQualityGate.gd"
)

var failures := 0


func _init() -> void:
	var gate = VIDEO_QUALITY_GATE.new()
	var healthy_ssim_lines: Array[String] = []
	var healthy_psnr_lines: Array[String] = []
	var corrupt_ssim_lines: Array[String] = []
	var corrupt_psnr_lines: Array[String] = []
	for frame in range(1, 13):
		healthy_ssim_lines.append(
			"n:%d Y:0.96 U:0.97 V:0.97 All:0.965000 (14.5)"
			% frame
		)
		healthy_psnr_lines.append(
			"n:%d mse_avg:40.0 psnr_avg:32.50 psnr_y:31.0"
			% frame
		)
		corrupt_ssim_lines.append(
			"n:%d Y:0.01 U:0.02 V:0.01 All:0.012000 (0.05)"
			% frame
		)
		corrupt_psnr_lines.append(
			"n:%d mse_avg:9000 psnr_avg:7.10 psnr_y:6.8"
			% frame
		)

	var healthy: Dictionary = gate.evaluate_stats_text(
		"\n".join(healthy_ssim_lines),
		"\n".join(healthy_psnr_lines)
	)
	_check(bool(healthy.get("valid", false)), "Acepta estadísticas completas")
	_check(bool(healthy.get("passed", false)), "Aprueba una conversión visualmente fiel")
	_check(
		is_equal_approx(float(healthy.get("average_ssim", 0.0)), 0.965),
		"Calcula el promedio SSIM"
	)
	_check(
		is_equal_approx(float(healthy.get("average_psnr_db", 0.0)), 32.5),
		"Calcula el promedio PSNR"
	)

	var compatible_ssim_lines: Array[String] = []
	var compatible_psnr_lines: Array[String] = []
	for frame in range(1, 13):
		compatible_ssim_lines.append(
			"n:%d Y:0.89 U:0.90 V:0.90 All:0.894416 (9.7)"
			% frame
		)
		compatible_psnr_lines.append(
			"n:%d mse_avg:276.8 psnr_avg:23.707 psnr_y:23.5"
			% frame
		)
	var compatible: Dictionary = gate.evaluate_stats_text(
		"\n".join(compatible_ssim_lines),
		"\n".join(compatible_psnr_lines)
	)
	_check(
		bool(compatible.get("passed", false)),
		"Acepta un video válido cercano al umbral sin confundirlo con corrupción"
	)

	var corrupt: Dictionary = gate.evaluate_stats_text(
		"\n".join(corrupt_ssim_lines),
		"\n".join(corrupt_psnr_lines)
	)
	_check(
		bool(corrupt.get("valid", false))
		and not bool(corrupt.get("passed", true)),
		"Rechaza las líneas de colores aunque el archivo pueda decodificarse"
	)
	_check(
		str(corrupt.get("error_code", "")) == "quality_below_threshold",
		"Explica el rechazo por calidad insuficiente"
	)

	var too_short: Dictionary = gate.evaluate_stats_text(
		"n:1 All:0.99\n",
		"n:1 psnr_avg:40.0\n"
	)
	_check(
		not bool(too_short.get("valid", true)),
		"No acepta una validación sin suficientes cuadros"
	)
	var perfect_psnr_lines: Array[String] = []
	for frame in range(1, 13):
		perfect_psnr_lines.append("n:%d psnr_avg:inf" % frame)
	var perfect: Dictionary = gate.evaluate_stats_text(
		"\n".join(healthy_ssim_lines),
		"\n".join(perfect_psnr_lines)
	)
	_check(
		bool(perfect.get("passed", false)),
		"Acepta PSNR infinito para cuadros idénticos"
	)

	var arguments: PackedStringArray = gate.build_ffmpeg_arguments(
		"C:/media/source video.mp4",
		"C:/cache/output.ogv",
		"C:/cache/quality ssim.log",
		"C:/cache/quality psnr.log",
		8.0
	)
	_check(
		"-filter_complex" in arguments
		and "[ssim_output]" in arguments
		and "[psnr_output]" in arguments,
		"Construye una comparación SSIM y PSNR en un solo proceso"
	)
	var filter_index := arguments.find("-filter_complex")
	var filter_graph := (
		str(arguments[filter_index + 1])
		if filter_index >= 0
		else ""
	)
	_check(
		filter_graph.contains("C\\:/cache/quality ssim.log")
		and filter_graph.contains("C\\:/cache/quality psnr.log"),
		"Escapa rutas Windows dentro de los filtros FFmpeg"
	)
	_check(
		arguments[arguments.find("-t") + 1] == "8.000",
		"Limita la muestra visual para mantener la importación ágil"
	)

	var missing: Dictionary = gate.evaluate_stats_files(
		"user://quality_missing_ssim.log",
		"user://quality_missing_psnr.log"
	)
	_check(
		not bool(missing.get("valid", true)),
		"Nunca marca listo cuando faltan las estadísticas"
	)

	if failures == 0:
		print("VIDEO QUALITY GATE TESTS PASSED")
		quit(0)
	else:
		push_error("VIDEO QUALITY GATE TESTS FAILED: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)
