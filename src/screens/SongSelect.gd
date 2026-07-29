extends Control

class_name SongSelect

const SONG_LIST_ITEM_SCENE := preload("res://src/screens/song_select/SongListItem.tscn")

@onready var back_button: Button = $LibraryMargins/PageLayout/Header/BackButton
@onready var title_label: Label = $LibraryMargins/PageLayout/Header/HeaderCopy/TitleLabel
@onready var subtitle_label: Label = $LibraryMargins/PageLayout/Header/HeaderCopy/SubtitleLabel
@onready var song_count_label: Label = $LibraryMargins/PageLayout/Header/SongCountLabel
@onready var song_list_header: Label = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/SongListHeader
@onready var song_list: VBoxContainer = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/SongScroll/SongList
@onready var preview_cover: TextureRect = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewCover
@onready var preview_video: VideoStreamPlayer = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewCover/PreviewVideo
@onready var preview_title: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewTitle
@onready var preview_artist: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewArtist
@onready var preview_meta: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewMeta
@onready var note_speed_down: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/NoteSpeedPanel/NoteSpeedMargins/NoteSpeedRow/DecreaseButton
@onready var note_speed_value: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/NoteSpeedPanel/NoteSpeedMargins/NoteSpeedRow/ValueLabel
@onready var note_speed_up: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/NoteSpeedPanel/NoteSpeedMargins/NoteSpeedRow/IncreaseButton
@onready var note_speed_caption: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/NoteSpeedPanel/NoteSpeedMargins/NoteSpeedRow/Caption
@onready var mode_buttons_container: HBoxContainer = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/ModeButtons
@onready var mode_caption: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/ModeCaption
@onready var difficulty_label: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/DifficultyLabel
@onready var preview_status: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewStatus
@onready var preview_button: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewActions/PreviewButton
@onready var delete_button: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewActions/DeleteButton
@onready var play_button: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PlayButton
@onready var controls_label: Label = $LibraryMargins/PageLayout/Footer/ControlsLabel
@onready var preview_audio: AudioStreamPlayer = $PreviewAudio

var scene_manager: SceneManager
var game_manager: GameManager
var song_manager: SongManager
var settings_manager: SettingsManager
var input_manager: InputManager
var songs: Array[SongData] = []
var song_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var selected_song_index := 0
var selected_chart_index := 0
var preview_end_seconds := 0.0
var preview_video_end_seconds := 0.0
var delete_modal: Control
var delete_dialog_message: Label
var delete_confirm_button: Button
var delete_cancel_button: Button
var pending_delete_song: SongData


func _ready() -> void:
	var app := get_tree().current_scene
	scene_manager = app.get_node("Managers/SceneManager")
	game_manager = app.get_node("Managers/GameManager")
	song_manager = app.get_node("Managers/SongManager")
	settings_manager = app.get_node("Managers/SettingsManager")
	input_manager = app.get_node("Managers/InputManager")
	songs = song_manager.get_all_songs()
	preview_video.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	preview_video.loop = false
	preview_video.autoplay = false
	preview_video.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_apply_localized_texts()
	back_button.pressed.connect(_return_to_menu)
	play_button.pressed.connect(_start_selected_song)
	preview_button.pressed.connect(_toggle_preview)
	delete_button.pressed.connect(_request_delete_selected_song)
	note_speed_down.pressed.connect(_adjust_note_speed.bind(-0.5))
	note_speed_up.pressed.connect(_adjust_note_speed.bind(0.5))
	_setup_delete_dialog()
	_refresh_note_speed()
	_populate_song_list()
	_refresh_selection()
	if not song_buttons.is_empty():
		song_buttons[0].grab_focus()


func _apply_localized_texts() -> void:
	back_button.text = AuroraLocale.text("VOLVER")
	title_label.text = AuroraLocale.text("BIBLIOTECA DE CANCIONES")
	subtitle_label.text = AuroraLocale.text("ELIGE UNA PISTA Y UN MODO DE TECLAS")
	song_list_header.text = AuroraLocale.text("LISTA DE PISTAS")
	note_speed_caption.text = AuroraLocale.text("VEL. DE NOTAS")
	mode_caption.text = AuroraLocale.text("MODO DE TECLAS")
	play_button.text = AuroraLocale.text("JUGAR")
	preview_button.text = AuroraLocale.text("▶ VISTA PREVIA")
	delete_button.text = AuroraLocale.text("BORRAR CANCION")
	controls_label.text = AuroraLocale.text(
		"↑↓ CANCION   ←→ MODO   %s JUGAR   %s PREVIA   %s BORRAR   %s VOLVER"
	) % [
		input_manager.get_controller_action_label("confirm"),
		input_manager.get_controller_action_label("preview"),
		input_manager.get_controller_action_label("delete"),
		input_manager.get_controller_action_label("back"),
	]


func _process(_delta: float) -> void:
	if preview_audio.playing and preview_audio.get_playback_position() >= preview_end_seconds:
		_finish_preview()
	elif (
		preview_video.is_playing()
		and preview_video.stream_position >= preview_video_end_seconds
	):
		_finish_preview()


func _exit_tree() -> void:
	_stop_preview()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if delete_modal != null and delete_modal.visible:
			if input_manager.controller_event_matches(event, "back"):
				_cancel_delete_selected_song()
				get_viewport().set_input_as_handled()
			return
		if input_manager.controller_event_matches(event, "back"):
			_return_to_menu()
			get_viewport().set_input_as_handled()
		elif input_manager.controller_event_matches(event, "preview"):
			_toggle_preview()
			get_viewport().set_input_as_handled()
		elif input_manager.controller_event_matches(event, "delete"):
			_request_delete_selected_song()
			get_viewport().set_input_as_handled()
		elif input_manager.controller_event_matches(event, "confirm"):
			_start_selected_song()
			get_viewport().set_input_as_handled()
		else:
			match event.button_index:
				JOY_BUTTON_DPAD_UP:
					_move_song_selection(-1)
					get_viewport().set_input_as_handled()
				JOY_BUTTON_DPAD_DOWN:
					_move_song_selection(1)
					get_viewport().set_input_as_handled()
				JOY_BUTTON_DPAD_LEFT:
					_move_chart_selection(-1)
					get_viewport().set_input_as_handled()
				JOY_BUTTON_DPAD_RIGHT:
					_move_chart_selection(1)
					get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if delete_modal != null and delete_modal.visible:
			if event.keycode == KEY_ESCAPE:
				_cancel_delete_selected_song()
				get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_return_to_menu()
			KEY_UP:
				_move_song_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_move_song_selection(1)
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				if note_speed_down.has_focus() or note_speed_up.has_focus():
					_adjust_note_speed(-0.5)
				else:
					_move_chart_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				if note_speed_down.has_focus() or note_speed_up.has_focus():
					_adjust_note_speed(0.5)
				else:
					_move_chart_selection(1)
				get_viewport().set_input_as_handled()
			KEY_P:
				_toggle_preview()
				get_viewport().set_input_as_handled()
			KEY_DELETE:
				_request_delete_selected_song()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
				_start_selected_song()


func _populate_song_list() -> void:
	for child in song_list.get_children():
		child.queue_free()
	song_buttons.clear()

	for index in range(songs.size()):
		var song := songs[index]
		var button := SONG_LIST_ITEM_SCENE.instantiate() as Button
		button.name = "Song%02d" % (index + 1)
		button.text = "%02d  %s\n     %s  ·  %s  ·  %s" % [
			index + 1,
			song.title.to_upper(),
			song.artist,
			song.get_duration_text(),
			song.get_available_modes_text(),
		]
		button.focus_entered.connect(_select_song.bind(index, false))
		button.pressed.connect(_select_song.bind(index, true))
		song_list.add_child(button)
		song_buttons.append(button)

	song_count_label.text = AuroraLocale.text("%d CANCIONES") % songs.size()


func _select_song(index: int, focus_button: bool) -> void:
	if index < 0 or index >= songs.size():
		return
	selected_song_index = index
	selected_chart_index = 0
	_refresh_selection()
	if focus_button and index < song_buttons.size():
		song_buttons[index].grab_focus()


func _refresh_selection() -> void:
	if songs.is_empty():
		_show_empty_library()
		return

	selected_song_index = clampi(selected_song_index, 0, songs.size() - 1)
	var song := songs[selected_song_index]
	preview_cover.texture = song.cover
	preview_title.text = song.title.to_upper()
	preview_artist.text = song.artist.to_upper()
	preview_meta.text = AuroraLocale.text("DURACION %s") % song.get_duration_text()
	_populate_mode_buttons(song)
	_update_chart_selection()
	delete_button.disabled = not song_manager.is_editor_song(song)
	delete_button.tooltip_text = (
		AuroraLocale.text("MOVER ESTE NIVEL A LA PAPELERA")
		if not delete_button.disabled
		else AuroraLocale.text("LAS CANCIONES INCLUIDAS CON AURORA ESTAN PROTEGIDAS")
	)
	_start_preview(song)


func _populate_mode_buttons(song: SongData) -> void:
	for child in mode_buttons_container.get_children():
		mode_buttons_container.remove_child(child)
		child.queue_free()
	mode_buttons.clear()
	var mode_group := ButtonGroup.new()
	mode_group.allow_unpress = false

	for index in range(song.charts.size()):
		var chart := song.charts[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(112, 48)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.toggle_mode = true
		button.button_group = mode_group
		button.text = chart.get_mode_label()
		button.pressed.connect(_select_chart.bind(index))
		mode_buttons_container.add_child(button)
		button.name = "Mode%s" % chart.get_mode_label()
		mode_buttons.append(button)


func _select_chart(index: int) -> void:
	var song := _get_selected_song()
	if song == null or index < 0 or index >= song.charts.size():
		return
	selected_chart_index = index
	_update_chart_selection()


func _update_chart_selection() -> void:
	var song := _get_selected_song()
	if song == null or song.charts.is_empty():
		difficulty_label.text = AuroraLocale.text("DIFICULTAD: -")
		play_button.disabled = true
		return

	selected_chart_index = clampi(selected_chart_index, 0, song.charts.size() - 1)
	for index in range(mode_buttons.size()):
		mode_buttons[index].button_pressed = index == selected_chart_index
	var chart := song.charts[selected_chart_index]
	difficulty_label.text = AuroraLocale.text("DIFICULTAD: %s") % chart.get_difficulty_label()
	play_button.disabled = false


func _move_song_selection(direction: int) -> void:
	if songs.is_empty():
		return
	selected_song_index = wrapi(selected_song_index + direction, 0, songs.size())
	selected_chart_index = 0
	_refresh_selection()
	song_buttons[selected_song_index].grab_focus()


func _move_chart_selection(direction: int) -> void:
	var song := _get_selected_song()
	if song == null or song.charts.is_empty():
		return
	selected_chart_index = wrapi(selected_chart_index + direction, 0, song.charts.size())
	_update_chart_selection()


func _adjust_note_speed(amount: float) -> void:
	var current := float(settings_manager.get_setting("note_speed", 5.5))
	var next_value := clampf(snappedf(current + amount, 0.5), 1.0, 10.0)
	settings_manager.set_setting("note_speed", next_value)
	_refresh_note_speed()


func _refresh_note_speed() -> void:
	var note_speed := float(settings_manager.get_setting("note_speed", 5.5))
	note_speed_value.text = "%.1fx" % note_speed
	AuroraUi.update_stepper_buttons(note_speed_down, note_speed_up, note_speed, 1.0, 10.0)


func _start_selected_song() -> void:
	var song := _get_selected_song()
	if song == null or song.charts.is_empty():
		return
	var chart := song.charts[selected_chart_index]
	_stop_preview()
	game_manager.start_song(song, chart)
	scene_manager.load_scene("gameplay")


func _start_preview(song: SongData) -> void:
	_stop_preview()
	var has_audio := song.audio != null
	var has_video := song.background_video != null
	preview_button.disabled = not has_audio and not has_video
	if preview_button.disabled:
		preview_status.text = AuroraLocale.text("DEMO SIN AUDIO")
		return
	var start_seconds := clampf(song.preview_start_seconds, 0.0, song.duration_seconds)
	preview_end_seconds = minf(
		song.duration_seconds,
		start_seconds + song.preview_duration_seconds
	)
	if has_video:
		preview_video.stream = song.background_video
		preview_video.visible = true
		preview_video.volume_db = -80.0 if has_audio else 0.0
		preview_video_end_seconds = (
			song.background_video_start_seconds + preview_end_seconds
		)
		preview_video.play()
		preview_video.stream_position = song.background_video_start_seconds + start_seconds
	if has_audio:
		preview_audio.stream = song.audio
		preview_audio.play(start_seconds)
	preview_button.text = AuroraLocale.text("■ DETENER VISTA PREVIA")
	preview_status.text = AuroraLocale.text("REPRODUCIENDO PREESCUCHA")


func _toggle_preview() -> void:
	if _is_preview_playing():
		_stop_preview()
		preview_status.text = AuroraLocale.text("VISTA PREVIA DETENIDA")
		return
	var song := _get_selected_song()
	if song != null:
		_start_preview(song)


func _is_preview_playing() -> bool:
	return preview_audio.playing or preview_video.is_playing()


func _finish_preview() -> void:
	_stop_preview()
	preview_status.text = AuroraLocale.text("PREESCUCHA FINALIZADA")


func _stop_preview() -> void:
	if preview_audio != null:
		preview_audio.stop()
		preview_audio.stream = null
	if preview_video != null:
		preview_video.stop()
		preview_video.stream = null
		preview_video.visible = false
	if preview_button != null:
		preview_button.text = AuroraLocale.text("▶ VISTA PREVIA")


func _setup_delete_dialog() -> void:
	delete_modal = Control.new()
	delete_modal.name = "DeleteSongModal"
	delete_modal.z_index = 100
	delete_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_modal.visible = false
	AuroraUi.fill(delete_modal)
	add_child(delete_modal)

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0.01, 0.015, 0.035, 0.86)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	AuroraUi.fill(dimmer)
	delete_modal.add_child(dimmer)

	var center := CenterContainer.new()
	center.name = "DialogCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AuroraUi.fill(center)
	delete_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "DialogPanel"
	panel.custom_minimum_size = Vector2(760.0, 310.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		AuroraUi.make_style(
			Color(0.035, 0.045, 0.085, 0.99),
			Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.95),
			6
		)
	)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.name = "DialogContent"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	panel.add_child(content)

	var title := AuroraUi.make_pixel_label(
		AuroraLocale.text("CONFIRMAR BORRADO"),
		22,
		AuroraUi.TEXT
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1.0, 2.0)
	divider.color = AuroraUi.TEAL
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)

	delete_dialog_message = AuroraUi.make_pixel_label("", 13, AuroraUi.MUTED)
	delete_dialog_message.custom_minimum_size = Vector2(680.0, 72.0)
	delete_dialog_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delete_dialog_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(delete_dialog_message)

	var actions := HBoxContainer.new()
	actions.name = "DialogActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	content.add_child(actions)

	delete_cancel_button = AuroraUi.make_button(AuroraLocale.text("CANCELAR"))
	delete_cancel_button.name = "CancelDeleteButton"
	delete_cancel_button.custom_minimum_size = Vector2(260.0, 58.0)
	AuroraUi.apply_pixel_font(delete_cancel_button, 13)
	delete_cancel_button.pressed.connect(_cancel_delete_selected_song)
	actions.add_child(delete_cancel_button)

	delete_confirm_button = AuroraUi.make_button(
		AuroraLocale.text("MOVER A PAPELERA")
	)
	delete_confirm_button.name = "ConfirmDeleteButton"
	delete_confirm_button.custom_minimum_size = Vector2(310.0, 58.0)
	AuroraUi.apply_pixel_font(delete_confirm_button, 13)
	delete_confirm_button.add_theme_color_override("font_color", AuroraUi.CORAL)
	delete_confirm_button.add_theme_color_override("font_hover_color", AuroraUi.CORAL)
	delete_confirm_button.add_theme_color_override("font_focus_color", AuroraUi.CORAL)
	delete_confirm_button.pressed.connect(_confirm_delete_selected_song)
	actions.add_child(delete_confirm_button)


func _request_delete_selected_song() -> void:
	var song := _get_selected_song()
	if song == null:
		return
	if not song_manager.is_editor_song(song):
		preview_status.text = AuroraLocale.text(
			"SOLO PUEDES BORRAR CANCIONES CREADAS EN EL EDITOR"
		)
		return
	_stop_preview()
	pending_delete_song = song
	delete_dialog_message.text = AuroraLocale.text(
		"¿MOVER \"%s\" A LA PAPELERA?\nPODRAS RECUPERARLA DESDE WINDOWS."
	) % song.title
	delete_modal.visible = true
	delete_cancel_button.grab_focus()


func _confirm_delete_selected_song() -> void:
	if pending_delete_song == null:
		return
	delete_modal.visible = false
	var removed_title := pending_delete_song.title
	var remove_error := song_manager.move_editor_song_to_trash(pending_delete_song)
	pending_delete_song = null
	if remove_error != OK:
		preview_status.text = AuroraLocale.text("NO SE PUDO MOVER LA CANCION A LA PAPELERA")
		return
	songs = song_manager.get_all_songs()
	selected_song_index = clampi(selected_song_index, 0, maxi(songs.size() - 1, 0))
	selected_chart_index = 0
	_populate_song_list()
	_refresh_selection()
	preview_status.text = AuroraLocale.text("\"%s\" SE MOVIO A LA PAPELERA") % removed_title
	if not song_buttons.is_empty():
		song_buttons[selected_song_index].grab_focus()


func _cancel_delete_selected_song() -> void:
	pending_delete_song = null
	delete_modal.visible = false
	if not song_buttons.is_empty():
		song_buttons[selected_song_index].grab_focus()


func _return_to_menu() -> void:
	_stop_preview()
	scene_manager.load_scene("main_menu")


func _get_selected_song() -> SongData:
	if selected_song_index < 0 or selected_song_index >= songs.size():
		return null
	return songs[selected_song_index]


func _show_empty_library() -> void:
	for child in mode_buttons_container.get_children():
		mode_buttons_container.remove_child(child)
		child.queue_free()
	mode_buttons.clear()
	preview_cover.texture = null
	preview_title.text = AuroraLocale.text("SIN CANCIONES")
	preview_artist.text = AuroraLocale.text("CREA O IMPORTA UN NIVEL DESDE EL EDITOR")
	preview_meta.text = AuroraLocale.text("DURACION --:--")
	difficulty_label.text = AuroraLocale.text("DIFICULTAD: -")
	preview_status.text = AuroraLocale.text("BIBLIOTECA VACIA")
	preview_button.disabled = true
	delete_button.disabled = true
	play_button.disabled = true
