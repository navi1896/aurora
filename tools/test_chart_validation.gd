extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	var valid_chart := ChartData.make_chart_document(
		[
			{"time": 1.0, "lane": 0, "duration": 0.0},
			{"time": 1.0, "lane": 1, "duration": 0.0},
			{"time": 2.0, "lane": 0, "duration": 1.0},
			{"time": 3.0, "lane": 0, "duration": 0.0},
		],
		4
	)
	_expect(
		ChartData.is_valid_chart_document(valid_chart, 4),
		"acepta acordes y notas en el final exacto de un hold"
	)
	_expect(
		not ChartData.is_valid_chart_document(
			ChartData.make_chart_document(
				[
					{"time": 1.0, "lane": 0, "duration": 0.0},
					{"time": 1.0, "lane": 0, "duration": 0.0},
				],
				4
			),
			4
		),
		"rechaza notas duplicadas en el mismo carril"
	)
	_expect(
		not ChartData.is_valid_chart_document(
			ChartData.make_chart_document(
				[
					{"time": 1.0, "lane": 2, "duration": 2.0},
					{"time": 2.5, "lane": 2, "duration": 0.0},
				],
				4
			),
			4
		),
		"rechaza notas dentro de un hold del mismo carril"
	)
	_expect(
		not ChartData.is_valid_chart_document(
			{
				"version": 2,
				"key_count": 4,
				"notes": [
					{"time": 1.0, "beat": 2.0, "lane": 0},
				],
			},
			4
		),
		"rechaza coordenadas de tiempo ambiguas"
	)
	var invalid_path := "user://aurora_invalid_chart_probe.json"
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	if invalid_file != null:
		invalid_file.store_string(
			JSON.stringify(
				ChartData.make_chart_document(
					[
						{"time": 1.0, "lane": 0, "duration": 1.0},
						{"time": 1.5, "lane": 0, "duration": 0.0},
					],
					4
				)
			)
		)
		invalid_file.close()
	var invalid_chart := ChartData.new()
	invalid_chart.chart_path = invalid_path
	var probe_song := SongData.new()
	probe_song.duration_seconds = 10.0
	probe_song.charts = [invalid_chart]
	var game_manager := GameManager.new()
	_expect(
		not game_manager.start_song(probe_song, invalid_chart)
		and not game_manager.is_playing,
		"GameManager impide iniciar un chart conflictivo"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	game_manager.free()
	_finish()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		printerr("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("CHART VALIDATION PASSED")
		quit(0)
	else:
		printerr("CHART VALIDATION FAILED: %s" % ", ".join(failures))
		quit(1)
