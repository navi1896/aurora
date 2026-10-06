extends Control

class_name PauseMenu

const SOUNDS := preload("res://src/audio/GameSoundBank.gd")
const COUNTDOWN_DIAL := preload("res://src/screens/pause/ResumeCountdownDial.gd")

signal restart_requested
signal song_select_requested
signal main_menu_requested

@onready var continue_button: Button = $PauseMargins/Page/ActionCenter/Actions/ContinueButton
@onready var restart_button: Button = $PauseMargins/Page/ActionCenter/Actions/RestartButton
@onready var song_select_button: Button = $PauseMargins/Page/ActionCenter/Actions/SongSelectButton
@onready var exit_button: Button = $PauseMargins/Page/ActionCenter/Actions/ExitButton
@onready var speed_down: Button = $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/SpeedModule/SpeedControls/DecreaseButton
@onready var speed_value: Label = $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/SpeedModule/SpeedControls/ValueLabel
@onready var speed_up: Button = $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/SpeedModule/SpeedControls/IncreaseButton
@onready var background_on: Button = $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/BackgroundModule/ToggleRow/OnButton
@onready var background_off: Button = $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/BackgroundModule/ToggleRow/OffButton
@onready var background_intensity: HSlider = $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/BackgroundModule/IntensityRow/Slider
@onready var pause_margins: MarginContainer = $PauseMargins
@onready var title_label: Label = $PauseMargins/Page/Title
@onready var track_context: VBoxContainer = $PauseMargins/Page/TrackContext
@onready var track_title_label: Label = $PauseMargins/Page/TrackContext/TrackTitle
@onready var track_meta_label: Label = $PauseMargins/Page/TrackContext/TrackMeta
@onready var track_progress: ProgressBar = $PauseMargins/Page/TrackContext/ProgressRow/TrackProgress
@onready var track_time_label: Label = $PauseMargins/Page/TrackContext/ProgressRow/TrackTime
@onready var speed_title: Label = $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/SpeedModule/Title
@onready var background_title: Label = $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/BackgroundModule/Title
@onready var background_caption: Label = $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/BackgroundModule/IntensityRow/Caption
@onready var footer_label: Label = $PauseMargins/Page/Footer

var settings_manager: SettingsManager
var input_manager: InputManager
var ui_feedback
var resume_countdown_label: Label
var resume_countdown_dial: Control
var resume_countdown_player: AudioStreamPlayer
var resume_countdown_step_seconds := 1.0
var resume_in_progress := false
var resume_countdown_token := 0
var editor_test_mode := false
var visual_sliders: Dictionary = {}
var visual_values: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_manager = get_tree().current_scene.get_node("Managers/SettingsManager")
	input_manager = get_tree().current_scene.get_node("Managers/InputManager")
	ui_feedback = get_tree().current_scene.get_node_or_null("Managers/UiFeedbackManager")

	continue_button.pressed.connect(close_menu)
	restart_button.pressed.connect(_request_restart)
	song_select_button.pressed.connect(_request_song_select)
	exit_button.pressed.connect(_request_main_menu)
	speed_down.pressed.connect(_adjust_note_speed.bind(-0.5))
	speed_up.pressed.connect(_adjust_note_speed.bind(0.5))

	_configure_toggle_pair(background_on, background_off)
	background_on.pressed.connect(_set_background_animation.bind(true))
	background_off.pressed.connect(_set_background_animation.bind(false))
	background_intensity.value_changed.connect(_set_background_intensity)
	$PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/KeySoundModule.hide()
	$PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/Divider2.hide()
	var speed_module := $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/SpeedModule as Control
	var background_module := $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow/BackgroundModule as Control
	speed_module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background_module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background_module.size_flags_stretch_ratio = 1.35
	_build_visual_controls()

	_apply_localized_texts()
	_build_resume_countdown()
	_refresh_controls()
	hide()


func _apply_localized_texts() -> void:
	title_label.text = AuroraLocale.text("PAUSA")
	continue_button.text = AuroraLocale.text("CONTINUAR")
	restart_button.text = AuroraLocale.text("REINICIAR")
	song_select_button.text = (
		AuroraLocale.text("VOLVER AL EDITOR")
		if editor_test_mode
		else AuroraLocale.text("SELECCION DE CANCIONES")
	)
	exit_button.text = AuroraLocale.text("SALIR")
	speed_title.text = AuroraLocale.text("VELOCIDAD DE NOTAS")
	background_title.text = AuroraLocale.text("ANIMACION DE FONDO")
	background_caption.text = AuroraLocale.text("INTENSIDAD")
	footer_label.text = AuroraLocale.text(
		"↑↓ / STICK SELECCIONAR   %s CONFIRMAR   %s O %s CONTINUAR"
	) % [
		input_manager.get_controller_action_label("confirm"),
		input_manager.get_controller_action_label("back"),
		input_manager.get_controller_action_label("pause"),
	]


func set_editor_test_mode(enabled: bool) -> void:
	editor_test_mode = enabled
	if is_node_ready():
		_apply_localized_texts()


func set_track_context(song: SongData, chart: ChartData) -> void:
	if song == null:
		track_context.hide()
		return

	track_title_label.text = song.title.to_upper()
	var details: PackedStringArray = []
	if not song.artist.is_empty():
		details.append(song.artist.to_upper())
	if chart != null:
		details.append(chart.get_mode_label())
		details.append(chart.get_difficulty_label().to_upper())
	track_meta_label.text = "  //  ".join(details)
	track_context.show()


func set_playback_progress(current_seconds: float, total_seconds: float) -> void:
	var safe_total := maxf(total_seconds, 0.0)
	var safe_current := clampf(current_seconds, 0.0, safe_total) if safe_total > 0.0 else 0.0
	track_progress.value = safe_current / safe_total if safe_total > 0.0 else 0.0
	track_time_label.text = "%s / %s" % [
		_format_time(safe_current),
		_format_time(safe_total),
	]


func _format_time(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	return "%02d:%02d" % [floori(float(total) / 60.0), total % 60]


func open_menu() -> void:
	resume_countdown_token += 1
	resume_in_progress = false
	resume_countdown_player.stop()
	$Dimmer.color.a = 0.86
	pause_margins.show()
	resume_countdown_label.hide()
	resume_countdown_dial.hide()
	_refresh_controls()
	show()
	get_tree().paused = true
	continue_button.grab_focus()


func close_menu() -> void:
	if resume_in_progress or not visible:
		return
	if ui_feedback != null:
		ui_feedback.play_resume()
	resume_in_progress = true
	resume_countdown_token += 1
	pause_margins.hide()
	$Dimmer.color.a = 0.55
	resume_countdown_label.show()
	resume_countdown_dial.show()
	_run_resume_countdown(resume_countdown_token)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton and event.pressed:
		if (
			input_manager.controller_event_matches(event, "back")
			or input_manager.controller_event_matches(event, "pause")
		):
			get_viewport().set_input_as_handled()
			if not resume_in_progress:
				close_menu()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if not resume_in_progress:
				close_menu()


func _build_resume_countdown() -> void:
	resume_countdown_player = AudioStreamPlayer.new()
	resume_countdown_player.name = "ResumeCountdownSound"
	resume_countdown_player.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_countdown_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	resume_countdown_player.volume_db = -2.0
	add_child(resume_countdown_player)
	resume_countdown_dial = COUNTDOWN_DIAL.new()
	AuroraUi.fill(resume_countdown_dial)
	add_child(resume_countdown_dial)
	resume_countdown_dial.hide()
	resume_countdown_label = AuroraUi.make_pixel_label("3", 96, AuroraUi.TEAL)
	AuroraUi.fill(resume_countdown_label)
	resume_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resume_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resume_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resume_countdown_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.94))
	resume_countdown_label.add_theme_constant_override("shadow_offset_x", 7)
	resume_countdown_label.add_theme_constant_override("shadow_offset_y", 7)
	add_child(resume_countdown_label)
	resume_countdown_label.hide()


func _run_resume_countdown(token: int) -> void:
	var step_seconds := maxf(resume_countdown_step_seconds, 0.01)
	for value in [3, 2, 1]:
		if token != resume_countdown_token or not is_inside_tree():
			return
		resume_countdown_label.text = str(value)
		resume_countdown_label.add_theme_color_override("font_color", AuroraUi.TEAL)
		resume_countdown_dial.begin_step(value, step_seconds, bool(settings_manager.get_setting("reduced_motion", false)))
		_play_countdown_cue(value)
		await get_tree().create_timer(step_seconds, true).timeout
	if token != resume_countdown_token or not is_inside_tree():
		return
	resume_countdown_label.text = "GO!"
	resume_countdown_label.add_theme_color_override("font_color", AuroraUi.GOLD)
	resume_countdown_dial.begin_step(0, step_seconds, true)
	_play_countdown_cue(0)
	await get_tree().create_timer(0.12, true).timeout
	if token == resume_countdown_token and is_inside_tree():
		_finish_resume()


func _play_countdown_cue(value: int) -> void:
	resume_countdown_player.stop()
	resume_countdown_player.stream = SOUNDS.COUNTDOWN.get(value)
	resume_countdown_player.play()


func _finish_resume() -> void:
	get_tree().paused = false
	resume_in_progress = false
	resume_countdown_label.hide()
	resume_countdown_dial.hide()
	pause_margins.show()
	hide()


func _configure_toggle_pair(on_button: Button, off_button: Button) -> void:
	var group := ButtonGroup.new()
	group.allow_unpress = false
	on_button.button_group = group
	off_button.button_group = group


func _adjust_note_speed(amount: float) -> void:
	var current := float(settings_manager.get_setting("note_speed", 5.5))
	var next_value := clampf(snappedf(current + amount, 0.5), 1.0, 10.0)
	settings_manager.set_setting("note_speed", next_value)
	speed_value.text = "%.1fx" % next_value
	AuroraUi.update_stepper_buttons(speed_down, speed_up, next_value, 1.0, 10.0)


func _set_background_animation(enabled: bool) -> void:
	settings_manager.set_setting("background_animation_enabled", enabled)
	background_on.button_pressed = enabled
	background_off.button_pressed = not enabled
	background_intensity.editable = enabled


func _set_background_intensity(value: float) -> void:
	settings_manager.set_setting("background_animation_intensity", roundi(value))


func _refresh_controls() -> void:
	for key in visual_sliders:
		var value := float(settings_manager.get_setting(key, 0.0))
		(visual_sliders[key] as HSlider).set_value_no_signal(value * 100.0)
		(visual_values[key] as Label).text = "%d%%" % roundi(value * 100.0)
	var note_speed := float(settings_manager.get_setting("note_speed", 5.5))
	var background_enabled := bool(settings_manager.get_setting("background_animation_enabled", true))
	var intensity := float(settings_manager.get_setting("background_animation_intensity", 3))

	speed_value.text = "%.1fx" % note_speed
	AuroraUi.update_stepper_buttons(speed_down, speed_up, note_speed, 1.0, 10.0)
	background_on.button_pressed = background_enabled
	background_off.button_pressed = not background_enabled
	background_intensity.set_block_signals(true)
	background_intensity.value = intensity
	background_intensity.set_block_signals(false)
	background_intensity.editable = background_enabled


func _build_visual_controls() -> void:
	var row := $PauseMargins/Page/SettingsPanel/SettingsMargins/SettingsRow
	var module := VBoxContainer.new()
	module.name = "VisibilityModule"
	module.custom_minimum_size.x = 310.0
	module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module.add_theme_constant_override("separation", 8)
	row.add_child(module)
	for entry in [["lane_opacity", "Opacidad de la pista"], ["background_dim", "Oscurecer fondo"]]:
		var key := str(entry[0])
		var title := AuroraUi.make_pixel_label(AuroraLocale.text(str(entry[1])), 9, AuroraUi.TEXT)
		module.add_child(title)
		var controls := HBoxContainer.new()
		controls.add_theme_constant_override("separation", 12)
		module.add_child(controls)
		var slider := HSlider.new()
		slider.name = key
		slider.max_value = 100.0
		slider.step = 1.0
		slider.custom_minimum_size = Vector2(190, 28)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(slider)
		var value_label := AuroraUi.make_pixel_label("", 9, AuroraUi.TEAL)
		value_label.custom_minimum_size.x = 46.0
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		controls.add_child(value_label)
		visual_sliders[key] = slider
		visual_values[key] = value_label
		slider.value_changed.connect(func(value: float) -> void:
			settings_manager.set_setting(key, value / 100.0)
			value_label.text = "%d%%" % roundi(value)
		)


func _request_restart() -> void:
	if ui_feedback != null:
		ui_feedback.play_confirm()
	_leave_pause_for_navigation()
	restart_requested.emit()


func _request_song_select() -> void:
	if ui_feedback != null:
		ui_feedback.play_confirm()
	_leave_pause_for_navigation()
	song_select_requested.emit()


func _request_main_menu() -> void:
	if ui_feedback != null:
		ui_feedback.play_confirm()
	_leave_pause_for_navigation()
	main_menu_requested.emit()


func _leave_pause_for_navigation() -> void:
	resume_countdown_token += 1
	resume_countdown_player.stop()
	get_tree().paused = false
	resume_in_progress = false
	if resume_countdown_label != null:
		resume_countdown_label.hide()
		resume_countdown_dial.hide()
	pause_margins.show()
	hide()


func _exit_tree() -> void:
	resume_countdown_token += 1
	if get_tree() != null:
		get_tree().paused = false
