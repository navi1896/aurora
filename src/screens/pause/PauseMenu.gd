extends Control

class_name PauseMenu

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
var resume_countdown_label: Label
var resume_countdown_step_seconds := 0.45
var resume_in_progress := false
var editor_test_mode := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_manager = get_tree().current_scene.get_node("Managers/SettingsManager")
	input_manager = get_tree().current_scene.get_node("Managers/InputManager")

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
	resume_in_progress = false
	pause_margins.show()
	resume_countdown_label.hide()
	_refresh_controls()
	show()
	get_tree().paused = true
	continue_button.grab_focus()


func close_menu() -> void:
	if resume_in_progress or not visible:
		return
	resume_in_progress = true
	pause_margins.hide()
	resume_countdown_label.show()
	_run_resume_countdown()


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


func _run_resume_countdown() -> void:
	var step_seconds := maxf(resume_countdown_step_seconds, 0.01)
	for value in [3, 2, 1]:
		resume_countdown_label.text = str(value)
		resume_countdown_label.add_theme_color_override("font_color", AuroraUi.TEAL)
		await get_tree().create_timer(step_seconds, true).timeout
	resume_countdown_label.text = "GO!"
	resume_countdown_label.add_theme_color_override("font_color", AuroraUi.GOLD)
	await get_tree().create_timer(step_seconds * 0.75, true).timeout
	_finish_resume()


func _finish_resume() -> void:
	get_tree().paused = false
	resume_in_progress = false
	resume_countdown_label.hide()
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


func _request_restart() -> void:
	_leave_pause_for_navigation()
	restart_requested.emit()


func _request_song_select() -> void:
	_leave_pause_for_navigation()
	song_select_requested.emit()


func _request_main_menu() -> void:
	_leave_pause_for_navigation()
	main_menu_requested.emit()


func _leave_pause_for_navigation() -> void:
	get_tree().paused = false
	resume_in_progress = false
	if resume_countdown_label != null:
		resume_countdown_label.hide()
	pause_margins.show()
	hide()


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
