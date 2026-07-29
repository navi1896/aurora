extends Control

class_name Editor

const PROJECT_STORE = preload("res://src/screens/editor/EditorProjectStore.gd")
const EDITOR_DIRECTORY := "user://aurora_editor"
const EDITOR_MEDIA_DIRECTORY := "user://aurora_editor/media"
const VIDEO_CONVERSION_PROFILE := "theora_v3_720p30"
const MIN_HOLD_DURATION := 0.18
const SUPPORTED_KEY_COUNTS: Array[int] = [4, 6, 8]
const DIRECT_VIDEO_EXTENSIONS: Array[String] = ["ogv"]
const CONVERTIBLE_VIDEO_EXTENSIONS: Array[String] = [
	"mp4",
	"mov",
	"mkv",
	"webm",
	"avi",
	"m4v",
]
const REQUIRED_FFMPEG_ENCODERS: Array[String] = ["libtheora", "libvorbis"]
const REQUIRED_FFMPEG_FILTERS: Array[String] = ["fps", "scale", "format"]
const REQUIRED_FFMPEG_DEMUXERS: Array[String] = ["mov", "avi", "matroska", "m4v"]
const REQUIRED_FFMPEG_MUXERS: Array[String] = ["ogg"]
const MEDIA_CACHE_SAMPLE_BYTES := 64 * 1024

var scene_manager: SceneManager
var game_manager: GameManager
var input_manager: InputManager
var song_manager: SongManager

var notes: Array[Dictionary] = []
var active_recording_holds: Dictionary = {}
var video_path := ""
var video_source_path := ""
var audio_path := ""
var current_project_path := ""
var preview_time := 0.0
var duration_seconds := 120.0
var key_count := 4
var creation_mode := "manual"
var recording := false
var preview_running := false
var automatic_density := 1

var video_player: VideoStreamPlayer
var audio_player: AudioStreamPlayer
var timeline: ChartTimeline
var seek_slider: HSlider
var time_label: Label
var note_count_label: Label
var media_status_label: Label
var preview_placeholder: Label
var status_label: Label
var record_button: Button
var play_button: Button
var creation_mode_switch: CheckButton
var manual_mode_label: Label
var automatic_mode_label: Label
var generate_button: Button
var test_button: Button
var recording_countdown_label: Label
var title_edit: LineEdit
var artist_edit: LineEdit
var bpm_spin: SpinBox
var duration_spin: SpinBox
var key_count_option: OptionButton
var difficulty_edit: LineEdit
var difficulty_level_spin: SpinBox
var density_option: OptionButton
var key_legend: HBoxContainer
var video_dialog: FileDialog
var audio_dialog: FileDialog
var project_dialog: FileDialog
var video_select_button: Button
var audio_select_button: Button
var video_conversion_pid := -1
var video_conversion_source_path := ""
var video_conversion_output_path := ""
var video_conversion_temporary_path := ""
var video_conversion_progress_path := ""
var video_conversion_legacy_path := ""
var video_conversion_ffmpeg_path := ""
var video_conversion_phase := ""
var video_conversion_expected_seconds := 0.0
var video_conversion_started_msec := 0
var video_conversion_status_tick := -1
var recording_countdown_active := false
var recording_countdown_token := 0


func _ready() -> void:
	AuroraUi.fill(self)
	var managers := get_tree().current_scene.get_node("Managers")
	scene_manager = managers.get_node("SceneManager") as SceneManager
	game_manager = managers.get_node("GameManager") as GameManager
	input_manager = managers.get_node("InputManager") as InputManager
	song_manager = managers.get_node("SongManager") as SongManager
	_setup_ui()
	_setup_file_dialogs()
	if not _restore_editor_test_if_needed():
		_refresh_editor_state()


func _process(_delta: float) -> void:
	_poll_video_conversion()
	if not preview_running:
		return
	if audio_player != null and audio_player.stream != null and audio_player.playing:
		preview_time = audio_player.get_playback_position()
	elif video_player != null and video_player.stream != null and video_player.is_playing():
		preview_time = video_player.stream_position
	if preview_time >= duration_seconds:
		_pause_preview()
		preview_time = duration_seconds
	_update_playhead_ui()


func _setup_ui() -> void:
	AuroraUi.clear(self)
	AuroraUi.add_background(self)

	var margin := AuroraUi.make_margin(34, 26, 34, 26)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	_build_header(page)

	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 2.0
	divider.color = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.76)
	page.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)

	var workspace := VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 12)
	body.add_child(workspace)
	_build_preview(workspace)
	_build_creation_controls(workspace)
	_build_timeline(workspace)
	_build_properties(body)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	page.add_child(footer)
	status_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("CREA UN PROYECTO Y SELECCIONA VIDEO O AUDIO"),
		7,
		AuroraUi.MUTED
	)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(status_label)
	var footer_help := AuroraUi.make_pixel_label(
		AuroraLocale.text(
			"ESPACIO / %s REPRODUCIR   ESC / %s VOLVER   CLIC EN TIMELINE PARA BUSCAR"
		) % [
			input_manager.get_controller_action_label("pause"),
			input_manager.get_controller_action_label("back"),
		],
		7,
		AuroraUi.MUTED
	)
	footer_help.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(footer_help)


func _build_header(page: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	page.add_child(header)

	var back := _make_tool_button(AuroraLocale.text("◀ VOLVER"), 132.0)
	back.pressed.connect(Callable(scene_manager, "load_scene").bind("main_menu"))
	header.add_child(back)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	var title := AuroraUi.make_pixel_label(
		AuroraLocale.text("EDITOR DE NIVELES"),
		18,
		AuroraUi.TEXT
	)
	title_box.add_child(title)
	title_box.add_child(
		AuroraUi.make_pixel_label(
			AuroraLocale.text("VIDEO + AUDIO // GRABACION DE CHART"),
			7,
			AuroraUi.TEAL
		)
	)

	var new_button := _make_tool_button(AuroraLocale.text("NUEVO"), 110.0)
	new_button.pressed.connect(_new_project)
	header.add_child(new_button)
	var import_button := _make_tool_button(AuroraLocale.text("IMPORTAR"), 130.0)
	import_button.pressed.connect(_open_project_dialog)
	header.add_child(import_button)
	var save_button := _make_tool_button(AuroraLocale.text("GUARDAR"), 130.0, true)
	save_button.pressed.connect(_save_project)
	header.add_child(save_button)


func _build_preview(workspace: VBoxContainer) -> void:
	var preview_panel := AuroraUi.make_panel(Color(0.006, 0.010, 0.030, 0.96))
	preview_panel.custom_minimum_size.y = 410.0
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(preview_panel)

	var preview_stage := Control.new()
	preview_stage.name = "PreviewStage"
	preview_panel.add_child(preview_stage)

	video_player = VideoStreamPlayer.new()
	video_player.name = "EditorVideoPreview"
	AuroraUi.fill(video_player)
	video_player.expand = true
	video_player.loop = false
	video_player.autoplay = false
	video_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	video_player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stage.add_child(video_player)

	var shade := ColorRect.new()
	AuroraUi.fill(shade)
	shade.color = Color(0.0, 0.0, 0.02, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stage.add_child(shade)

	preview_placeholder = AuroraUi.make_pixel_label(
		AuroraLocale.text("SELECCIONA VIDEO O AUDIO"),
		12,
		AuroraUi.MUTED
	)
	AuroraUi.fill(preview_placeholder)
	preview_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stage.add_child(preview_placeholder)

	recording_countdown_label = AuroraUi.make_pixel_label("", 54, AuroraUi.GOLD)
	AuroraUi.fill(recording_countdown_label)
	recording_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recording_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recording_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recording_countdown_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.96)
	)
	recording_countdown_label.add_theme_constant_override("shadow_offset_x", 6)
	recording_countdown_label.add_theme_constant_override("shadow_offset_y", 6)
	preview_stage.add_child(recording_countdown_label)
	recording_countdown_label.hide()

	var preview_badge := PanelContainer.new()
	preview_badge.anchor_left = 0.02
	preview_badge.anchor_top = 0.04
	preview_badge.anchor_right = 0.38
	preview_badge.anchor_bottom = 0.14
	preview_badge.add_theme_stylebox_override(
		"panel",
		AuroraUi.make_style(
			Color(0.006, 0.010, 0.030, 0.86),
			Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.62),
			0
		)
	)
	preview_stage.add_child(preview_badge)
	media_status_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("VIDEO REQUERIDO"),
		7,
		AuroraUi.CORAL
	)
	media_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_badge.add_child(media_status_label)

	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 10)
	workspace.add_child(transport)
	play_button = _make_tool_button(AuroraLocale.text("▶ REPRODUCIR"), 150.0, true)
	play_button.pressed.connect(_toggle_preview)
	transport.add_child(play_button)
	var stop_button := _make_tool_button(AuroraLocale.text("■ DETENER"), 132.0)
	stop_button.pressed.connect(_stop_preview)
	transport.add_child(stop_button)
	time_label = AuroraUi.make_pixel_label("00:00.000 / 02:00.000", 8, AuroraUi.GOLD)
	time_label.custom_minimum_size.x = 210.0
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transport.add_child(time_label)
	seek_slider = HSlider.new()
	seek_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seek_slider.min_value = 0.0
	seek_slider.max_value = duration_seconds
	seek_slider.step = 0.001
	seek_slider.value_changed.connect(_seek_preview)
	transport.add_child(seek_slider)

	audio_player = AudioStreamPlayer.new()
	audio_player.name = "EditorAudioPreview"
	audio_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	add_child(audio_player)


func _build_creation_controls(workspace: VBoxContainer) -> void:
	var panel := AuroraUi.make_panel(AuroraUi.SURFACE)
	workspace.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	content.add_child(mode_row)

	var mode_label := AuroraUi.make_pixel_label(AuroraLocale.text("CREACION"), 8, AuroraUi.MUTED)
	mode_label.custom_minimum_size.x = 100.0
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_row.add_child(mode_label)

	manual_mode_label = AuroraUi.make_pixel_label(AuroraLocale.text("MANUAL"), 8, AuroraUi.TEAL)
	manual_mode_label.custom_minimum_size.x = 86.0
	manual_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	manual_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_row.add_child(manual_mode_label)
	creation_mode_switch = CheckButton.new()
	creation_mode_switch.custom_minimum_size = Vector2(66.0, 44.0)
	creation_mode_switch.tooltip_text = AuroraLocale.text("CAMBIAR ENTRE CREACION MANUAL Y AUTOMATICA")
	creation_mode_switch.toggled.connect(_on_creation_mode_switched)
	mode_row.add_child(creation_mode_switch)
	automatic_mode_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("AUTOMATICA"),
		8,
		AuroraUi.MUTED
	)
	automatic_mode_label.custom_minimum_size.x = 112.0
	automatic_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_row.add_child(automatic_mode_label)

	note_count_label = AuroraUi.make_pixel_label("000 NOTAS", 8, AuroraUi.TEAL)
	note_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_row.add_child(note_count_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)

	record_button = _make_tool_button(AuroraLocale.text("● GRABAR NOTAS"), 174.0)
	record_button.toggle_mode = true
	record_button.pressed.connect(_toggle_recording)
	row.add_child(record_button)

	generate_button = _make_tool_button(AuroraLocale.text("GENERAR POR BPM"), 190.0)
	generate_button.disabled = true
	generate_button.pressed.connect(_generate_automatic_chart)
	row.add_child(generate_button)

	test_button = _make_tool_button(AuroraLocale.text("▶ PROBAR CHART"), 166.0, true)
	test_button.pressed.connect(_test_chart)
	row.add_child(test_button)

	var undo_button := _make_tool_button(AuroraLocale.text("DESHACER"), 122.0)
	undo_button.pressed.connect(_undo_last_note)
	row.add_child(undo_button)
	var clear_button := _make_tool_button(AuroraLocale.text("LIMPIAR"), 112.0)
	clear_button.pressed.connect(_clear_notes)
	row.add_child(clear_button)
	row.add_child(AuroraUi.spacer(1))


func _build_timeline(workspace: VBoxContainer) -> void:
	var timeline_panel := AuroraUi.make_panel(Color(0.008, 0.012, 0.035, 0.96))
	timeline_panel.custom_minimum_size.y = 235.0
	workspace.add_child(timeline_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	timeline_panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var timeline_title := AuroraUi.make_pixel_label(
		AuroraLocale.text("LINEA DE TIEMPO // CLIC PARA BUSCAR"),
		8,
		AuroraUi.TEAL
	)
	timeline_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(timeline_title)
	var hold_hint := AuroraUi.make_pixel_label(
		AuroraLocale.text("TOQUE = NOTA   MANTENER = NOTA LARGA"),
		7,
		AuroraUi.MUTED
	)
	hold_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hold_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hold_hint)
	timeline = ChartTimeline.new()
	timeline.name = "ChartTimeline"
	timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline.seek_requested.connect(_seek_preview)
	box.add_child(timeline)


func _build_properties(body: HBoxContainer) -> void:
	var side := AuroraUi.make_panel(Color(0.025, 0.030, 0.065, 0.98))
	side.custom_minimum_size.x = 370.0
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 10)
	scroll.add_child(controls)
	controls.add_child(AuroraUi.make_pixel_label(AuroraLocale.text("PROPIEDADES"), 12, AuroraUi.TEXT))
	controls.add_child(
		AuroraUi.make_label(
			AuroraLocale.text("Usa un video con audio o crea un nivel solo con MP3, OGG o WAV."),
			11,
			AuroraUi.MUTED
		)
	)

	video_select_button = _make_tool_button(AuroraLocale.text("ELEGIR VIDEO"), 0.0, true)
	video_select_button.pressed.connect(_open_video_dialog)
	controls.add_child(video_select_button)
	audio_select_button = _make_tool_button(AuroraLocale.text("AUDIO SEPARADO (OPCIONAL)"), 0.0)
	audio_select_button.pressed.connect(_open_audio_dialog)
	controls.add_child(audio_select_button)

	controls.add_child(HSeparator.new())
	title_edit = _add_line_edit(controls, AuroraLocale.text("TITULO"), "Nuevo nivel")
	artist_edit = _add_line_edit(controls, AuroraLocale.text("ARTISTA"), "Aurora Creator")
	difficulty_edit = _add_line_edit(controls, AuroraLocale.text("DIFICULTAD"), "NORMAL")

	bpm_spin = _add_spin_box(controls, "BPM", 40.0, 300.0, 1.0, 128.0)
	bpm_spin.value_changed.connect(_on_chart_property_changed)
	duration_spin = _add_spin_box(
		controls,
		AuroraLocale.text("DURACION (SEGUNDOS)"),
		1.0,
		3600.0,
		0.1,
		duration_seconds
	)
	duration_spin.value_changed.connect(_on_duration_changed)
	difficulty_level_spin = _add_spin_box(
		controls,
		AuroraLocale.text("NIVEL"),
		1.0,
		20.0,
		1.0,
		4.0
	)

	controls.add_child(AuroraUi.make_pixel_label(AuroraLocale.text("CANTIDAD DE TECLAS"), 7, AuroraUi.MUTED))
	key_count_option = OptionButton.new()
	for mode in SUPPORTED_KEY_COUNTS:
		key_count_option.add_item("%dK" % mode, mode)
	key_count_option.selected = 0
	key_count_option.item_selected.connect(_on_key_count_selected)
	key_count_option.custom_minimum_size.y = 44.0
	AuroraUi.apply_pixel_font(key_count_option, 9)
	controls.add_child(key_count_option)

	controls.add_child(AuroraUi.make_pixel_label(AuroraLocale.text("DENSIDAD AUTOMATICA"), 7, AuroraUi.MUTED))
	density_option = OptionButton.new()
	density_option.add_item(AuroraLocale.text("SUAVE"))
	density_option.add_item(AuroraLocale.text("NORMAL"))
	density_option.add_item(AuroraLocale.text("INTENSA"))
	density_option.selected = automatic_density
	density_option.item_selected.connect(_on_density_selected)
	density_option.custom_minimum_size.y = 44.0
	AuroraUi.apply_pixel_font(density_option, 8)
	controls.add_child(density_option)

	controls.add_child(HSeparator.new())
	controls.add_child(
		AuroraUi.make_pixel_label(
			AuroraLocale.text("TECLAS DE GRABACION"),
			8,
			AuroraUi.TEAL
		)
	)
	key_legend = HBoxContainer.new()
	key_legend.add_theme_constant_override("separation", 6)
	controls.add_child(key_legend)

	controls.add_child(AuroraUi.spacer(4))
	controls.add_child(
		AuroraUi.make_label(
			AuroraLocale.text(
				"Manual: reproduce el video y pulsa las teclas. Mantén una tecla para crear una nota larga."
			),
			11,
			AuroraUi.MUTED
		)
	)


func _setup_file_dialogs() -> void:
	video_dialog = FileDialog.new()
	video_dialog.access = FileDialog.ACCESS_FILESYSTEM
	video_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	video_dialog.filters = PackedStringArray(
		[
			"*.ogv,*.mp4,*.mov,*.mkv,*.webm,*.avi,*.m4v ; Video",
			"*.ogv ; Ogg Theora",
			"*.mp4 ; MPEG-4",
			"*.mov ; QuickTime",
			"*.mkv,*.webm ; Matroska / WebM",
			"*.avi ; AVI",
		]
	)
	video_dialog.title = AuroraLocale.text("Seleccionar video con audio")
	video_dialog.file_selected.connect(_load_video)
	add_child(video_dialog)

	audio_dialog = FileDialog.new()
	audio_dialog.access = FileDialog.ACCESS_FILESYSTEM
	audio_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	audio_dialog.filters = PackedStringArray(["*.mp3,*.ogg,*.wav ; Audio"])
	audio_dialog.title = AuroraLocale.text("Seleccionar audio separado")
	audio_dialog.file_selected.connect(_load_audio)
	add_child(audio_dialog)

	project_dialog = FileDialog.new()
	project_dialog.access = FileDialog.ACCESS_USERDATA
	project_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	project_dialog.filters = PackedStringArray(["*.json ; Aurora Editor Project"])
	project_dialog.current_dir = EDITOR_DIRECTORY
	project_dialog.title = AuroraLocale.text("Importar proyecto de Aurora")
	project_dialog.file_selected.connect(_load_project)
	add_child(project_dialog)


func _make_tool_button(text: String, width: float = 0.0, primary: bool = false) -> Button:
	var button := AuroraUi.make_button(text, primary)
	button.custom_minimum_size = Vector2(width, 44.0)
	AuroraUi.apply_pixel_font(button, 8)
	return button


func _add_line_edit(parent: VBoxContainer, caption: String, value: String) -> LineEdit:
	parent.add_child(AuroraUi.make_pixel_label(caption, 7, AuroraUi.MUTED))
	var edit := LineEdit.new()
	edit.text = value
	edit.custom_minimum_size.y = 42.0
	edit.add_theme_font_size_override("font_size", 15)
	parent.add_child(edit)
	return edit


func _add_spin_box(
	parent: VBoxContainer,
	caption: String,
	minimum: float,
	maximum: float,
	step_value: float,
	value: float
) -> SpinBox:
	parent.add_child(AuroraUi.make_pixel_label(caption, 7, AuroraUi.MUTED))
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step_value
	spin.value = value
	spin.custom_minimum_size.y = 42.0
	spin.update_on_text_changed = true
	parent.add_child(spin)
	return spin


func _open_video_dialog() -> void:
	video_dialog.popup_centered_ratio(0.72)


func _open_audio_dialog() -> void:
	audio_dialog.popup_centered_ratio(0.72)


func _open_project_dialog() -> void:
	project_dialog.current_dir = EDITOR_DIRECTORY
	project_dialog.popup_centered_ratio(0.72)


func _load_video(path: String) -> void:
	var import_mode := _get_video_import_mode(path)
	if import_mode == "convert":
		_start_video_conversion(path)
		return
	if import_mode != "direct":
		_set_status(AuroraLocale.text("EL FORMATO DE VIDEO NO ES COMPATIBLE"), true)
		return
	var imported_path := _import_media_file(path, DIRECT_VIDEO_EXTENSIONS)
	if imported_path.is_empty():
		_set_status(AuroraLocale.text("NO SE PUDO COPIAR EL VIDEO AL PROYECTO"), true)
		return
	_assign_video_stream(imported_path, false, path)


func _assign_video_stream(
	imported_path: String,
	was_converted: bool,
	source_path: String = ""
) -> void:
	var resource := load(imported_path)
	if not (resource is VideoStream):
		_set_status(AuroraLocale.text("EL ARCHIVO NO ES UN VIDEO COMPATIBLE"), true)
		return
	_stop_preview()
	video_path = imported_path
	video_source_path = source_path if not source_path.is_empty() else imported_path
	video_player.stream = resource as VideoStream
	preview_placeholder.hide()
	media_status_label.text = AuroraLocale.text("VIDEO LISTO // AUDIO INTEGRADO")
	media_status_label.add_theme_color_override("font_color", AuroraUi.TEAL)
	call_deferred("_refresh_media_duration")
	if was_converted:
		_set_status(
			AuroraLocale.text(
				"VIDEO CONVERTIDO Y CARGADO. EL ARCHIVO ORIGINAL PERMANECE INTACTO."
			)
		)
	else:
		_set_status(AuroraLocale.text("VIDEO CARGADO. YA PUEDES GRABAR O GENERAR NOTAS."))
	_refresh_editor_state()


func _get_video_import_mode(path: String) -> String:
	var extension := path.get_extension().to_lower()
	if extension in DIRECT_VIDEO_EXTENSIONS:
		return "direct"
	if extension in CONVERTIBLE_VIDEO_EXTENSIONS:
		return "convert"
	return "unsupported"


func _start_video_conversion(source_path: String) -> void:
	if video_conversion_pid > 0:
		_set_status(AuroraLocale.text("YA HAY UN VIDEO EN CONVERSIÓN"), true)
		return
	if not FileAccess.file_exists(source_path):
		_set_status(AuroraLocale.text("NO SE ENCONTRÓ EL VIDEO SELECCIONADO"), true)
		return
	var ffmpeg_path := _find_ffmpeg_executable()
	if ffmpeg_path.is_empty():
		_set_status(
			AuroraLocale.text(
				"FALTA EL CONVERSOR THEORA COMPATIBLE PARA IMPORTAR ESTE VIDEO."
			),
			true
		)
		return
	if DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EDITOR_MEDIA_DIRECTORY)
	) != OK:
		_set_status(AuroraLocale.text("NO SE PUDO PREPARAR LA CARPETA DE MEDIOS"), true)
		return

	var source_hash := _media_source_cache_key(source_path)
	if source_hash.is_empty():
		_set_status(AuroraLocale.text("NO SE PUDO LEER EL VIDEO SELECCIONADO"), true)
		return
	var safe_name := _slugify(source_path.get_file().get_basename())
	video_conversion_output_path = "%s/%s_%s_%s.ogv" % [
		EDITOR_MEDIA_DIRECTORY,
		source_hash,
		safe_name,
		VIDEO_CONVERSION_PROFILE,
	]
	if FileAccess.file_exists(video_conversion_output_path):
		_assign_video_stream(video_conversion_output_path, true, source_path)
		return

	video_conversion_temporary_path = "%s/%s_%s_%s.convirtiendo.ogv" % [
		EDITOR_MEDIA_DIRECTORY,
		source_hash,
		safe_name,
		VIDEO_CONVERSION_PROFILE,
	]
	video_conversion_progress_path = "%s/%s_%s_%s.progress" % [
		EDITOR_MEDIA_DIRECTORY,
		source_hash,
		safe_name,
		VIDEO_CONVERSION_PROFILE,
	]
	video_conversion_legacy_path = "%s/%s_%s.ogv" % [
		EDITOR_MEDIA_DIRECTORY,
		source_hash,
		safe_name,
	]
	var temporary_absolute := ProjectSettings.globalize_path(video_conversion_temporary_path)
	if FileAccess.file_exists(video_conversion_temporary_path):
		DirAccess.remove_absolute(temporary_absolute)
	if FileAccess.file_exists(video_conversion_progress_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(video_conversion_progress_path))
	var source_absolute := ProjectSettings.globalize_path(source_path)
	video_conversion_expected_seconds = _probe_media_duration(ffmpeg_path, source_absolute)
	video_conversion_ffmpeg_path = ffmpeg_path
	video_conversion_phase = "encoding"
	var arguments := _build_ffmpeg_arguments(
		source_absolute,
		temporary_absolute,
		ProjectSettings.globalize_path(video_conversion_progress_path)
	)
	video_conversion_pid = OS.create_process(ffmpeg_path, arguments, false)
	if video_conversion_pid <= 0:
		_reset_video_conversion_state()
		_set_status(AuroraLocale.text("NO SE PUDO INICIAR LA CONVERSIÓN DEL VIDEO"), true)
		return

	_stop_preview()
	video_conversion_source_path = source_path
	video_conversion_started_msec = Time.get_ticks_msec()
	video_conversion_status_tick = -1
	_set_video_conversion_controls_disabled(true)
	media_status_label.text = AuroraLocale.text("CONVIRTIENDO VIDEO 0%")
	media_status_label.add_theme_color_override("font_color", AuroraUi.GOLD)
	_set_status(AuroraLocale.text("CONVIRTIENDO VIDEO... PUEDES ESPERAR EN ESTA PANTALLA."))


func _build_ffmpeg_arguments(
	source_absolute: String,
	destination_absolute: String,
	progress_absolute: String = ""
) -> PackedStringArray:
	var arguments := PackedStringArray(
		[
			"-hide_banner",
			"-loglevel",
			"error",
			"-nostats",
			"-y",
		]
	)
	if not progress_absolute.is_empty():
		arguments.append_array(PackedStringArray(["-progress", progress_absolute]))
	arguments.append_array(
		PackedStringArray(
			[
				"-i",
				source_absolute,
				"-map",
				"0:v:0",
				"-map",
				"0:a:0?",
				"-sn",
				"-dn",
				"-vf",
				"fps=30,scale=w='min(1280,iw)':h=-2:flags=lanczos,format=yuv420p",
				"-c:v",
				"libtheora",
				"-g",
				"30",
				"-q:v",
				"5",
				"-c:a",
				"libvorbis",
				"-q:a",
				"4",
				"-ac",
				"2",
				destination_absolute,
			]
		)
	)
	return arguments


func _find_ffmpeg_executable() -> String:
	var local_app_data := OS.get_environment("LOCALAPPDATA")
	var executable_directory := OS.get_executable_path().get_base_dir()
	var candidates: Array[String] = [
		executable_directory.path_join("tools/ffmpeg/bin/ffmpeg.exe"),
		executable_directory.path_join("tools/ffmpeg/ffmpeg.exe"),
		ProjectSettings.globalize_path("res://tools/ffmpeg/bin/ffmpeg.exe"),
		ProjectSettings.globalize_path("res://tools/ffmpeg/ffmpeg.exe"),
		local_app_data.path_join(
			"AuroraDevTools/ffmpeg-minimal-build/package/bin/ffmpeg.exe"
		),
		local_app_data.path_join("Microsoft/WinGet/Links/ffmpeg.exe"),
	]
	for candidate in candidates:
		if (
			not candidate.is_empty()
			and FileAccess.file_exists(candidate)
			and _ffmpeg_has_required_capabilities(candidate)
		):
			return candidate
	var winget_ffmpeg := _find_winget_ffmpeg(local_app_data)
	if not winget_ffmpeg.is_empty() and _ffmpeg_has_required_capabilities(winget_ffmpeg):
		return winget_ffmpeg
	if _ffmpeg_has_required_capabilities("ffmpeg"):
		return "ffmpeg"
	return ""


func _ffmpeg_has_required_capabilities(executable_path: String) -> bool:
	var encoders := _read_ffmpeg_capability_list(executable_path, "-encoders")
	var filters := _read_ffmpeg_capability_list(executable_path, "-filters")
	var demuxers := _read_ffmpeg_capability_list(executable_path, "-demuxers")
	var muxers := _read_ffmpeg_capability_list(executable_path, "-muxers")
	if encoders.is_empty() or filters.is_empty() or demuxers.is_empty() or muxers.is_empty():
		return false
	return (
		_ffmpeg_listing_has_all(encoders, REQUIRED_FFMPEG_ENCODERS)
		and _ffmpeg_listing_has_all(filters, REQUIRED_FFMPEG_FILTERS)
		and _ffmpeg_listing_has_all(demuxers, REQUIRED_FFMPEG_DEMUXERS)
		and _ffmpeg_listing_has_all(muxers, REQUIRED_FFMPEG_MUXERS)
	)


func _read_ffmpeg_capability_list(executable_path: String, option: String) -> String:
	var output: Array = []
	var exit_code := OS.execute(
		executable_path,
		PackedStringArray(["-hide_banner", option]),
		output,
		true,
		false
	)
	return "\n".join(output) if exit_code == 0 else ""


func _ffmpeg_listing_has_all(listing: String, required_names: Array[String]) -> bool:
	for required_name in required_names:
		if not _ffmpeg_listing_has_name(listing, required_name):
			return false
	return true


func _ffmpeg_listing_has_name(listing: String, required_name: String) -> bool:
	for line in listing.split("\n"):
		var columns := line.strip_edges().split(" ", false)
		if columns.size() < 2:
			continue
		for listed_name in columns[1].split(",", false):
			if listed_name == required_name:
				return true
	return false


func _find_winget_ffmpeg(local_app_data: String) -> String:
	var packages_path := local_app_data.path_join("Microsoft/WinGet/Packages")
	var packages := DirAccess.open(packages_path)
	if packages == null:
		return ""
	for package_name in packages.get_directories():
		if (
			not package_name.begins_with("Gyan.FFmpeg_")
			and not package_name.begins_with("BtbN.FFmpeg_")
		):
			continue
		var package_path := packages_path.path_join(package_name)
		var package := DirAccess.open(package_path)
		if package == null:
			continue
		for build_name in package.get_directories():
			var candidate := package_path.path_join(build_name).path_join("bin/ffmpeg.exe")
			if FileAccess.file_exists(candidate):
				return candidate
	return ""


func _probe_media_duration(ffmpeg_path: String, source_absolute: String) -> float:
	var ffprobe_path := ffmpeg_path.get_base_dir().path_join(
		"ffprobe.exe" if OS.get_name() == "Windows" else "ffprobe"
	)
	if not FileAccess.file_exists(ffprobe_path):
		return 0.0
	var output: Array = []
	var exit_code := OS.execute(
		ffprobe_path,
		PackedStringArray(
			[
				"-v",
				"error",
				"-show_entries",
				"format=duration",
				"-of",
				"default=noprint_wrappers=1:nokey=1",
				source_absolute,
			]
		),
		output,
		true,
		false
	)
	if exit_code != 0 or output.is_empty():
		return 0.0
	return maxf(float(str(output[0]).strip_edges()), 0.0)


func _poll_video_conversion() -> void:
	if video_conversion_pid <= 0:
		return
	if OS.is_process_running(video_conversion_pid):
		var elapsed_seconds := int(
			float(Time.get_ticks_msec() - video_conversion_started_msec) / 1000.0
		)
		var tick := elapsed_seconds % 4
		if tick != video_conversion_status_tick:
			video_conversion_status_tick = tick
			if video_conversion_phase == "validating":
				media_status_label.text = AuroraLocale.text("VALIDANDO VIDEO")
			else:
				var progress := _read_video_conversion_progress()
				if progress >= 0:
					media_status_label.text = AuroraLocale.text("CONVIRTIENDO VIDEO %d%%") % progress
				else:
					var dots := ".".repeat(tick)
					media_status_label.text = AuroraLocale.text("CONVIRTIENDO VIDEO%s") % dots
		return

	var exit_code := OS.get_process_exit_code(video_conversion_pid)
	if video_conversion_phase == "encoding":
		if exit_code != 0 or not FileAccess.file_exists(video_conversion_temporary_path):
			_fail_video_conversion(
				AuroraLocale.text(
					"NO SE PUDO CONVERTIR EL VIDEO. REVISA QUE EL ARCHIVO NO ESTÉ DAÑADO."
				)
			)
			return
		_start_video_validation()
		return

	var completed_output_path := video_conversion_output_path
	var completed_temporary_path := video_conversion_temporary_path
	var completed_source_path := video_conversion_source_path
	var completed_legacy_path := video_conversion_legacy_path
	var completed_progress_path := video_conversion_progress_path
	_reset_video_conversion_state()
	_set_video_conversion_controls_disabled(false)
	if exit_code != 0 or not FileAccess.file_exists(completed_temporary_path):
		_remove_generated_file(completed_temporary_path)
		_remove_generated_file(completed_progress_path)
		media_status_label.text = AuroraLocale.text("VIDEO INVÁLIDO")
		media_status_label.add_theme_color_override("font_color", AuroraUi.CORAL)
		_set_status(AuroraLocale.text("LA COPIA CONVERTIDA NO SUPERÓ LA VALIDACIÓN."), true)
		return
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(completed_temporary_path),
		ProjectSettings.globalize_path(completed_output_path)
	)
	if rename_error != OK:
		_set_status(AuroraLocale.text("EL VIDEO SE CONVIRTIÓ, PERO NO SE PUDO GUARDAR"), true)
		return
	_remove_generated_file(completed_progress_path)
	if completed_legacy_path != completed_output_path:
		_remove_generated_file(completed_legacy_path)
	_assign_video_stream(completed_output_path, true, completed_source_path)


func _start_video_validation() -> void:
	video_conversion_phase = "validating"
	media_status_label.text = AuroraLocale.text("VALIDANDO VIDEO")
	var arguments := PackedStringArray(
		[
			"-hide_banner",
			"-loglevel",
			"error",
			"-xerror",
			"-i",
			ProjectSettings.globalize_path(video_conversion_temporary_path),
			"-f",
			"null",
			"-",
		]
	)
	video_conversion_pid = OS.create_process(video_conversion_ffmpeg_path, arguments, false)
	if video_conversion_pid <= 0:
		_fail_video_conversion(AuroraLocale.text("NO SE PUDO VALIDAR EL VIDEO CONVERTIDO."))


func _read_video_conversion_progress() -> int:
	if video_conversion_expected_seconds <= 0.0:
		return -1
	if not FileAccess.file_exists(video_conversion_progress_path):
		return 0
	var file := FileAccess.open(video_conversion_progress_path, FileAccess.READ)
	if file == null:
		return 0
	var output_seconds := 0.0
	for line in file.get_as_text().split("\n"):
		if line.begins_with("out_time_us="):
			output_seconds = float(line.trim_prefix("out_time_us=")) / 1000000.0
	return clampi(roundi(output_seconds / video_conversion_expected_seconds * 100.0), 0, 99)


func _fail_video_conversion(message: String) -> void:
	_remove_generated_file(video_conversion_temporary_path)
	_remove_generated_file(video_conversion_progress_path)
	_reset_video_conversion_state()
	_set_video_conversion_controls_disabled(false)
	media_status_label.text = AuroraLocale.text("ERROR DE CONVERSIÓN")
	media_status_label.add_theme_color_override("font_color", AuroraUi.CORAL)
	_set_status(message, true)


func _remove_generated_file(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _set_video_conversion_controls_disabled(disabled: bool) -> void:
	if video_select_button != null:
		video_select_button.disabled = disabled
	if audio_select_button != null:
		audio_select_button.disabled = disabled
	if record_button != null:
		record_button.disabled = disabled
	if generate_button != null:
		generate_button.disabled = disabled
	if test_button != null:
		test_button.disabled = disabled


func _reset_video_conversion_state() -> void:
	video_conversion_pid = -1
	video_conversion_source_path = ""
	video_conversion_output_path = ""
	video_conversion_temporary_path = ""
	video_conversion_progress_path = ""
	video_conversion_legacy_path = ""
	video_conversion_ffmpeg_path = ""
	video_conversion_phase = ""
	video_conversion_expected_seconds = 0.0
	video_conversion_started_msec = 0
	video_conversion_status_tick = -1


func _load_audio(path: String) -> void:
	var imported_path := _import_media_file(path, ["mp3", "ogg", "wav"])
	if imported_path.is_empty():
		_set_status(AuroraLocale.text("NO SE PUDO COPIAR EL AUDIO AL PROYECTO"), true)
		return
	var resource := _load_audio_stream(imported_path)
	if resource == null:
		_set_status(AuroraLocale.text("EL ARCHIVO NO ES AUDIO COMPATIBLE"), true)
		return
	_stop_preview()
	audio_path = imported_path
	audio_player.stream = resource
	video_player.volume_db = -80.0
	if video_player.stream != null:
		media_status_label.text = AuroraLocale.text("VIDEO + AUDIO SEPARADO")
		preview_placeholder.hide()
	else:
		media_status_label.text = AuroraLocale.text("AUDIO LISTO // SIN VIDEO")
		preview_placeholder.text = AuroraLocale.text("NIVEL SOLO AUDIO")
		preview_placeholder.show()
	media_status_label.add_theme_color_override("font_color", AuroraUi.GOLD)
	_refresh_media_duration()
	_set_status(AuroraLocale.text("AUDIO CARGADO Y LISTO PARA CREAR EL CHART."))


func _import_media_file(source_path: String, allowed_extensions: Array) -> String:
	var extension := source_path.get_extension().to_lower()
	if extension not in allowed_extensions:
		return ""
	if source_path.begins_with("res://") or source_path.begins_with("user://"):
		return source_path
	if not FileAccess.file_exists(source_path):
		return ""

	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EDITOR_MEDIA_DIRECTORY)
	)
	if directory_error != OK:
		return ""
	var source_hash := _media_source_cache_key(source_path)
	if source_hash.is_empty():
		return ""
	var safe_name := _slugify(source_path.get_file().get_basename())
	var destination := "%s/%s_%s.%s" % [
		EDITOR_MEDIA_DIRECTORY,
		source_hash,
		safe_name,
		extension,
	]
	if FileAccess.file_exists(destination):
		return destination
	var copy_error := DirAccess.copy_absolute(
		source_path,
		ProjectSettings.globalize_path(destination)
	)
	return destination if copy_error == OK else ""


func _media_source_cache_key(source_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path(source_path)
	var source_file := FileAccess.open(absolute_path, FileAccess.READ)
	if source_file == null:
		return ""
	var file_size := source_file.get_length()
	var modified_time := FileAccess.get_modified_time(absolute_path)
	var normalized_path := absolute_path.simplify_path().replace("\\", "/")
	if OS.get_name() == "Windows":
		normalized_path = normalized_path.to_lower()

	var hash_context := HashingContext.new()
	if hash_context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	hash_context.update(
		("%s\n%d\n%d\n" % [normalized_path, file_size, modified_time]).to_utf8_buffer()
	)

	# Reading the first, middle and last 64 KiB detects replaced media without
	# hashing an entire multi-gigabyte video on the main thread.
	var sample_size := mini(MEDIA_CACHE_SAMPLE_BYTES, file_size)
	var sample_offsets: Array[int] = [0]
	if file_size > sample_size:
		sample_offsets.append(maxi(0, int((file_size - sample_size) / 2)))
		sample_offsets.append(maxi(0, file_size - sample_size))
	for sample_offset in sample_offsets:
		source_file.seek(sample_offset)
		hash_context.update(source_file.get_buffer(sample_size))
	return hash_context.finish().hex_encode().substr(0, 16)


func _load_audio_stream(path: String) -> AudioStream:
	if path.begins_with("res://"):
		var imported_resource := load(path)
		if imported_resource is AudioStream:
			return imported_resource as AudioStream
	var filesystem_path := ProjectSettings.globalize_path(path)
	match path.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_file(filesystem_path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(filesystem_path)
		"wav":
			return AudioStreamWAV.load_from_file(filesystem_path)
	return null


func _refresh_media_duration() -> void:
	var detected_duration := 0.0
	if video_player.stream != null:
		detected_duration = maxf(detected_duration, video_player.get_stream_length())
	if audio_player.stream != null:
		detected_duration = maxf(detected_duration, audio_player.stream.get_length())
	if detected_duration > 0.1:
		duration_seconds = detected_duration
		duration_spin.set_value_no_signal(duration_seconds)
		notes = ChartData.normalize_notes(
			notes.filter(func(note: Dictionary) -> bool: return float(note.get("time", 0.0)) <= duration_seconds),
			key_count
		)
	seek_slider.max_value = maxf(duration_seconds, 1.0)
	_refresh_editor_state()


func _has_media() -> bool:
	return (
		(video_player != null and video_player.stream != null)
		or (audio_player != null and audio_player.stream != null)
	)


func _toggle_preview() -> void:
	if preview_running:
		_pause_preview()
	else:
		_play_preview()


func _play_preview() -> void:
	if not _has_media():
		_set_status(AuroraLocale.text("PRIMERO SELECCIONA VIDEO O AUDIO"), true)
		return
	if preview_time >= duration_seconds - 0.01:
		preview_time = 0.0

	if video_player.stream != null:
		video_player.play()
		video_player.stream_position = preview_time
		video_player.paused = false
	if audio_player.stream != null:
		video_player.volume_db = -80.0
		audio_player.play(preview_time)
		audio_player.stream_paused = false
	else:
		video_player.volume_db = 0.0
	preview_running = true
	play_button.text = AuroraLocale.text("Ⅱ PAUSAR")


func _pause_preview() -> void:
	if video_player != null:
		video_player.paused = true
	if audio_player != null and audio_player.stream != null:
		audio_player.stream_paused = true
	preview_running = false
	play_button.text = AuroraLocale.text("▶ REPRODUCIR")


func _stop_preview() -> void:
	_cancel_recording_countdown()
	_finish_open_recorded_notes()
	recording = false
	if record_button != null:
		record_button.button_pressed = false
		record_button.text = AuroraLocale.text("● GRABAR NOTAS")
	if video_player != null:
		video_player.stop()
	if audio_player != null:
		audio_player.stop()
	preview_running = false
	preview_time = 0.0
	if play_button != null:
		play_button.text = AuroraLocale.text("▶ REPRODUCIR")
	_update_playhead_ui()


func _seek_preview(seconds: float) -> void:
	preview_time = clampf(seconds, 0.0, duration_seconds)
	if video_player != null and video_player.stream != null:
		video_player.stream_position = preview_time
	if audio_player != null and audio_player.stream != null and audio_player.playing:
		audio_player.seek(preview_time)
	_update_playhead_ui()


func _update_playhead_ui() -> void:
	if seek_slider != null:
		seek_slider.set_value_no_signal(preview_time)
	if timeline != null:
		timeline.set_playhead(preview_time)
	if time_label != null:
		time_label.text = "%s / %s" % [_format_time(preview_time), _format_time(duration_seconds)]


func _set_creation_mode(mode: String) -> void:
	creation_mode = mode
	if recording_countdown_active:
		_cancel_recording_countdown()
	if creation_mode != "manual" and recording:
		_toggle_recording()
	if creation_mode_switch != null:
		creation_mode_switch.set_pressed_no_signal(creation_mode == "automatic")
	if manual_mode_label != null:
		manual_mode_label.add_theme_color_override(
			"font_color",
			AuroraUi.TEAL if creation_mode == "manual" else AuroraUi.MUTED
		)
	if automatic_mode_label != null:
		automatic_mode_label.add_theme_color_override(
			"font_color",
			AuroraUi.TEAL if creation_mode == "automatic" else AuroraUi.MUTED
		)
	record_button.disabled = creation_mode != "manual" or not _has_media()
	generate_button.disabled = creation_mode != "automatic" or not _has_media()
	_set_status(
		AuroraLocale.text("MODO MANUAL: PULSA Y MANTEN LAS TECLAS")
		if creation_mode == "manual"
		else AuroraLocale.text("MODO AUTOMATICO: GENERACION BASE POR BPM")
	)


func _on_creation_mode_switched(automatic_enabled: bool) -> void:
	_set_creation_mode("automatic" if automatic_enabled else "manual")


func _toggle_recording() -> void:
	if recording_countdown_active:
		_cancel_recording_countdown()
		_set_status(AuroraLocale.text("PREPARACION DE GRABACION CANCELADA"))
		return
	if recording:
		_finish_open_recorded_notes()
		recording = false
		record_button.button_pressed = false
		record_button.text = AuroraLocale.text("● GRABAR NOTAS")
		_set_status(AuroraLocale.text("GRABACION DETENIDA"))
		return
	if not _has_media():
		record_button.button_pressed = false
		_set_status(AuroraLocale.text("SELECCIONA VIDEO O AUDIO ANTES DE GRABAR"), true)
		return
	if creation_mode != "manual":
		record_button.button_pressed = false
		return
	_begin_recording_countdown()


func _begin_recording_countdown() -> void:
	_pause_preview()
	recording_countdown_active = true
	recording_countdown_token += 1
	var countdown_token := recording_countdown_token
	record_button.button_pressed = true
	record_button.text = AuroraLocale.text("CANCELAR PREPARACION")
	for value in [2, 1]:
		if countdown_token != recording_countdown_token or not is_inside_tree():
			return
		recording_countdown_label.text = str(value)
		recording_countdown_label.add_theme_color_override("font_color", AuroraUi.GOLD)
		recording_countdown_label.show()
		_set_status(AuroraLocale.text("GRABACION COMIENZA EN %d") % value)
		await get_tree().create_timer(1.0).timeout
	if countdown_token != recording_countdown_token or not is_inside_tree():
		return
	recording_countdown_label.text = AuroraLocale.text("¡YA!")
	recording_countdown_label.add_theme_color_override("font_color", AuroraUi.TEAL)
	await get_tree().create_timer(0.22).timeout
	if countdown_token != recording_countdown_token or not is_inside_tree():
		return
	recording_countdown_label.hide()
	recording_countdown_active = false
	recording = true
	record_button.button_pressed = true
	record_button.text = AuroraLocale.text("■ DETENER GRABACION")
	_play_preview()
	_set_status(AuroraLocale.text("GRABANDO // TOCA O MANTEN LAS TECLAS DE CARRIL"))


func _cancel_recording_countdown() -> void:
	if not recording_countdown_active:
		return
	recording_countdown_token += 1
	recording_countdown_active = false
	if recording_countdown_label != null:
		recording_countdown_label.hide()
	if record_button != null:
		record_button.set_pressed_no_signal(false)
		record_button.text = AuroraLocale.text("● GRABAR NOTAS")


func _record_lane_pressed(lane: int) -> void:
	if active_recording_holds.has(lane):
		return
	active_recording_holds[lane] = preview_time


func _record_lane_released(lane: int) -> void:
	if not active_recording_holds.has(lane):
		return
	var start_time := float(active_recording_holds[lane])
	active_recording_holds.erase(lane)
	var hold_duration := maxf(preview_time - start_time, 0.0)
	notes.append({
		"time": snappedf(start_time, 0.001),
		"lane": lane,
		"duration": snappedf(hold_duration, 0.001) if hold_duration >= MIN_HOLD_DURATION else 0.0,
	})
	notes = ChartData.normalize_notes(notes, key_count)
	_refresh_editor_state()


func _finish_open_recorded_notes() -> void:
	for raw_lane in active_recording_holds.keys():
		_record_lane_released(int(raw_lane))
	active_recording_holds.clear()


func _generate_automatic_chart() -> void:
	if not _has_media():
		_set_status(AuroraLocale.text("SELECCIONA VIDEO O AUDIO ANTES DE GENERAR"), true)
		return
	_finish_open_recorded_notes()
	notes = _build_automatic_notes(
		float(bpm_spin.value),
		duration_seconds,
		key_count,
		automatic_density
	)
	_refresh_editor_state()
	_set_status(
		AuroraLocale.text(
			"PATRON BASE GENERADO POR BPM. REVISA Y AJUSTA LAS NOTAS MANUALMENTE."
		)
	)


func _build_automatic_notes(
	chart_bpm: float,
	chart_duration: float,
	chart_key_count: int,
	density: int
) -> Array[Dictionary]:
	var generated: Array[Dictionary] = []
	var beat_seconds := 60.0 / maxf(chart_bpm, 1.0)
	var subdivision := 1.0
	if density <= 0:
		subdivision = 2.0
	elif density >= 2:
		subdivision = 0.5
	var step_seconds := beat_seconds * subdivision
	var start_time := maxf(1.5, beat_seconds * 4.0)
	var step := 0
	var note_time := start_time
	while note_time < chart_duration - 0.5 and step < 10000:
		var lane := (step * 3 + floori(float(step) / float(maxi(chart_key_count, 1)))) % chart_key_count
		var hold_duration := 0.0
		if step > 0 and step % 12 == 8:
			hold_duration = minf(beat_seconds * 1.5, chart_duration - note_time - 0.1)
		generated.append({
			"time": snappedf(note_time, 0.001),
			"lane": lane,
			"duration": snappedf(maxf(hold_duration, 0.0), 0.001),
		})
		if density >= 2 and step > 0 and step % 8 == 0:
			generated.append({
				"time": snappedf(note_time, 0.001),
				"lane": (lane + maxi(1, floori(float(chart_key_count) / 2.0))) % chart_key_count,
				"duration": 0.0,
			})
		step += 1
		note_time = start_time + float(step) * step_seconds
	return ChartData.normalize_notes(generated, chart_key_count)


func _undo_last_note() -> void:
	if notes.is_empty():
		return
	notes.remove_at(notes.size() - 1)
	_refresh_editor_state()
	_set_status(AuroraLocale.text("ULTIMA NOTA ELIMINADA"))


func _clear_notes() -> void:
	_finish_open_recorded_notes()
	notes.clear()
	_refresh_editor_state()
	_set_status(AuroraLocale.text("CHART LIMPIO"))


func _on_key_count_selected(index: int) -> void:
	if index < 0 or index >= SUPPORTED_KEY_COUNTS.size():
		return
	_finish_open_recorded_notes()
	key_count = SUPPORTED_KEY_COUNTS[index]
	notes = ChartData.normalize_notes(notes, key_count)
	_refresh_editor_state()
	_set_status(AuroraLocale.text("MODO DE TECLAS CAMBIADO A %dK") % key_count)


func _on_density_selected(index: int) -> void:
	automatic_density = clampi(index, 0, 2)


func _on_chart_property_changed(_value: float) -> void:
	_refresh_editor_state()


func _on_duration_changed(value: float) -> void:
	duration_seconds = maxf(value, 1.0)
	seek_slider.max_value = duration_seconds
	notes = ChartData.normalize_notes(
		notes.filter(func(note: Dictionary) -> bool: return float(note["time"]) <= duration_seconds),
		key_count
	)
	_refresh_editor_state()


func _refresh_editor_state() -> void:
	if timeline != null:
		timeline.set_chart(notes, duration_seconds, float(bpm_spin.value), key_count)
		timeline.set_playhead(preview_time)
	if note_count_label != null:
		var hold_count := 0
		for note in notes:
			if float(note.get("duration", 0.0)) >= MIN_HOLD_DURATION:
				hold_count += 1
		note_count_label.text = "%03d NOTAS // %02d HOLD" % [notes.size(), hold_count]
	if key_legend != null:
		for child in key_legend.get_children():
			child.queue_free()
		var keycodes := input_manager.get_mode_keycodes(key_count)
		for lane in range(key_count):
			var badge := AuroraUi.make_pixel_label(input_manager.get_key_label(keycodes[lane]), 8, AuroraUi.TEXT)
			badge.custom_minimum_size = Vector2(34.0, 34.0)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			key_legend.add_child(badge)
	if record_button != null:
		record_button.disabled = creation_mode != "manual" or not _has_media()
	if generate_button != null:
		generate_button.disabled = creation_mode != "automatic" or not _has_media()
	if test_button != null:
		test_button.disabled = not _has_media() or notes.is_empty()
	_update_playhead_ui()


func _save_project() -> bool:
	_finish_open_recorded_notes()
	var next_project_path := current_project_path
	var chart_path := ""
	if next_project_path.is_empty():
		var new_path_result := PROJECT_STORE.make_new_project_path(
			EDITOR_DIRECTORY,
			_slugify(title_edit.text)
		)
		if not bool(new_path_result.get("ok", false)):
			_set_status(AuroraLocale.text(str(new_path_result.get("message", ""))), true)
			return false
		next_project_path = str(new_path_result.get("project_path", ""))
		chart_path = str(new_path_result.get("chart_path", ""))
	else:
		chart_path = "%s/%s" % [
			next_project_path.get_base_dir(),
			PROJECT_STORE.CHART_FILE_NAME,
		]

	var project_data := _make_project_document(chart_path)
	var save_result := PROJECT_STORE.save_bundle(
		next_project_path,
		project_data,
		ChartData.make_chart_document(notes, key_count)
	)
	if not bool(save_result.get("ok", false)):
		_set_status(AuroraLocale.text(str(save_result.get("message", ""))), true)
		return false

	current_project_path = str(save_result.get("project_path", next_project_path))
	song_manager.load_songs()

	if not _has_media():
		_set_status(AuroraLocale.text("BORRADOR GUARDADO // FALTA VIDEO O AUDIO"), true)
	elif notes.is_empty():
		_set_status(AuroraLocale.text("BORRADOR GUARDADO // FALTAN NOTAS"), true)
	else:
		_set_status(AuroraLocale.text("PROYECTO Y CHART GUARDADOS EN DATOS DE USUARIO"))
	return true


func _make_project_document(chart_path: String = "") -> Dictionary:
	return {
		"version": PROJECT_STORE.PROJECT_VERSION,
		"type": "aurora_editor_project",
		"metadata": {
			"title": title_edit.text.strip_edges(),
			"artist": artist_edit.text.strip_edges(),
			"difficulty": difficulty_edit.text.strip_edges().to_upper(),
			"difficulty_level": int(difficulty_level_spin.value),
			"bpm": float(bpm_spin.value),
			"duration_seconds": duration_seconds,
			"key_count": key_count,
			"creation_mode": creation_mode,
			"automatic_density": automatic_density,
		},
		"media": {
			"video_path": video_path,
			"video_source_path": video_source_path,
			"audio_path": audio_path,
		},
		"chart_path": chart_path,
	}


func _load_project(path: String) -> void:
	var load_result := PROJECT_STORE.load_bundle(path)
	if not bool(load_result.get("ok", false)):
		_set_status(AuroraLocale.text(str(load_result.get("message", ""))), true)
		return

	_stop_preview()
	current_project_path = str(load_result.get("project_path", path))
	var parsed: Dictionary = load_result.get("project", {})
	var metadata: Dictionary = parsed.get("metadata", {})
	title_edit.text = str(metadata.get("title", "Nuevo nivel"))
	artist_edit.text = str(metadata.get("artist", "Aurora Creator"))
	difficulty_edit.text = str(metadata.get("difficulty", "NORMAL"))
	bpm_spin.value = clampf(float(metadata.get("bpm", 128.0)), 40.0, 300.0)
	duration_seconds = maxf(float(metadata.get("duration_seconds", 120.0)), 1.0)
	duration_spin.set_value_no_signal(duration_seconds)
	difficulty_level_spin.value = clampi(int(metadata.get("difficulty_level", 4)), 1, 20)
	key_count = int(metadata.get("key_count", 4))
	if key_count not in SUPPORTED_KEY_COUNTS:
		key_count = 4
	key_count_option.selected = SUPPORTED_KEY_COUNTS.find(key_count)
	automatic_density = clampi(int(metadata.get("automatic_density", 1)), 0, 2)
	density_option.selected = automatic_density
	notes = ChartData.normalize_notes(load_result.get("notes", []), key_count)
	var media: Dictionary = parsed.get("media", {})
	video_path = str(media.get("video_path", ""))
	video_source_path = str(media.get("video_source_path", ""))
	audio_path = str(media.get("audio_path", ""))
	if not video_source_path.is_empty() and FileAccess.file_exists(video_source_path):
		_load_video(video_source_path)
	elif not video_path.is_empty():
		_load_video(video_path)
	if not audio_path.is_empty():
		_load_audio(audio_path)
	_set_creation_mode(str(metadata.get("creation_mode", "manual")))
	seek_slider.max_value = duration_seconds
	_refresh_editor_state()
	if bool(load_result.get("needs_migration", false)):
		_set_status(AuroraLocale.text("PROYECTO ANTIGUO ABIERTO // SE MIGRARA AL GUARDAR"))
	else:
		_set_status(AuroraLocale.text("PROYECTO ABIERTO"))


func _new_project() -> void:
	_stop_preview()
	notes.clear()
	active_recording_holds.clear()
	video_path = ""
	video_source_path = ""
	audio_path = ""
	current_project_path = ""
	video_player.stream = null
	audio_player.stream = null
	video_player.volume_db = 0.0
	title_edit.text = "Nuevo nivel"
	artist_edit.text = "Aurora Creator"
	difficulty_edit.text = "NORMAL"
	bpm_spin.value = 128.0
	duration_seconds = 120.0
	duration_spin.set_value_no_signal(duration_seconds)
	difficulty_level_spin.value = 4.0
	key_count = 4
	key_count_option.selected = 0
	automatic_density = 1
	density_option.selected = 1
	preview_placeholder.show()
	preview_placeholder.text = AuroraLocale.text("SELECCIONA VIDEO O AUDIO")
	media_status_label.text = AuroraLocale.text("MEDIO REQUERIDO")
	media_status_label.add_theme_color_override("font_color", AuroraUi.CORAL)
	_set_creation_mode("manual")
	_refresh_editor_state()
	_set_status(AuroraLocale.text("PROYECTO NUEVO"))


func _restore_editor_test_if_needed() -> bool:
	if not game_manager.editor_test_active:
		return false
	var return_project_path := game_manager.take_editor_test_project_path()
	if return_project_path.is_empty() or not FileAccess.file_exists(return_project_path):
		_refresh_editor_state()
		_set_status(AuroraLocale.text("NO SE PUDO RECUPERAR EL PROYECTO DE PRUEBA"), true)
		return true
	_load_project(return_project_path)
	_set_status(AuroraLocale.text("PRUEBA FINALIZADA // CHART RECUPERADO PARA SEGUIR EDITANDO"))
	return true


func _test_chart() -> void:
	if not _has_media():
		_set_status(AuroraLocale.text("SELECCIONA VIDEO O AUDIO PARA PROBAR"), true)
		return
	if notes.is_empty():
		_set_status(AuroraLocale.text("AGREGA O GENERA NOTAS ANTES DE PROBAR"), true)
		return
	if not _save_project():
		_set_status(AuroraLocale.text("NO SE PUDO GUARDAR; LA PRUEBA FUE CANCELADA"), true)
		return
	var saved_bundle := PROJECT_STORE.load_bundle(current_project_path)
	if not bool(saved_bundle.get("ok", false)):
		_set_status(AuroraLocale.text("NO SE PUDO PREPARAR EL CHART DE PRUEBA"), true)
		return
	var chart_path := str(saved_bundle.get("chart_path", ""))

	var chart := ChartData.new()
	chart.key_count = key_count
	chart.difficulty_name = difficulty_edit.text.strip_edges().to_upper()
	chart.difficulty_level = int(difficulty_level_spin.value)
	chart.chart_path = chart_path

	var song := SongData.new()
	var project_id := current_project_path.get_base_dir().get_file()
	song.song_id = StringName("editor_%s" % project_id)
	song.title = title_edit.text.strip_edges()
	song.artist = artist_edit.text.strip_edges()
	song.bpm = float(bpm_spin.value)
	song.duration_seconds = duration_seconds
	song.background_video = video_player.stream
	song.audio = audio_player.stream
	song.charts = [chart]
	game_manager.start_editor_test(song, chart, current_project_path)
	scene_manager.load_scene("gameplay")


func _slugify(source: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-z0-9]+")
	var slug := regex.sub(source.strip_edges().to_lower(), "_", true).trim_prefix("_").trim_suffix("_")
	return slug if not slug.is_empty() else "nuevo_nivel"


func _format_time(seconds: float) -> String:
	var safe_seconds := maxf(seconds, 0.0)
	var minutes := floori(safe_seconds / 60.0)
	var remaining_seconds := floori(fmod(safe_seconds, 60.0))
	var milliseconds := floori(fmod(safe_seconds * 1000.0, 1000.0))
	return "%02d:%02d.%03d" % [minutes, remaining_seconds, milliseconds]


func _set_status(message: String, is_warning: bool = false) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.add_theme_color_override("font_color", AuroraUi.CORAL if is_warning else AuroraUi.TEAL)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if recording:
			var joy_lane := input_manager.get_mode_joy_buttons(key_count).find(
				int(event.button_index)
			)
			if joy_lane >= 0:
				if event.pressed:
					_record_lane_pressed(joy_lane)
				else:
					_record_lane_released(joy_lane)
				get_viewport().set_input_as_handled()
				return
			if event.pressed and input_manager.controller_event_matches(event, "pause"):
				_toggle_recording()
			if event.pressed:
				get_viewport().set_input_as_handled()
			return

		if event.pressed and input_manager.controller_event_matches(event, "pause"):
			get_viewport().set_input_as_handled()
			if recording_countdown_active:
				_toggle_recording()
			else:
				_toggle_preview()
			return
		if event.pressed and input_manager.controller_event_matches(event, "back"):
			get_viewport().set_input_as_handled()
			if recording_countdown_active:
				_toggle_recording()
			else:
				scene_manager.load_scene("main_menu")
			return

	if event is InputEventKey and not event.echo:
		if recording:
			var keycode := int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
			var lane := input_manager.get_mode_keycodes(key_count).find(keycode)
			if lane >= 0:
				if event.pressed:
					_record_lane_pressed(lane)
				else:
					_record_lane_released(lane)
				get_viewport().set_input_as_handled()
				return

		if event.pressed and event.keycode == KEY_SPACE:
			var focus_owner := get_viewport().gui_get_focus_owner()
			if not (focus_owner is LineEdit or focus_owner is TextEdit):
				get_viewport().set_input_as_handled()
				if not recording and not recording_countdown_active:
					_toggle_preview()
				return

		if event.pressed and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if recording or recording_countdown_active:
				_toggle_recording()
			else:
				scene_manager.load_scene("main_menu")


func _exit_tree() -> void:
	if video_conversion_pid > 0 and OS.is_process_running(video_conversion_pid):
		OS.kill(video_conversion_pid)
	if not video_conversion_temporary_path.is_empty() and FileAccess.file_exists(
		video_conversion_temporary_path
	):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(video_conversion_temporary_path))
	if not video_conversion_progress_path.is_empty() and FileAccess.file_exists(
		video_conversion_progress_path
	):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(video_conversion_progress_path))
	_reset_video_conversion_state()
	if video_player != null:
		video_player.stop()
	if audio_player != null:
		audio_player.stop()
