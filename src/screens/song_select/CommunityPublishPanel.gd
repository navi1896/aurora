extends VBoxContainer

class_name CommunityPublishPanel

const PROJECT_STORE := preload("res://src/screens/editor/EditorProjectStore.gd")
const SUBMISSION_SERVICE_TYPE := preload(
	"res://src/online/CommunitySubmissionService.gd"
)

var song_manager: SongManager
var songs: Array[SongData] = []
var selected_song: SongData
var submission_service = SUBMISSION_SERVICE_TYPE.new()
var submission_thread: Thread
var song_selector: OptionButton
var title_edit: LineEdit
var artist_edit: LineEdit
var author_edit: LineEdit
var version_edit: LineEdit
var license_selector: OptionButton
var description_edit: TextEdit
var rights_check: CheckBox
var files_label: Label
var prepare_button: Button
var status_label: Label
var prepared_path_label: Label


func setup(manager: SongManager, initial_song: SongData) -> void:
	song_manager = manager
	_build_interface()
	_refresh_songs(initial_song)


func is_busy() -> bool:
	return submission_thread != null


func set_actions_disabled(disabled: bool) -> void:
	if song_selector != null:
		song_selector.disabled = disabled or songs.is_empty()
	for edit in [title_edit, artist_edit, author_edit, version_edit]:
		if edit != null:
			edit.editable = not disabled
	if license_selector != null:
		license_selector.disabled = disabled
	if description_edit != null:
		description_edit.editable = not disabled
	if rights_check != null:
		rights_check.disabled = disabled
	if prepare_button != null:
		prepare_button.disabled = disabled
	if not disabled:
		_refresh_prepare_state()


func _build_interface() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var intro := AuroraUi.make_label(
		AuroraLocale.text(
			"SELECCIONA UNA CANCIÓN CREADA EN AURORA. EL JUEGO REÚNE EL CHART Y LOS MEDIOS SIN PEDIRTE BUSCAR ARCHIVOS."
		),
		14,
		AuroraUi.MUTED
	)
	add_child(intro)

	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(body_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	body_scroll.add_child(body)

	var song_row := HBoxContainer.new()
	song_row.add_theme_constant_override("separation", 14)
	body.add_child(song_row)
	var song_label := AuroraUi.make_pixel_label(
		AuroraLocale.text("CANCIÓN DE TU BIBLIOTECA"),
		12,
		AuroraUi.TEAL
	)
	song_label.custom_minimum_size = Vector2(280, 44)
	song_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	song_row.add_child(song_label)
	song_selector = OptionButton.new()
	song_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	song_selector.custom_minimum_size = Vector2(0, 44)
	AuroraUi.apply_pixel_font(song_selector, 11)
	song_selector.item_selected.connect(_on_song_selected)
	song_row.add_child(song_selector)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	body.add_child(columns)
	var metadata_column := VBoxContainer.new()
	metadata_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metadata_column.add_theme_constant_override("separation", 9)
	columns.add_child(metadata_column)
	var rights_column := VBoxContainer.new()
	rights_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rights_column.add_theme_constant_override("separation", 9)
	columns.add_child(rights_column)

	title_edit = _make_line_edit("TÍTULO", metadata_column)
	artist_edit = _make_line_edit("ARTISTA", metadata_column)
	author_edit = _make_line_edit("CREADOR DEL CHART", metadata_column)
	version_edit = _make_line_edit("VERSIÓN DEL PAQUETE", metadata_column)
	version_edit.placeholder_text = "1.0.0"

	var license_label := AuroraUi.make_pixel_label(
		AuroraLocale.text("LICENCIA PARA COMPARTIR"),
		10,
		AuroraUi.TEAL
	)
	rights_column.add_child(license_label)
	license_selector = OptionButton.new()
	license_selector.custom_minimum_size = Vector2(0, 42)
	for license_name in [
		"OBRA ORIGINAL / CON PERMISO",
		"CC0",
		"CC BY 4.0",
		"CC BY-SA 4.0",
		"OTRA / REQUIERE REVISIÓN",
	]:
		license_selector.add_item(license_name)
	rights_column.add_child(license_selector)

	var description_label := AuroraUi.make_pixel_label(
		AuroraLocale.text("DESCRIPCIÓN"),
		10,
		AuroraUi.TEAL
	)
	rights_column.add_child(description_label)
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size = Vector2(0, 88)
	description_edit.placeholder_text = AuroraLocale.text(
		"Describe el chart y cualquier crédito necesario."
	)
	description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rights_column.add_child(description_edit)

	files_label = AuroraUi.make_label("", 13, AuroraUi.MUTED)
	files_label.custom_minimum_size = Vector2(0, 54)
	rights_column.add_child(files_label)
	rights_check = CheckBox.new()
	rights_check.text = AuroraLocale.text(
		"SOY AUTOR O TENGO PERMISO PARA COMPARTIR AUDIO, VIDEO, PORTADA Y CHART."
	)
	rights_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rights_check.toggled.connect(_refresh_prepare_state)
	rights_column.add_child(rights_check)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 14)
	body.add_child(action_row)
	prepare_button = AuroraUi.make_button(
		AuroraLocale.text("PREPARAR PUBLICACIÓN"),
		true
	)
	prepare_button.custom_minimum_size = Vector2(280, 52)
	prepare_button.pressed.connect(_prepare_submission)
	action_row.add_child(prepare_button)
	status_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("SELECCIONA UNA CANCIÓN"),
		11,
		AuroraUi.TEAL
	)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_row.add_child(status_label)

	prepared_path_label = AuroraUi.make_label("", 12, AuroraUi.MUTED)
	prepared_path_label.visible = false
	body.add_child(prepared_path_label)

	var online_note := AuroraUi.make_label(
		AuroraLocale.text(
			"EL PAQUETE Y LA FICHA QUEDAN LISTOS DENTRO DE AURORA. EL ENVÍO AUTOMÁTICO SE ACTIVARÁ AL CONECTAR UN SERVICIO SEGURO; NO SE GUARDARÁN CONTRASEÑAS EN EL JUEGO."
		),
		12,
		AuroraUi.GOLD
	)
	body.add_child(online_note)


func _make_line_edit(label_text: String, parent: VBoxContainer) -> LineEdit:
	var label := AuroraUi.make_pixel_label(
		AuroraLocale.text(label_text),
		10,
		AuroraUi.TEAL
	)
	parent.add_child(label)
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(0, 42)
	edit.text_changed.connect(_on_field_changed)
	parent.add_child(edit)
	return edit


func _refresh_songs(initial_song: SongData) -> void:
	songs.clear()
	song_selector.clear()
	for song in song_manager.get_all_songs():
		if song_manager.is_editor_song(song):
			songs.append(song)
			song_selector.add_item("%s  //  %s" % [song.title, song.artist])
	if songs.is_empty():
		selected_song = null
		song_selector.add_item(AuroraLocale.text("NO HAY PROYECTOS PUBLICABLES"))
		song_selector.disabled = true
		status_label.text = AuroraLocale.text(
			"CREA O EDITA UNA CANCIÓN EN AURORA ANTES DE PUBLICARLA"
		)
		_refresh_prepare_state()
		return
	var selected_index := 0
	if initial_song != null:
		for index in range(songs.size()):
			if songs[index].song_id == initial_song.song_id:
				selected_index = index
				break
	song_selector.select(selected_index)
	_load_song(songs[selected_index])


func _on_song_selected(index: int) -> void:
	if index < 0 or index >= songs.size():
		return
	_load_song(songs[index])


func _load_song(song: SongData) -> void:
	selected_song = song
	prepared_path_label.visible = false
	prepared_path_label.text = ""
	var load_result: Dictionary = PROJECT_STORE.load_bundle(song.editor_project_path)
	if not bool(load_result.get("ok", false)):
		status_label.text = str(load_result.get("message", "PROYECTO NO DISPONIBLE"))
		_refresh_prepare_state()
		return
	var project: Dictionary = load_result.get("project", {})
	var metadata: Dictionary = project.get("metadata", {})
	title_edit.text = str(metadata.get("title", song.title))
	artist_edit.text = str(metadata.get("artist", song.artist))
	author_edit.text = str(metadata.get("chart_author", "Aurora Creator"))
	version_edit.text = str(project.get("package_version", "1.0.0"))
	description_edit.text = ""
	rights_check.button_pressed = false
	files_label.text = _media_summary(project, load_result.get("chart", {}))
	status_label.text = AuroraLocale.text("DATOS CARGADOS AUTOMÁTICAMENTE")
	_refresh_prepare_state()


func _media_summary(project: Dictionary, chart: Dictionary) -> String:
	var media: Dictionary = project.get("media", {})
	var names: PackedStringArray = []
	for key in ["audio_path", "video_path", "cover_path"]:
		var path := str(media.get(key, "")).strip_edges()
		if not path.is_empty():
			names.append(path.get_file())
	var note_count := (chart.get("notes", []) as Array).size()
	return AuroraLocale.text("ARCHIVOS DETECTADOS: %s // %d NOTAS") % [
		", ".join(names) if not names.is_empty() else "SIN MEDIOS",
		note_count,
	]


func _on_field_changed(_value: String) -> void:
	_refresh_prepare_state()


func _refresh_prepare_state(_pressed: bool = false) -> void:
	if prepare_button == null:
		return
	prepare_button.disabled = (
		selected_song == null
		or title_edit.text.strip_edges().is_empty()
		or artist_edit.text.strip_edges().is_empty()
		or author_edit.text.strip_edges().is_empty()
		or version_edit.text.strip_edges().is_empty()
		or not rights_check.button_pressed
		or is_busy()
	)


func _prepare_submission() -> void:
	if selected_song == null or is_busy():
		return
	var publication := {
		"title": title_edit.text.strip_edges(),
		"artist": artist_edit.text.strip_edges(),
		"chart_author": author_edit.text.strip_edges(),
		"package_version": version_edit.text.strip_edges(),
		"license": license_selector.get_item_text(license_selector.selected),
		"description": description_edit.text.strip_edges(),
		"rights_confirmed": rights_check.button_pressed,
	}
	submission_thread = Thread.new()
	set_actions_disabled(true)
	status_label.text = AuroraLocale.text("REUNIENDO CHART Y MEDIOS...")
	var start_error := submission_thread.start(
		Callable(submission_service, "prepare_submission").bind(
			selected_song.editor_project_path,
			publication
		)
	)
	if start_error != OK:
		submission_thread = null
		set_actions_disabled(false)
		status_label.text = AuroraLocale.text("NO SE PUDO INICIAR LA PREPARACIÓN")
	_refresh_prepare_state()


func _process(_delta: float) -> void:
	if submission_thread == null or submission_thread.is_alive():
		return
	var result_value = submission_thread.wait_to_finish()
	submission_thread = null
	set_actions_disabled(false)
	var result: Dictionary = result_value if result_value is Dictionary else {}
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "NO SE PUDO PREPARAR"))
		_refresh_prepare_state()
		return
	var package_path := str(result.get("package_path", ""))
	status_label.text = AuroraLocale.text("PUBLICACIÓN PREPARADA Y VERIFICADA")
	prepared_path_label.text = AuroraLocale.text(
		"PAQUETE: %s // SHA-256 VERIFICADO // PENDIENTE DE ENVÍO SEGURO"
	) % package_path.get_file()
	prepared_path_label.visible = true
	_refresh_prepare_state()


func _exit_tree() -> void:
	if submission_thread != null:
		submission_thread.wait_to_finish()
		submission_thread = null
