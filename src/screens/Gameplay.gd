extends Control

class_name Gameplay

const CINEMATICS := preload("res://src/data/CinematicSections.gd")
const PAUSE_MENU_SCENE := preload("res://src/screens/pause/PauseMenu.tscn")
const AUTO_SIDE_TRACK := preload("res://src/screens/gameplay/AutoSideTrack.gd")
const CABINET_CHROME := preload("res://src/screens/gameplay/CabinetChrome.gd")
const PERFECT_PLAY := preload("res://src/screens/gameplay/PerfectPlayCelebration.gd")
const GAMEPLAY_CABINET_OVERLAY := preload("res://assets/gameplay/ui/gameplay_cabinet_overlay.png")
const PERFECT_JUDGMENT_ART := preload("res://assets/gameplay/ui/judgment_perfect.png")
const JUDGMENT_RATINGS_SHEET := preload("res://assets/gameplay/ui/judgment_ratings_sheet.png")
const LANE_RECEPTOR_KEY_ART := preload("res://assets/gameplay/ui/lane_receptor_key.png")
const HIT_LINE_ART := preload("res://assets/gameplay/ui/hit_line_neon.png")
const NEON_NOTE := preload("res://src/screens/gameplay/NeonGameplayNote.gd")
const NEON_RECEPTOR := preload("res://src/screens/gameplay/NeonGameplayReceptor.gd")
const SKIN_REFERENCE_SIZE := Vector2(1672.0, 941.0)
const SKIN_HIT_OFFSET := 170.0
const SKIN_RECEPTOR_TOP := 160.0
const SKIN_RECEPTOR_BOTTOM := 113.0
const PERFECT_WINDOW := 0.045
const GREAT_WINDOW := 0.090
const GOOD_WINDOW := 0.120
const MISS_WINDOW := 0.150
const SLOWEST_NOTE_TRAVEL_TIME := 4.2
const FASTEST_NOTE_TRAVEL_TIME := 0.42
const CONTROL_DECK_HEIGHT := 118.0
const RECEPTOR_TOP_OFFSET := 130.0
const RECEPTOR_BOTTOM_OFFSET := 76.0
const NOTE_HALF_HEIGHT := 10.0
const HOLD_NOTE_MIN_DURATION := 0.18
const HIT_ZONE_HEIGHT := 40.0
const HIT_LINE_GAP := NOTE_HALF_HEIGHT * 3.0
const HIT_LINE_BOTTOM_OFFSET := CONTROL_DECK_HEIGHT + RECEPTOR_TOP_OFFSET + HIT_LINE_GAP
const EXTRA_PREPARATION_SECONDS := 2.5
const CLEAR_CELEBRATION_DELAY := 0.25
const FEVER_HITS_PER_LEVEL := 20
const FEVER_MAX_LEVEL := 5
const FEVER_PINK := Color(1.0, 0.20, 0.72)
const LANE_COLORS: Array[Color] = [
	Color(0.08, 0.86, 1.0),
	Color(1.0, 0.20, 0.72),
	Color(0.08, 0.86, 1.0),
	Color(1.0, 0.20, 0.72),
	Color(0.08, 0.86, 1.0),
	Color(1.0, 0.20, 0.72),
	Color(0.42, 0.24, 1.0),
	Color(0.08, 0.86, 1.0),
]

var scene_manager: SceneManager
var game_manager: GameManager
var settings_manager: SettingsManager
var input_manager: InputManager
var pause_menu: PauseMenu
var ui_feedback

var lane_mode := 4
var lane_panels: Array[PanelContainer] = []
var lane_receptors: Array[Control] = []
var lane_receptor_tints: Array[Color] = []
var lane_labels: Array[Label] = []
var lane_note_layers: Array[Control] = []
var lane_pressed: Array[bool] = []

var score := 0
var combo := 0
var max_combo := 0
var score_streak := 0
var combo_earned := 0
var fever_level := 1
var fever_hits := 0
var fever_max_level := 1
var use_gameplay_skin := false
var skin_canvas: Control
var cabinet_art_overlay: Control
var cabinet_chrome_visual: CanvasItem
var cabinet_frame_bars: Array[ColorRect] = []
var fever_label: Label
var fever_level_segments: Array[Control] = []
var fever_level_segment_frames: Array[Panel] = []
var fever_level_segment_fills: Array[ColorRect] = []
var fever_progress_label: Label
var fever_multiplier_label: Label
var fever_displayed_level := 0
var cumulative_label: Label
var perfect_count := 0
var great_count := 0
var good_count := 0
var miss_count := 0
var judged_count := 0
var accuracy_points := 0.0
var timing_error_total_ms := 0.0
var timing_sample_count := 0
var early_hit_count := 0
var late_hit_count := 0
var on_time_hit_count := 0
var ambient_time := 0.0
var gameplay_time := 0.0
var chart_end_time := 0.0
var level_end_time := 0.0
var next_note_index := 0
var next_shift_note_index := 0
var next_beat_time := 0.0
var gameplay_finished := false
var clear_celebration
var clear_ready_time := -1.0
var start_gate_active := true
var start_countdown_active := false
var start_countdown_token := 0
var media_started := false
var intro_hidden_controls: Array[Control] = []

var chart_notes: Array[Dictionary] = []
var chart_shift_notes: Array[Dictionary] = []
var chart_side_notes: Array[Dictionary] = []
var side_note_entries: Array[Dictionary] = []
var side_pressed := [false, false]
var active_notes: Array[Dictionary] = []
var active_shift_pairs: Dictionary = {}
var side_tracks: Array[Control] = []
var song_player: AudioStreamPlayer
var media_fade_tween: Tween
var background_video_player: VideoStreamPlayer
var beat_player: AudioStreamPlayer
var miss_sound_player: AudioStreamPlayer
var countdown_sound_player: AudioStreamPlayer
var last_countdown_value := 4

var score_label: Label
var combo_label: Label
var combo_caption_label: Label
var precision_label: Label
var judgment_label: Label
var judgment_art: TextureRect
var judgment_art_textures: Dictionary = {}
var hit_precision_label: Label
var judgment_feedback_tween: Tween
var timing_feedback_label: Label
var speed_label: Label
var progress_label: Label
var progress_fill: ColorRect
var cinematic_sections: Array[Dictionary] = []
var safe_cinematic_sections: Array[Dictionary] = []
var track_rails: Array[ColorRect] = []
var frame_panel: PanelContainer
var hit_line: ColorRect
var control_deck: PanelContainer
var dim_overlay: ColorRect
var preparation_blackout: ColorRect
var start_gate_panel: PanelContainer
var start_prompt_label: Label
var combo_feedback_tween: Tween
var lane_miss_feedback_tweens: Dictionary = {}
var miss_feedback_duration := 0.22


func _ready() -> void:
	AuroraUi.fill(self)
	var managers := get_tree().current_scene.get_node("Managers")
	scene_manager = managers.get_node("SceneManager") as SceneManager
	game_manager = managers.get_node("GameManager") as GameManager
	settings_manager = managers.get_node("SettingsManager") as SettingsManager
	input_manager = managers.get_node("InputManager") as InputManager
	ui_feedback = managers.get_node_or_null("UiFeedbackManager")
	start_gate_active = true
	lane_mode = _get_lane_mode()
	setup_ui()
	_setup_pause_menu()
	_initialize_gameplay()
	call_deferred("_begin_start_countdown")
	settings_manager.setting_changed.connect(_on_setting_changed)
	input_manager.input_device_changed.connect(_on_input_device_changed)


func setup_ui() -> void:
	AuroraUi.clear(self)
	use_gameplay_skin = lane_mode == 4
	lane_panels.clear()
	lane_receptors.clear()
	lane_receptor_tints.clear()
	lane_labels.clear()
	lane_note_layers.clear()
	lane_pressed.clear()
	lane_miss_feedback_tweens.clear()
	active_notes.clear()
	active_shift_pairs.clear()
	side_tracks.clear()
	side_note_entries.clear()
	side_pressed = [false, false]
	track_rails.clear()
	intro_hidden_controls.clear()
	cabinet_art_overlay = null
	cabinet_chrome_visual = null
	cabinet_frame_bars.clear()

	AuroraUi.add_background(self)
	_add_stage_background()
	_build_preparation_blackout()
	_build_reference_canvas()
	_build_compact_playfield()
	_build_gameplay_art_overlay()
	_build_floating_screen_hud()
	_apply_visual_settings()
	_build_start_gate()
	_apply_intro_visibility()
	if not resized.is_connected(_layout_reference_canvas):
		resized.connect(_layout_reference_canvas)
	call_deferred("_layout_reference_canvas")


func _build_reference_canvas() -> void:
	skin_canvas = null
	if not use_gameplay_skin:
		return
	skin_canvas = Control.new()
	skin_canvas.name = "GameplayReferenceCanvas"
	skin_canvas.size = SKIN_REFERENCE_SIZE
	skin_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skin_canvas)
	_layout_reference_canvas()


func _layout_reference_canvas() -> void:
	if skin_canvas == null or not is_instance_valid(skin_canvas):
		return
	var fit := minf(size.x / SKIN_REFERENCE_SIZE.x, size.y / SKIN_REFERENCE_SIZE.y)
	skin_canvas.scale = Vector2.ONE * fit
	skin_canvas.position = (size - SKIN_REFERENCE_SIZE * fit) * 0.5


func _add_stage_background() -> void:
	background_video_player = null
	if game_manager.current_song != null and game_manager.current_song.background_video != null:
		var song_gain_db := clampf(game_manager.current_song.audio_gain_db, -18.0, 12.0)
		background_video_player = VideoStreamPlayer.new()
		background_video_player.name = "BackgroundVideo"
		AuroraUi.fill(background_video_player)
		background_video_player.stream = game_manager.current_song.background_video
		background_video_player.expand = true
		background_video_player.loop = false
		background_video_player.autoplay = false
		background_video_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		background_video_player.volume_db = -80.0 if game_manager.current_song.audio != null else song_gain_db
		background_video_player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		background_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background_video_player)

	dim_overlay = ColorRect.new()
	AuroraUi.fill(dim_overlay)
	dim_overlay.color = Color(0.0, 0.005, 0.02, 0.34)
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim_overlay)



func _build_preparation_blackout() -> void:
	preparation_blackout = ColorRect.new()
	preparation_blackout.name = "PreparationBlackout"
	AuroraUi.fill(preparation_blackout)
	preparation_blackout.color = Color.BLACK
	preparation_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if use_gameplay_skin:
		preparation_blackout.z_index = 4
		preparation_blackout.z_as_relative = false
	preparation_blackout.visible = start_gate_active
	add_child(preparation_blackout)


func _build_compact_playfield() -> void:
	use_gameplay_skin = lane_mode == 4
	var track_width := 815.0 if use_gameplay_skin else 760.0 + float(lane_mode - 4) * 60.0
	frame_panel = PanelContainer.new()
	frame_panel.name = "PlayfieldFrame"
	frame_panel.anchor_left = 0.5
	frame_panel.anchor_right = 0.5
	frame_panel.anchor_bottom = 1.0
	frame_panel.offset_left = -track_width * 0.5
	frame_panel.offset_right = track_width * 0.5
	frame_panel.add_theme_stylebox_override("panel", _make_playfield_frame_style())
	if use_gameplay_skin:
		frame_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		frame_panel.position = Vector2(480, 0)
		frame_panel.size = Vector2(712, 941)
		skin_canvas.add_child(frame_panel)
	else:
		add_child(frame_panel)

	var stage := Control.new()
	stage.name = "PlayfieldStage"
	stage.z_index = 2 if use_gameplay_skin else 0
	stage.z_as_relative = false
	frame_panel.add_child(stage)
	if not use_gameplay_skin:
		var cabinet_chrome = CABINET_CHROME.new()
		cabinet_chrome.name = "CabinetChrome"
		AuroraUi.fill(cabinet_chrome)
		cabinet_chrome_visual = cabinet_chrome
		stage.add_child(cabinet_chrome)
		intro_hidden_controls.append(cabinet_chrome)
	_build_auto_side_tracks(stage)

	if not use_gameplay_skin:
		var left_rail := ColorRect.new()
		left_rail.anchor_bottom = 1.0
		left_rail.offset_right = 8.0
		left_rail.color = Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.94)
		left_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(left_rail)

		var right_rail := ColorRect.new()
		right_rail.anchor_left = 1.0
		right_rail.anchor_right = 1.0
		right_rail.anchor_bottom = 1.0
		right_rail.offset_left = -8.0
		right_rail.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.94)
		right_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(right_rail)
		track_rails.assign([left_rail, right_rail])

	var lanes := GridContainer.new()
	lanes.name = "Lanes"
	lanes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lanes.offset_left = 92.0 if use_gameplay_skin else 38.0
	lanes.offset_right = -92.0 if use_gameplay_skin else -38.0
	lanes.offset_top = 44.0 if use_gameplay_skin else 0.0
	lanes.offset_bottom = -97.0 if use_gameplay_skin else -CONTROL_DECK_HEIGHT
	lanes.columns = lane_mode
	lanes.add_theme_constant_override("h_separation", 0 if use_gameplay_skin else 3)
	stage.add_child(lanes)

	var keycodes := input_manager.get_mode_keycodes(lane_mode)
	for lane_index in range(lane_mode):
		_add_lane(
			lanes,
			lane_index,
			input_manager.get_lane_input_label(lane_mode, lane_index, keycodes[lane_index])
		)
	if use_gameplay_skin:
		for divider_index in range(1, 4):
			var divider := ColorRect.new()
			divider.name = "LaneDivider%d" % divider_index
			divider.position = Vector2(92.0 + float(divider_index) * 132.0 - 0.6, 44.0)
			divider.size = Vector2(1.2, 800.0)
			divider.color = Color(0.16, 0.72, 1.0, 0.56)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stage.add_child(divider)

	var progress_track := ColorRect.new()
	progress_track.name = "SongProgressTrack"
	progress_track.anchor_left = 0.055
	progress_track.anchor_top = 0.084
	progress_track.anchor_right = 0.945
	progress_track.anchor_bottom = 0.084
	progress_track.offset_bottom = 3.0
	progress_track.color = Color(1.0, 1.0, 1.0, 0.18)
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.visible = not use_gameplay_skin
	stage.add_child(progress_track)
	if not use_gameplay_skin:
		intro_hidden_controls.append(progress_track)

	progress_fill = ColorRect.new()
	progress_fill.anchor_right = 0.0
	progress_fill.anchor_bottom = 1.0
	progress_fill.color = AuroraUi.TEAL
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(progress_fill)

	progress_label = AuroraUi.make_pixel_label("000 / 000", 9, Color(0.86, 0.92, 1.0, 0.88))
	progress_label.anchor_left = 0.60
	progress_label.anchor_top = 0.087
	progress_label.anchor_right = 0.93
	progress_label.anchor_bottom = 0.116
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.visible = not use_gameplay_skin
	stage.add_child(progress_label)
	if not use_gameplay_skin:
		intro_hidden_controls.append(progress_label)

	var sync_glow := ColorRect.new()
	sync_glow.anchor_left = 0.12 if use_gameplay_skin else 0.025
	sync_glow.anchor_top = 1.0
	sync_glow.anchor_right = 0.88 if use_gameplay_skin else 0.975
	sync_glow.anchor_bottom = 1.0
	sync_glow.offset_top = -HIT_LINE_BOTTOM_OFFSET - HIT_ZONE_HEIGHT * 0.62
	sync_glow.offset_bottom = -HIT_LINE_BOTTOM_OFFSET + HIT_ZONE_HEIGHT * 0.62
	sync_glow.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.12)
	sync_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sync_glow.visible = not use_gameplay_skin
	stage.add_child(sync_glow)

	hit_line = ColorRect.new()
	hit_line.name = "HitLine"
	hit_line.anchor_left = 0.12 if use_gameplay_skin else 0.025
	hit_line.anchor_top = 1.0
	hit_line.anchor_right = 0.88 if use_gameplay_skin else 0.975
	hit_line.anchor_bottom = 1.0
	hit_line.offset_top = -HIT_LINE_BOTTOM_OFFSET - HIT_ZONE_HEIGHT * 0.5
	hit_line.offset_bottom = -HIT_LINE_BOTTOM_OFFSET + HIT_ZONE_HEIGHT * 0.5
	hit_line.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.18) if not use_gameplay_skin else Color(0.0, 0.0, 0.0, 0.0)
	hit_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(hit_line)
	if use_gameplay_skin:
		hit_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		hit_line.position = Vector2(92, 667)
		hit_line.size = Vector2(528, 14)
		for band in [Vector3(0, 14, 0.10), Vector3(3, 8, 0.22), Vector3(5, 4, 0.65), Vector3(6, 2, 1.0)]:
			var light := ColorRect.new()
			light.name = "HitLineGlow"
			light.anchor_right = 1.0
			light.offset_top = band.x
			light.offset_bottom = band.x + band.y
			light.color = Color(0.85, 1.0, 1.0, band.z)
			light.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hit_line.add_child(light)
	else:
		for edge_anchor in [0.0, 1.0]:
			var edge := ColorRect.new()
			edge.anchor_top = edge_anchor
			edge.anchor_right = 1.0
			edge.anchor_bottom = edge_anchor
			edge.offset_top = -1.5
			edge.offset_bottom = 1.5
			edge.color = Color(0.82, 0.98, 1.0, 0.88)
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hit_line.add_child(edge)

		var line_core := ColorRect.new()
		line_core.anchor_top = 0.5
		line_core.anchor_right = 1.0
		line_core.anchor_bottom = 0.5
		line_core.offset_top = -2.0
		line_core.offset_bottom = 2.0
		line_core.color = AuroraUi.TEAL
		line_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit_line.add_child(line_core)

	_build_center_performance_hud(stage)
	_build_fever_display(stage)
	_build_playfield_deck(stage)
	if not use_gameplay_skin:
		_build_cabinet_chrome(stage)


func _build_gameplay_art_overlay() -> void:
	if not use_gameplay_skin:
		return
	var art := Control.new()
	cabinet_art_overlay = art
	art.name = "GameplayCabinetArtwork"
	AuroraUi.fill(art)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.z_index = 3
	art.z_as_relative = false
	skin_canvas.add_child(art)
	# Compress only the outside chrome. The 528px play area stays unchanged.
	# The header has no baked Fever boxes; Fever lives in the lower deck.
	var pieces: Array = [
		[Rect2(467, 0, 141, 61), Rect2(505, 0, 92, 44)],
		[Rect2(1064, 0, 140, 61), Rect2(1075, 0, 91, 44)],
		[Rect2(0, 61, 575, 783), Rect2(201.25, 44, 373.75, 800)],
		[Rect2(1097, 61, 575, 783), Rect2(1097, 44, 373.75, 800)],
		[Rect2(467, 844, 108, 97), Rect2(505, 844, 70, 97)],
		[Rect2(575, 844, 522, 97), Rect2(575, 844, 522, 97)],
		[Rect2(1097, 844, 107, 97), Rect2(1097, 844, 70, 97)],
		[Rect2(575, 790, 50, 54), Rect2(575, 790, 50, 54)],
		[Rect2(1047, 790, 50, 54), Rect2(1047, 790, 50, 54)],
	]
	for piece_rects in pieces:
		var region: Rect2 = piece_rects[0]
		var destination: Rect2 = piece_rects[1]
		var texture := AtlasTexture.new()
		texture.atlas = GAMEPLAY_CABINET_OVERLAY
		texture.region = region
		texture.filter_clip = true
		var piece := TextureRect.new()
		piece.position = destination.position
		piece.size = destination.size
		piece.texture = texture
		piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece.stretch_mode = TextureRect.STRETCH_SCALE
		piece.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(piece)
	var header := ColorRect.new()
	header.name = "CleanCabinetHeader"
	header.position = Vector2(597, 0)
	header.size = Vector2(478, 44)
	header.color = Color(0.004, 0.008, 0.025, 0.98)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(header)
	for height in [5.0, 38.0]:
		var accent := ColorRect.new()
		accent.position = Vector2(597, height)
		accent.size = Vector2(478, 1.5)
		accent.color = Color(0.04, 0.75, 1.0, 0.80) if height < 10.0 else Color(1.0, 0.06, 0.85, 0.80)
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(accent)


func _build_cabinet_chrome(stage: Control) -> void:
	var cyan := Color(0.05, 0.88, 1.0, 0.94)
	var pink := Color(1.0, 0.14, 0.82, 0.94)
	var shadow := Color(0.005, 0.010, 0.04, 0.96)
	_add_chrome_bar(stage, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 17.0, shadow)
	_add_chrome_bar(stage, 0.0, 0.0, 1.0, 0.0, 20.0, 6.0, -20.0, 10.0, cyan)
	_add_chrome_bar(stage, 0.0, 0.0, 0.0, 1.0, 3.0, 16.0, 9.0, -CONTROL_DECK_HEIGHT, cyan)
	_add_chrome_bar(stage, 1.0, 0.0, 1.0, 1.0, -9.0, 16.0, -3.0, -CONTROL_DECK_HEIGHT, pink)
	_add_chrome_bar(stage, 0.0, 1.0, 1.0, 1.0, 22.0, -CONTROL_DECK_HEIGHT, -22.0, -CONTROL_DECK_HEIGHT + 5.0, cyan)
	_add_chrome_bar(stage, 0.0, 1.0, 0.0, 1.0, 28.0, -11.0, 180.0, -7.0, pink)
	_add_chrome_bar(stage, 1.0, 1.0, 1.0, 1.0, -180.0, -11.0, -28.0, -7.0, cyan)


func _add_chrome_bar(stage: Control, left: float, top: float, right: float, bottom: float, x1: float, y1: float, x2: float, y2: float, tint: Color) -> void:
	var bar := ColorRect.new()
	bar.anchor_left = left
	bar.anchor_top = top
	bar.anchor_right = right
	bar.anchor_bottom = bottom
	bar.offset_left = x1
	bar.offset_top = y1
	bar.offset_right = x2
	bar.offset_bottom = y2
	bar.color = tint
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bar)
	cabinet_frame_bars.append(bar)
	intro_hidden_controls.append(bar)


func _build_center_performance_hud(stage: Control) -> void:
	if use_gameplay_skin:
		_build_reference_performance_hud(stage)
		return
	var hud := VBoxContainer.new()
	hud.name = "PerformanceCenter"
	hud.anchor_left = 0.10
	hud.anchor_top = 0.28
	hud.anchor_right = 0.90
	hud.anchor_bottom = 0.61
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 3)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(hud)
	intro_hidden_controls.append(hud)

	combo_caption_label = AuroraUi.make_pixel_label("COMBO", 13, AuroraUi.TEAL)
	combo_caption_label.custom_minimum_size.y = 22.0
	combo_caption_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	combo_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(combo_caption_label)

	combo_label = AuroraUi.make_pixel_label("000", 72, AuroraUi.TEXT)
	combo_label.custom_minimum_size.y = 94.0
	combo_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.94))
	combo_label.add_theme_constant_override("shadow_offset_x", 4)
	combo_label.add_theme_constant_override("shadow_offset_y", 4)
	hud.add_child(combo_label)

	precision_label = AuroraUi.make_pixel_label("RATE  100.00%", 14, Color(0.86, 0.92, 1.0, 0.90))
	precision_label.custom_minimum_size.y = 28.0
	precision_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	precision_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	precision_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(precision_label)

	judgment_label = AuroraUi.make_pixel_label("READY", 44, AuroraUi.GOLD)
	judgment_label.custom_minimum_size.y = 92.0 if use_gameplay_skin else 64.0
	judgment_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	judgment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judgment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	judgment_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	judgment_label.add_theme_constant_override("shadow_offset_x", 3)
	judgment_label.add_theme_constant_override("shadow_offset_y", 3)
	hud.add_child(judgment_label)
	if use_gameplay_skin:
		judgment_art_textures = {
			"PERFECT": PERFECT_JUDGMENT_ART,
			"GREAT": _make_judgment_atlas_texture(150.0),
			"GOOD": _make_judgment_atlas_texture(635.0),
			"MISS": _make_judgment_atlas_texture(1080.0),
		}
		judgment_art = TextureRect.new()
		judgment_art.name = "JudgmentArtwork"
		judgment_art.anchor_left = 0.12
		judgment_art.anchor_top = 0.462
		judgment_art.anchor_right = 0.88
		judgment_art.anchor_bottom = 0.547
		judgment_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		judgment_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		judgment_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		judgment_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		judgment_art.visible = false
		stage.add_child(judgment_art)

	hit_precision_label = AuroraUi.make_pixel_label("", 18, Color.WHITE)
	hit_precision_label.name = "HitPrecisionPercentage"
	hit_precision_label.custom_minimum_size.y = 30.0
	hit_precision_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hit_precision_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_precision_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hit_precision_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hit_precision_label)

	timing_feedback_label = AuroraUi.make_pixel_label("SYNC READY", 8, AuroraUi.MUTED)
	timing_feedback_label.custom_minimum_size.y = 20.0
	timing_feedback_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	timing_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timing_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timing_feedback_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	timing_feedback_label.add_theme_constant_override("shadow_offset_x", 2)
	timing_feedback_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(timing_feedback_label)


func _make_judgment_atlas_texture(top: float) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = JUDGMENT_RATINGS_SHEET
	texture.region = Rect2(20.0, top, 984.0, 300.0)
	texture.filter_clip = true
	return texture


func _reference_label(parent: Control, text: String, font_size: int, color: Color, rect: Rect2) -> Label:
	var label := AuroraUi.make_pixel_label(text, font_size, color)
	label.position = rect.position
	label.size = rect.size
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _build_reference_performance_hud(stage: Control) -> void:
	var hud := Control.new()
	hud.name = "PerformanceCenter"
	AuroraUi.fill(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(hud)
	intro_hidden_controls.append(hud)
	combo_caption_label = _reference_label(hud, "COMBO", 16, AuroraUi.TEAL, Rect2(92, 330, 528, 32))
	combo_label = _reference_label(hud, "000", 54, Color.WHITE, Rect2(92, 356, 528, 73))
	_reference_label(hud, "RATE", 13, AuroraUi.TEAL, Rect2(272, 428, 60, 28))
	precision_label = _reference_label(hud, "100.00%", 13, Color.WHITE, Rect2(337, 428, 116, 28))
	judgment_label = _reference_label(hud, "READY", 36, AuroraUi.TEAL, Rect2(92, 456, 528, 82))
	hit_precision_label = _reference_label(hud, "--", 23, Color.WHITE, Rect2(92, 532, 528, 38))
	hit_precision_label.name = "HitPrecisionPercentage"
	hit_precision_label.visible = false
	timing_feedback_label = _reference_label(hud, "SYNC READY", 8, AuroraUi.MUTED, Rect2(92, 576, 528, 20))
	var perfect_texture := AtlasTexture.new()
	perfect_texture.atlas = PERFECT_JUDGMENT_ART
	perfect_texture.region = Rect2(65, 155, 2025, 430)
	perfect_texture.filter_clip = true
	judgment_art_textures = {
		"PERFECT": perfect_texture,
		"GREAT": _make_judgment_atlas_texture(150.0),
		"GOOD": _make_judgment_atlas_texture(635.0),
		"MISS": _make_judgment_atlas_texture(1080.0),
	}
	judgment_art = TextureRect.new()
	judgment_art.name = "JudgmentArtwork"
	judgment_art.position = Vector2(176, 454)
	judgment_art.size = Vector2(360, 84)
	judgment_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	judgment_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	judgment_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	judgment_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	judgment_art.visible = false
	hud.add_child(judgment_art)


func _build_fever_display(stage: Control) -> void:
	if use_gameplay_skin:
		_build_reference_fever(stage)
		return
	var fever_box := PanelContainer.new() if not use_gameplay_skin else Control.new()
	fever_box.name = "FeverGauge"
	fever_box.anchor_left = 0.0 if use_gameplay_skin else 0.055
	fever_box.anchor_top = 0.012
	fever_box.anchor_right = 1.0 if use_gameplay_skin else 0.945
	fever_box.anchor_bottom = 0.074
	if not use_gameplay_skin:
		var fever_frame := AuroraUi.make_style(
			Color(0.005, 0.012, 0.035, 0.94),
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.78),
			0
		)
		fever_frame.border_width_left = 1
		fever_frame.border_width_top = 2
		fever_frame.border_width_right = 1
		fever_frame.border_width_bottom = 2
		fever_frame.content_margin_left = 12.0
		fever_frame.content_margin_top = 5.0
		fever_frame.content_margin_right = 12.0
		fever_frame.content_margin_bottom = 5.0
		fever_box.add_theme_stylebox_override("panel", fever_frame)
	fever_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(fever_box)
	intro_hidden_controls.append(fever_box)

	var row := HBoxContainer.new()
	row.name = "FeverStatusRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8 if use_gameplay_skin else 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := VBoxContainer.new()
	content.name = "FeverContent"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AuroraUi.fill(content)
	fever_box.add_child(content)
	content.add_child(row)

	fever_label = AuroraUi.make_pixel_label("FEVER 01", 16, AuroraUi.TEAL)
	fever_label.custom_minimum_size = Vector2(150.0 if use_gameplay_skin else 128.0, 28.0)
	fever_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	fever_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(fever_label)

	var segment_row := HBoxContainer.new()
	segment_row.name = "FeverLevelSegments"
	segment_row.add_theme_constant_override("separation", 5)
	segment_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	segment_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(segment_row)
	fever_level_segments.clear()
	fever_level_segment_frames.clear()
	fever_level_segment_fills.clear()
	for level_index in range(FEVER_MAX_LEVEL):
		var segment := Control.new()
		segment.name = "LevelSegment%d" % (level_index + 1)
		segment.custom_minimum_size = Vector2(26.0, 22.0)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var segment_frame := Panel.new()
		AuroraUi.fill(segment_frame)
		segment_frame.name = "LevelOutline"
		segment.add_child(segment_frame)
		var segment_fill := ColorRect.new()
		segment_fill.name = "LevelFill"
		segment_fill.anchor_left = 0.16
		segment_fill.anchor_top = 0.16
		segment_fill.anchor_right = 0.84
		segment_fill.anchor_bottom = 0.84
		segment_fill.color = AuroraUi.TEAL
		segment_fill.visible = false
		segment_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.add_child(segment_fill)
		segment_row.add_child(segment)
		fever_level_segments.append(segment)
		fever_level_segment_frames.append(segment_frame)
		fever_level_segment_fills.append(segment_fill)

	fever_progress_label = AuroraUi.make_pixel_label("00 / 20", 13, Color(0.88, 0.93, 1.0, 0.88))
	fever_progress_label.custom_minimum_size = Vector2(82.0, 26.0)
	fever_progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	fever_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fever_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(fever_progress_label)

	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(2.0, 20.0)
	separator.color = Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.7)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(separator)

	fever_multiplier_label = AuroraUi.make_pixel_label("×1", 22, FEVER_PINK)
	fever_multiplier_label.custom_minimum_size = Vector2(56.0, 28.0)
	fever_multiplier_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	fever_multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fever_multiplier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(fever_multiplier_label)

	_refresh_fever_display()


func _build_reference_fever(stage: Control) -> void:
	var gauge := Control.new()
	gauge.name = "FeverGauge"
	gauge.z_index = 4
	gauge.z_as_relative = false
	gauge.position = Vector2(0, 860)
	gauge.size = Vector2(712, 68)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(gauge)
	intro_hidden_controls.append(gauge)
	var header := Panel.new()
	header.position = Vector2(111, 7)
	header.size = Vector2(485, 49)
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.004, 0.008, 0.026, 0.96)
	header_style.border_color = Color(0.08, 0.80, 1.0, 0.65)
	header_style.set_border_width_all(1)
	header.add_theme_stylebox_override("panel", header_style)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(header)
	fever_label = _reference_label(gauge, "FEVER 01", 14, AuroraUi.TEAL, Rect2(124, 18, 110, 25))
	fever_level_segments.clear()
	fever_level_segment_frames.clear()
	fever_level_segment_fills.clear()
	fever_displayed_level = 0
	for index in range(FEVER_MAX_LEVEL):
		var segment := Control.new()
		segment.name = "LevelSegment%d" % (index + 1)
		segment.position = Vector2(246.0 + float(index) * 29.0, 19)
		segment.size = Vector2(24, 24)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauge.add_child(segment)
		var outline := Panel.new()
		outline.name = "LevelOutline"
		AuroraUi.fill(outline)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.005, 0.015, 0.04, 0.98)
		style.border_color = Color(0.08, 0.7, 1.0, 0.85)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		outline.add_theme_stylebox_override("panel", style)
		segment.add_child(outline)
		var fill := ColorRect.new()
		fill.name = "LevelFill"
		fill.position = Vector2(2, 2)
		fill.size = Vector2(20, 20)
		fill.color = Color(0.04, 0.93, 1.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.add_child(fill)
		fever_level_segments.append(segment)
		fever_level_segment_frames.append(outline)
		fever_level_segment_fills.append(fill)
	fever_progress_label = _reference_label(gauge, "00 / 20", 13, Color.WHITE, Rect2(406, 18, 90, 25))
	var separator := ColorRect.new()
	separator.position = Vector2(513, 18)
	separator.size = Vector2(2, 25)
	separator.color = Color(0.4, 0.95, 1.0)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(separator)
	fever_multiplier_label = _reference_label(gauge, "×1", 22, FEVER_PINK, Rect2(532, 14, 58, 32))
	_refresh_fever_display()


func _refresh_fever_display() -> void:
	if fever_label == null or fever_progress_label == null or fever_multiplier_label == null:
		return
	var display_level := clampi(fever_level, 1, FEVER_MAX_LEVEL)
	fever_label.text = "FEVER %02d" % display_level
	fever_multiplier_label.text = "×%d" % display_level
	fever_label.add_theme_color_override("font_color", AuroraUi.TEAL if use_gameplay_skin else AuroraUi.GOLD if display_level > 1 else AuroraUi.TEAL)
	fever_multiplier_label.add_theme_color_override("font_color", FEVER_PINK if use_gameplay_skin or display_level > 1 else AuroraUi.MUTED)
	if fever_displayed_level != display_level:
		for index in range(fever_level_segments.size()):
			var active := index < display_level
			var segment_frame := fever_level_segment_frames[index]
			segment_frame.visible = true
			if not use_gameplay_skin:
				var segment_style := AuroraUi.make_style(
					Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.86) if active else Color(0.015, 0.030, 0.080, 0.92),
					Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.98) if active else Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.50),
					0
				)
				segment_style.border_width_left = 1
				segment_style.border_width_top = 1
				segment_style.border_width_right = 1
				segment_style.border_width_bottom = 1
				segment_frame.add_theme_stylebox_override("panel", segment_style)
			fever_level_segment_fills[index].visible = use_gameplay_skin and active
		fever_displayed_level = display_level
	if display_level >= FEVER_MAX_LEVEL:
		fever_progress_label.text = "MAX"
	else:
		fever_progress_label.text = "%02d / %02d" % [fever_hits, FEVER_HITS_PER_LEVEL]


func _build_playfield_deck(stage: Control) -> void:
	control_deck = PanelContainer.new()
	control_deck.name = "ControlDeck"
	control_deck.anchor_top = 1.0
	control_deck.anchor_right = 1.0
	control_deck.anchor_bottom = 1.0
	control_deck.offset_top = -CONTROL_DECK_HEIGHT
	var deck_style := AuroraUi.make_style(
		Color(0.006, 0.010, 0.030, 0.97),
		Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.68),
		0
	)
	deck_style.border_width_top = 2
	deck_style.content_margin_left = 22.0
	deck_style.content_margin_top = 16.0
	deck_style.content_margin_right = 22.0
	deck_style.content_margin_bottom = 14.0
	control_deck.add_theme_stylebox_override("panel", deck_style)
	control_deck.visible = not use_gameplay_skin
	stage.add_child(control_deck)
	if not use_gameplay_skin:
		intro_hidden_controls.append(control_deck)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	control_deck.add_child(content)

	var deck_header := HBoxContainer.new()
	content.add_child(deck_header)
	var brand := AuroraUi.make_pixel_label("LIVE LINK // CABINA", 7, Color(0.80, 0.86, 0.98, 0.68))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	deck_header.add_child(brand)
	var chart_online := AuroraUi.make_pixel_label("● CHART ONLINE", 7, AuroraUi.TEAL)
	chart_online.autowrap_mode = TextServer.AUTOWRAP_OFF
	chart_online.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deck_header.add_child(chart_online)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	content.add_child(status_row)

	var speed_badge := PanelContainer.new()
	speed_badge.custom_minimum_size = Vector2(136, 48)
	speed_badge.add_theme_stylebox_override(
		"panel",
		AuroraUi.make_style(
			Color(AuroraUi.CORAL.r, AuroraUi.CORAL.g, AuroraUi.CORAL.b, 0.18),
			Color(AuroraUi.CORAL.r, AuroraUi.CORAL.g, AuroraUi.CORAL.b, 0.82),
			0
		)
	)
	status_row.add_child(speed_badge)
	speed_label = AuroraUi.make_pixel_label("", 9, AuroraUi.TEXT)
	speed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_badge.add_child(speed_label)

	var center_status := PanelContainer.new()
	center_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_status.add_theme_stylebox_override(
		"panel",
		AuroraUi.make_style(
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.05),
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.28),
			0
		)
	)
	status_row.add_child(center_status)
	var video_status := "BGA VIDEO" if background_video_player != null else "PRACTICE VISUAL"
	var visual_label := AuroraUi.make_pixel_label("INPUT READY // %s" % video_status, 7, AuroraUi.MUTED)
	visual_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	visual_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visual_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_status.add_child(visual_label)

	var difficulty := "PRACTICE 04"
	if game_manager.current_chart != null:
		difficulty = "%s %02d" % [
			game_manager.current_chart.difficulty_name.to_upper(),
			game_manager.current_chart.difficulty_level,
		]
	var mode_badge := _make_badge("%dK  %s" % [lane_mode, difficulty], AuroraUi.VIOLET)
	mode_badge.custom_minimum_size = Vector2(190, 48)
	status_row.add_child(mode_badge)


func _build_floating_screen_hud() -> void:
	if use_gameplay_skin:
		_build_reference_screen_hud()
		return
	var song_info := VBoxContainer.new()
	song_info.anchor_left = 0.018
	song_info.anchor_top = 0.022
	song_info.anchor_right = 0.30
	song_info.anchor_bottom = 0.14
	song_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(song_info)
	if use_gameplay_skin:
		song_info.z_index = 3
		song_info.z_as_relative = false
	intro_hidden_controls.append(song_info)

	var title := "AURORA DEMO"
	var artist := "AURORA PROJECT"
	if game_manager.current_song != null:
		title = game_manager.current_song.title.to_upper()
		artist = game_manager.current_song.artist.to_upper()
	var title_label := AuroraUi.make_pixel_label(title, 19, AuroraUi.TEXT)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	song_info.add_child(title_label)
	var artist_label := AuroraUi.make_pixel_label(artist, 12, AuroraUi.TEAL)
	artist_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	song_info.add_child(artist_label)

	var right_hud := VBoxContainer.new()
	right_hud.anchor_left = 0.76
	right_hud.anchor_top = 0.022
	right_hud.anchor_right = 0.982
	right_hud.anchor_bottom = 0.16
	right_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_hud)
	if use_gameplay_skin:
		right_hud.z_index = 3
		right_hud.z_as_relative = false
	intro_hidden_controls.append(right_hud)

	var score_caption := AuroraUi.make_pixel_label("SCORE", 12, Color(0.82, 0.88, 0.98, 0.78))
	score_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_hud.add_child(score_caption)
	score_label = AuroraUi.make_pixel_label("0000000", 30, AuroraUi.GOLD)
	score_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_hud.add_child(score_label)
	var pause_hint := AuroraUi.make_pixel_label(
		AuroraLocale.text("ESC / %s  PAUSA")
		% input_manager.get_controller_action_label("pause"),
		8,
		AuroraUi.MUTED
	)
	pause_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_hud.add_child(pause_hint)
	if not side_tracks.is_empty():
		var automatic_hint := AuroraUi.make_pixel_label("L SHIFT / R SHIFT // LATERALES", 7, AuroraUi.MUTED)
		automatic_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_hud.add_child(automatic_hint)
	cumulative_label = AuroraUi.make_pixel_label("ACUMULADO  %d" % game_manager.cumulative_combo, 8, AuroraUi.TEAL)
	cumulative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_hud.add_child(cumulative_label)


func _build_reference_screen_hud() -> void:
	var screen_hud := Control.new()
	screen_hud.name = "ScreenHud"
	AuroraUi.fill(screen_hud)
	screen_hud.z_index = 3
	screen_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin_canvas.add_child(screen_hud)
	intro_hidden_controls.append(screen_hud)
	if game_manager.current_song != null:
		var title := _reference_label(screen_hud, game_manager.current_song.title.to_upper(), 10, Color(1, 1, 1, 0.80), Rect2(24, 16, 420, 22))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var artist := _reference_label(screen_hud, game_manager.current_song.artist.to_upper(), 8, AuroraUi.TEAL, Rect2(24, 39, 420, 18))
		artist.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var caption := _reference_label(screen_hud, "SCORE", 13, AuroraUi.TEAL, Rect2(1400, 22, 242, 26))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label = _reference_label(screen_hud, "0000000", 28, Color.WHITE, Rect2(1400, 48, 242, 40))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index in range(7):
		var underline := ColorRect.new()
		underline.position = Vector2(1480 + index * 22, 91)
		underline.size = Vector2(18, 2)
		underline.color = AuroraUi.TEAL if index < 5 else FEVER_PINK
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen_hud.add_child(underline)
	cumulative_label = _reference_label(screen_hud, "ACUMULADO  %d" % game_manager.cumulative_combo, 7, AuroraUi.TEAL, Rect2(1400, 103, 242, 18))
	cumulative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pause_hint := _reference_label(screen_hud, "ESC  PAUSA", 7, AuroraUi.MUTED, Rect2(1400, 123, 242, 18))
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_auto_side_tracks(stage: Control) -> void:
	if game_manager.current_chart == null or game_manager.current_song == null:
		return
	chart_side_notes = game_manager.current_chart.load_side_notes(
		game_manager.current_song.bpm, game_manager.current_song.duration_seconds
	)
	if chart_side_notes.is_empty():
		return
	for side in range(2):
		var track = AUTO_SIDE_TRACK.new()
		track.name = "ShiftSideTrack%d" % side
		track.anchor_left = float(side)
		track.anchor_right = float(side)
		track.anchor_bottom = 1.0
		track.offset_left = 11.0 if side == 0 else -30.0
		track.offset_right = 30.0 if side == 0 else -11.0
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.deck_height = 97.0 if use_gameplay_skin else CONTROL_DECK_HEIGHT
		track.hit_offset = SKIN_HIT_OFFSET if use_gameplay_skin else RECEPTOR_TOP_OFFSET + HIT_LINE_GAP
		track.notes = chart_side_notes.filter(func(note: Dictionary) -> bool: return int(note["side"]) == side)
		track.tint = AuroraUi.VIOLET if side == 0 else AuroraUi.TEAL
		stage.add_child(track)
		side_tracks.append(track)
		for index in range(track.notes.size()):
			var entry: Dictionary = track.notes[index].duplicate()
			entry["track"] = track
			entry["track_index"] = index
			entry["state"] = "pending"
			side_note_entries.append(entry)


func _make_playfield_frame_style() -> StyleBoxFlat:
	if use_gameplay_skin:
		var transparent_style := AuroraUi.make_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0)
		transparent_style.border_width_left = 0
		transparent_style.border_width_top = 0
		transparent_style.border_width_right = 0
		transparent_style.border_width_bottom = 0
		transparent_style.content_margin_left = 0.0
		transparent_style.content_margin_top = 0.0
		transparent_style.content_margin_right = 0.0
		transparent_style.content_margin_bottom = 0.0
		return transparent_style
	var style := AuroraUi.make_style(
		Color(0.006, 0.009, 0.026, float(settings_manager.get_setting("lane_opacity", 0.82))),
		Color(0.70, 0.60, 1.0, 0.92 * float(settings_manager.get_setting("lane_opacity", 0.82))),
		0
	)
	style.border_width_left = 2
	style.border_width_top = 0
	style.border_width_right = 2
	style.border_width_bottom = 0
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _add_lane(parent: GridContainer, lane_index: int, key_name: String) -> void:
	var tint := _get_visual_lane_tint(lane_index)
	var lane := PanelContainer.new()
	lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lane.add_theme_stylebox_override("panel", _make_lane_style(tint, false))
	parent.add_child(lane)
	lane_panels.append(lane)
	lane_pressed.append(false)

	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.add_child(content)

	var note_layer := Control.new()
	note_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_layer.clip_contents = true
	content.add_child(note_layer)
	lane_note_layers.append(note_layer)

	var receptor: Control
	if use_gameplay_skin:
		receptor = NEON_RECEPTOR.new()
		receptor.tint = tint
	else:
		receptor = PanelContainer.new()
	receptor.name = "Receptor%02d" % (lane_index + 1)
	receptor.anchor_left = 0.025 if use_gameplay_skin else 0.055
	receptor.anchor_top = 1.0
	receptor.anchor_right = 0.975 if use_gameplay_skin else 0.945
	receptor.anchor_bottom = 1.0
	receptor.offset_top = -SKIN_RECEPTOR_TOP if use_gameplay_skin else -RECEPTOR_TOP_OFFSET
	receptor.offset_bottom = -SKIN_RECEPTOR_BOTTOM if use_gameplay_skin else -RECEPTOR_BOTTOM_OFFSET
	if not use_gameplay_skin:
		receptor.add_theme_stylebox_override("panel", _make_receptor_style(tint, false))
	content.add_child(receptor)
	lane_receptors.append(receptor)
	lane_receptor_tints.append(tint)

	var label := AuroraUi.make_pixel_label(key_name, 8 if use_gameplay_skin else 14, Color(0.7, 0.85, 0.96, 0.65) if use_gameplay_skin else AuroraUi.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if use_gameplay_skin:
		label.anchor_top = 1.0
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.offset_top = 9.0
		label.offset_bottom = 25.0
	receptor.add_child(label)
	lane_labels.append(label)


func _make_badge(text: String, color: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size.x = maxf(78.0, float(text.length()) * 10.0 + 32.0)
	badge.add_theme_stylebox_override(
		"panel",
		AuroraUi.make_style(
			Color(color.r, color.g, color.b, 0.12),
			Color(color.r, color.g, color.b, 0.64),
			0
		)
	)
	var label := AuroraUi.make_pixel_label(text, 9, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	return badge


func _get_visual_lane_tint(lane_index: int) -> Color:
	if use_gameplay_skin:
		return Color(0.02, 0.86, 1.0) if lane_index % 2 == 0 else Color(1.0, 0.08, 0.92)
	return LANE_COLORS[lane_index]


func _make_lane_style(tint: Color, active: bool) -> StyleBoxFlat:
	var opacity := float(settings_manager.get_setting("lane_opacity", 0.82))
	var lane_alpha := opacity * 0.77 if use_gameplay_skin else 0.0
	var border_alpha := (0.18 if active else 0.08) * opacity
	var style := AuroraUi.make_style(
		Color(0.008, 0.012, 0.028, lane_alpha),
		Color(tint.r, tint.g, tint.b, border_alpha),
		0
	)
	if use_gameplay_skin:
		style.set_border_width_all(0)
	style.content_margin_left = 0.0 if use_gameplay_skin else 1.0
	style.content_margin_right = 0.0 if use_gameplay_skin else 1.0
	style.content_margin_top = 0.0 if use_gameplay_skin else 1.0
	style.content_margin_bottom = 0.0 if use_gameplay_skin else 1.0
	return style


func _make_receptor_style(tint: Color, active: bool) -> StyleBoxFlat:
	var style := AuroraUi.make_style(
		Color(tint.r, tint.g, tint.b, 0.88 if active else 0.36),
		Color(0.95, 0.99, 1.0, 1.0) if active else Color(tint.r, tint.g, tint.b, 0.98),
		0
	)
	style.border_width_left = 2
	style.border_width_top = 3 if active else 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style


func _make_receptor_texture() -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = LANE_RECEPTOR_KEY_ART
	texture.region = Rect2(0.0, 170.0, 1536.0, 684.0)
	return texture


func _make_hit_line_texture() -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = HIT_LINE_ART
	texture.region = Rect2(0.0, 280.0, 2156.0, 160.0)
	return texture


func _process(delta: float) -> void:
	ambient_time += delta
	if start_gate_active:
		_update_ambient_frame()
		return
	if not gameplay_finished:
		_update_song_clock(delta)
		_update_ambient_frame()
		_spawn_upcoming_notes()
		_update_active_notes()
		_update_side_notes()
		for track in side_tracks:
			track.set_playback_time(gameplay_time, _get_note_travel_time())
		_update_practice_beat()
		_check_level_finished()

	for lane_index in range(lane_mode):
		var action := input_manager.get_lane_action(lane_mode, lane_index)
		var is_pressed := Input.is_action_pressed(action)
		if is_pressed != lane_pressed[lane_index]:
			lane_pressed[lane_index] = is_pressed
			_set_lane_pressed(lane_index, is_pressed)
		if Input.is_action_just_pressed(action):
			_register_lane_input(lane_index)
		if Input.is_action_just_released(action):
			_register_lane_release(lane_index)


func _set_lane_pressed(lane_index: int, pressed: bool) -> void:
	var tint := _get_visual_lane_tint(lane_index)
	var receptor := lane_receptors[lane_index]
	lane_panels[lane_index].add_theme_stylebox_override("panel", _make_lane_style(tint, pressed))
	if use_gameplay_skin:
		receptor.set_pressed(pressed)
	else:
		var receptor_panel := receptor as PanelContainer
		receptor_panel.add_theme_stylebox_override("panel", _make_receptor_style(tint, pressed))
	lane_labels[lane_index].add_theme_color_override("font_color", Color.WHITE if pressed else AuroraUi.TEXT)


func _register_lane_input(lane_index: int) -> void:
	if gameplay_finished:
		return

	var timing_offset := float(settings_manager.get_setting("timing_offset_ms", 0)) / 1000.0
	var judgment_time := gameplay_time + timing_offset
	var earliest_note: Dictionary = {}
	var earliest_time := INF
	var earliest_error := INF
	for note_entry in active_notes:
		if int(note_entry["lane"]) != lane_index:
			continue
		if bool(note_entry.get("holding", false)):
			continue
		var note_time := float(note_entry["time"])
		var error := absf(note_time - judgment_time)
		if error > MISS_WINDOW:
			continue
		# When timing windows overlap, consume notes in chart order so one tap
		# cannot skip an earlier note for a slightly closer upcoming note.
		if note_time < earliest_time or (is_equal_approx(note_time, earliest_time) and error < earliest_error):
			earliest_time = note_time
			earliest_error = error
			earliest_note = note_entry

	if earliest_note.is_empty():
		return
	if not str(earliest_note.get("shift_id", "")).is_empty():
		_try_start_shift_pair(
			str(earliest_note["shift_id"]),
			judgment_time
		)
		return

	var signed_error := judgment_time - earliest_time
	if float(earliest_note.get("duration", 0.0)) >= HOLD_NOTE_MIN_DURATION:
		_start_hold_note(earliest_note, signed_error)
		return

	var judgment := _get_judgment_for_error(signed_error)
	var timing_score := _get_timing_score(signed_error)
	match judgment:
		"PERFECT":
			_judge_note(earliest_note, judgment, 1.0, timing_score, AuroraUi.TEAL)
		"GREAT":
			_judge_note(earliest_note, judgment, 0.80, timing_score, AuroraUi.GOLD)
		_:
			_judge_note(earliest_note, "GOOD", 0.50, timing_score, AuroraUi.CORAL)
	_record_timing_sample(signed_error)
	_show_timing_feedback(signed_error)


func _register_lane_release(lane_index: int) -> void:
	if gameplay_finished:
		return
	var held_note: Dictionary = {}
	var earliest_end := INF
	for note_entry in active_notes:
		if int(note_entry["lane"]) != lane_index or not bool(note_entry.get("holding", false)):
			continue
		var note_end := float(note_entry["time"]) + float(note_entry.get("duration", 0.0))
		if note_end < earliest_end:
			earliest_end = note_end
			held_note = note_entry
	if held_note.is_empty():
		return
	if not str(held_note.get("shift_id", "")).is_empty():
		var pair_id := str(held_note["shift_id"])
		if _are_shift_lanes_pressed(pair_id):
			return
		_finish_shift_hold(pair_id, gameplay_time + float(settings_manager.get_setting("timing_offset_ms", 0)) / 1000.0)
		return

	var timing_offset := float(settings_manager.get_setting("timing_offset_ms", 0)) / 1000.0
	_finish_hold_note(held_note, gameplay_time + timing_offset)


func _register_side_input(side: int) -> void:
	if gameplay_finished or start_gate_active:
		return
	var judgment_time := gameplay_time + float(settings_manager.get_setting("timing_offset_ms", 0)) / 1000.0
	var closest: Dictionary = {}
	var closest_error := INF
	for entry in side_note_entries:
		if int(entry["side"]) != side or str(entry["state"]) != "pending":
			continue
		var error := absf(float(entry["time"]) - judgment_time)
		if error < closest_error:
			closest_error = error
			closest = entry
	if closest.is_empty() or closest_error > MISS_WINDOW:
		return
	var signed_error := judgment_time - float(closest["time"])
	if float(closest.get("duration", 0.0)) >= HOLD_NOTE_MIN_DURATION:
		closest["state"] = "holding"
		var track = closest["track"]
		track.set_note_holding(int(closest["track_index"]), true)
		_show_judgment("DOBLE HOLD", AuroraUi.GOLD)
		_record_timing_sample(signed_error)
		_show_timing_feedback(signed_error)
		return
	_record_timing_sample(signed_error)
	_show_timing_feedback(signed_error)
	var judgment := _get_judgment_for_error(signed_error)
	_judge_side_note(closest, judgment, 1.0 if judgment == "PERFECT" else 0.80 if judgment == "GREAT" else 0.50, _get_timing_score(signed_error))


func _register_side_release(side: int) -> void:
	if gameplay_finished:
		return
	for entry in side_note_entries:
		if int(entry["side"]) == side and str(entry["state"]) == "holding":
			_finish_side_hold(entry, gameplay_time + float(settings_manager.get_setting("timing_offset_ms", 0)) / 1000.0)
			return


func _finish_side_hold(entry: Dictionary, release_time: float) -> void:
	var start_time := float(entry["time"])
	var duration := maxf(float(entry["duration"]), HOLD_NOTE_MIN_DURATION)
	var release_error := release_time - start_time - duration
	var result := _get_hold_release_result((release_time - start_time) / duration, release_error)
	_record_timing_sample(release_error)
	_show_timing_feedback(release_error)
	_judge_side_note(entry, str(result["judgment"]), float(result["accuracy"]), int(result["score"]))


func _update_side_notes() -> void:
	var judgment_time := gameplay_time + float(settings_manager.get_setting("timing_offset_ms", 0)) / 1000.0
	for entry in side_note_entries:
		var state := str(entry["state"])
		if state == "pending" and judgment_time - float(entry["time"]) > MISS_WINDOW:
			_judge_side_note(entry, "MISS", 0.0, 0)
		elif state == "holding" and judgment_time - float(entry["time"]) - float(entry["duration"]) > GOOD_WINDOW:
			_finish_side_hold(entry, judgment_time)


func _judge_side_note(entry: Dictionary, judgment: String, accuracy_value: float, base_score: int) -> void:
	if str(entry["state"]) == "done":
		return
	entry["state"] = "done"
	var track = entry["track"]
	track.resolve_note(int(entry["track_index"]))
	var color := AuroraUi.CORAL if judgment == "MISS" else AuroraUi.TEAL if judgment == "PERFECT" else AuroraUi.GOLD
	_record_judgment(judgment, accuracy_value, base_score, color, -1, true, 1200.0 if float(entry.get("duration", 0.0)) >= HOLD_NOTE_MIN_DURATION else 1000.0)


func _are_shift_lanes_pressed(pair_id: String) -> bool:
	var pair_value = active_shift_pairs.get(pair_id, null)
	if not (pair_value is Dictionary):
		return false
	var pair: Dictionary = pair_value
	for lane_value in pair.get("lanes", []):
		var lane := int(lane_value)
		if lane < 0 or lane >= lane_mode:
			return false
		if not Input.is_action_pressed(input_manager.get_lane_action(lane_mode, lane)):
			return false
	return true


func _try_start_shift_pair(pair_id: String, judgment_time: float) -> void:
	var pair_value = active_shift_pairs.get(pair_id, null)
	if not (pair_value is Dictionary) or not _are_shift_lanes_pressed(pair_id):
		return
	var pair: Dictionary = pair_value
	if bool(pair.get("holding", false)):
		return
	var entries: Array = pair.get("entries", [])
	if entries.size() != 2 or not active_notes.has(entries[0]) or not active_notes.has(entries[1]):
		return
	var primary: Dictionary = entries[0]
	var signed_error := judgment_time - float(primary["time"])
	if absf(signed_error) > MISS_WINDOW:
		return
	var duration := float(primary.get("duration", 0.0))
	if duration >= HOLD_NOTE_MIN_DURATION:
		pair["holding"] = true
		active_shift_pairs[pair_id] = pair
		for entry_value in entries:
			var entry: Dictionary = entry_value
			entry["holding"] = true
			var node := entry.get("node", null) as PanelContainer
			if node != null and is_instance_valid(node):
				node.modulate = Color(1.25, 1.20, 1.05, 1.0)
		_record_timing_sample(signed_error)
		_show_timing_feedback(signed_error)
		_show_judgment("SHIFT HOLD", AuroraUi.GOLD)
		return
	var judgment := _get_judgment_for_error(signed_error)
	var accuracy := 1.0 if judgment == "PERFECT" else 0.80 if judgment == "GREAT" else 0.50
	var score_value := _get_timing_score(signed_error)
	_record_timing_sample(signed_error)
	_show_timing_feedback(signed_error)
	_judge_shift_pair(pair_id, judgment, accuracy, score_value, AuroraUi.GOLD)


func _finish_shift_hold(pair_id: String, release_time: float) -> void:
	var pair_value = active_shift_pairs.get(pair_id, null)
	if not (pair_value is Dictionary):
		return
	var pair: Dictionary = pair_value
	var entries: Array = pair.get("entries", [])
	if entries.is_empty() or not active_notes.has(entries[0]):
		return
	var primary: Dictionary = entries[0]
	var start_time := float(primary["time"])
	var duration := maxf(float(primary.get("duration", 0.0)), HOLD_NOTE_MIN_DURATION)
	var release_error := release_time - (start_time + duration)
	var result := _get_hold_release_result((release_time - start_time) / duration, release_error)
	_record_timing_sample(release_error)
	_show_timing_feedback(release_error)
	_judge_shift_pair(
		pair_id,
		str(result["judgment"]),
		float(result["accuracy"]),
		int(result["score"]),
		AuroraUi.GOLD
	)


func _judge_shift_pair(
	pair_id: String,
	judgment: String,
	accuracy_value: float,
	base_score: int,
	color: Color
) -> void:
	var pair_value = active_shift_pairs.get(pair_id, null)
	if not (pair_value is Dictionary):
		return
	var pair: Dictionary = pair_value
	active_shift_pairs.erase(pair_id)
	for entry_value in pair.get("entries", []):
		var entry: Dictionary = entry_value
		_judge_note(entry, judgment, accuracy_value, base_score, color)


func _start_hold_note(note_entry: Dictionary, signed_error: float) -> void:
	note_entry["holding"] = true
	note_entry["hold_start_error"] = signed_error
	var note_node := note_entry["node"] as PanelContainer
	if note_node != null and is_instance_valid(note_node):
		note_node.modulate = Color(1.24, 1.24, 1.24, 1.0)
	_record_timing_sample(signed_error)
	_show_timing_feedback(signed_error)
	_show_judgment("HOLD", AuroraUi.TEAL)


func _finish_hold_note(note_entry: Dictionary, release_time: float) -> void:
	var start_time := float(note_entry["time"])
	var duration := maxf(float(note_entry.get("duration", 0.0)), HOLD_NOTE_MIN_DURATION)
	var end_time := start_time + duration
	var progress := (release_time - start_time) / duration
	var release_error := release_time - end_time
	var release_result := _get_hold_release_result(progress, release_error)
	var judgment := str(release_result["judgment"])
	var accuracy_value := float(release_result["accuracy"])
	var base_score := int(release_result["score"])
	var color := AuroraUi.CORAL
	match judgment:
		"PERFECT":
			color = AuroraUi.TEAL
		"GREAT":
			color = AuroraUi.GOLD

	_record_timing_sample(release_error)
	_show_timing_feedback(release_error)
	_judge_note(note_entry, judgment, accuracy_value, base_score, color)


func _get_hold_release_result(progress: float, release_error: float) -> Dictionary:
	if progress < 0.5:
		return {"judgment": "MISS", "accuracy": 0.0, "score": 0}

	var absolute_error := absf(release_error)
	var hold_score := _get_timing_score(release_error, 1200.0, 1080.0, 900.0, 550.0, 200.0)
	if absolute_error <= PERFECT_WINDOW:
		return {"judgment": "PERFECT", "accuracy": 1.0, "score": hold_score}
	if absolute_error <= GREAT_WINDOW:
		return {"judgment": "GREAT", "accuracy": 0.80, "score": hold_score}
	if absolute_error <= GOOD_WINDOW:
		return {"judgment": "GOOD", "accuracy": 0.50, "score": hold_score}

	# Late releases preserve the combo while their score falls toward the miss limit.
	return {"judgment": "GOOD", "accuracy": 0.25, "score": hold_score}


func _get_judgment_for_error(error_seconds: float) -> String:
	var absolute_error := absf(error_seconds)
	if absolute_error <= PERFECT_WINDOW:
		return "PERFECT"
	if absolute_error <= GREAT_WINDOW:
		return "GREAT"
	if absolute_error <= MISS_WINDOW:
		return "GOOD"
	return "MISS"


func _get_timing_score(
	error_seconds: float,
	perfect_score: float = 1000.0,
	perfect_edge_score: float = 950.0,
	great_edge_score: float = 750.0,
	good_edge_score: float = 450.0,
	miss_edge_score: float = 0.0
) -> int:
	# Preserve judgment bands while scoring each hit from its exact timing offset.
	var absolute_error := absf(error_seconds)
	if absolute_error > MISS_WINDOW:
		return 0
	if absolute_error <= PERFECT_WINDOW:
		return roundi(
			lerpf(perfect_score, perfect_edge_score, absolute_error / PERFECT_WINDOW)
		)
	if absolute_error <= GREAT_WINDOW:
		var great_progress := (absolute_error - PERFECT_WINDOW) / (GREAT_WINDOW - PERFECT_WINDOW)
		return roundi(lerpf(perfect_edge_score, great_edge_score, great_progress))
	if absolute_error <= GOOD_WINDOW:
		var good_progress := (absolute_error - GREAT_WINDOW) / (GOOD_WINDOW - GREAT_WINDOW)
		return roundi(lerpf(great_edge_score, good_edge_score, good_progress))
	var late_progress := (absolute_error - GOOD_WINDOW) / (MISS_WINDOW - GOOD_WINDOW)
	return roundi(lerpf(good_edge_score, miss_edge_score, late_progress))


func _initialize_gameplay() -> void:
	var bpm := 128.0
	var duration := 24.0
	if game_manager.current_song != null:
		bpm = game_manager.current_song.bpm
		duration = game_manager.current_song.duration_seconds

	var chart := game_manager.current_chart
	if chart == null:
		chart = ChartData.new()
		chart.key_count = lane_mode
		chart.difficulty_name = "PRACTICE"
		chart.difficulty_level = 4
	chart_notes = chart.load_notes(bpm, duration)
	chart_shift_notes = chart.load_shift_notes(bpm, duration)
	cinematic_sections = chart.load_cinematic_sections()
	_rebuild_cinematic_sections()
	chart_end_time = chart.get_chart_end_time(bpm, duration)
	# The editor stores the detected media duration in SongData. It is the
	# authoritative level boundary, so an intentional outro without notes plays
	# completely. Chart time is only a fallback for legacy data without duration.
	level_end_time = duration if duration > 0.0 else chart_end_time + 0.65

	next_note_index = 0
	next_shift_note_index = 0
	# Give even a note at time zero its full approach from above the playfield.
	gameplay_time = -_get_preparation_duration()
	media_started = false
	next_beat_time = 0.0
	gameplay_finished = false
	_setup_audio_players()
	_refresh_progress()


func _setup_audio_players() -> void:
	countdown_sound_player = AudioStreamPlayer.new()
	countdown_sound_player.name = "StartCountdownSound"
	countdown_sound_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	countdown_sound_player.volume_db = -2.0
	add_child(countdown_sound_player)
	last_countdown_value = 4
	song_player = AudioStreamPlayer.new()
	song_player.name = "SongAudio"
	song_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	add_child(song_player)

	beat_player = AudioStreamPlayer.new()
	beat_player.name = "PracticeBeat"
	beat_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	beat_player.stream = _create_click_stream(180.0, 0.075, 0.42)
	add_child(beat_player)

	miss_sound_player = AudioStreamPlayer.new()
	miss_sound_player.name = "MissSound"
	miss_sound_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	miss_sound_player.stream = _create_click_stream(118.0, 0.12, 0.20)
	miss_sound_player.volume_db = -4.0
	add_child(miss_sound_player)

	if game_manager.current_song != null and game_manager.current_song.audio != null:
		song_player.stream = game_manager.current_song.audio
		song_player.volume_db = clampf(
			game_manager.current_song.audio_gain_db,
			-18.0,
			12.0
		)


func _build_start_gate() -> void:
	start_gate_panel = PanelContainer.new()
	start_gate_panel.name = "StartGate"
	start_gate_panel.anchor_left = 0.5
	start_gate_panel.anchor_top = 0.5
	start_gate_panel.anchor_right = 0.5
	start_gate_panel.anchor_bottom = 0.5
	start_gate_panel.offset_left = -250.0
	start_gate_panel.offset_top = -76.0
	start_gate_panel.offset_right = 250.0
	start_gate_panel.offset_bottom = 76.0
	start_gate_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if use_gameplay_skin:
		start_gate_panel.z_index = 4
		start_gate_panel.z_as_relative = false
	start_gate_panel.add_theme_stylebox_override(
		"panel",
		AuroraUi.make_style(
			Color(0.006, 0.010, 0.030, 0.94),
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.90),
			0
		)
	)
	add_child(start_gate_panel)

	var initial_prompt := AuroraLocale.text("PREPÁRATE")
	if game_manager.editor_test_active:
		initial_prompt = (
			AuroraLocale.text("ESPACIO O %s\nPARA INICIAR")
			% input_manager.get_controller_action_label("confirm")
		)
	start_prompt_label = AuroraUi.make_pixel_label(
		initial_prompt,
		15,
		AuroraUi.TEXT
	)
	start_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_prompt_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.96)
	)
	start_prompt_label.add_theme_constant_override("shadow_offset_x", 5)
	start_prompt_label.add_theme_constant_override("shadow_offset_y", 5)
	start_gate_panel.add_child(start_prompt_label)
	start_gate_panel.hide()


func _begin_start_countdown() -> void:
	# Keep the clean black preparation; cues follow the song clock below.
	if not start_gate_active:
		return
	start_countdown_active = false
	start_gate_active = false
	start_gate_panel.hide()
	if ui_feedback != null:
		ui_feedback.play_confirm()
	_apply_visual_settings()
	_spawn_upcoming_notes()
	_update_active_notes()


func _start_gameplay_media() -> void:
	if media_started:
		return
	media_started = true
	var song_gain := clampf(game_manager.current_song.audio_gain_db, -18.0, 12.0) if game_manager.current_song != null else 0.0
	media_fade_tween = create_tween()
	media_fade_tween.set_parallel(true)
	media_fade_tween.set_trans(Tween.TRANS_SINE)
	media_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if background_video_player != null:
		if song_player == null or song_player.stream == null:
			background_video_player.volume_db = -48.0
		background_video_player.play()
		if game_manager.current_song != null:
			background_video_player.stream_position = (
				game_manager.current_song.background_video_start_seconds
			)
		if song_player == null or song_player.stream == null:
			media_fade_tween.tween_property(background_video_player, "volume_db", song_gain, 0.65)
	if song_player != null and song_player.stream != null:
		song_player.volume_db = -48.0
		song_player.play()
		media_fade_tween.tween_property(song_player, "volume_db", song_gain, 0.65)
	_apply_visual_settings()


func _apply_intro_visibility() -> void:
	var preparing := not media_started
	if preparation_blackout != null:
		preparation_blackout.visible = preparing
	for control in intro_hidden_controls:
		control.visible = not preparing


func _create_click_stream(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := maxi(1, roundi(float(sample_rate) * duration))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(sample_rate)
		var envelope := exp(-time * 34.0)
		var wave := sin(TAU * frequency * time) + sin(TAU * frequency * 2.01 * time) * 0.18
		var sample := clampi(roundi(wave * envelope * amplitude * 32767.0), -32768, 32767)
		bytes.encode_s16(sample_index * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream


func _update_song_clock(delta: float) -> void:
	if not media_started:
		gameplay_time += delta
		var countdown_value := ceili(-gameplay_time)
		if countdown_value >= 1 and countdown_value <= 3 and countdown_value < last_countdown_value:
			_play_start_countdown_cue(countdown_value)
		if gameplay_time >= 0.0:
			gameplay_time = 0.0
			_play_start_countdown_cue(0)
			_start_gameplay_media()
		return
	if song_player != null and song_player.playing:
		var audio_time := song_player.get_playback_position()
		audio_time += AudioServer.get_time_since_last_mix()
		audio_time -= AudioServer.get_output_latency()
		gameplay_time = maxf(gameplay_time, audio_time)
	elif background_video_player != null and background_video_player.is_playing():
		var video_time := background_video_player.stream_position
		if game_manager.current_song != null:
			video_time -= game_manager.current_song.background_video_start_seconds
		gameplay_time = maxf(gameplay_time, video_time)
	else:
		gameplay_time += delta


func _get_note_travel_time() -> float:
	var note_speed := float(settings_manager.get_setting("note_speed", 5.5))
	var normalized := clampf((note_speed - 1.0) / 9.0, 0.0, 1.0)
	# Spread the slider perceptually: higher settings gain speed much sooner,
	# while preserving a broad slow-to-fast range across levels 1 through 10.
	return SLOWEST_NOTE_TRAVEL_TIME * pow(
		FASTEST_NOTE_TRAVEL_TIME / SLOWEST_NOTE_TRAVEL_TIME,
		normalized
	)


func _get_preparation_duration() -> float:
	return maxf(3.05, _get_note_travel_time() + 0.15 + EXTRA_PREPARATION_SECONDS)


func _play_start_countdown_cue(value: int) -> void:
	last_countdown_value = value
	if countdown_sound_player == null:
		return
	var bank = preload("res://src/audio/GameSoundBank.gd")
	countdown_sound_player.stop()
	countdown_sound_player.stream = bank.COUNTDOWN.get(value)
	countdown_sound_player.play()


func _spawn_upcoming_notes() -> void:
	var travel_time := _get_note_travel_time()
	while next_note_index < chart_notes.size():
		var note_data: Dictionary = chart_notes[next_note_index]
		if float(note_data["time"]) - gameplay_time > travel_time:
			break
		_spawn_note(note_data)
		next_note_index += 1
	while next_shift_note_index < chart_shift_notes.size():
		var shift_data: Dictionary = chart_shift_notes[next_shift_note_index]
		if float(shift_data["time"]) - gameplay_time > travel_time:
			break
		_spawn_shift_pair(shift_data, next_shift_note_index)
		next_shift_note_index += 1


func _spawn_shift_pair(shift_data: Dictionary, sequence: int) -> void:
	var lanes: Array = shift_data.get("lanes", [])
	if lanes.size() != 2:
		return
	var shift_id := "shift_%d" % sequence
	var start_index := active_notes.size()
	for lane_index in range(2):
		_spawn_note({
			"time": float(shift_data["time"]),
			"lane": int(lanes[lane_index]),
			"duration": float(shift_data.get("duration", 0.0)),
			"shift_id": shift_id,
			"shift_secondary": lane_index == 1,
		})
	var entries: Array = []
	for entry_index in range(start_index, active_notes.size()):
		entries.append(active_notes[entry_index])
	if entries.size() == 2:
		active_shift_pairs[shift_id] = {
			"entries": entries,
			"lanes": [int(lanes[0]), int(lanes[1])],
			"holding": false,
		}


func _spawn_note(note_data: Dictionary) -> void:
	var lane := int(note_data["lane"])
	if lane < 0 or lane >= lane_note_layers.size():
		return
	var is_shift := note_data.has("shift_id")
	var tint := AuroraUi.GOLD if is_shift else _get_visual_lane_tint(lane)
	var duration := float(note_data.get("duration", 0.0))
	var is_hold := duration >= HOLD_NOTE_MIN_DURATION
	var note := PanelContainer.new()
	note.name = "ShiftHold" if is_shift and is_hold else "ShiftNote" if is_shift else "HoldNote" if is_hold else "TapNote"
	note.anchor_left = 0.0
	note.anchor_right = 1.0
	note.offset_top = -NOTE_HALF_HEIGHT
	note.offset_bottom = NOTE_HALF_HEIGHT
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note_style := AuroraUi.make_style(
		Color(tint.r, tint.g, tint.b, 0.86 if is_hold else 0.92),
		Color(0.92, 0.98, 1.0, 1.0),
		0
	)
	note_style.border_width_left = 2
	note_style.border_width_top = 2
	note_style.border_width_right = 2
	note_style.border_width_bottom = 2
	note_style.content_margin_left = 0.0
	note_style.content_margin_top = 0.0
	note_style.content_margin_right = 0.0
	note_style.content_margin_bottom = 0.0
	note.add_theme_stylebox_override("panel", note_style)
	if use_gameplay_skin:
		note.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var visual := NEON_NOTE.new()
		visual.name = "NeonNoteVisual"
		visual.tint = tint
		visual.is_hold = is_hold
		note.add_child(visual)
		visual.set_reduced_motion(bool(settings_manager.get_setting("reduced_motion", false)))
	elif is_hold:
		var hold_visual := Control.new()
		hold_visual.name = "HoldVisual"
		hold_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.add_child(hold_visual)

		var hold_head := ColorRect.new()
		hold_head.name = "HoldHead"
		hold_head.anchor_top = 1.0
		hold_head.anchor_right = 1.0
		hold_head.anchor_bottom = 1.0
		hold_head.offset_top = -NOTE_HALF_HEIGHT * 2.0
		hold_head.color = Color(tint.r, tint.g, tint.b, 0.98)
		hold_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold_visual.add_child(hold_head)

		var hold_tail := ColorRect.new()
		hold_tail.name = "HoldTail"
		hold_tail.anchor_right = 1.0
		hold_tail.offset_bottom = 5.0
		hold_tail.color = Color(0.92, 0.98, 1.0, 0.92)
		hold_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold_visual.add_child(hold_tail)
	lane_note_layers[lane].add_child(note)
	active_notes.append({
		"time": float(note_data["time"]),
		"lane": lane,
		"duration": duration,
		"node": note,
		"holding": false,
		"shift_id": str(note_data.get("shift_id", "")),
		"shift_secondary": bool(note_data.get("shift_secondary", false)),
	})


func _update_active_notes() -> void:
	var timing_offset := float(settings_manager.get_setting("timing_offset_ms", 0)) / 1000.0
	var judgment_time := gameplay_time + timing_offset
	var travel_time := _get_note_travel_time()

	for note_entry in active_notes.duplicate():
		var lane := int(note_entry["lane"])
		var note_node := note_entry["node"] as PanelContainer
		if note_node == null or not is_instance_valid(note_node):
			active_notes.erase(note_entry)
			continue
		var layer := lane_note_layers[lane]
		var receptor_y := maxf(layer.size.y - (SKIN_HIT_OFFSET if use_gameplay_skin else RECEPTOR_TOP_OFFSET + HIT_LINE_GAP), 100.0)
		var note_time := float(note_entry["time"])
		var duration := float(note_entry.get("duration", 0.0))
		var is_hold := duration >= HOLD_NOTE_MIN_DURATION
		if use_gameplay_skin:
			var visual := note_node.get_node_or_null("NeonNoteVisual")
			if visual != null:
				visual.set_holding(bool(note_entry.get("holding", false)))
		var progress := 1.0 - (note_time - gameplay_time) / travel_time
		var note_y := lerpf(-NOTE_HALF_HEIGHT, receptor_y, progress)
		if bool(note_entry.get("holding", false)):
			note_y = receptor_y
		var hold_height := 0.0
		if is_hold:
			var travel_distance := maxf(receptor_y + NOTE_HALF_HEIGHT, 1.0)
			var remaining_duration := duration
			if bool(note_entry.get("holding", false)):
				remaining_duration = maxf(note_time + duration - gameplay_time, 0.0)
			hold_height = maxf(
				remaining_duration / travel_time * travel_distance,
				NOTE_HALF_HEIGHT * 2.0
			)
		note_node.offset_top = note_y - NOTE_HALF_HEIGHT - hold_height
		note_node.offset_bottom = note_y + NOTE_HALF_HEIGHT

		var shift_id := str(note_entry.get("shift_id", ""))
		if not shift_id.is_empty():
			if bool(note_entry.get("shift_secondary", false)):
				continue
			if bool(note_entry.get("holding", false)):
				var shift_hold_end := note_time + duration
				if judgment_time - shift_hold_end > GOOD_WINDOW:
					_finish_shift_hold(shift_id, judgment_time)
			elif judgment_time - note_time > MISS_WINDOW:
				_judge_shift_pair(shift_id, "MISS", 0.0, 0, AuroraUi.CORAL)
			continue

		if bool(note_entry.get("holding", false)):
			var hold_end_time := note_time + duration
			if judgment_time - hold_end_time > GOOD_WINDOW:
				_finish_hold_note(note_entry, judgment_time)
			else:
				var hold_progress := clampf((judgment_time - note_time) / maxf(duration, 0.001), 0.0, 1.0)
				note_node.modulate = Color(
					1.08 + hold_progress * 0.20,
					1.08 + hold_progress * 0.20,
					1.08 + hold_progress * 0.20,
					1.0
				)
		elif judgment_time - note_time > MISS_WINDOW:
			_judge_note(note_entry, "MISS", 0.0, 0, AuroraUi.CORAL)
	if use_gameplay_skin:
		for lane_index in range(lane_receptors.size()):
			var holding := false
			for entry in active_notes:
				if int(entry["lane"]) == lane_index and bool(entry.get("holding", false)):
					holding = true
					break
			lane_receptors[lane_index].set_holding(holding)


func _judge_note(
	note_entry: Dictionary,
	judgment: String,
	accuracy_value: float,
	base_score: int,
	color: Color
) -> void:
	if not active_notes.has(note_entry):
		return
	active_notes.erase(note_entry)
	var note_node := note_entry["node"] as PanelContainer
	if note_node != null and is_instance_valid(note_node):
		note_node.queue_free()

	var counts_as_one := not bool(note_entry.get("shift_secondary", false))
	if not counts_as_one:
		if judgment != "MISS":
			_play_hit_effect(int(note_entry["lane"]), color, judgment)
		return
	_record_judgment(judgment, accuracy_value, base_score, color, int(note_entry["lane"]), not str(note_entry.get("shift_id", "")).is_empty(), 1200.0 if float(note_entry.get("duration", 0.0)) >= HOLD_NOTE_MIN_DURATION else 1000.0)


func _record_judgment(judgment: String, accuracy_value: float, base_score: int, color: Color, lane_index: int, preserve_combo_on_miss: bool = false, maximum_note_score: float = 1000.0) -> void:
	_set_hit_percentage(float(base_score) / maximum_note_score * 100.0 if judgment != "MISS" else 0.0)
	judged_count += 1
	accuracy_points += accuracy_value
	if judgment == "MISS":
		miss_count += 1
		if not preserve_combo_on_miss:
			combo = 0
		score_streak = 0
		fever_hits = 0
		fever_level = 1
		if not preserve_combo_on_miss:
			_reset_combo_feedback()
		_show_miss_timing_feedback()
		if lane_index >= 0:
			_play_miss_effect(lane_index)
		_play_miss_sound()
	else:
		score_streak += 1
		if fever_level < FEVER_MAX_LEVEL:
			fever_hits += 1
			if fever_hits >= FEVER_HITS_PER_LEVEL:
				fever_level = mini(fever_level + 1, FEVER_MAX_LEVEL)
				fever_hits = 0
				fever_max_level = maxi(fever_max_level, fever_level)
		var combo_gain := fever_level
		combo += combo_gain
		combo_earned += combo_gain
		max_combo = maxi(max_combo, combo)
		score += base_score + mini(score_streak * 5, 500)
		match judgment:
			"PERFECT":
				perfect_count += 1
			"GREAT":
				great_count += 1
			_:
				good_count += 1
		_play_combo_feedback()
		if lane_index >= 0:
			_play_hit_effect(lane_index, color, judgment)

	_show_judgment(judgment, color)
	_refresh_fever_display()
	_refresh_score_display()
	_refresh_progress()


func _show_judgment(text: String, color: Color) -> void:
	if judgment_art != null:
		var judgment_texture: Texture2D = judgment_art_textures.get(text)
		var has_judgment_art := judgment_texture != null
		judgment_art.texture = judgment_texture
		judgment_art.visible = has_judgment_art
		if use_gameplay_skin:
			var art_width := 360.0
			match text:
				"GREAT": art_width = 240.0
				"GOOD": art_width = 232.0
				"MISS": art_width = 220.0
			judgment_art.position.x = (712.0 - art_width) * 0.5
			judgment_art.size.x = art_width
		judgment_label.modulate = Color(1.0, 1.0, 1.0, 0.0) if has_judgment_art else Color.WHITE
	judgment_label.text = text
	judgment_label.add_theme_color_override("font_color", color)
	_animate_judgment_feedback()


func _set_hit_percentage(percentage: float) -> void:
	if hit_precision_label == null:
		return
	var value := clampf(percentage, 0.0, 100.0)
	hit_precision_label.text = "%d%%" % roundi(value)
	hit_precision_label.visible = true
	hit_precision_label.add_theme_color_override("font_color", Color(0.78, 1.0, 1.0) if value >= 95.0 else AuroraUi.GOLD if value >= 75.0 else AuroraUi.CORAL)


func _animate_judgment_feedback() -> void:
	if not use_gameplay_skin or judgment_art == null:
		return
	if judgment_feedback_tween != null and judgment_feedback_tween.is_valid():
		judgment_feedback_tween.kill()
	judgment_art.position.y = 454.0
	judgment_art.modulate = Color.WHITE
	hit_precision_label.scale = Vector2.ONE
	if bool(settings_manager.get_setting("reduced_motion", false)):
		return
	judgment_art.position.y -= 5.0
	judgment_art.modulate = Color(1.13, 1.13, 1.13, 0.84)
	hit_precision_label.pivot_offset = hit_precision_label.size * 0.5
	hit_precision_label.scale = Vector2.ONE * 1.10
	judgment_feedback_tween = create_tween()
	judgment_feedback_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	judgment_feedback_tween.set_parallel(true)
	judgment_feedback_tween.tween_property(judgment_art, "position:y", 454.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	judgment_feedback_tween.tween_property(judgment_art, "modulate", Color.WHITE, 0.18)
	judgment_feedback_tween.tween_property(hit_precision_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_combo_feedback() -> void:
	if combo_label == null or combo_caption_label == null:
		return
	var milestone := _is_combo_milestone(combo)
	combo_caption_label.text = "%d CHAIN" % combo if milestone else "COMBO"
	combo_caption_label.add_theme_color_override("font_color", AuroraUi.GOLD if milestone else AuroraUi.TEAL)

	if combo_feedback_tween != null and combo_feedback_tween.is_valid():
		combo_feedback_tween.kill()
	combo_label.pivot_offset = combo_label.size * 0.5
	combo_label.scale = Vector2.ONE
	combo_label.modulate = Color.WHITE
	if bool(settings_manager.get_setting("reduced_motion", false)):
		return

	var pulse_scale := 1.16 if milestone else 1.07
	combo_label.scale = Vector2.ONE * pulse_scale
	combo_label.modulate = Color(1.22, 1.12, 0.76, 1.0) if milestone else Color(1.08, 1.14, 1.24, 1.0)
	combo_feedback_tween = combo_label.create_tween()
	combo_feedback_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	combo_feedback_tween.set_parallel(true)
	combo_feedback_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	combo_feedback_tween.tween_property(combo_label, "modulate", Color.WHITE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _reset_combo_feedback() -> void:
	if combo_feedback_tween != null and combo_feedback_tween.is_valid():
		combo_feedback_tween.kill()
	if combo_label != null:
		combo_label.scale = Vector2.ONE
		combo_label.modulate = Color.WHITE
	if combo_caption_label != null:
		combo_caption_label.text = "COMBO"
		combo_caption_label.add_theme_color_override("font_color", AuroraUi.TEAL)


func _is_combo_milestone(value: int) -> bool:
	return value > 0 and value % 10 == 0


func _show_timing_feedback(error_seconds: float) -> void:
	_set_hit_percentage(float(_get_timing_score(error_seconds)) / 10.0)
	if timing_feedback_label == null:
		return
	var error_ms := roundi(error_seconds * 1000.0)
	if absi(error_ms) <= 8:
		timing_feedback_label.text = "ON TIME  %dms" % absi(error_ms)
		timing_feedback_label.add_theme_color_override("font_color", AuroraUi.TEAL)
	elif error_ms < 0:
		timing_feedback_label.text = "EARLY  %dms" % error_ms
		timing_feedback_label.add_theme_color_override("font_color", AuroraUi.VIOLET)
	else:
		timing_feedback_label.text = "LATE  +%dms" % error_ms
		timing_feedback_label.add_theme_color_override("font_color", AuroraUi.CORAL)


func _show_miss_timing_feedback() -> void:
	if timing_feedback_label == null:
		return
	timing_feedback_label.text = "NO INPUT"
	timing_feedback_label.add_theme_color_override("font_color", AuroraUi.CORAL)


func _record_timing_sample(error_seconds: float) -> void:
	var error_ms := error_seconds * 1000.0
	timing_error_total_ms += error_ms
	timing_sample_count += 1
	if error_ms < -8.0:
		early_hit_count += 1
	elif error_ms > 8.0:
		late_hit_count += 1
	else:
		on_time_hit_count += 1


func _refresh_score_display() -> void:
	combo_label.text = "%03d" % combo
	score_label.text = "%07d" % score
	var accuracy := 100.0 if judged_count == 0 else accuracy_points / float(judged_count) * 100.0
	precision_label.text = ("%.2f%%" if use_gameplay_skin else "RATE  %.2f%%") % accuracy


func _refresh_progress() -> void:
	var total_notes := _get_total_judgment_count()
	if progress_label != null:
		progress_label.text = "%03d / %03d" % [judged_count, total_notes]
	if progress_fill != null:
		var ratio := 0.0 if total_notes <= 0 else clampf(float(judged_count) / float(total_notes), 0.0, 1.0)
		progress_fill.anchor_right = ratio


func _get_total_judgment_count() -> int:
	return chart_notes.size() + chart_shift_notes.size() + chart_side_notes.size()


func _play_hit_effect(lane_index: int, _color: Color, judgment: String = "PERFECT") -> void:
	if not bool(settings_manager.get_setting("show_hit_effects", true)):
		return
	var receptor := lane_receptors[lane_index]
	if use_gameplay_skin:
		var quality := 1.0 if judgment == "PERFECT" else 0.70 if judgment == "GREAT" else 0.42
		receptor.flash_hit(quality)
		return
	var resting_tint := Color.WHITE
	if use_gameplay_skin and not lane_pressed[lane_index]:
		resting_tint = lane_receptor_tints[lane_index]
	receptor.modulate = Color(1.45, 1.45, 1.45, 1.0)
	var flash := receptor.create_tween()
	flash.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	flash.tween_property(receptor, "modulate", resting_tint, 0.12)

	if bool(settings_manager.get_setting("screen_shake_enabled", true)) and not bool(settings_manager.get_setting("reduced_motion", false)):
		frame_panel.pivot_offset = frame_panel.size * 0.5
		frame_panel.rotation = deg_to_rad(0.22 if lane_index % 2 == 0 else -0.22)
		var shake := frame_panel.create_tween()
		shake.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		shake.tween_property(frame_panel, "rotation", 0.0, 0.09)


func _play_miss_effect(lane_index: int) -> void:
	if not bool(settings_manager.get_setting("show_hit_effects", true)):
		return
	if lane_index < 0 or lane_index >= lane_receptors.size():
		return
	var previous_tween = lane_miss_feedback_tweens.get(lane_index)
	if previous_tween is Tween and previous_tween.is_valid():
		previous_tween.kill()

	var receptor := lane_receptors[lane_index]
	if use_gameplay_skin:
		receptor.flash_miss()
		return
	var resting_tint := Color.WHITE
	if use_gameplay_skin and not lane_pressed[lane_index]:
		resting_tint = lane_receptor_tints[lane_index]
	receptor.modulate = Color(1.0, 0.26, 0.38, 1.0)
	var flash := receptor.create_tween()
	flash.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	flash.tween_property(
		receptor,
		"modulate",
		resting_tint,
		maxf(miss_feedback_duration, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lane_miss_feedback_tweens[lane_index] = flash


func _play_miss_sound() -> void:
	if miss_sound_player == null or miss_sound_player.stream == null:
		return
	miss_sound_player.stop()
	miss_sound_player.play()


func _update_practice_beat() -> void:
	if game_manager.current_song != null and game_manager.current_song.audio != null:
		return
	if background_video_player != null:
		return
	var bpm := 128.0
	if game_manager.current_song != null:
		bpm = game_manager.current_song.bpm
	var beat_seconds := 60.0 / maxf(bpm, 1.0)
	if gameplay_time + 0.001 >= next_beat_time:
		beat_player.pitch_scale = 1.22 if roundi(next_beat_time / beat_seconds) % 4 == 0 else 1.0
		beat_player.volume_db = linear_to_db(maxf(float(settings_manager.get_setting("music_volume", 0.85)) * 0.42, 0.001))
		beat_player.play()
		next_beat_time += beat_seconds


func _check_level_finished() -> void:
	if gameplay_finished:
		return
	_try_start_clear_celebration()
	# Music/video keep running under the celebration. Neither the last note nor
	# the effect's completion is allowed to truncate a longer authored outro.
	var pending_clear := clear_ready_time >= 0.0 and clear_celebration == null
	var running_clear := clear_celebration != null and bool(clear_celebration.running)
	if _has_reached_level_end() and not pending_clear and not running_clear:
		_finish_gameplay()


func _try_start_clear_celebration() -> void:
	if clear_celebration != null or not media_started:
		return
	if judged_count != _get_total_judgment_count() or not active_notes.is_empty():
		return
	# A hold is judged on release, never on its head. Also wait for the actual
	# chart tail so an early accepted release cannot show the badge prematurely.
	if gameplay_time < chart_end_time or not PERFECT_PLAY.qualifies(_build_result_data()):
		return
	if clear_ready_time < 0.0:
		clear_ready_time = gameplay_time + CLEAR_CELEBRATION_DELAY
	if gameplay_time < clear_ready_time:
		return
	clear_celebration = PERFECT_PLAY.new()
	clear_celebration.name = "PerfectPlayCelebration"
	add_child(clear_celebration)
	# The last hit feedback gives way to the compact clear badge.
	if judgment_feedback_tween != null and judgment_feedback_tween.is_valid():
		judgment_feedback_tween.kill()
	judgment_label.hide()
	if judgment_art != null:
		judgment_art.hide()
	if hit_precision_label != null:
		hit_precision_label.hide()
	timing_feedback_label.hide()
	clear_celebration.play(bool(settings_manager.get_setting("reduced_motion", false)))


func _has_reached_level_end() -> bool:
	return level_end_time > 0.0 and gameplay_time >= level_end_time


func _finish_gameplay() -> void:
	if gameplay_finished:
		return
	gameplay_finished = true
	if song_player != null:
		song_player.stop()
	if background_video_player != null:
		background_video_player.paused = true
	var result := _build_result_data()
	result["clear_celebration_played"] = clear_celebration != null
	game_manager.complete_song(result)
	_show_finished_results()


func _show_finished_results() -> void:
	scene_manager.load_scene("results")


func _build_result_data() -> Dictionary:
	var accuracy := 100.0 if judged_count == 0 else accuracy_points / float(judged_count) * 100.0
	var average_timing_ms := 0
	if timing_sample_count > 0:
		average_timing_ms = roundi(timing_error_total_ms / float(timing_sample_count))
	return {
		"score": score,
		"accuracy": accuracy,
		"max_combo": max_combo,
		"combo_earned": combo_earned,
		"fever_reached": fever_max_level > 1,
		"fever_max_level": fever_max_level,
		"perfect": perfect_count,
		"great": great_count,
		"good": good_count,
		"miss": miss_count,
		"total_notes": _get_total_judgment_count(),
		"mode": "%dK" % lane_mode,
		"average_timing_ms": average_timing_ms,
		"timing_samples": timing_sample_count,
		"early_hits": early_hit_count,
		"late_hits": late_hit_count,
		"on_time_hits": on_time_hit_count,
	}


func _update_ambient_frame() -> void:
	if frame_panel == null:
		return
	var enabled := bool(settings_manager.get_setting("background_animation_enabled", true))
	var reduced := bool(settings_manager.get_setting("reduced_motion", false))
	var track_alpha := _get_cinematic_opacity()
	if cabinet_art_overlay != null:
		var lane_alpha := clampf(float(settings_manager.get_setting("lane_opacity", 0.82)), 0.0, 1.0)
		cabinet_art_overlay.modulate = Color(1.0, 1.0, 1.0, lane_alpha * track_alpha)
	if not enabled or reduced:
		frame_panel.modulate = Color(1.0, 1.0, 1.0, track_alpha)
		return
	var intensity := float(settings_manager.get_setting("background_animation_intensity", 3))
	var pulse := 0.94 + sin(ambient_time * (0.7 + intensity * 0.08)) * 0.06
	frame_panel.modulate = Color(pulse, pulse, 1.0, track_alpha)


func _apply_visual_settings() -> void:
	var dim := float(settings_manager.get_setting("background_dim", 0.46))
	dim_overlay.color = Color(0.0, 0.0, 0.0, clampf(dim, 0.0, 1.0))
	var show_labels := bool(settings_manager.get_setting("show_lane_labels", true))
	for label in lane_labels:
		label.visible = show_labels
	if use_gameplay_skin:
		for receptor in lane_receptors:
			receptor.effects_enabled = bool(settings_manager.get_setting("show_hit_effects", true))
			receptor.reduced_motion = bool(settings_manager.get_setting("reduced_motion", false))
		for entry in active_notes:
			var node := entry["node"] as Control
			if is_instance_valid(node):
				var visual := node.get_node_or_null("NeonNoteVisual")
				if visual != null:
					visual.set_reduced_motion(bool(settings_manager.get_setting("reduced_motion", false)))
	if background_video_player != null:
		var background_enabled := bool(settings_manager.get_setting("background_animation_enabled", true))
		background_video_player.visible = background_enabled and media_started
		background_video_player.modulate = Color.WHITE
	var opacity := clampf(float(settings_manager.get_setting("lane_opacity", 0.82)), 0.0, 1.0)
	if cabinet_chrome_visual != null:
		cabinet_chrome_visual.modulate = Color(1.0, 1.0, 1.0, opacity)
	for frame_bar in cabinet_frame_bars:
		if is_instance_valid(frame_bar):
			frame_bar.modulate = Color(1.0, 1.0, 1.0, opacity)
	frame_panel.add_theme_stylebox_override("panel", _make_playfield_frame_style())
	var deck_style := control_deck.get_theme_stylebox("panel") as StyleBoxFlat
	deck_style.bg_color.a = opacity
	deck_style.border_color.a = 0.68 * opacity
	for rail in track_rails:
		rail.self_modulate.a = opacity
	_rebuild_cinematic_sections()
	_update_ambient_frame()
	for lane_index in range(lane_panels.size()):
		_set_lane_pressed(lane_index, lane_pressed[lane_index])
	_update_speed_label()
	_apply_intro_visibility()


func _rebuild_cinematic_sections() -> void:
	var timing_guard := absf(float(settings_manager.get_setting("timing_offset_ms", 0))) / 1000.0
	safe_cinematic_sections = CINEMATICS.safe_sections(
		cinematic_sections, chart_notes, _get_note_travel_time(), MISS_WINDOW + timing_guard
	)


func _get_cinematic_opacity() -> float:
	if not media_started or start_gate_active or not bool(settings_manager.get_setting("cinematic_sections_enabled", true)):
		return 1.0
	return CINEMATICS.opacity_at(safe_cinematic_sections, gameplay_time)


func _update_speed_label() -> void:
	if speed_label != null:
		speed_label.text = "SPEED  %.1fx" % float(settings_manager.get_setting("note_speed", 5.5))


func _on_setting_changed(key: String, _value) -> void:
	if key in [
		"note_speed",
		"timing_offset_ms",
		"background_animation_enabled",
		"background_animation_intensity",
		"background_dim",
		"lane_opacity",
		"cinematic_sections_enabled",
		"show_lane_labels",
		"reduced_motion",
	]:
		_apply_visual_settings()


func _on_input_device_changed(_using_controller: bool) -> void:
	var keycodes := input_manager.get_mode_keycodes(lane_mode)
	for lane_index in range(mini(lane_labels.size(), keycodes.size())):
		lane_labels[lane_index].text = input_manager.get_lane_input_label(
			lane_mode,
			lane_index,
			keycodes[lane_index]
		)


func _get_lane_mode() -> int:
	if game_manager.current_chart != null and game_manager.current_chart.key_count in [4, 6, 8]:
		return game_manager.current_chart.key_count
	return 4


func _setup_pause_menu() -> void:
	pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	if use_gameplay_skin:
		pause_menu.z_index = 5
		pause_menu.z_as_relative = false
	add_child(pause_menu)
	pause_menu.restart_requested.connect(_restart_song)
	pause_menu.song_select_requested.connect(_return_to_song_select)
	pause_menu.main_menu_requested.connect(_return_to_main_menu)
	pause_menu.set_editor_test_mode(game_manager.editor_test_active)
	pause_menu.set_track_context(game_manager.current_song, game_manager.current_chart)


func _restart_song() -> void:
	scene_manager.load_scene("gameplay")


func _return_to_song_select() -> void:
	_fade_gameplay_audio_out(0.45 if game_manager.editor_test_active else 0.22)
	if game_manager.editor_test_active:
		scene_manager.load_scene("editor")
		return
	game_manager.stop_song()
	scene_manager.load_scene("song_select")


func _return_to_main_menu() -> void:
	_fade_gameplay_audio_out(0.22)
	game_manager.stop_song()
	scene_manager.load_scene("main_menu")


func _fade_gameplay_audio_out(fade_seconds: float) -> void:
	if media_fade_tween != null and media_fade_tween.is_valid():
		media_fade_tween.kill()
	media_fade_tween = create_tween()
	media_fade_tween.set_parallel(true)
	media_fade_tween.set_trans(Tween.TRANS_SINE)
	media_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if song_player != null and song_player.playing:
		media_fade_tween.tween_property(song_player, "volume_db", -48.0, fade_seconds)
	if background_video_player != null and background_video_player.is_playing():
		media_fade_tween.tween_property(background_video_player, "volume_db", -48.0, fade_seconds)


func _open_pause_menu() -> void:
	if pause_menu == null or gameplay_finished:
		return
	if ui_feedback != null:
		ui_feedback.play_pause()
	pause_menu.set_playback_progress(gameplay_time, level_end_time)
	pause_menu.open_menu()


func _input(event: InputEvent) -> void:
	if gameplay_finished:
		return
	if event is InputEventJoypadButton:
		if event.pressed:
			if input_manager.controller_event_matches(event, "confirm"):
				if start_gate_active and not start_countdown_active:
					_begin_start_countdown()
					get_viewport().set_input_as_handled()
			elif input_manager.controller_event_matches(event, "pause"):
				_open_pause_menu()
				get_viewport().set_input_as_handled()
			elif input_manager.controller_event_matches(event, "shift_left"):
				if not side_pressed[0]:
					side_pressed[0] = true
					_register_side_input(0)
				get_viewport().set_input_as_handled()
			elif input_manager.controller_event_matches(event, "shift_right"):
				if not side_pressed[1]:
					side_pressed[1] = true
					_register_side_input(1)
				get_viewport().set_input_as_handled()
		else:
			var side := -1
			if int(event.button_index) == input_manager.get_controller_action_button("shift_left"):
				side = 0
			elif int(event.button_index) == input_manager.get_controller_action_button("shift_right"):
				side = 1
			if side >= 0:
				side_pressed[side] = false
				_register_side_release(side)
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_SHIFT or event.physical_keycode == KEY_SHIFT) and event.location in [KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT]:
			var side := 0 if event.location == KEY_LOCATION_LEFT else 1
			if not side_pressed[side]:
				side_pressed[side] = true
				_register_side_input(side)
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_SPACE:
				if start_gate_active and not start_countdown_active:
					_begin_start_countdown()
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_open_pause_menu()
				get_viewport().set_input_as_handled()
	elif event is InputEventKey and not event.pressed and (event.keycode == KEY_SHIFT or event.physical_keycode == KEY_SHIFT) and event.location in [KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT]:
		var side := 0 if event.location == KEY_LOCATION_LEFT else 1
		side_pressed[side] = false
		_register_side_release(side)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	start_countdown_token += 1
	if get_tree() != null:
		get_tree().paused = false
