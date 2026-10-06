extends SceneTree

const EFFECT = preload("res://src/screens/gameplay/PerfectPlayCelebration.gd")
var failures := 0
var captures := false

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	print(("PASS " if value else "FAIL ") + message)
	if not value:
		failures += 1

func _run() -> void:
	if not "perfect_play_review/isolated" in OS.get_user_data_dir().replace("\\", "/"):
		push_error("Refusing to run without isolated APPDATA")
		quit(2)
		return
	captures = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	var result := {"total_notes": 10, "perfect": 10, "great": 0, "good": 0, "miss": 0, "max_combo": 10}
	check(EFFECT.qualifies(result), "All perfect qualifies")
	result.perfect = 4
	result.great = 3
	result.good = 3
	check(EFFECT.qualifies(result), "Full combo with Great/Good qualifies as requested")
	result.miss = 1
	check(not EFFECT.qualifies(result), "A miss excludes celebration")
	result.miss = 0
	result.good = 2
	check(not EFFECT.qualifies(result), "Unjudged note excludes celebration")
	result.good = 3
	result.max_combo = 9
	check(not EFFECT.qualifies(result), "Broken combo excludes celebration")
	check(not EFFECT.qualifies({}), "Empty chart excludes celebration")
	var app = load("res://src/App.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	var gm = app.get_node("Managers/GameManager")
	var sm = app.get_node("Managers/SceneManager")
	var settings = app.get_node("Managers/SettingsManager")
	settings.set_setting("fullscreen", false)
	var chart := ChartData.new()
	chart.key_count = 4
	var song := SongData.new()
	var silence := AudioStreamWAV.new()
	silence.mix_rate = 8000
	silence.format = AudioStreamWAV.FORMAT_8_BITS
	var silence_data := PackedByteArray()
	silence_data.resize(30 * 8000)
	silence_data.fill(128)
	silence.data = silence_data
	song.audio = silence
	var video := VideoStreamTheora.new()
	video.file = "E:/Juego_Musica_Assets/DJMAX/Metadata/perfect_play_review/outro_fixture.ogv"
	if FileAccess.file_exists(video.file):
		song.background_video = video
	song.song_id = &"perfect_play_isolated_test"
	song.title = "Perfect Play test"
	song.duration_seconds = 30.0
	song.bpm = 120.0
	song.charts = [chart]
	check(gm.start_editor_test(song, chart, "user://test_only.json"), "Isolated editor test starts")
	sm.load_scene("gameplay")
	await process_frame
	var game = sm.current_scene
	game.set_process(false)
	game._start_gameplay_media()
	game.chart_end_time = 1.0
	game.gameplay_time = 1.0
	game.perfect_count = game.chart_notes.size() - 1
	game.judged_count = game.chart_notes.size() - 1
	game.max_combo = game.chart_notes.size() - 1
	game._check_level_finished()
	check(game.clear_celebration == null, "No celebration while the final hold is unjudged")
	game.perfect_count = game.chart_notes.size()
	game.judged_count = game.chart_notes.size()
	game.max_combo = game.chart_notes.size()
	game.accuracy_points = float(game.judged_count)
	game.gameplay_time = 0.99
	game._check_level_finished()
	check(game.clear_celebration == null, "Early accepted hold release waits for chart tail")
	game.gameplay_time = 1.0
	game._check_level_finished()
	check(game.clear_celebration == null, "Brief delay after final note")
	game.gameplay_time = 1.3
	game._check_level_finished()
	check(sm.current_scene_name == "gameplay" and not game.gameplay_finished, "Celebration starts during outro, not after media end")
	var effect = game.clear_celebration
	check(effect != null and effect.running, "Effect runs inside gameplay")
	if effect == null:
		quit(1)
		return
	check(effect.audio_player.playing and effect.audio_player.bus == "SFX", "Original sound plays through effects volume")
	check(
		effect.audio_player.stream.get_length() > 1.5
		and effect.audio_player.stream.get_length() < 3.0
		and EFFECT.DURATION >= 4.0,
		"The original cue and full-length visual celebration have separate durations"
	)
	game._check_level_finished()
	check(game.clear_celebration == effect, "Duplicate finish does not replay effect")
	var audio_before: float = game.song_player.get_playback_position()
	await create_timer(0.2).timeout
	check(game.song_player.playing and game.song_player.get_playback_position() > audio_before, "Song keeps playing underneath celebration")
	if game.background_video_player != null:
		check(game.background_video_player.is_playing() and not game.background_video_player.paused and game.background_video_player.stream_position > 0, "Video continues under celebration")
	if captures:
		effect.set_process(false)
		for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = resolution
			await process_frame
			for phase in [0.5, 2.4]:
				effect.elapsed = phase
				effect.queue_redraw()
				await RenderingServer.frame_post_draw
				var path := "E:/Juego_Musica_Assets/DJMAX/Metadata/perfect_play_review/aurora_%d_%s.png" % [resolution.x, str(phase)]
				check(root.get_texture().get_image().save_png(path) == OK, "Screenshot " + path)
			effect.reduced_motion = true
			effect.queue_redraw()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("E:/Juego_Musica_Assets/DJMAX/Metadata/perfect_play_review/reduced_%d.png" % resolution.x)
			effect.reduced_motion = false
		effect.elapsed = 0.0
		effect.set_process(true)
	await create_timer(4.2).timeout
	game._check_level_finished()
	check(sm.current_scene_name == "gameplay", "A long outro is not cut by the end of the effect")
	check(not effect.running and not effect.visible, "Badge disappears cleanly while video continues")
	check(game.song_player.playing, "Song is not stopped when badge disappears")
	game.gameplay_time = game.level_end_time
	game._check_level_finished()
	check(sm.current_scene_name == "results", "Results only after both media and celebration finish")
	await process_frame
	check(not is_instance_valid(effect), "Sound and effect freed after exit")
	check(gm.last_result.get("clear_celebration_played", false), "Results know not to replay victory sound")
	check(gm.personal_records.is_empty(), "No personal records changed")
	gm.start_editor_test(song, chart, "user://test_only.json")
	sm.load_scene("gameplay")
	await process_frame
	game = sm.current_scene
	game.set_process(false)
	game._start_gameplay_media()
	game.chart_end_time = game.level_end_time
	game.gameplay_time = game.level_end_time
	game.perfect_count = game.chart_notes.size()
	game.judged_count = game.chart_notes.size()
	game.max_combo = game.chart_notes.size()
	game._check_level_finished()
	check(sm.current_scene_name == "gameplay", "Short outro waits for pending celebration")
	game.gameplay_time += 0.3
	game._check_level_finished()
	check(game.clear_celebration != null and game.clear_celebration.running, "Last note at media end still gets a full celebration")
	game.clear_celebration.complete()
	game._check_level_finished()
	check(sm.current_scene_name == "results", "Short outro completes after celebration, without extra wait")
	await process_frame
	for missed in [true, false]:
		gm.start_editor_test(song, chart, "user://test_only.json")
		sm.load_scene("gameplay")
		await process_frame
		game = sm.current_scene
		game.set_process(false)
		if missed:
			game.perfect_count = game.chart_notes.size() - 1
			game.miss_count = 1
			game.judged_count = game.chart_notes.size()
		else:
			game.chart_notes.clear()
		game._finish_gameplay()
		check(sm.current_scene_name == "results", "Miss/empty chart goes straight to results")
		check(not gm.last_result.get("clear_celebration_played", false), "No false full combo")
		await process_frame
	var reduced = EFFECT.new()
	root.add_child(reduced)
	reduced.play(true)
	check(reduced.reduced_motion, "Reduced motion setting is honored")
	reduced.complete()
	reduced.complete()
	check(not reduced.audio_player.playing, "Completion stops sound, including repeated calls")
	reduced.queue_free()
	await process_frame
	app.queue_free()
	await process_frame
	await process_frame
	print("PERFECT_PLAY_TEST failures=", failures)
	quit(0 if failures == 0 else 1)
