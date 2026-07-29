extends SceneTree

const TapBpmEstimatorType := preload(
	"res://src/screens/editor/TapBpmEstimator.gd"
)
const ChartDifficultyEstimatorType := preload(
	"res://src/screens/editor/ChartDifficultyEstimator.gd"
)
const WaveformEnvelopeModelType := preload(
	"res://src/screens/editor/WaveformEnvelopeModel.gd"
)

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tap_bpm_estimator()
	_test_difficulty_estimator()
	_test_waveform_envelope_and_cache()
	_finish()


func _test_tap_bpm_estimator() -> void:
	var estimator = TapBpmEstimatorType.new()
	var taps: Array[float] = [
		0.0,
		0.5,
		1.0,
		1.5,
		4.5,
		5.0,
		5.5,
		6.5,
		7.0,
		7.5,
	]
	for tap_time in taps:
		_expect(estimator.register_tap(tap_time), "Tap BPM acepta un tap cronológico")
	var result: Dictionary = estimator.estimate()
	_expect(
		bool(result["valid"])
		and absf(float(result["primary_bpm"]) - 120.0) < 0.01,
		"Tap BPM conserva el tempo tocado sin normalizarlo automáticamente"
	)
	_expect(
		int(result["pause_count"]) == 1
		and int(result["discarded_outlier_count"]) == 1
		and int(result["used_interval_count"]) == 7,
		"Tap BPM descarta pausas y valores atípicos de forma robusta"
	)
	_expect(
		float(result["confidence"]) >= 0.8,
		"Una secuencia estable conserva una confianza alta"
	)
	var relationships: Array[String] = []
	var suggestion_bpms: Array[float] = []
	for suggestion in result["suggestions"]:
		relationships.append(str(suggestion["relationship"]))
		suggestion_bpms.append(float(suggestion["bpm"]))
	_expect(
		relationships == ["tapped", "half_time", "double_time"]
		and suggestion_bpms == [120.0, 60.0, 240.0]
		and bool(result["requires_confirmation"]),
		"Mitad y doble BPM se ofrecen como sugerencias que requieren confirmación"
	)
	_expect(
		not estimator.register_tap(7.5)
		and not estimator.register_tap(-1.0)
		and estimator.get_tap_count() == taps.size(),
		"Tap BPM rechaza tiempos repetidos, regresivos o negativos"
	)

	var half_time_estimator = TapBpmEstimatorType.new()
	for tap_time in [0.0, 1.0, 2.0, 3.0, 4.0]:
		half_time_estimator.register_tap(tap_time)
	var half_time_result: Dictionary = half_time_estimator.estimate()
	var offers_double_time := false
	for suggestion in half_time_result["suggestions"]:
		if (
			str(suggestion["relationship"]) == "double_time"
			and is_equal_approx(float(suggestion["bpm"]), 120.0)
		):
			offers_double_time = true
	_expect(
		is_equal_approx(float(half_time_result["primary_bpm"]), 60.0)
		and offers_double_time,
		"El estimador no confunde automáticamente una interpretación a medio tiempo"
	)

	estimator.clear()
	_expect(
		estimator.get_tap_count() == 0 and not bool(estimator.estimate()["valid"]),
		"Tap BPM puede reiniciarse sin conservar mediciones anteriores"
	)
	for index in range(70):
		estimator.register_tap(float(index) * 0.5)
	_expect(
		estimator.get_tap_count() == TapBpmEstimatorType.MAX_TAPS,
		"Tap BPM limita su historial para mantener un coste estable"
	)


func _test_difficulty_estimator() -> void:
	var estimator = ChartDifficultyEstimatorType.new()
	var empty_result: Dictionary = estimator.estimate([], 4, 120.0)
	_expect(
		bool(empty_result["valid"])
		and int(empty_result["level"]) == 1
		and int(empty_result["note_count"]) == 0,
		"Un chart vacío recibe el mínimo informativo sin producir errores"
	)

	var simple_notes: Array[Dictionary] = []
	for index in range(20):
		simple_notes.append(
			{
				"time": float(index) * 2.0,
				"lane": index % 4,
				"duration": 0.0,
			}
		)
	var simple_snapshot := JSON.stringify(simple_notes)
	var simple_result: Dictionary = estimator.estimate(simple_notes, 4, 40.0)
	_expect(
		JSON.stringify(simple_notes) == simple_snapshot,
		"El análisis de dificultad no modifica el chart de entrada"
	)

	var medium_notes: Array[Dictionary] = []
	for index in range(60):
		medium_notes.append(
			{
				"time": float(index) * 0.5,
				"lane": (index * 2 + index / 3) % 6,
				"duration": 0.5 if index % 5 == 0 else 0.0,
			}
		)
	var medium_result: Dictionary = estimator.estimate(medium_notes, 6, 30.0)

	var complex_notes: Array[Dictionary] = []
	for event_index in range(80):
		var event_time := float(event_index) * 0.25
		var base_lane := (event_index * 3) % 8
		for chord_offset in range(3):
			complex_notes.append(
				{
					"time": event_time,
					"lane": (base_lane + chord_offset * 2) % 8,
					"duration": 0.75 if (event_index + chord_offset) % 4 == 0 else 0.0,
				}
			)
	var complex_result: Dictionary = estimator.estimate(complex_notes, 8, 20.0)
	_expect(
		int(simple_result["level"]) < int(medium_result["level"])
		and int(medium_result["level"]) < int(complex_result["level"]),
		"Densidad, acordes, holds y picos elevan progresivamente la estimación"
	)
	_expect(
		int(simple_result["level"]) >= 1
		and int(complex_result["level"]) <= 20,
		"La dificultad informativa siempre permanece entre 1 y 20"
	)
	var complex_metrics: Dictionary = complex_result["metrics"]
	var complex_breakdown: Dictionary = complex_result["breakdown"]
	_expect(
		float(complex_metrics["chord_note_ratio"]) > 0.9
		and int(complex_metrics["max_chord_size"]) == 3
		and float(complex_metrics["hold_ratio"]) > 0.0
		and float(complex_metrics["peak_nps"]) > float(complex_metrics["average_nps"])
		and complex_breakdown.has("density")
		and complex_breakdown.has("chords")
		and complex_breakdown.has("holds")
		and complex_breakdown.has("peaks")
		and complex_breakdown.has("lane_changes"),
		"El resultado incluye métricas y un desglose explicable"
	)
	_expect(
		estimator.estimate(complex_notes, 8, 20.0) == complex_result,
		"La estimación es determinista para el mismo chart"
	)
	var invalid_notes: Array = simple_notes.duplicate(true)
	invalid_notes.append({"time": -1.0, "lane": 0, "duration": 0.0})
	invalid_notes.append({"time": 1.0, "lane": 9, "duration": 0.0})
	var sanitized_result: Dictionary = estimator.estimate(invalid_notes, 4, 40.0)
	_expect(
		int(sanitized_result["invalid_note_count"]) == 2
		and int(sanitized_result["note_count"]) == simple_notes.size(),
		"Las notas inválidas se informan y no contaminan el cálculo"
	)
	_expect(
		not bool(estimator.estimate(simple_notes, 5, 40.0)["valid"]),
		"El modelo rechaza modos distintos de 4K, 6K u 8K"
	)


func _test_waveform_envelope_and_cache() -> void:
	var cache_directory := "user://aurora_model_tests/waveform_%d" % Time.get_ticks_usec()
	var model = WaveformEnvelopeModelType.new(cache_directory)
	var pcm := PackedFloat32Array(
		[-1.0, -0.5, 0.5, 1.0, -0.25, 0.25, -0.75, 0.75]
	)
	var envelope: Dictionary = model.build_envelope("mono-source", pcm, 1, 2, 8)
	_expect(
		bool(envelope["valid"])
		and int(envelope["bucket_count"]) == 2
		and int(envelope["frame_count"]) == 8
		and is_equal_approx(float(envelope["duration_seconds"]), 1.0),
		"La envolvente usa muestras PCM ya decodificadas sin invocar conversores"
	)
	_expect(
		is_equal_approx(float(envelope["minimums"][0]), -1.0)
		and is_equal_approx(float(envelope["maximums"][0]), 1.0)
		and absf(float(envelope["rms"][0]) - 0.790569) < 0.0001
		and is_equal_approx(float(envelope["minimums"][1]), -0.75)
		and is_equal_approx(float(envelope["maximums"][1]), 0.75),
		"La envolvente conserva mínimos, máximos y RMS por bloque"
	)

	var stereo_pcm := PackedFloat32Array(
		[-1.0, 0.5, -0.5, 1.0, 0.25, -0.25, 0.75, -0.75]
	)
	var stereo_envelope: Dictionary = model.build_envelope(
		"stereo-source",
		stereo_pcm,
		2,
		2,
		4
	)
	_expect(
		int(stereo_envelope["frame_count"]) == 4
		and is_equal_approx(float(stereo_envelope["minimums"][0]), -1.0)
		and is_equal_approx(float(stereo_envelope["maximums"][0]), 1.0),
		"El modelo procesa PCM intercalado de varios canales"
	)

	var generated: Dictionary = model.get_or_build("cached-source", pcm, 1, 2, 8)
	_expect(
		not bool(generated["from_cache"])
		and bool(generated["cache_saved"])
		and FileAccess.file_exists(model.get_cache_path_for_source("cached-source")),
		"La primera construcción guarda una caché persistente"
	)
	var other_source: Dictionary = model.get_or_build("other-source", pcm, 1, 2, 8)
	_expect(
		bool(other_source["cache_saved"]),
		"La caché admite fuentes independientes"
	)
	generated["minimums"][0] = 99.0
	var memory_cached: Dictionary = model.get_or_build("cached-source", pcm, 1, 2, 8)
	_expect(
		bool(memory_cached["from_cache"])
		and str(memory_cached["cache_layer"]) == "memory"
		and is_equal_approx(float(memory_cached["minimums"][0]), -1.0),
		"La caché en memoria entrega copias aisladas al consumidor"
	)

	var replacement_pcm := PackedFloat32Array(
		[0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25]
	)
	var reloaded_model = WaveformEnvelopeModelType.new(cache_directory)
	var disk_cached: Dictionary = reloaded_model.get_or_build(
		"cached-source",
		replacement_pcm,
		1,
		2,
		8
	)
	_expect(
		bool(disk_cached["from_cache"])
		and str(disk_cached["cache_layer"]) == "disk"
		and is_equal_approx(float(disk_cached["minimums"][0]), -1.0),
		"Una instancia nueva reutiliza la envolvente válida guardada en disco"
	)
	_expect(
		reloaded_model.invalidate_source("cached-source") == OK
		and not FileAccess.file_exists(
			reloaded_model.get_cache_path_for_source("cached-source")
		)
		and FileAccess.file_exists(
			reloaded_model.get_cache_path_for_source("other-source")
		),
		"Invalidar una clave elimina solo la fuente solicitada"
	)
	var rebuilt: Dictionary = reloaded_model.get_or_build(
		"cached-source",
		replacement_pcm,
		1,
		2,
		8
	)
	_expect(
		not bool(rebuilt["from_cache"])
		and is_equal_approx(float(rebuilt["minimums"][0]), 0.25),
		"Después de invalidar, la envolvente se reconstruye desde el PCM actual"
	)
	var resized: Dictionary = reloaded_model.get_or_build(
		"cached-source",
		replacement_pcm,
		1,
		4,
		8
	)
	_expect(
		not bool(resized["from_cache"]) and int(resized["bucket_count"]) == 4,
		"Cambiar los parámetros invalida de forma segura la caché anterior"
	)
	var corrupt_path: String = reloaded_model.get_cache_path_for_source("corrupt-source")
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt_file.store_string("{not valid json")
	corrupt_file.close()
	var recovered: Dictionary = reloaded_model.get_or_build(
		"corrupt-source",
		pcm,
		1,
		2,
		8
	)
	_expect(
		bool(recovered["valid"])
		and not bool(recovered["from_cache"])
		and bool(recovered["cache_saved"]),
		"Una caché corrupta se reemplaza de forma atómica por una envolvente válida"
	)
	_expect(
		_cache_directory_has_no_atomic_artifacts(cache_directory),
		"El guardado atómico no deja archivos temporales ni respaldos"
	)
	_expect(
		not bool(model.build_envelope("", pcm, 1, 2, 8)["valid"])
		and not bool(model.build_envelope("bad", PackedFloat32Array(), 1, 2, 8)["valid"])
		and not bool(model.build_envelope("bad", pcm, 0, 2, 8)["valid"]),
		"El modelo rechaza solicitudes PCM incompletas"
	)
	_cleanup_cache_directory(cache_directory)


func _cache_directory_has_no_atomic_artifacts(cache_directory: String) -> bool:
	var directory := DirAccess.open(cache_directory)
	if directory == null:
		return false
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if file_name.contains(".tmp.") or file_name.ends_with(".bak"):
			directory.list_dir_end()
			return false
		file_name = directory.get_next()
	directory.list_dir_end()
	return true


func _cleanup_cache_directory(cache_directory: String) -> void:
	var directory := DirAccess.open(cache_directory)
	if directory == null:
		return
	var absolute_directory := ProjectSettings.globalize_path(cache_directory)
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir():
			DirAccess.remove_absolute("%s/%s" % [absolute_directory, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_directory)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("EDITOR ANALYSIS MODELS TESTS PASSED")
		quit(0)
	else:
		print("EDITOR ANALYSIS MODELS TESTS FAILED: ", ", ".join(failures))
		quit(1)
