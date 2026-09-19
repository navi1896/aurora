extends SceneTree

const Cinematics := preload("res://src/data/CinematicSections.gd")
const Store := preload("res://src/screens/editor/EditorProjectStore.gd")
const Recovery := preload("res://src/screens/editor/EditorRecoveryStore.gd")
const Exporter := preload("res://src/screens/editor/EditorPackageExporter.gd")
const Packages := preload("res://src/packages/SongPackageService.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	AudioServer.set_bus_mute(0, true)
	var sections := [{"start": 3.0, "end": 8.0}]
	var notes := [{"time": 1.0, "lane": 0, "duration": 0.5}, {"time": 10.0, "lane": 3, "duration": 1.0}]
	_expect(Cinematics.is_valid(sections), "Accepts cinematic ranges")
	for invalid in [null, {}, [{"start": "bad", "end": 2}], [{"start": 3, "end": 2}], [{"start": -1, "end": 2}], [{"start": NAN, "end": 2}]]:
		_expect(not Cinematics.is_valid(invalid), "Rejects malformed range")
	_expect(Cinematics.normalize([{"start": 4.0, "end": 6.0}, {"start": 3.0, "end": 5.0}]) == [{"start": 3.0, "end": 6.0}], "Merges overlapping ranges")
	var protected := Cinematics.safe_sections([{"start": 0.0, "end": 12.0}], notes, 2.0, 0.22)
	_expect(is_equal_approx(Cinematics.opacity_at(protected, 4.0), 0.0), "Hides during an empty musical break")
	for seconds in [0.0, 1.0, 1.4, 1.7, 8.0, 9.0, 10.0, 10.8, 11.2]:
		_expect(is_equal_approx(Cinematics.opacity_at(protected, seconds), 1.0), "Keeps approach, hold and missed-note windows visible at %.1f" % seconds)
	var fade := Cinematics.opacity_at(sections, 3.175)
	_expect(fade > 0.0 and fade < 1.0, "Fades smoothly at the start")
	_expect(is_equal_approx(Cinematics.opacity_at(sections, 8.0), 1.0), "Restores exactly at section end")

	var fixture := "user://cinematic_flow"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_8_BITS
	wave.mix_rate = 8000
	var silence := PackedByteArray()
	silence.resize(96000)
	silence.fill(128)
	wave.data = silence
	var audio_path := fixture.path_join("audio.wav")
	_expect(wave.save_to_wav(audio_path) == OK, "Creates isolated test media")
	var path := fixture.path_join("project.json")
	var project := {"version": 3, "type": Store.PROJECT_TYPE, "package_id": "cinematic-fixture", "package_version": "1.0.0",
		"metadata": {"title": "Prueba de cinemática", "artist": "Aurora Tests", "key_count": 4, "difficulty": "NORMAL", "difficulty_level": 4,
			"bpm": 120.0, "duration_seconds": 12.0, "creation_mode": "manual"},
		"media": {"audio_path": audio_path}, "chart_path": "chart.json"}
	var doc := ChartData.make_chart_document(notes, 4, 0.25, [], sections)
	_expect(ChartData.is_valid_chart_document(doc, 4), "Validates chart v4")
	_expect(Store.save_bundle(path, project, doc).ok, "Saves sections with the chart")
	var chart := ChartData.new()
	chart.chart_path = fixture.path_join("chart.json")
	chart.audio_offset_seconds = -0.1
	_expect(chart.load_cinematic_sections() == [{"start": 3.15, "end": 8.15}], "Applies chart and audio offsets consistently")
	# Editor writes canonical seconds with zero offset.
	_expect(Store.save_bundle(path, project, ChartData.make_chart_document(notes, 4, 0.0, [], sections)).ok, "Saves canonical test chart")
	_expect(Recovery.save_snapshot(fixture.path_join("recovery.json"), project, notes, path, [], sections).ok, "Autosaves cinematic sections")
	_expect(Recovery.load_snapshot(fixture.path_join("recovery.json")).get("cinematic_sections") == sections, "Recovery retains cinematic sections")

	var app := (load("res://src/App.tscn") as PackedScene).instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	var scenes := app.get_node("Managers/SceneManager") as SceneManager
	var game := app.get_node("Managers/GameManager") as GameManager
	var settings := app.get_node("Managers/SettingsManager") as SettingsManager
	var songs := app.get_node("Managers/SongManager") as SongManager
	scenes.load_scene("editor")
	await process_frame
	await process_frame
	var editor := scenes.current_scene as Editor
	editor._load_project(path)
	await process_frame
	await process_frame
	_expect(editor.cinematic_sections == sections, "Editor opens stored sections")
	var section_ui = editor.cinematic_section_editor
	section_ui.heading.button_pressed = true
	section_ui.start_spin.value = 8.5
	section_ui.end_spin.value = 9.5
	section_ui._add_section()
	_expect(editor.cinematic_sections.size() == 2 and editor._is_editor_dirty(), "Visible editor controls add a section and mark unsaved changes")
	editor._undo_chart_action()
	_expect(editor.cinematic_sections == sections, "Undo restores original sections")
	editor._redo_chart_action()
	_expect(editor.cinematic_sections.size() == 2, "Redo restores new section")
	section_ui.section_list.select(1)
	section_ui._remove_section()
	_expect(editor.cinematic_sections == sections, "Remove updates section list")
	_expect(editor._save_project(), "Editor saves its cinematic changes")
	_expect(Store.load_bundle(path).get("cinematic_sections") == sections, "Reopening preserves sections")
	await _capture("editor_sections")
	var package_path := fixture.path_join("cinematic.aurora")
	_expect(Exporter.new().export_saved_project(path, package_path).get("ok", false), "Exports cinematic chart")
	_expect(Packages.new().validate_package(package_path).get("ok", false), "Exported package passes validation")
	var zip := ZIPReader.new()
	if zip.open(package_path) == OK:
		var exported: Dictionary = JSON.parse_string(zip.read_file("charts/chart.json").get_string_from_utf8())
		_expect(exported.get("cinematic_sections") == sections, "Shared package contains cinematic sections")
		zip.close()
	else:
		_expect(false, "Opens exported package")
	_expect(songs.import_song_package(package_path).get("ok", false), "Imports package into test profile")
	var song: SongData
	for candidate in songs.songs:
		if candidate.song_id == "package_cinematic-fixture":
			song = candidate
	if song == null:
		_expect(false, "Finds installed fixture")
		quit(1)
		return
	var editable := songs.prepare_song_for_editor(song, song.charts[0])
	_expect(editable.get("ok", false) and Store.load_bundle(editable.get("project_path", "")).get("cinematic_sections") == sections, "Library's editable copy retains sections")
	_expect(songs.ensure_song_media_loaded(song), "Loads package media before gameplay")
	_expect(game.start_editor_test(song, song.charts[0], path), "Starts gameplay from editor")
	scenes.load_scene("gameplay")
	await process_frame
	await process_frame
	var gameplay := scenes.current_scene as Gameplay
	gameplay.set_process(false)
	_expect(not gameplay.start_gate_panel.visible and not gameplay.start_countdown_active, "Startup has no visible countdown")
	_expect(gameplay.gameplay_time < 0.0 and not gameplay.media_started and gameplay.preparation_blackout.visible, "Starts with black background and silent preroll")
	_expect(
		gameplay.gameplay_time <= -gameplay._get_note_travel_time() - Gameplay.EXTRA_PREPARATION_SECONDS,
		"Black startup includes the added preparation time"
	)
	_expect(not gameplay.score_label.is_visible_in_tree() and not gameplay.control_deck.visible, "Startup shows only playfield and notes")
	gameplay.chart_notes.assign([{"time": 0.0, "lane": 0, "duration": 0.0}])
	gameplay.gameplay_time = -gameplay._get_note_travel_time()
	gameplay._spawn_upcoming_notes()
	gameplay._update_active_notes()
	_expect(gameplay.active_notes.size() == 1, "Time-zero note is prepared before song starts")
	var first_note := gameplay.active_notes[0].node as PanelContainer
	_expect(is_zero_approx(first_note.offset_bottom), "First note enters from the top edge")
	gameplay._update_song_clock(gameplay._get_note_travel_time() * 0.5)
	gameplay._update_active_notes()
	_expect(first_note.offset_bottom > 0.0 and first_note.offset_bottom < gameplay.hit_line.position.y, "First note descends while the background stays black")
	_expect(gameplay.preparation_blackout.visible and not gameplay.song_player.playing, "Black entry does not start media early")
	await _capture("black_startup")
	gameplay.pause_menu.open_menu()
	var paused_time := gameplay.gameplay_time
	await process_frame
	await process_frame
	_expect(gameplay.gameplay_time == paused_time, "Pausing the entry freezes preroll")
	gameplay.pause_menu._leave_pause_for_navigation()
	gameplay._update_song_clock(gameplay._get_note_travel_time())
	_expect(gameplay.media_started and gameplay.song_player.playing and gameplay.gameplay_time == 0.0, "Audio begins at zero after full note approach")
	_expect(not gameplay.preparation_blackout.visible and gameplay.score_label.is_visible_in_tree(), "Video area and HUD reveal when media begins")
	first_note.queue_free()
	gameplay.active_notes.clear()
	gameplay.chart_notes.assign(notes)
	gameplay.next_note_index = 0
	gameplay.start_gate_active = false
	gameplay.start_gate_panel.hide()
	gameplay.preparation_blackout.hide()
	gameplay.media_started = true
	_add_test_background(gameplay)
	settings.set_setting("background_dim", 0.0)
	settings.set_setting("lane_opacity", 0.0)
	_expect(is_zero_approx(gameplay.dim_overlay.color.a), "Background dim reaches true zero")
	_expect(is_zero_approx((gameplay.frame_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a), "Track backing reaches true zero")
	_expect(is_zero_approx((gameplay.control_deck.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a), "Lower deck backing follows opacity")
	_expect(gameplay.lane_receptors[0].modulate.a == 1.0 and gameplay.lane_note_layers[0].modulate.a == 1.0, "Opacity preserves notes and receptors")
	gameplay.gameplay_time = 1.0
	gameplay._spawn_upcoming_notes()
	gameplay._update_active_notes()
	await _capture("transparent_track")
	settings.set_setting("lane_opacity", 1.0)
	settings.set_setting("background_dim", 1.0)
	_expect(gameplay.dim_overlay.color.a == 1.0, "Background dim reaches full black")
	_expect((gameplay.frame_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a == 1.0, "Track reaches full opacity")
	settings.set_setting("background_dim", 0.0)
	settings.set_setting("lane_opacity", 0.75)
	await _capture("opaque_track")
	gameplay.gameplay_time = 5.0
	gameplay._update_ambient_frame()
	_expect(is_zero_approx(gameplay.frame_panel.modulate.a), "Entire central playfield disappears in its authored break")
	_expect(gameplay.dim_overlay.visible and gameplay.score_label.is_visible_in_tree(), "Background and outer HUD stay visible")
	await _capture("cinematic_break")
	settings.set_setting("reduced_motion", true)
	_expect(is_zero_approx(gameplay.frame_panel.modulate.a), "Ambient settings do not reset cinematic alpha")
	settings.set_setting("cinematic_sections_enabled", false)
	_expect(gameplay.frame_panel.modulate.a == 1.0, "Player can disable cinematic hiding")
	settings.set_setting("cinematic_sections_enabled", true)
	gameplay.gameplay_time = 9.0
	gameplay._update_ambient_frame()
	_expect(gameplay.frame_panel.modulate.a == 1.0, "Track is restored before upcoming notes")
	gameplay.pause_menu.open_menu()
	(gameplay.pause_menu.visual_sliders["lane_opacity"] as HSlider).value = 25.0
	(gameplay.pause_menu.visual_sliders["background_dim"] as HSlider).value = 12.0
	_expect(is_equal_approx(float(settings.get_setting("lane_opacity")), 0.25), "Pause slider changes track opacity")
	_expect(is_equal_approx(gameplay.dim_overlay.color.a, 0.12), "Pause slider updates gameplay background immediately")
	await _capture("pause_visibility")
	settings.save_settings()
	var loaded := SettingsManager.new()
	loaded.load_settings()
	_expect(is_equal_approx(float(loaded.get_setting("lane_opacity")), 0.25), "Opacity survives settings reload")
	loaded.free()
	gameplay.pause_menu._leave_pause_for_navigation()
	scenes.load_scene("settings")
	await process_frame
	await process_frame
	(scenes.current_scene as Settings)._show_category("gameplay")
	await _capture("gameplay_settings")
	current_scene = null
	app.queue_free()
	await process_frame
	await process_frame
	var result_path := OS.get_environment("AURORA_CINEMATIC_QA_RESULT")
	if not result_path.is_empty():
		var result_file := FileAccess.open(result_path, FileAccess.WRITE)
		if result_file != null:
			result_file.store_string(JSON.stringify({"passed": failures == 0, "failures": failures,
				"executable": OS.get_executable_path(), "renderer": DisplayServer.get_name()}))
			result_file.close()
	print("CINEMATIC SECTIONS %s" % ("PASSED" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)


func _add_test_background(gameplay: Gameplay) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.16, 0.72, 0.75))
	gradient.set_color(1, Color(0.86, 0.42, 0.35))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1280
	texture.height = 720
	texture.fill_to = Vector2(1, 1)
	var backdrop := TextureRect.new()
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	AuroraUi.fill(backdrop)
	gameplay.add_child(backdrop)
	gameplay.move_child(backdrop, gameplay.dim_overlay.get_index())


func _capture(label: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("AURORA_VISUAL_QA_DIR")
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	_expect(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Captures " + label)
