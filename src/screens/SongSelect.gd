extends Control

class_name SongSelect

const SONG_LIST_ITEM_SCENE := preload("res://src/screens/song_select/SongListItem.tscn")
const LOCAL_PACKAGE_SHARE_PANEL := preload(
	"res://src/screens/song_select/LocalPackageSharePanel.gd"
)
const LOCAL_PACKAGE_INSTALL_PANEL := preload(
	"res://src/screens/song_select/LocalPackageInstallPanel.gd"
)
const PREVIEW_FADE_SECONDS := 0.5
const PREVIEW_SILENT_DB := -48.0

@onready var back_button: Button = $LibraryMargins/PageLayout/Header/BackButton
@onready var title_label: Label = $LibraryMargins/PageLayout/Header/HeaderCopy/TitleLabel
@onready var subtitle_label: Label = $LibraryMargins/PageLayout/Header/HeaderCopy/SubtitleLabel
@onready var import_package_button: Button = $LibraryMargins/PageLayout/Header/HeaderActions/ActionButtons/ImportPackageButton
@onready var share_package_button: Button = $LibraryMargins/PageLayout/Header/HeaderActions/ActionButtons/SharePackageButton
@onready var song_count_label: Label = $LibraryMargins/PageLayout/Header/HeaderActions/SongCountLabel
@onready var song_list_header: Label = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/SongListHeader
@onready var search_field: LineEdit = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/FilterRow/SearchField
@onready var filter_option: OptionButton = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/FilterRow/FilterOption
@onready var song_scroll: ScrollContainer = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/SongScroll
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
@onready var mode_buttons_container: HFlowContainer = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/ModeButtons
@onready var mode_caption: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/ModeCaption
@onready var difficulty_label: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/DifficultyLabel
@onready var personal_best_label: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PersonalBestLabel
@onready var preview_status: Label = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewStatus
@onready var preview_button: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewActions/PreviewButton
@onready var favorite_button: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewActions/FavoriteButton
@onready var edit_button: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewActions/EditButton
@onready var delete_button: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PreviewActions/DeleteButton
@onready var play_button: Button = $LibraryMargins/PageLayout/LibraryBody/PreviewPanel/PreviewMargins/PreviewLayout/PlayButton
@onready var controls_label: Label = $LibraryMargins/PageLayout/Footer/ControlsLabel
@onready var preview_audio: AudioStreamPlayer = $PreviewAudio

static var remembered_song_id := ""
static var remembered_chart_signature := ""
static var remembered_scroll_value := 0.0
static var remembered_search_text := ""
static var remembered_filter_index := 0

var scene_manager: SceneManager
var game_manager: GameManager
var song_manager: SongManager
var settings_manager: SettingsManager
var input_manager: InputManager
var all_songs: Array[SongData] = []
var songs: Array[SongData] = []
var song_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var song_button_group := ButtonGroup.new()
var selected_song_index := 0
var selected_chart_index := 0
var preview_end_seconds := 0.0
var preview_video_end_seconds := 0.0
var preview_loop_song: SongData
var preview_fade_tween: Tween
var preview_fade_timer: Timer
var preview_finish_timer: Timer
var delete_modal: Control
var delete_dialog_message: Label
var delete_confirm_button: Button
var delete_cancel_button: Button
var pending_delete_song: SongData
var preview_request_token := 0
var package_dialog: FileDialog
var package_import_thread: Thread
var package_import_path := ""
var package_import_selected_song_id := ""
var package_import_chart_signature := ""
var preserve_remembered_selection_on_exit := false
var share_panel: Control
var package_install_panel: Control


func _ready() -> void:
	var app := get_tree().current_scene
	scene_manager = app.get_node("Managers/SceneManager")
	game_manager = app.get_node("Managers/GameManager")
	song_manager = app.get_node("Managers/SongManager")
	settings_manager = app.get_node("Managers/SettingsManager")
	input_manager = app.get_node("Managers/InputManager")
	input_manager.input_device_changed.connect(_on_input_device_changed)
	input_manager.controller_bindings_changed.connect(
		_on_controller_bindings_changed
	)
	all_songs = song_manager.get_all_songs()
	song_button_group.allow_unpress = false
	preview_video.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	preview_audio.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	preview_video.loop = false
	preview_video.autoplay = false
	preview_video.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_setup_preview_loop_timers()
	_apply_localized_texts()
	_setup_package_dialog()
	back_button.pressed.connect(_return_to_menu)
	import_package_button.pressed.connect(_open_package_dialog)
	share_package_button.pressed.connect(_open_local_package_share)
	play_button.pressed.connect(_start_selected_song)
	preview_button.pressed.connect(_toggle_preview)
	favorite_button.pressed.connect(_toggle_selected_favorite)
	edit_button.pressed.connect(_edit_selected_song)
	delete_button.pressed.connect(_request_delete_selected_song)
	note_speed_down.pressed.connect(_adjust_note_speed.bind(-0.5))
	note_speed_up.pressed.connect(_adjust_note_speed.bind(0.5))
	search_field.text_changed.connect(_on_search_changed)
	filter_option.item_selected.connect(_on_filter_selected)
	filter_option.add_item(AuroraLocale.text("TODAS"))
	filter_option.add_item(AuroraLocale.text("FAVORITAS"))
	filter_option.add_item(AuroraLocale.text("RECIENTES"))
	search_field.text = remembered_search_text
	filter_option.select(clampi(remembered_filter_index, 0, 2))
	_setup_delete_dialog()
	_refresh_note_speed()
	_apply_song_filter()
	if not song_buttons.is_empty():
		song_buttons[selected_song_index].grab_focus()
	elif all_songs.is_empty():
		import_package_button.grab_focus()
	call_deferred("_restore_scroll_position")


func _apply_localized_texts() -> void:
	back_button.text = AuroraLocale.text("VOLVER")
	import_package_button.text = AuroraLocale.text("INSTALAR NIVEL")
	import_package_button.tooltip_text = AuroraLocale.text(
		"AÑADE A TU BIBLIOTECA UN ARCHIVO .AURORA RECIBIDO POR CORREO, CHAT, USB O NUBE"
	)
	share_package_button.text = AuroraLocale.text("COMPARTIR NIVEL")
	share_package_button.tooltip_text = AuroraLocale.text(
		"CREA UN ARCHIVO .AURORA PORTÁTIL PARA ENVIAR A OTRA PERSONA"
	)
	title_label.text = AuroraLocale.text("BIBLIOTECA DE CANCIONES")
	subtitle_label.text = AuroraLocale.text("ELIGE UNA PISTA Y UN MODO DE TECLAS")
	song_list_header.text = AuroraLocale.text("LISTA DE PISTAS")
	note_speed_caption.text = AuroraLocale.text("VEL. DE NOTAS")
	mode_caption.text = AuroraLocale.text("MODO DE TECLAS")
	play_button.text = AuroraLocale.text("JUGAR")
	preview_button.text = AuroraLocale.text("▶ VISTA PREVIA")
	favorite_button.text = AuroraLocale.text("☆ FAVORITA")
	edit_button.text = AuroraLocale.text("EDITAR CANCION")
	delete_button.text = AuroraLocale.text("BORRAR CANCION")
	_refresh_controls_hint()


func _on_input_device_changed(_using_controller: bool) -> void:
	_refresh_controls_hint()


func _on_controller_bindings_changed(_mode: int) -> void:
	_refresh_controls_hint()


func _refresh_controls_hint() -> void:
	if controls_label == null or input_manager == null:
		return
	if input_manager.using_controller:
		controls_label.text = AuroraLocale.text(
			"D-PAD CANCION/MODO   %s JUGAR   %s PREVIA   %s BORRAR   %s VOLVER"
		) % [
			input_manager.get_controller_action_label("confirm"),
			input_manager.get_controller_action_label("preview"),
			input_manager.get_controller_action_label("delete"),
			input_manager.get_controller_action_label("back"),
		]
	else:
		controls_label.text = AuroraLocale.text(
			"↑↓ CANCION   ←→ MODO   ENTER JUGAR   P PREVIA   SUPR BORRAR   ESC VOLVER"
		)


func _setup_package_dialog() -> void:
	package_dialog = FileDialog.new()
	package_dialog.name = "ImportPackageDialog"
	package_dialog.title = AuroraLocale.text("INSTALAR NIVEL .AURORA")
	package_dialog.access = FileDialog.ACCESS_FILESYSTEM
	package_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	package_dialog.use_native_dialog = true
	package_dialog.filters = PackedStringArray([
		"*.aurora ; Aurora Song Package",
	])
	package_dialog.file_selected.connect(
		_on_package_file_selected
	)
	add_child(package_dialog)


func _open_package_dialog() -> void:
	if package_dialog == null or _is_package_import_active():
		return
	var last_directory := str(
		settings_manager.get_setting(
			"last_package_directory",
			""
		)
	).strip_edges()
	if (
		not last_directory.is_empty()
		and DirAccess.dir_exists_absolute(last_directory)
	):
		package_dialog.current_dir = last_directory
	package_dialog.popup_centered_ratio(0.72)


func _on_package_file_selected(package_path: String) -> void:
	if _is_package_import_active():
		preview_status.text = AuroraLocale.text(
			"ESPERA A QUE TERMINE LA IMPORTACIÓN DEL PAQUETE."
		)
		return
	settings_manager.set_setting(
		"last_package_directory",
		package_path.get_base_dir(),
		false
	)
	var inspection := song_manager.inspect_song_package(package_path)
	if not bool(inspection.get("ok", false)):
		preview_status.text = _package_import_error_text(inspection)
		return
	_open_package_install_confirmation(
		package_path,
		inspection.get("manifest", {})
	)


func _open_package_install_confirmation(
	package_path: String,
	manifest: Dictionary
) -> void:
	_close_package_install_confirmation()
	var package_id := str(manifest.get("package_id", ""))
	var installed_version := song_manager.get_installed_package_version(package_id)
	package_install_panel = LOCAL_PACKAGE_INSTALL_PANEL.new()
	package_install_panel.name = "LocalPackageInstallPanel"
	package_install_panel.install_confirmed.connect(_confirm_package_install)
	package_install_panel.close_requested.connect(
		_close_package_install_confirmation
	)
	add_child(package_install_panel)
	package_install_panel.setup(package_path, manifest, installed_version)


func _close_package_install_confirmation() -> void:
	if package_install_panel == null:
		return
	package_install_panel.queue_free()
	package_install_panel = null
	import_package_button.grab_focus()


func _confirm_package_install(package_path: String) -> void:
	_close_package_install_confirmation()
	var selected_before := _get_selected_song()
	package_import_selected_song_id = (
		str(selected_before.song_id)
		if selected_before != null
		else ""
	)
	package_import_chart_signature = remembered_chart_signature
	preview_request_token += 1
	_stop_preview()
	song_manager.release_unselected_package_media(null)
	if (
		selected_before != null
		and not selected_before.charts.is_empty()
	):
		var safe_index := clampi(
			selected_chart_index,
			0,
			selected_before.charts.size() - 1
		)
		package_import_chart_signature = _chart_signature(
			selected_before.charts[safe_index]
		)
	_start_package_import(package_path)


func _start_package_import(package_path: String) -> void:
	package_import_path = package_path
	package_import_thread = Thread.new()
	_set_package_import_controls_disabled(true)
	preview_status.text = AuroraLocale.text("VALIDANDO PAQUETE...")
	var start_error := package_import_thread.start(
		Callable(
			song_manager,
			"install_song_package_files"
		).bind(package_path)
	)
	if start_error == OK:
		return
	package_import_thread = null
	package_import_path = ""
	_set_package_import_controls_disabled(false)
	preview_status.text = AuroraLocale.text(
		"NO SE PUDO INICIAR LA IMPORTACIÓN DEL PAQUETE."
	)


func _poll_package_import() -> void:
	if (
		package_import_thread == null
		or package_import_thread.is_alive()
	):
		return
	var result_value = package_import_thread.wait_to_finish()
	package_import_thread = null
	var completed_path := package_import_path
	package_import_path = ""
	_set_package_import_controls_disabled(false)
	var result: Dictionary = (
		result_value
		if result_value is Dictionary
		else {}
	)
	if not bool(result.get("ok", false)):
		preview_status.text = _package_import_error_text(result)
		return
	song_manager.load_songs()
	all_songs = song_manager.get_all_songs()
	remembered_song_id = package_import_selected_song_id
	remembered_chart_signature = package_import_chart_signature
	if remembered_song_id.is_empty():
		remembered_song_id = str(result.get("song_id", ""))
		remembered_chart_signature = ""
	package_import_selected_song_id = ""
	package_import_chart_signature = ""
	_apply_song_filter()
	var imported_song := _find_song_by_id(
		str(result.get("song_id", ""))
	)
	var imported_title := (
		imported_song.title
		if imported_song != null
		else completed_path.get_file().get_basename()
	)
	var imported_version := str(result.get("package_version", "1.0.0"))
	preview_status.text = AuroraLocale.text(
		"PAQUETE ACTUALIZADO: %s // v%s"
		if bool(result.get("updated", false))
		else "PAQUETE IMPORTADO: %s // v%s"
	) % [imported_title, imported_version]


func _is_package_import_active() -> bool:
	return package_import_thread != null


func _set_package_import_controls_disabled(disabled: bool) -> void:
	for button in [
		back_button,
		import_package_button,
		share_package_button,
		play_button,
		preview_button,
		favorite_button,
		edit_button,
		delete_button,
		note_speed_down,
		note_speed_up,
	]:
		if button != null:
			button.disabled = disabled
	for button in song_buttons:
		button.disabled = disabled
	for button in mode_buttons:
		button.disabled = disabled
	if search_field != null:
		search_field.editable = not disabled
	if filter_option != null:
		filter_option.disabled = disabled
	if import_package_button != null:
		import_package_button.text = AuroraLocale.text(
			"INSTALANDO..." if disabled else "INSTALAR NIVEL"
		)
	if share_package_button != null:
		share_package_button.text = AuroraLocale.text("COMPARTIR NIVEL")
	if not disabled:
		_refresh_selection()


func _package_import_error_text(result: Dictionary) -> String:
	if str(result.get("error_code", "")) == "destination_exists":
		return AuroraLocale.text(
			"ESTE PAQUETE YA ESTA INSTALADO"
		)
	var message := str(
		result.get(
			"message",
			AuroraLocale.text("ARCHIVO NO VALIDO")
		)
	).strip_edges()
	return AuroraLocale.text(
		"NO SE PUDO IMPORTAR EL PAQUETE: %s"
	) % message


func _find_song_by_id(song_id: String) -> SongData:
	for song in all_songs:
		if str(song.song_id) == song_id:
			return song
	return null


func _process(_delta: float) -> void:
	_poll_package_import()


func _exit_tree() -> void:
	if package_import_thread != null:
		package_import_thread.wait_to_finish()
		package_import_thread = null
	if not preserve_remembered_selection_on_exit:
		_remember_library_state()
	preview_request_token += 1
	_stop_preview()


func _input(event: InputEvent) -> void:
	if _is_package_import_active():
		var requested_back: bool = (
			event is InputEventJoypadButton
			and event.pressed
			and input_manager.controller_event_matches(event, "back")
		) or (
			event is InputEventKey
			and event.pressed
			and not event.echo
			and event.keycode == KEY_ESCAPE
		)
		if requested_back:
			preview_status.text = AuroraLocale.text(
				"ESPERA A QUE TERMINE LA IMPORTACIÓN DEL PAQUETE."
			)
			get_viewport().set_input_as_handled()
		return
	if package_install_panel != null:
		var close_install: bool = (
			event is InputEventJoypadButton
			and event.pressed
			and input_manager.controller_event_matches(event, "back")
		) or (
			event is InputEventKey
			and event.pressed
			and not event.echo
			and event.keycode == KEY_ESCAPE
		)
		if close_install:
			package_install_panel.request_close()
			get_viewport().set_input_as_handled()
		return
	if share_panel != null:
		var close_share: bool = (
			event is InputEventJoypadButton
			and event.pressed
			and input_manager.controller_event_matches(event, "back")
		) or (
			event is InputEventKey
			and event.pressed
			and not event.echo
			and event.keycode == KEY_ESCAPE
		)
		if close_share:
			share_panel.request_close()
			get_viewport().set_input_as_handled()
		return
	var focused_control := get_viewport().gui_get_focus_owner()
	var use_library_shortcuts := _uses_library_shortcuts(focused_control)
	if focused_control == search_field and event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			search_field.release_focus()
			if not song_buttons.is_empty():
				song_buttons[selected_song_index].grab_focus()
			get_viewport().set_input_as_handled()
		return
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
			if use_library_shortcuts:
				_start_selected_song()
				get_viewport().set_input_as_handled()
		else:
			match event.button_index:
				JOY_BUTTON_DPAD_UP:
					if use_library_shortcuts:
						_move_song_selection(-1)
						get_viewport().set_input_as_handled()
				JOY_BUTTON_DPAD_DOWN:
					if use_library_shortcuts:
						_move_song_selection(1)
						get_viewport().set_input_as_handled()
				JOY_BUTTON_DPAD_LEFT:
					if _is_note_speed_control(focused_control):
						_adjust_note_speed(-0.5)
						get_viewport().set_input_as_handled()
					elif use_library_shortcuts:
						_move_chart_selection(-1)
						get_viewport().set_input_as_handled()
				JOY_BUTTON_DPAD_RIGHT:
					if _is_note_speed_control(focused_control):
						_adjust_note_speed(0.5)
						get_viewport().set_input_as_handled()
					elif use_library_shortcuts:
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
				if use_library_shortcuts:
					_move_song_selection(-1)
					get_viewport().set_input_as_handled()
			KEY_DOWN:
				if use_library_shortcuts:
					_move_song_selection(1)
					get_viewport().set_input_as_handled()
			KEY_LEFT:
				if use_library_shortcuts:
					_move_chart_selection(-1)
					get_viewport().set_input_as_handled()
				elif _is_note_speed_control(focused_control):
					_adjust_note_speed(-0.5)
					get_viewport().set_input_as_handled()
			KEY_RIGHT:
				if use_library_shortcuts:
					_move_chart_selection(1)
					get_viewport().set_input_as_handled()
				elif _is_note_speed_control(focused_control):
					_adjust_note_speed(0.5)
					get_viewport().set_input_as_handled()
			KEY_P:
				_toggle_preview()
				get_viewport().set_input_as_handled()
			KEY_DELETE:
				_request_delete_selected_song()
				get_viewport().set_input_as_handled()
			KEY_I:
				_open_package_dialog()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				if use_library_shortcuts:
					get_viewport().set_input_as_handled()
					_start_selected_song()


func _uses_library_shortcuts(focused_control: Control) -> bool:
	return focused_control == null or song_buttons.has(focused_control)


func _is_note_speed_control(focused_control: Control) -> bool:
	return focused_control == note_speed_down or focused_control == note_speed_up


func _populate_song_list() -> void:
	for child in song_list.get_children():
		child.queue_free()
	song_buttons.clear()

	for index in range(songs.size()):
		var song := songs[index]
		var button := SONG_LIST_ITEM_SCENE.instantiate() as Button
		button.name = "Song%02d" % (index + 1)
		button.toggle_mode = true
		button.button_group = song_button_group
		button.text = "%02d  %s\n     %s  ·  %s  ·  %s" % [
			index + 1,
			song.title.to_upper(),
			song.artist,
			song.get_duration_text(),
			_song_modes_text(song),
		]
		button.focus_entered.connect(_select_song.bind(index, false))
		button.pressed.connect(_select_song.bind(index, true))
		song_list.add_child(button)
		song_buttons.append(button)

	song_count_label.text = (
		AuroraLocale.text("%d / %d CANCIONES") % [songs.size(), all_songs.size()]
		if songs.size() != all_songs.size()
		else AuroraLocale.text("%d CANCIONES") % songs.size()
	)


func _song_modes_text(song: SongData) -> String:
	var unique_modes := PackedStringArray()
	for chart in song.charts:
		var mode_label := chart.get_mode_label()
		if mode_label not in unique_modes:
			unique_modes.append(mode_label)
	return "  ".join(unique_modes)


func _select_song(index: int, focus_button: bool) -> void:
	if index < 0 or index >= songs.size():
		return
	var song_changed := index != selected_song_index
	selected_song_index = index
	if song_changed:
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
	for index in range(song_buttons.size()):
		song_buttons[index].set_pressed_no_signal(index == selected_song_index)
	_restore_chart_selection_for(song)
	song_manager.release_unselected_package_media(song)
	song_manager.ensure_song_cover_loaded(song)
	preview_cover.texture = song.cover
	preview_title.text = song.title.to_upper()
	preview_artist.text = song.artist.to_upper()
	preview_meta.text = AuroraLocale.text("DURACION %s") % song.get_duration_text()
	_populate_mode_buttons(song)
	_update_chart_selection()
	delete_button.disabled = not song_manager.is_removable_local_song(
		song
	)
	favorite_button.disabled = false
	delete_button.tooltip_text = (
		AuroraLocale.text(
			"MOVER ESTA CANCION LOCAL A LA PAPELERA"
		)
		if not delete_button.disabled
		else AuroraLocale.text("LAS CANCIONES INCLUIDAS CON AURORA ESTAN PROTEGIDAS")
	)
	_refresh_favorite_button(song)
	_schedule_preview(song)
	_remember_library_state()


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
		button.custom_minimum_size = Vector2(148, 48)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.toggle_mode = true
		button.button_group = mode_group
		button.text = "%s  %s" % [
			chart.get_mode_label(),
			chart.get_difficulty_label(),
		]
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(_select_chart.bind(index))
		mode_buttons_container.add_child(button)
		button.name = "Chart%02d" % (index + 1)
		mode_buttons.append(button)


func _select_chart(index: int) -> void:
	var song := _get_selected_song()
	if song == null or index < 0 or index >= song.charts.size():
		return
	selected_chart_index = index
	_update_chart_selection()
	_remember_library_state()


func _update_chart_selection() -> void:
	var song := _get_selected_song()
	if song == null or song.charts.is_empty():
		difficulty_label.text = AuroraLocale.text("DIFICULTAD: -")
		personal_best_label.text = AuroraLocale.text("MEJOR: SIN REGISTRO")
		play_button.disabled = true
		edit_button.disabled = true
		return

	selected_chart_index = clampi(selected_chart_index, 0, song.charts.size() - 1)
	for index in range(mode_buttons.size()):
		mode_buttons[index].button_pressed = index == selected_chart_index
	var chart := song.charts[selected_chart_index]
	difficulty_label.text = AuroraLocale.text("DIFICULTAD: %s") % chart.get_difficulty_label()
	_refresh_personal_best(song, chart)
	play_button.disabled = false
	_refresh_edit_action(song, chart)


func _refresh_edit_action(song: SongData, chart: ChartData) -> void:
	edit_button.text = AuroraLocale.text("EDITAR CANCION")
	edit_button.disabled = not song_manager.can_edit_song(song, chart)
	if edit_button.disabled:
		edit_button.tooltip_text = AuroraLocale.text(
			"ESTA CANCION NO TIENE UN CHART O MEDIO DISPONIBLE PARA EDITAR"
		)
	elif song_manager.is_editor_song(song):
		edit_button.tooltip_text = AuroraLocale.text(
			"ABRE ESTE PROYECTO PARA CAMBIAR NOTAS, DIFICULTAD Y DATOS"
		)
	else:
		edit_button.tooltip_text = AuroraLocale.text(
			"CREA UNA COPIA EDITABLE DEL CHART SELECCIONADO; EL ORIGINAL NO CAMBIA"
		)


func _refresh_personal_best(song: SongData, chart: ChartData) -> void:
	var record := game_manager.get_personal_record(song, chart)
	if record.is_empty():
		personal_best_label.text = AuroraLocale.text("MEJOR: SIN REGISTRO")
		return
	personal_best_label.text = AuroraLocale.text(
		"MEJOR %07d  //  %.2f%%  //  COMBO %d  //  %d PARTIDAS"
	) % [
		int(record.get("best_score", 0)),
		float(record.get("best_accuracy", 0.0)),
		int(record.get("best_max_combo", 0)),
		int(record.get("play_count", 0)),
	]


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
	_remember_library_state()


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
	if (
		song_manager.is_local_package_song(song)
		and not song_manager.ensure_song_media_loaded(song)
	):
		preview_status.text = AuroraLocale.text(
			"NO SE PUDO CARGAR EL MEDIO DEL PAQUETE"
		)
		return
	var chart := song.charts[selected_chart_index]
	if not game_manager.can_start_song(song, chart):
		preview_status.text = AuroraLocale.text("EL CHART ESTA VACIO O DAÑADO")
		play_button.disabled = true
		return
	_add_recent_song(song)
	_remember_library_state()
	_stop_preview()
	if not game_manager.start_song(song, chart):
		preview_status.text = AuroraLocale.text("NO SE PUDO INICIAR EL CHART")
		return
	scene_manager.load_scene("gameplay")


func _schedule_preview(song: SongData) -> void:
	preview_request_token += 1
	var request_token := preview_request_token
	_stop_preview()
	var has_media := song_manager.has_available_media(song)
	if not has_media:
		preview_button.disabled = true
		preview_status.text = AuroraLocale.text("SIN MEDIO PARA PREVISUALIZAR")
		return
	preview_button.disabled = false
	preview_status.text = AuroraLocale.text("PREPARANDO VISTA PREVIA...")
	await get_tree().create_timer(0.28).timeout
	if (
		request_token != preview_request_token
		or not is_inside_tree()
		or _get_selected_song() != song
	):
		return
	_start_preview(song)


func _setup_preview_loop_timers() -> void:
	preview_fade_timer = Timer.new()
	preview_fade_timer.name = "PreviewFadeTimer"
	preview_fade_timer.one_shot = true
	preview_fade_timer.timeout.connect(_begin_preview_fade_out)
	add_child(preview_fade_timer)
	preview_finish_timer = Timer.new()
	preview_finish_timer.name = "PreviewFinishTimer"
	preview_finish_timer.one_shot = true
	preview_finish_timer.timeout.connect(_finish_preview)
	add_child(preview_finish_timer)


func _start_preview(song: SongData) -> void:
	_stop_preview()
	song_manager.ensure_song_media_loaded(song)
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
	var segment_duration := maxf(preview_end_seconds - start_seconds, 0.1)
	var fade_duration := minf(PREVIEW_FADE_SECONDS, segment_duration * 0.5)
	preview_loop_song = song
	preview_cover.modulate = Color.BLACK
	if has_video:
		preview_video.stream = song.background_video
		preview_video.visible = true
		preview_video.volume_db = -80.0 if has_audio else PREVIEW_SILENT_DB
		preview_video_end_seconds = (
			song.background_video_start_seconds + preview_end_seconds
		)
		preview_video.play()
		preview_video.stream_position = song.background_video_start_seconds + start_seconds
	if has_audio:
		preview_audio.stream = song.audio
		preview_audio.volume_db = PREVIEW_SILENT_DB
		preview_audio.play(start_seconds)
	preview_fade_tween = create_tween()
	preview_fade_tween.set_parallel(true)
	preview_fade_tween.tween_property(
		preview_cover,
		"modulate",
		Color.WHITE,
		fade_duration
	)
	if has_audio:
		preview_fade_tween.tween_property(
			preview_audio,
			"volume_db",
			0.0,
			fade_duration
		)
	elif has_video:
		preview_fade_tween.tween_property(
			preview_video,
			"volume_db",
			0.0,
			fade_duration
		)
	preview_fade_timer.start(maxf(segment_duration - fade_duration, 0.01))
	preview_finish_timer.start(segment_duration)
	preview_button.text = AuroraLocale.text("■ DETENER VISTA PREVIA")
	preview_status.text = AuroraLocale.text("PREESCUCHA EN BUCLE")


func _toggle_preview() -> void:
	preview_request_token += 1
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
	var loop_song := preview_loop_song
	if loop_song == null or loop_song != _get_selected_song():
		_stop_preview()
		return
	_start_preview(loop_song)


func _begin_preview_fade_out() -> void:
	if preview_loop_song == null or not _is_preview_playing():
		return
	if preview_fade_tween != null and preview_fade_tween.is_valid():
		preview_fade_tween.kill()
	preview_fade_tween = create_tween()
	preview_fade_tween.set_parallel(true)
	preview_fade_tween.tween_property(
		preview_cover,
		"modulate",
		Color.BLACK,
		PREVIEW_FADE_SECONDS
	)
	if preview_audio.playing:
		preview_fade_tween.tween_property(
			preview_audio,
			"volume_db",
			PREVIEW_SILENT_DB,
			PREVIEW_FADE_SECONDS
		)
	elif preview_video.is_playing():
		preview_fade_tween.tween_property(
			preview_video,
			"volume_db",
			PREVIEW_SILENT_DB,
			PREVIEW_FADE_SECONDS
		)


func _stop_preview() -> void:
	if preview_fade_timer != null:
		preview_fade_timer.stop()
	if preview_finish_timer != null:
		preview_finish_timer.stop()
	if preview_fade_tween != null and preview_fade_tween.is_valid():
		preview_fade_tween.kill()
	preview_fade_tween = null
	preview_loop_song = null
	if preview_audio != null:
		preview_audio.stop()
		preview_audio.stream = null
		preview_audio.volume_db = 0.0
	if preview_video != null:
		preview_video.stop()
		preview_video.stream = null
		preview_video.volume_db = 0.0
		preview_video.visible = false
	if preview_cover != null:
		preview_cover.modulate = Color.WHITE
	if preview_button != null:
		preview_button.text = AuroraLocale.text("▶ VISTA PREVIA")


func _on_search_changed(value: String) -> void:
	remembered_search_text = value
	_apply_song_filter()


func _on_filter_selected(index: int) -> void:
	remembered_filter_index = clampi(index, 0, 2)
	_apply_song_filter()


func _apply_song_filter() -> void:
	var previous_song_id := ""
	var selected_song := _get_selected_song()
	if selected_song != null:
		previous_song_id = str(selected_song.song_id)
	if previous_song_id.is_empty():
		previous_song_id = remembered_song_id

	var query := search_field.text.strip_edges().to_lower()
	var favorite_ids: Array = settings_manager.get_setting("favorite_song_ids", [])
	var recent_ids: Array = settings_manager.get_setting("recent_song_ids", [])
	songs.clear()

	if filter_option.selected == 2:
		for recent_id in recent_ids:
			for candidate in all_songs:
				if (
					str(candidate.song_id) == str(recent_id)
					and _song_matches_search(candidate, query)
				):
					songs.append(candidate)
					break
	else:
		for candidate in all_songs:
			if filter_option.selected == 1 and str(candidate.song_id) not in favorite_ids:
				continue
			if _song_matches_search(candidate, query):
				songs.append(candidate)

	selected_song_index = 0
	for index in range(songs.size()):
		if str(songs[index].song_id) == previous_song_id:
			selected_song_index = index
			break
	selected_chart_index = 0
	_populate_song_list()
	_refresh_selection()
	if not song_buttons.is_empty():
		song_buttons[selected_song_index].grab_focus()


func _song_matches_search(song: SongData, query: String) -> bool:
	if query.is_empty():
		return true
	return (
		song.title.to_lower().contains(query)
		or song.artist.to_lower().contains(query)
	)


func _toggle_selected_favorite() -> void:
	var song := _get_selected_song()
	if song == null:
		return
	var song_id := str(song.song_id)
	var favorite_ids: Array = settings_manager.get_setting("favorite_song_ids", []).duplicate()
	if song_id in favorite_ids:
		favorite_ids.erase(song_id)
	else:
		favorite_ids.append(song_id)
	settings_manager.set_setting("favorite_song_ids", favorite_ids, false)
	_refresh_favorite_button(song)
	if filter_option.selected == 1:
		_apply_song_filter()


func _refresh_favorite_button(song: SongData) -> void:
	var favorite_ids: Array = settings_manager.get_setting("favorite_song_ids", [])
	var is_favorite := str(song.song_id) in favorite_ids
	favorite_button.text = (
		AuroraLocale.text("★ FAVORITA")
		if is_favorite
		else AuroraLocale.text("☆ FAVORITA")
	)


func _add_recent_song(song: SongData) -> void:
	var song_id := str(song.song_id)
	var recent_ids: Array = settings_manager.get_setting("recent_song_ids", []).duplicate()
	recent_ids.erase(song_id)
	recent_ids.push_front(song_id)
	while recent_ids.size() > 20:
		recent_ids.pop_back()
	settings_manager.set_setting("recent_song_ids", recent_ids, false)


func _edit_selected_song() -> void:
	var song := _get_selected_song()
	if song == null:
		if all_songs.is_empty():
			_remember_library_state()
			preview_request_token += 1
			_stop_preview()
			game_manager.request_editor_project("")
			scene_manager.load_scene("editor")
		return
	if song.charts.is_empty():
		return
	var chart := song.charts[
		clampi(selected_chart_index, 0, song.charts.size() - 1)
	]
	if not song_manager.is_editor_song(song):
		edit_button.disabled = true
		preview_status.text = AuroraLocale.text(
			"PREPARANDO COPIA EDITABLE..."
		)
		await get_tree().process_frame
	var edit_result: Dictionary = song_manager.prepare_song_for_editor(
		song,
		chart
	)
	if not bool(edit_result.get("ok", false)):
		_refresh_edit_action(song, chart)
		preview_status.text = AuroraLocale.text(
			str(
				edit_result.get(
					"message",
					"NO SE PUDO PREPARAR LA CANCION PARA EDITAR"
				)
			)
		)
		return
	_remember_library_state()
	var editor_song_id := str(edit_result.get("editor_song_id", ""))
	if not editor_song_id.is_empty():
		remembered_song_id = editor_song_id
		remembered_chart_signature = _chart_signature(chart)
	preserve_remembered_selection_on_exit = true
	preview_request_token += 1
	_stop_preview()
	game_manager.request_editor_project(
		str(edit_result.get("project_path", ""))
	)
	scene_manager.load_scene("editor")


func _chart_signature(chart: ChartData) -> String:
	if chart == null:
		return ""
	return "%d|%s|%d" % [
		chart.key_count,
		chart.difficulty_name,
		chart.difficulty_level,
	]


func _restore_chart_selection_for(song: SongData) -> void:
	if str(song.song_id) != remembered_song_id or remembered_chart_signature.is_empty():
		return
	for index in range(song.charts.size()):
		if _chart_signature(song.charts[index]) == remembered_chart_signature:
			selected_chart_index = index
			return


func _remember_library_state() -> void:
	var song := _get_selected_song()
	if song != null:
		remembered_song_id = str(song.song_id)
		if not song.charts.is_empty():
			var safe_chart_index := clampi(selected_chart_index, 0, song.charts.size() - 1)
			remembered_chart_signature = _chart_signature(song.charts[safe_chart_index])
	if song_scroll != null:
		remembered_scroll_value = song_scroll.scroll_vertical
	if search_field != null:
		remembered_search_text = search_field.text
	if filter_option != null:
		remembered_filter_index = filter_option.selected


func _restore_scroll_position() -> void:
	if song_scroll != null:
		song_scroll.scroll_vertical = int(remembered_scroll_value)


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
	if not song_manager.is_removable_local_song(song):
		preview_status.text = AuroraLocale.text(
			"SOLO PUEDES BORRAR NIVELES DEL EDITOR O PAQUETES LOCALES"
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
	var remove_error := song_manager.move_local_song_to_trash(
		pending_delete_song
	)
	pending_delete_song = null
	if remove_error != OK:
		preview_status.text = AuroraLocale.text("NO SE PUDO MOVER LA CANCION A LA PAPELERA")
		return
	all_songs = song_manager.get_all_songs()
	_apply_song_filter()
	preview_status.text = AuroraLocale.text("\"%s\" SE MOVIO A LA PAPELERA") % removed_title
	if not song_buttons.is_empty():
		song_buttons[selected_song_index].grab_focus()
	elif all_songs.is_empty():
		import_package_button.grab_focus()


func _cancel_delete_selected_song() -> void:
	pending_delete_song = null
	delete_modal.visible = false
	if not song_buttons.is_empty():
		song_buttons[selected_song_index].grab_focus()


func _return_to_menu() -> void:
	_stop_preview()
	scene_manager.load_scene("main_menu")


func _open_local_package_share() -> void:
	if share_panel != null or _is_package_import_active():
		return
	preview_request_token += 1
	_stop_preview()
	share_panel = LOCAL_PACKAGE_SHARE_PANEL.new()
	share_panel.name = "LocalPackageSharePanel"
	share_panel.close_requested.connect(_close_local_package_share)
	add_child(share_panel)
	share_panel.setup(song_manager, settings_manager, _get_selected_song())


func _close_local_package_share() -> void:
	if share_panel == null:
		return
	share_panel.queue_free()
	share_panel = null
	share_package_button.grab_focus()


func _get_selected_song() -> SongData:
	if selected_song_index < 0 or selected_song_index >= songs.size():
		return null
	return songs[selected_song_index]


func _show_empty_library() -> void:
	var library_is_empty := all_songs.is_empty()
	preview_request_token += 1
	_stop_preview()
	for child in mode_buttons_container.get_children():
		mode_buttons_container.remove_child(child)
		child.queue_free()
	mode_buttons.clear()
	preview_cover.texture = null
	preview_title.text = (
		AuroraLocale.text("SIN RESULTADOS")
		if not all_songs.is_empty()
		else AuroraLocale.text("SIN CANCIONES")
	)
	preview_artist.text = (
		AuroraLocale.text("CAMBIA LA BUSQUEDA O EL FILTRO")
		if not all_songs.is_empty()
		else AuroraLocale.text(
			"USA INSTALAR NIVEL O CREA UNO EN EL EDITOR"
		)
	)
	preview_meta.text = AuroraLocale.text("DURACION --:--")
	personal_best_label.text = AuroraLocale.text("MEJOR: SIN REGISTRO")
	difficulty_label.text = AuroraLocale.text("DIFICULTAD: -")
	preview_status.text = AuroraLocale.text("BIBLIOTECA VACIA")
	song_count_label.text = AuroraLocale.text("%d / %d CANCIONES") % [
		songs.size(),
		all_songs.size(),
	]
	preview_button.disabled = true
	favorite_button.disabled = true
	edit_button.text = AuroraLocale.text(
		"CREAR NIVEL" if library_is_empty else "EDITAR CANCION"
	)
	edit_button.disabled = not library_is_empty
	delete_button.disabled = true
	play_button.disabled = true
