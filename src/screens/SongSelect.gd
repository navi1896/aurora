extends Control

class_name SongSelect

const SONG_LIST_ITEM_SCENE := preload("res://src/screens/song_select/SongListItem.tscn")
const LOCAL_PACKAGE_SHARE_PANEL := preload(
	"res://src/screens/song_select/LocalPackageSharePanel.gd"
)
const LOCAL_PACKAGE_INSTALL_PANEL := preload(
	"res://src/screens/song_select/LocalPackageInstallPanel.gd"
)
const LOCAL_PACKAGE_BATCH_PANEL := preload(
	"res://src/screens/song_select/LocalPackageBatchPanel.gd"
)
const SONG_PACKAGE_SERVICE := preload("res://src/packages/SongPackageService.gd")
const PREVIEW_FADE_SECONDS := 0.5
const PREVIEW_EXTRA_DURATION_SECONDS := 10.0
const PREVIEW_SILENT_DB := -48.0
const DEFAULT_SONG_ICON := preload("res://assets/menu/ui/music_note.png")

@onready var back_button: Button = $LibraryMargins/PageLayout/Header/BackButton
@onready var title_label: Label = $LibraryMargins/PageLayout/Header/HeaderCopy/TitleLabel
@onready var subtitle_label: Label = $LibraryMargins/PageLayout/Header/HeaderCopy/SubtitleLabel
@onready var import_package_button: Button = $LibraryMargins/PageLayout/Header/HeaderActions/ActionButtons/ImportPackageButton
@onready var share_package_button: Button = $LibraryMargins/PageLayout/Header/HeaderActions/ActionButtons/SharePackageButton
@onready var song_count_label: Label = $LibraryMargins/PageLayout/Header/HeaderActions/SongCountLabel
@onready var song_list_header: Label = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/SongListHeader
@onready var search_field: LineEdit = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/FilterRow/SearchField
@onready var filter_option: OptionButton = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/FilterRow/FilterOption
@onready var collection_option: OptionButton = $LibraryMargins/PageLayout/LibraryBody/SongListPanel/SongListMargins/SongListLayout/FilterRow/CollectionOption
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
@onready var version_label: Label = $LibraryMargins/PageLayout/Footer/VersionLabel
@onready var preview_audio: AudioStreamPlayer = $PreviewAudio

static var remembered_song_id := ""
static var remembered_chart_signature := ""
static var remembered_search_text := ""
static var remembered_filter_index := 0
static var remembered_collection_id := ""

var scene_manager: SceneManager
var game_manager: GameManager
var song_manager: SongManager
var settings_manager: SettingsManager
var input_manager: InputManager
var ui_feedback
var all_songs: Array[SongData] = []
var songs: Array[SongData] = []
var song_buttons: Array[Button] = []
var song_thumbnails: Dictionary = {}
var song_top_spacer: Control
var song_bottom_spacer: Control
var recenter_generation := 0
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
var package_import_queue := PackedStringArray()
var package_import_batch_total := 0
var package_import_batch_results: Array[Dictionary] = []
var package_import_batch_items: Array[Dictionary] = []
var package_import_selected_song_id := ""
var package_import_chart_signature := ""
var preserve_remembered_selection_on_exit := false
var share_panel: Control
var package_install_panel: Control
var preview_content_scroll: ScrollContainer


func _ready() -> void:
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	var app := get_tree().current_scene
	scene_manager = app.get_node("Managers/SceneManager")
	game_manager = app.get_node("Managers/GameManager")
	song_manager = app.get_node("Managers/SongManager")
	settings_manager = app.get_node("Managers/SettingsManager")
	input_manager = app.get_node("Managers/InputManager")
	ui_feedback = app.get_node_or_null("Managers/UiFeedbackManager")
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
	_apply_library_layout()
	_setup_preview_loop_timers()
	_apply_localized_texts()
	_setup_package_dialog()
	back_button.pressed.connect(_return_to_menu)
	import_package_button.pressed.connect(_open_local_package_import)
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
	collection_option.tooltip_text = AuroraLocale.text(
		"FILTRA POR ARCHIVO DJMAX O POR AURORA MIX, TU GALERÍA DE YOUTUBE"
	)
	collection_option.item_selected.connect(_on_collection_filter_selected)
	_setup_collection_filter()
	search_field.text = remembered_search_text
	filter_option.select(clampi(remembered_filter_index, 0, 2))
	_setup_delete_dialog()
	_refresh_note_speed()
	song_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	song_scroll.resized.connect(_queue_center_song_selection)
	_apply_song_filter()
	if not song_buttons.is_empty():
		song_buttons[selected_song_index].grab_focus()
	elif all_songs.is_empty():
		import_package_button.grab_focus()


func _apply_library_layout() -> void:
	var body := $LibraryMargins/PageLayout/LibraryBody as HBoxContainer
	var list_panel := body.get_node("SongListPanel") as PanelContainer
	var preview_panel := body.get_node("PreviewPanel") as PanelContainer
	body.move_child(preview_panel, 0)
	body.add_theme_constant_override("separation", 18)
	preview_panel.custom_minimum_size.x = 0.0
	preview_panel.size_flags_stretch_ratio = 0.85
	list_panel.size_flags_stretch_ratio = 1.15
	var preview_layout := preview_title.get_parent() as VBoxContainer
	preview_layout.move_child(preview_title, 1)
	preview_layout.move_child(preview_artist, 2)
	preview_layout.move_child(preview_meta, 3)
	var spacer := preview_layout.get_node("PreviewSpacer")
	preview_layout.move_child(spacer, 10)
	preview_layout.move_child(play_button, 11)
	preview_layout.move_child(preview_button.get_parent(), 12)
	var preview_margins := preview_layout.get_parent()
	preview_margins.remove_child(preview_layout)
	preview_content_scroll = ScrollContainer.new()
	preview_content_scroll.name = "PreviewContentScroll"
	preview_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preview_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preview_content_scroll.follow_focus = true
	preview_margins.add_child(preview_content_scroll)
	preview_content_scroll.add_child(preview_layout)
	preview_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_update_library_layout)
	preview_content_scroll.resized.connect(_update_library_layout)
	call_deferred("_update_library_layout")


func _update_library_layout() -> void:
	if preview_content_scroll == null or preview_content_scroll.size.y <= 0.0:
		return
	var preview_layout := preview_title.get_parent() as VBoxContainer
	preview_cover.custom_minimum_size.y = 0.0
	var controls_height := preview_layout.get_combined_minimum_size().y
	var cover_height := maxf(0.0, preview_content_scroll.size.y - controls_height - 4.0)
	preview_cover.custom_minimum_size.y = minf(370.0, cover_height)


func _apply_localized_texts() -> void:
	back_button.text = AuroraLocale.text("VOLVER")
	import_package_button.text = AuroraLocale.text("INSTALAR NIVELES")
	import_package_button.tooltip_text = AuroraLocale.text(
		"AÑADE A TU BIBLIOTECA UNO O VARIOS ARCHIVOS .AURORA RECIBIDOS POR CORREO, CHAT, USB O NUBE"
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
	package_dialog.title = AuroraLocale.text("INSTALAR UNO O VARIOS NIVELES .AURORA")
	package_dialog.access = FileDialog.ACCESS_FILESYSTEM
	package_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	package_dialog.use_native_dialog = true
	package_dialog.filters = PackedStringArray([
		"*.aurora ; Aurora Song Package",
	])
	package_dialog.files_selected.connect(
		_on_package_files_selected
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


func _on_package_files_selected(paths: PackedStringArray) -> void:
	if _is_package_import_active():
		preview_status.text = AuroraLocale.text(
			"ESPERA A QUE TERMINE LA IMPORTACIÓN DEL PAQUETE."
		)
		return
	if paths.is_empty():
		return
	settings_manager.set_setting(
		"last_package_directory",
		paths[0].get_base_dir(),
		false
	)
	if paths.size() == 1:
		_on_package_file_selected(paths[0])
		return
	_open_package_batch_confirmation(paths)


func _on_package_file_selected(package_path: String) -> void:
	var inspection := song_manager.inspect_song_package(package_path)
	if not bool(inspection.get("ok", false)):
		preview_status.text = _package_import_error_text(inspection)
		return
	_open_package_install_confirmation(
		package_path,
		inspection.get("manifest", {})
	)


func _open_package_batch_confirmation(paths: PackedStringArray) -> void:
	var items: Array[Dictionary] = []
	var latest_by_id: Dictionary = {}
	for path in paths:
		var item := {
			"path": path,
			"name": path.get_file(),
			"status": AuroraLocale.text("ARCHIVO NO VÁLIDO"),
			"installable": false,
		}
		items.append(item)
		if path.get_extension().to_lower() != "aurora":
			continue
		var inspection := song_manager.inspect_song_package(path)
		if not bool(inspection.get("ok", false)):
			item["status"] = str(inspection.get("message", AuroraLocale.text("ARCHIVO NO VÁLIDO")))
			continue
		var manifest: Dictionary = inspection.get("manifest", {})
		var package_id := str(manifest.get("package_id", ""))
		var version := str(manifest.get("package_version", "1.0.0"))
		var song: Dictionary = manifest.get("song", {})
		item["name"] = "%s  //  %s" % [str(song.get("title", path.get_file())), path.get_file()]
		var installed_version := song_manager.get_installed_package_version(package_id)
		if not installed_version.is_empty() and SONG_PACKAGE_SERVICE.compare_package_versions(version, installed_version) <= 0:
			item["status"] = AuroraLocale.text("YA INSTALADO O VERSIÓN ANTERIOR")
			continue
		item["status"] = (AuroraLocale.text("ACTUALIZAR A v%s") if not installed_version.is_empty() else AuroraLocale.text("INSTALAR v%s")) % version
		item["installable"] = true
		if latest_by_id.has(package_id):
			var previous_index := int(latest_by_id[package_id])
			var previous: Dictionary = items[previous_index]
			if SONG_PACKAGE_SERVICE.compare_package_versions(version, str(previous.get("version", "0.0.0"))) > 0:
				previous["installable"] = false
				previous["status"] = AuroraLocale.text("OTRA VERSIÓN SELECCIONADA ES MÁS RECIENTE")
				latest_by_id[package_id] = items.size() - 1
			else:
				item["installable"] = false
				item["status"] = AuroraLocale.text("OTRA VERSIÓN SELECCIONADA ES MÁS RECIENTE")
		else:
			latest_by_id[package_id] = items.size() - 1
		item["version"] = version
	package_import_batch_items = items
	_close_package_install_confirmation()
	package_install_panel = LOCAL_PACKAGE_BATCH_PANEL.new()
	package_install_panel.name = "LocalPackageBatchPanel"
	package_install_panel.install_confirmed.connect(_confirm_package_batch_install)
	package_install_panel.close_requested.connect(_close_package_install_confirmation)
	add_child(package_install_panel)
	package_install_panel.show_selection(items)


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
	_prepare_package_import()
	_start_package_import(package_path)


func _confirm_package_batch_install(paths: PackedStringArray) -> void:
	_close_package_install_confirmation()
	if paths.is_empty():
		return
	_prepare_package_import()
	package_import_queue = paths
	package_import_batch_total = paths.size()
	package_import_batch_results.clear()
	for item in package_import_batch_items:
		if not bool(item.get("installable", false)):
			package_import_batch_results.append({
				"path": str(item.get("path", "")),
				"result": {
					"ok": false,
					"error_code": "selection_skipped",
					"message": str(item.get("status", "")),
				},
			})
	package_import_batch_items.clear()
	_set_package_import_controls_disabled(true)
	_start_next_package_import()


func _prepare_package_import() -> void:
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


func _start_next_package_import() -> void:
	if package_import_queue.is_empty():
		_finish_package_batch_import()
		return
	var path := package_import_queue[0]
	package_import_queue.remove_at(0)
	_start_package_import(path)


func _start_package_import(package_path: String) -> void:
	package_import_path = package_path
	package_import_thread = Thread.new()
	_set_package_import_controls_disabled(true)
	preview_status.text = (
		AuroraLocale.text("INSTALANDO %d / %d // %s") % [
			package_import_batch_total - package_import_queue.size(),
			package_import_batch_total,
			package_path.get_file(),
		]
		if package_import_batch_total > 0
		else AuroraLocale.text("VALIDANDO PAQUETE...")
	)
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
	var failure := {
		"ok": false,
		"message": "NO SE PUDO INICIAR LA IMPORTACIÓN DEL PAQUETE.",
	}
	if package_import_batch_total > 0:
		package_import_batch_results.append({"path": package_path, "result": failure})
		_start_next_package_import()
	else:
		_set_package_import_controls_disabled(false)
		preview_status.text = AuroraLocale.text(str(failure["message"]))


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
	var result: Dictionary = (
		result_value
		if result_value is Dictionary
		else {}
	)
	if package_import_batch_total > 0:
		package_import_batch_results.append({"path": completed_path, "result": result})
		_start_next_package_import()
		return
	_set_package_import_controls_disabled(false)
	if not bool(result.get("ok", false)):
		preview_status.text = _package_import_error_text(result)
		return
	song_manager.load_songs()
	all_songs = song_manager.get_all_songs()
	song_thumbnails.clear()
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


func _finish_package_batch_import() -> void:
	var installed := 0
	var updated := 0
	for item in package_import_batch_results:
		var result: Dictionary = item.get("result", {})
		if bool(result.get("ok", false)):
			if bool(result.get("updated", false)):
				updated += 1
			else:
				installed += 1
			if package_import_selected_song_id.is_empty():
				package_import_selected_song_id = str(result.get("song_id", ""))
	if installed + updated > 0:
		song_manager.load_songs()
		all_songs = song_manager.get_all_songs()
		song_thumbnails.clear()
		remembered_song_id = package_import_selected_song_id
		remembered_chart_signature = package_import_chart_signature
		_apply_song_filter()
	package_import_queue.clear()
	package_import_batch_total = 0
	package_import_batch_items.clear()
	package_import_selected_song_id = ""
	package_import_chart_signature = ""
	_set_package_import_controls_disabled(false)
	preview_status.text = AuroraLocale.text("%d INSTALADOS · %d ACTUALIZADOS // REVISA EL RESUMEN") % [installed, updated]
	package_install_panel = LOCAL_PACKAGE_BATCH_PANEL.new()
	package_install_panel.name = "LocalPackageBatchResults"
	package_install_panel.close_requested.connect(_close_package_install_confirmation)
	add_child(package_install_panel)
	package_install_panel.show_results(package_import_batch_results)
	package_import_batch_results.clear()


func _is_package_import_active() -> bool:
	return package_import_thread != null or package_import_batch_total > 0


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
			"INSTALANDO..." if disabled else "INSTALAR NIVELES"
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
	if (
		event is InputEventMouseButton
		and event.pressed
		and (delete_modal == null or not delete_modal.visible)
		and song_scroll.get_global_rect().has_point(event.position)
	):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move_song_selection(-1)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_song_selection(1)
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
				_open_local_package_import()
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
		song_list.remove_child(child)
		child.queue_free()
	song_buttons.clear()
	song_top_spacer = Control.new()
	song_top_spacer.name = "TopCenterSpacer"
	song_top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song_list.add_child(song_top_spacer)

	for index in range(songs.size()):
		var song := songs[index]
		var button := SONG_LIST_ITEM_SCENE.instantiate() as Button
		button.name = "Song%02d" % (index + 1)
		button.toggle_mode = true
		button.button_group = song_button_group
		button.text = "%s\n%s  ·  %s  ·  %s" % [
			song.title.to_upper(),
			song.artist,
			song.get_duration_text(),
			_song_modes_text(song),
		]
		var thumbnail := button.get_node("ThumbnailFrame/Thumbnail") as TextureRect
		thumbnail.texture = _get_song_thumbnail(song)
		button.focus_entered.connect(_select_song.bind(index, false))
		button.pressed.connect(_select_song.bind(index, true))
		song_list.add_child(button)
		song_buttons.append(button)
	song_bottom_spacer = Control.new()
	song_bottom_spacer.name = "BottomCenterSpacer"
	song_bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song_list.add_child(song_bottom_spacer)

	song_count_label.text = (
		AuroraLocale.text("%d / %d CANCIONES") % [songs.size(), all_songs.size()]
		if songs.size() != all_songs.size()
		else AuroraLocale.text("%d CANCIONES") % songs.size()
	)


func _get_song_thumbnail(song: SongData) -> Texture2D:
	var song_id := str(song.song_id)
	if song_thumbnails.has(song_id):
		return song_thumbnails[song_id] as Texture2D
	var source_image: Image
	var media: Dictionary = song_manager.package_media_by_song_id.get(song_id, {})
	var cover_path := str(media.get("cover_path", ""))
	if not cover_path.is_empty() and FileAccess.file_exists(cover_path):
		source_image = Image.load_from_file(ProjectSettings.globalize_path(cover_path))
	if (source_image == null or source_image.is_empty()) and song.cover != null:
		source_image = song.cover.get_image()
	if source_image == null or source_image.is_empty():
		return DEFAULT_SONG_ICON
	var thumbnail := source_image.duplicate() as Image
	thumbnail.resize(46, 46, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(thumbnail)
	song_thumbnails[song_id] = texture
	return texture


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
		if ui_feedback != null:
			ui_feedback.play_song_navigation()
		selected_chart_index = 0
	_refresh_selection()
	if song_changed:
		_queue_center_song_selection()
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
	preview_meta.text = "%s  //  %s" % [
		AuroraLocale.text(SongData.collection_label(song.collection_id)),
		AuroraLocale.text("DURACION %s") % song.get_duration_text(),
	]
	_populate_mode_buttons(song)
	_update_chart_selection()
	call_deferred("_update_library_layout")
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
	if ui_feedback != null:
		ui_feedback.play_song_navigation()
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
	_queue_center_song_selection()
	if not search_field.has_focus():
		song_buttons[selected_song_index].grab_focus()


func _queue_center_song_selection() -> void:
	recenter_generation += 1
	call_deferred("_center_song_selection", recenter_generation)


func _center_song_selection(generation: int) -> void:
	if not is_inside_tree() or generation != recenter_generation or song_buttons.is_empty():
		return
	var row_height := song_buttons[selected_song_index].size.y
	var separation := float(song_list.get_theme_constant("separation"))
	var padding := maxf(0.0, (song_scroll.size.y - row_height) * 0.5 - separation)
	song_top_spacer.custom_minimum_size.y = padding
	song_bottom_spacer.custom_minimum_size.y = padding
	var center_slot := song_buttons.size() / 2
	for visual_slot in range(song_buttons.size()):
		var song_index := wrapi(
			selected_song_index - center_slot + visual_slot,
			0,
			song_buttons.size()
		)
		song_list.move_child(song_buttons[song_index], visual_slot + 1)
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if generation != recenter_generation or not is_inside_tree():
		return
	var selected_button := song_buttons[selected_song_index]
	song_scroll.scroll_vertical = roundi(
		selected_button.position.y
		+ selected_button.size.y * 0.5
		- song_scroll.size.y * 0.5
	)


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
	if not game_manager.start_song(song, chart):
		preview_status.text = AuroraLocale.text("NO SE PUDO INICIAR EL CHART")
		return
	_fade_preview_for_exit(4.6)
	if ui_feedback != null:
		ui_feedback.play_confirm()
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
	var preview_duration := maxf(song.preview_duration_seconds, 1.0) + PREVIEW_EXTRA_DURATION_SECONDS
	preview_end_seconds = minf(
		song.duration_seconds,
		start_seconds + preview_duration
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
	if ui_feedback != null:
		ui_feedback.play_confirm()
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


func _fade_preview_for_exit(fade_seconds: float) -> void:
	preview_request_token += 1
	if preview_fade_timer != null:
		preview_fade_timer.stop()
	if preview_finish_timer != null:
		preview_finish_timer.stop()
	preview_loop_song = null
	if preview_fade_tween != null and preview_fade_tween.is_valid():
		preview_fade_tween.kill()
	if not preview_audio.playing and not preview_video.is_playing():
		return
	preview_fade_tween = create_tween()
	preview_fade_tween.set_parallel(true)
	preview_fade_tween.set_trans(Tween.TRANS_SINE)
	if preview_audio.playing:
		preview_fade_tween.tween_property(preview_audio, "volume_db", PREVIEW_SILENT_DB, fade_seconds)
	if preview_video.is_playing():
		preview_fade_tween.tween_property(preview_video, "volume_db", PREVIEW_SILENT_DB, fade_seconds)


func _on_search_changed(value: String) -> void:
	remembered_search_text = value
	_apply_song_filter()


func _on_filter_selected(index: int) -> void:
	remembered_filter_index = clampi(index, 0, 2)
	_apply_song_filter()


func _setup_collection_filter() -> void:
	collection_option.clear()
	collection_option.add_item(AuroraLocale.text("TODAS LAS COLECCIONES"))
	collection_option.set_item_metadata(0, "")

	var available_ids: Array[String] = []
	for song in all_songs:
		var collection_id := SongData.resolve_collection_id(
			song.collection_id,
			str(song.song_id).trim_prefix("package_")
		)
		if collection_id not in available_ids:
			available_ids.append(collection_id)

	var collection_ids: Array[String] = []
	for preferred_id in [
		SongData.COLLECTION_DJMAX_ARCHIVE,
		SongData.COLLECTION_AURORA_MIX,
	]:
		if preferred_id in available_ids:
			collection_ids.append(preferred_id)
			available_ids.erase(preferred_id)
	available_ids.sort()
	collection_ids.append_array(available_ids)

	var selected_index := 0
	var found_remembered_collection := remembered_collection_id.is_empty()
	for collection_id in collection_ids:
		var count := 0
		for song in all_songs:
			if SongData.resolve_collection_id(
				song.collection_id,
				str(song.song_id).trim_prefix("package_")
			) == collection_id:
				count += 1
		var item_index := collection_option.item_count
		collection_option.add_item(
			"%s  //  %d" % [
				AuroraLocale.text(SongData.collection_label(collection_id)),
				count,
			]
		)
		collection_option.set_item_metadata(item_index, collection_id)
		if collection_id == remembered_collection_id:
			selected_index = item_index
			found_remembered_collection = true
	if not found_remembered_collection:
		remembered_collection_id = ""
	collection_option.select(selected_index)


func _on_collection_filter_selected(index: int) -> void:
	if index < 0 or index >= collection_option.item_count:
		return
	remembered_collection_id = str(
		collection_option.get_item_metadata(index)
	)
	_apply_song_filter()


func _apply_song_filter() -> void:
	var keep_search_focus := search_field.has_focus()
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
					and _song_matches_collection(candidate)
					and _song_matches_search(candidate, query)
				):
					songs.append(candidate)
					break
	else:
		for candidate in all_songs:
			if filter_option.selected == 1 and str(candidate.song_id) not in favorite_ids:
				continue
			if not _song_matches_collection(candidate):
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
	_queue_center_song_selection()
	if not song_buttons.is_empty() and not keep_search_focus:
		song_buttons[selected_song_index].grab_focus()


func _song_matches_search(song: SongData, query: String) -> bool:
	if query.is_empty():
		return true
	return (
		song.title.to_lower().contains(query)
		or song.artist.to_lower().contains(query)
		or SongData.collection_label(song.collection_id).to_lower().contains(query)
	)


func _song_matches_collection(song: SongData) -> bool:
	if collection_option == null or collection_option.selected < 0:
		return true
	var selected_collection := str(
		collection_option.get_item_metadata(collection_option.selected)
	)
	if selected_collection.is_empty():
		return true
	return SongData.resolve_collection_id(
		song.collection_id,
		str(song.song_id).trim_prefix("package_")
	) == selected_collection


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
			_fade_preview_for_exit(4.6)
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
			"ABRIENDO EDICION..."
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
	var return_song_id := str(
		edit_result.get("return_song_id", edit_result.get("editor_song_id", ""))
	)
	if not return_song_id.is_empty():
		remembered_song_id = return_song_id
		remembered_chart_signature = _chart_signature(chart)
	preserve_remembered_selection_on_exit = true
	preview_request_token += 1
	_fade_preview_for_exit(4.6)
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
	if search_field != null:
		remembered_search_text = search_field.text
	if filter_option != null:
		remembered_filter_index = filter_option.selected


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
	_fade_preview_for_exit(0.22)
	scene_manager.load_scene("main_menu")


func _open_local_package_import() -> void:
	_open_local_package_share("import")


func _open_local_package_share(initial_tab := "export") -> void:
	if share_panel != null or _is_package_import_active():
		return
	preview_request_token += 1
	_stop_preview()
	share_panel = LOCAL_PACKAGE_SHARE_PANEL.new()
	share_panel.name = "LocalPackageSharePanel"
	share_panel.close_requested.connect(_close_local_package_share)
	share_panel.import_requested.connect(_on_share_import_requested)
	add_child(share_panel)
	share_panel.setup(song_manager, settings_manager, _get_selected_song(), initial_tab)


func _on_share_import_requested() -> void:
	_close_local_package_share()
	_open_package_dialog()


func _close_local_package_share() -> void:
	if share_panel == null:
		return
	var focus_import: bool = share_panel.import_view.visible
	share_panel.queue_free()
	share_panel = null
	if focus_import:
		import_package_button.grab_focus()
	else:
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
