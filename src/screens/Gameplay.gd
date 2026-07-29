extends Control

class_name Gameplay

const PAUSE_MENU_SCENE := preload("res://src/screens/pause/PauseMenu.tscn")
const PERFECT_WINDOW := 0.065
const GREAT_WINDOW := 0.115
const GOOD_WINDOW := 0.170
const MISS_WINDOW := 0.220
const CONTROL_DECK_HEIGHT := 150.0
const RECEPTOR_TOP_OFFSET := 64.0
const RECEPTOR_BOTTOM_OFFSET := 10.0
const NOTE_HALF_HEIGHT := 10.0
const HOLD_NOTE_MIN_DURATION := 0.18
const HIT_ZONE_HEIGHT := 40.0
const HIT_LINE_GAP := NOTE_HALF_HEIGHT * 3.0
const HIT_LINE_BOTTOM_OFFSET := CONTROL_DECK_HEIGHT + RECEPTOR_TOP_OFFSET + HIT_LINE_GAP
const LANE_COLORS: Array[Color] = [
	Color(0.08, 0.86, 1.0),
	Color(0.42, 0.24, 1.0),
	Color(1.0, 0.20, 0.72),
	Color(0.08, 0.86, 1.0),
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

var lane_mode := 4
var lane_panels: Array[PanelContainer] = []
var lane_receptors: Array[PanelContainer] = []
var lane_labels: Array[Label] = []
var lane_note_layers: Array[Control] = []
var lane_pressed: Array[bool] = []

var score := 0
var combo := 0
var max_combo := 0
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
var next_note_index := 0
var next_beat_time := 0.0
var gameplay_finished := false
var start_gate_active := true
var start_countdown_active := false
var start_countdown_token := 0
var start_countdown_step_seconds := 0.75

var chart_notes: Array[Dictionary] = []
var active_notes: Array[Dictionary] = []
var song_player: AudioStreamPlayer
var background_video_player: VideoStreamPlayer
var beat_player: AudioStreamPlayer
var miss_sound_player: AudioStreamPlayer

var score_label: Label
var combo_label: Label
var combo_caption_label: Label
var precision_label: Label
var judgment_label: Label
var timing_feedback_label: Label
var speed_label: Label
var progress_label: Label
var progress_fill: ColorRect
var frame_panel: PanelContainer
var hit_line: ColorRect
var control_deck: PanelContainer
var dim_overlay: ColorRect
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
	start_gate_active = game_manager.editor_test_active
	lane_mode = _get_lane_mode()
	setup_ui()
	_setup_pause_menu()
	_initialize_gameplay()
	if not start_gate_active:
		_start_gameplay_media()
	settings_manager.setting_changed.connect(_on_setting_changed)
	input_manager.input_device_changed.connect(_on_input_device_changed)


func setup_ui() -> void:
	AuroraUi.clear(self)
	lane_panels.clear()
	lane_receptors.clear()
	lane_labels.clear()
	lane_note_layers.clear()
	lane_pressed.clear()
	lane_miss_feedback_tweens.clear()
	active_notes.clear()

	AuroraUi.add_background(self)
	_add_stage_background()
	_build_compact_playfield()
	_build_floating_screen_hud()
	_apply_visual_settings()
	_build_start_gate()


func _add_stage_background() -> void:
	background_video_player = null
	if game_manager.current_song != null and game_manager.current_song.background_video != null:
		background_video_player = VideoStreamPlayer.new()
		background_video_player.name = "BackgroundVideo"
		AuroraUi.fill(background_video_player)
		background_video_player.stream = game_manager.current_song.background_video
		background_video_player.expand = true
		background_video_player.loop = false
		background_video_player.autoplay = false
		background_video_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		background_video_player.volume_db = -80.0 if game_manager.current_song.audio != null else 0.0
		background_video_player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		background_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background_video_player)

	dim_overlay = ColorRect.new()
	AuroraUi.fill(dim_overlay)
	dim_overlay.color = Color(0.0, 0.005, 0.02, 0.34)
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim_overlay)

	var top_shade := ColorRect.new()
	top_shade.anchor_right = 1.0
	top_shade.offset_bottom = 118.0
	top_shade.color = Color(0.0, 0.005, 0.025, 0.54)
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_shade)

	var bottom_shade := ColorRect.new()
	bottom_shade.anchor_top = 1.0
	bottom_shade.anchor_right = 1.0
	bottom_shade.anchor_bottom = 1.0
	bottom_shade.offset_top = -170.0
	bottom_shade.color = Color(0.0, 0.005, 0.025, 0.58)
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_shade)


func _build_compact_playfield() -> void:
	var track_width := 640.0 + float(lane_mode - 4) * 64.0
	frame_panel = PanelContainer.new()
	frame_panel.name = "PlayfieldFrame"
	frame_panel.anchor_left = 0.5
	frame_panel.anchor_right = 0.5
	frame_panel.anchor_bottom = 1.0
	frame_panel.offset_left = -track_width * 0.5
	frame_panel.offset_right = track_width * 0.5
	frame_panel.add_theme_stylebox_override("panel", _make_playfield_frame_style())
	add_child(frame_panel)

	var stage := Control.new()
	stage.name = "PlayfieldStage"
	frame_panel.add_child(stage)

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

	var lanes := GridContainer.new()
	lanes.name = "Lanes"
	lanes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lanes.offset_left = 14.0
	lanes.offset_right = -14.0
	lanes.offset_bottom = -CONTROL_DECK_HEIGHT
	lanes.columns = lane_mode
	lanes.add_theme_constant_override("h_separation", 3)
	stage.add_child(lanes)

	var keycodes := input_manager.get_mode_keycodes(lane_mode)
	for lane_index in range(lane_mode):
		_add_lane(
			lanes,
			lane_index,
			input_manager.get_lane_input_label(lane_mode, lane_index, keycodes[lane_index])
		)

	var progress_track := ColorRect.new()
	progress_track.anchor_left = 0.055
	progress_track.anchor_top = 0.022
	progress_track.anchor_right = 0.945
	progress_track.anchor_bottom = 0.022
	progress_track.offset_bottom = 5.0
	progress_track.color = Color(1.0, 1.0, 1.0, 0.18)
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(progress_track)

	progress_fill = ColorRect.new()
	progress_fill.anchor_right = 0.0
	progress_fill.anchor_bottom = 1.0
	progress_fill.color = AuroraUi.TEAL
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(progress_fill)

	progress_label = AuroraUi.make_pixel_label("000 / 000", 9, Color(0.86, 0.92, 1.0, 0.88))
	progress_label.anchor_left = 0.55
	progress_label.anchor_top = 0.035
	progress_label.anchor_right = 0.93
	progress_label.anchor_bottom = 0.072
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(progress_label)

	var sync_glow := ColorRect.new()
	sync_glow.anchor_left = 0.025
	sync_glow.anchor_top = 1.0
	sync_glow.anchor_right = 0.975
	sync_glow.anchor_bottom = 1.0
	sync_glow.offset_top = -HIT_LINE_BOTTOM_OFFSET - HIT_ZONE_HEIGHT * 0.62
	sync_glow.offset_bottom = -HIT_LINE_BOTTOM_OFFSET + HIT_ZONE_HEIGHT * 0.62
	sync_glow.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.12)
	sync_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(sync_glow)

	hit_line = ColorRect.new()
	hit_line.name = "HitLine"
	hit_line.anchor_left = 0.025
	hit_line.anchor_top = 1.0
	hit_line.anchor_right = 0.975
	hit_line.anchor_bottom = 1.0
	hit_line.offset_top = -HIT_LINE_BOTTOM_OFFSET - HIT_ZONE_HEIGHT * 0.5
	hit_line.offset_bottom = -HIT_LINE_BOTTOM_OFFSET + HIT_ZONE_HEIGHT * 0.5
	hit_line.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.18)
	hit_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(hit_line)

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
	_build_playfield_deck(stage)


func _build_center_performance_hud(stage: Control) -> void:
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

	combo_caption_label = AuroraUi.make_pixel_label("COMBO", 9, AuroraUi.TEAL)
	combo_caption_label.custom_minimum_size.y = 20.0
	combo_caption_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	combo_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(combo_caption_label)

	combo_label = AuroraUi.make_pixel_label("000", 46, AuroraUi.TEXT)
	combo_label.custom_minimum_size.y = 74.0
	combo_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.94))
	combo_label.add_theme_constant_override("shadow_offset_x", 4)
	combo_label.add_theme_constant_override("shadow_offset_y", 4)
	hud.add_child(combo_label)

	precision_label = AuroraUi.make_pixel_label("RATE  100.00%", 10, Color(0.86, 0.92, 1.0, 0.86))
	precision_label.custom_minimum_size.y = 24.0
	precision_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	precision_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	precision_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(precision_label)

	judgment_label = AuroraUi.make_pixel_label("READY", 24, AuroraUi.GOLD)
	judgment_label.custom_minimum_size.y = 46.0
	judgment_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	judgment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judgment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	judgment_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	judgment_label.add_theme_constant_override("shadow_offset_x", 3)
	judgment_label.add_theme_constant_override("shadow_offset_y", 3)
	hud.add_child(judgment_label)

	timing_feedback_label = AuroraUi.make_pixel_label("SYNC READY", 8, AuroraUi.MUTED)
	timing_feedback_label.custom_minimum_size.y = 20.0
	timing_feedback_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	timing_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timing_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timing_feedback_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	timing_feedback_label.add_theme_constant_override("shadow_offset_x", 2)
	timing_feedback_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(timing_feedback_label)


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
	stage.add_child(control_deck)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	control_deck.add_child(content)

	var deck_header := HBoxContainer.new()
	content.add_child(deck_header)
	var brand := AuroraUi.make_pixel_label("AURORA // LIVE LINK", 7, Color(0.80, 0.86, 0.98, 0.68))
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
	var song_info := VBoxContainer.new()
	song_info.anchor_left = 0.018
	song_info.anchor_top = 0.022
	song_info.anchor_right = 0.30
	song_info.anchor_bottom = 0.14
	song_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(song_info)

	var title := "AURORA DEMO"
	var artist := "AURORA PROJECT"
	if game_manager.current_song != null:
		title = game_manager.current_song.title.to_upper()
		artist = game_manager.current_song.artist.to_upper()
	var title_label := AuroraUi.make_pixel_label(title, 13, AuroraUi.TEXT)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	song_info.add_child(title_label)
	var artist_label := AuroraUi.make_pixel_label(artist, 8, AuroraUi.TEAL)
	artist_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	song_info.add_child(artist_label)

	var right_hud := VBoxContainer.new()
	right_hud.anchor_left = 0.76
	right_hud.anchor_top = 0.022
	right_hud.anchor_right = 0.982
	right_hud.anchor_bottom = 0.16
	right_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_hud)

	var score_caption := AuroraUi.make_pixel_label("SCORE", 8, Color(0.82, 0.88, 0.98, 0.70))
	score_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_hud.add_child(score_caption)
	score_label = AuroraUi.make_pixel_label("0000000", 22, AuroraUi.GOLD)
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


func _make_playfield_frame_style() -> StyleBoxFlat:
	var style := AuroraUi.make_style(
		Color(0.006, 0.009, 0.026, 0.70),
		Color(0.70, 0.60, 1.0, 0.92),
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
	var tint := LANE_COLORS[lane_index]
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
	content.add_child(note_layer)
	lane_note_layers.append(note_layer)

	var receptor := PanelContainer.new()
	receptor.name = "Receptor%02d" % (lane_index + 1)
	receptor.anchor_left = 0.055
	receptor.anchor_top = 1.0
	receptor.anchor_right = 0.945
	receptor.anchor_bottom = 1.0
	receptor.offset_top = -RECEPTOR_TOP_OFFSET
	receptor.offset_bottom = -RECEPTOR_BOTTOM_OFFSET
	receptor.add_theme_stylebox_override("panel", _make_receptor_style(tint, false))
	content.add_child(receptor)
	lane_receptors.append(receptor)

	var label := AuroraUi.make_pixel_label(key_name, 14, AuroraUi.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _make_lane_style(tint: Color, active: bool) -> StyleBoxFlat:
	var opacity := float(settings_manager.get_setting("lane_opacity", 0.82))
	var lane_alpha := opacity * 0.64
	var border_alpha := 0.18 if active else 0.08
	var style := AuroraUi.make_style(
		Color(0.008, 0.012, 0.028, lane_alpha),
		Color(tint.r, tint.g, tint.b, border_alpha),
		0
	)
	style.content_margin_left = 1.0
	style.content_margin_right = 1.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
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


func _process(delta: float) -> void:
	ambient_time += delta
	_update_ambient_frame()
	if start_gate_active:
		return
	if not gameplay_finished:
		_update_song_clock(delta)
		_spawn_upcoming_notes()
		_update_active_notes()
		_update_practice_beat()
		_check_chart_finished()

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
	var tint := LANE_COLORS[lane_index]
	lane_panels[lane_index].add_theme_stylebox_override("panel", _make_lane_style(tint, pressed))
	lane_receptors[lane_index].add_theme_stylebox_override("panel", _make_receptor_style(tint, pressed))
	lane_labels[lane_index].add_theme_color_override("font_color", Color.WHITE if pressed else AuroraUi.TEXT)


func _register_lane_input(lane_index: int) -> void:
	if gameplay_finished:
		return

	var timing_offset := float(settings_manager.get_setting("timing_offset_ms", 0)) / 1000.0
	var judgment_time := gameplay_time + timing_offset
	var closest_note: Dictionary = {}
	var closest_error := INF
	for note_entry in active_notes:
		if int(note_entry["lane"]) != lane_index:
			continue
		if bool(note_entry.get("holding", false)):
			continue
		var error := absf(float(note_entry["time"]) - judgment_time)
		if error < closest_error:
			closest_error = error
			closest_note = note_entry

	if closest_note.is_empty() or closest_error > MISS_WINDOW:
		return

	var signed_error := judgment_time - float(closest_note["time"])
	if float(closest_note.get("duration", 0.0)) >= HOLD_NOTE_MIN_DURATION:
		_start_hold_note(closest_note, signed_error)
		return

	var judgment := _get_judgment_for_error(signed_error)
	match judgment:
		"PERFECT":
			_judge_note(closest_note, judgment, 1.0, 1000, AuroraUi.TEAL)
		"GREAT":
			_judge_note(closest_note, judgment, 0.80, 750, AuroraUi.GOLD)
		_:
			_judge_note(closest_note, "GOOD", 0.50, 450, AuroraUi.CORAL)
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

	var timing_offset := float(settings_manager.get_setting("timing_offset_ms", 0)) / 1000.0
	_finish_hold_note(held_note, gameplay_time + timing_offset)


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
	if absolute_error <= PERFECT_WINDOW:
		return {"judgment": "PERFECT", "accuracy": 1.0, "score": 1200}
	if absolute_error <= GREAT_WINDOW:
		return {"judgment": "GREAT", "accuracy": 0.80, "score": 900}
	if absolute_error <= GOOD_WINDOW:
		return {"judgment": "GOOD", "accuracy": 0.50, "score": 550}

	# Releasing after the halfway point preserves the combo but grants
	# only the minimum hold-note reward.
	return {"judgment": "GOOD", "accuracy": 0.25, "score": 200}


func _get_judgment_for_error(error_seconds: float) -> String:
	var absolute_error := absf(error_seconds)
	if absolute_error <= PERFECT_WINDOW:
		return "PERFECT"
	if absolute_error <= GREAT_WINDOW:
		return "GREAT"
	if absolute_error <= GOOD_WINDOW:
		return "GOOD"
	return "MISS"


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
	chart_end_time = 0.0
	for note_data in chart_notes:
		chart_end_time = maxf(
			chart_end_time,
			float(note_data.get("time", 0.0)) + float(note_data.get("duration", 0.0))
		)

	next_note_index = 0
	gameplay_time = 0.0
	next_beat_time = 0.0
	gameplay_finished = false
	_setup_audio_players()
	_refresh_progress()


func _setup_audio_players() -> void:
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
	start_gate_panel.add_theme_stylebox_override(
		"panel",
		AuroraUi.make_style(
			Color(0.006, 0.010, 0.030, 0.94),
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.90),
			0
		)
	)
	add_child(start_gate_panel)

	start_prompt_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("ESPACIO O %s\nPARA INICIAR")
		% input_manager.get_controller_action_label("confirm"),
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
	start_gate_panel.visible = start_gate_active


func _begin_start_countdown() -> void:
	if not start_gate_active or start_countdown_active:
		return
	start_countdown_active = true
	start_countdown_token += 1
	var countdown_token := start_countdown_token
	for value in [2, 1]:
		if countdown_token != start_countdown_token or not is_inside_tree():
			return
		start_prompt_label.text = str(value)
		start_prompt_label.add_theme_color_override("font_color", AuroraUi.GOLD)
		await get_tree().create_timer(start_countdown_step_seconds).timeout
	if countdown_token != start_countdown_token or not is_inside_tree():
		return
	start_prompt_label.text = AuroraLocale.text("¡YA!")
	start_prompt_label.add_theme_color_override("font_color", AuroraUi.TEAL)
	await get_tree().create_timer(0.22).timeout
	if countdown_token != start_countdown_token or not is_inside_tree():
		return
	start_countdown_active = false
	start_gate_active = false
	start_gate_panel.hide()
	_start_gameplay_media()


func _start_gameplay_media() -> void:
	if background_video_player != null:
		background_video_player.play()
		if game_manager.current_song != null:
			background_video_player.stream_position = (
				game_manager.current_song.background_video_start_seconds
			)
	if song_player != null and song_player.stream != null:
		song_player.play()


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
	if song_player != null and song_player.playing:
		gameplay_time = song_player.get_playback_position()
		gameplay_time += AudioServer.get_time_since_last_mix()
		gameplay_time -= AudioServer.get_output_latency()
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
	return lerpf(2.65, 0.72, normalized)


func _spawn_upcoming_notes() -> void:
	var travel_time := _get_note_travel_time()
	while next_note_index < chart_notes.size():
		var note_data: Dictionary = chart_notes[next_note_index]
		if float(note_data["time"]) - gameplay_time > travel_time:
			break
		_spawn_note(note_data)
		next_note_index += 1


func _spawn_note(note_data: Dictionary) -> void:
	var lane := int(note_data["lane"])
	if lane < 0 or lane >= lane_note_layers.size():
		return
	var tint := LANE_COLORS[lane]
	var duration := float(note_data.get("duration", 0.0))
	var is_hold := duration >= HOLD_NOTE_MIN_DURATION
	var note := PanelContainer.new()
	note.name = "HoldNote" if is_hold else "TapNote"
	note.anchor_left = 0.075
	note.anchor_right = 0.925
	note.offset_top = -NOTE_HALF_HEIGHT
	note.offset_bottom = NOTE_HALF_HEIGHT
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note_style := AuroraUi.make_style(
		Color(tint.r, tint.g, tint.b, 0.52 if is_hold else 0.92),
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
	if is_hold:
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
		var receptor_y := maxf(
			layer.size.y - RECEPTOR_TOP_OFFSET - HIT_LINE_GAP,
			100.0
		)
		var note_time := float(note_entry["time"])
		var duration := float(note_entry.get("duration", 0.0))
		var is_hold := duration >= HOLD_NOTE_MIN_DURATION
		var progress := 1.0 - (note_time - gameplay_time) / travel_time
		var note_y := lerpf(24.0, receptor_y, progress)
		if bool(note_entry.get("holding", false)):
			note_y = receptor_y
		var hold_height := 0.0
		if is_hold:
			var travel_distance := maxf(receptor_y - 24.0, 1.0)
			var remaining_duration := duration
			if bool(note_entry.get("holding", false)):
				remaining_duration = maxf(note_time + duration - gameplay_time, 0.0)
			hold_height = maxf(
				remaining_duration / travel_time * travel_distance,
				NOTE_HALF_HEIGHT * 2.0
			)
		note_node.offset_top = note_y - NOTE_HALF_HEIGHT - hold_height
		note_node.offset_bottom = note_y + NOTE_HALF_HEIGHT

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

	judged_count += 1
	accuracy_points += accuracy_value
	if judgment == "MISS":
		miss_count += 1
		combo = 0
		_reset_combo_feedback()
		_show_miss_timing_feedback()
		_play_miss_effect(int(note_entry["lane"]))
		_play_miss_sound()
	else:
		combo += 1
		max_combo = maxi(max_combo, combo)
		score += base_score + mini(combo * 5, 500)
		match judgment:
			"PERFECT":
				perfect_count += 1
			"GREAT":
				great_count += 1
			_:
				good_count += 1
		_play_combo_feedback()
		_play_hit_effect(int(note_entry["lane"]), color)

	_show_judgment(judgment, color)
	_refresh_score_display()
	_refresh_progress()


func _show_judgment(text: String, color: Color) -> void:
	judgment_label.text = text
	judgment_label.add_theme_color_override("font_color", color)


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
	precision_label.text = "RATE  %.2f%%" % accuracy


func _refresh_progress() -> void:
	if progress_label != null:
		progress_label.text = "%03d / %03d" % [judged_count, chart_notes.size()]
	if progress_fill != null:
		var ratio := 0.0 if chart_notes.is_empty() else clampf(float(judged_count) / float(chart_notes.size()), 0.0, 1.0)
		progress_fill.anchor_right = ratio


func _play_hit_effect(lane_index: int, _color: Color) -> void:
	if not bool(settings_manager.get_setting("show_hit_effects", true)):
		return
	var receptor := lane_receptors[lane_index]
	receptor.modulate = Color(1.45, 1.45, 1.45, 1.0)
	var flash := receptor.create_tween()
	flash.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	flash.tween_property(receptor, "modulate", Color.WHITE, 0.12)

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
	receptor.modulate = Color(1.0, 0.26, 0.38, 1.0)
	var flash := receptor.create_tween()
	flash.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	flash.tween_property(
		receptor,
		"modulate",
		Color.WHITE,
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


func _check_chart_finished() -> void:
	if chart_notes.is_empty():
		return
	if next_note_index >= chart_notes.size() and active_notes.is_empty() and gameplay_time >= chart_end_time + 0.65:
		_finish_gameplay()


func _finish_gameplay() -> void:
	if gameplay_finished:
		return
	gameplay_finished = true
	if song_player != null:
		song_player.stop()
	if background_video_player != null:
		background_video_player.stop()
	game_manager.complete_song(_build_result_data())
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
		"perfect": perfect_count,
		"great": great_count,
		"good": good_count,
		"miss": miss_count,
		"total_notes": chart_notes.size(),
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
	if not enabled or reduced:
		frame_panel.modulate = Color.WHITE
		return
	var intensity := float(settings_manager.get_setting("background_animation_intensity", 3))
	var pulse := 0.94 + sin(ambient_time * (0.7 + intensity * 0.08)) * 0.06
	frame_panel.modulate = Color(pulse, pulse, 1.0, 1.0)


func _apply_visual_settings() -> void:
	var dim := float(settings_manager.get_setting("background_dim", 0.46))
	dim_overlay.color = Color(0.0, 0.008, 0.03, clampf(dim * 0.74, 0.0, 0.82))
	var show_labels := bool(settings_manager.get_setting("show_lane_labels", true))
	for label in lane_labels:
		label.visible = show_labels
	if background_video_player != null:
		var background_enabled := bool(settings_manager.get_setting("background_animation_enabled", true))
		var intensity := float(settings_manager.get_setting("background_animation_intensity", 3))
		var brightness := 0.72 + intensity * 0.055
		background_video_player.visible = background_enabled
		background_video_player.modulate = Color(brightness, brightness, brightness, 1.0)
	for lane_index in range(lane_panels.size()):
		_set_lane_pressed(lane_index, lane_pressed[lane_index])
	_update_speed_label()


func _update_speed_label() -> void:
	if speed_label != null:
		speed_label.text = "SPEED  %.1fx" % float(settings_manager.get_setting("note_speed", 5.5))


func _on_setting_changed(key: String, _value) -> void:
	if key in [
		"note_speed",
		"background_animation_enabled",
		"background_animation_intensity",
		"background_dim",
		"lane_opacity",
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
	add_child(pause_menu)
	pause_menu.restart_requested.connect(_restart_song)
	pause_menu.song_select_requested.connect(_return_to_song_select)
	pause_menu.main_menu_requested.connect(_return_to_main_menu)
	pause_menu.set_editor_test_mode(game_manager.editor_test_active)
	pause_menu.set_track_context(game_manager.current_song, game_manager.current_chart)


func _restart_song() -> void:
	scene_manager.load_scene("gameplay")


func _return_to_song_select() -> void:
	if game_manager.editor_test_active:
		scene_manager.load_scene("editor")
		return
	game_manager.stop_song()
	scene_manager.load_scene("song_select")


func _return_to_main_menu() -> void:
	game_manager.stop_song()
	scene_manager.load_scene("main_menu")


func _open_pause_menu() -> void:
	if pause_menu == null:
		return
	var total_seconds := chart_end_time
	if game_manager.current_song != null:
		total_seconds = maxf(total_seconds, game_manager.current_song.duration_seconds)
	pause_menu.set_playback_progress(gameplay_time, total_seconds)
	pause_menu.open_menu()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if input_manager.controller_event_matches(event, "confirm"):
			if start_gate_active and not start_countdown_active:
				_begin_start_countdown()
				get_viewport().set_input_as_handled()
		elif input_manager.controller_event_matches(event, "pause"):
			_open_pause_menu()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if start_gate_active and not start_countdown_active:
					_begin_start_countdown()
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_open_pause_menu()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				if start_gate_active:
					return
				get_viewport().set_input_as_handled()
				game_manager.complete_song(_build_result_data())
				scene_manager.load_scene("results")


func _exit_tree() -> void:
	start_countdown_token += 1
	if get_tree() != null:
		get_tree().paused = false
