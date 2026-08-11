extends Control

class_name LocalPackageSharePanel

const SHARE_SERVICE_TYPE := preload(
	"res://src/screens/song_select/LocalPackageShareService.gd"
)

signal close_requested

var song_manager: SongManager
var settings_manager: SettingsManager
var songs: Array[SongData] = []
var selected_song: SongData
var share_service = SHARE_SERVICE_TYPE.new()
var export_thread: Thread
var exported_path := ""
var song_selector: OptionButton
var title_value: Label
var artist_value: Label
var details_value: Label
var files_value: Label
var status_label: Label
var export_button: Button
var open_folder_button: Button
var copy_path_button: Button
var close_button: Button
var save_dialog: FileDialog


func setup(
	manager: SongManager,
	settings: SettingsManager,
	initial_song: SongData = null
) -> void:
	song_manager = manager
	settings_manager = settings
	_build_interface()
	_refresh_songs(initial_song)


func request_close() -> void:
	if export_thread != null:
		status_label.text = AuroraLocale.text(
			"ESPERA A QUE TERMINE LA CREACIÓN DEL ARCHIVO."
		)
		return
	close_requested.emit()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var shade := ColorRect.new()
	AuroraUi.fill(shade)
	shade.color = Color(0.005, 0.008, 0.025, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var margins := AuroraUi.make_margin(100, 60, 100, 60)
	add_child(margins)
	var panel := AuroraUi.make_panel(Color(0.025, 0.03, 0.075, 0.99))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var heading := AuroraUi.make_pixel_label(
		AuroraLocale.text("COMPARTIR NIVEL"),
		24
	)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	close_button = AuroraUi.make_button(AuroraLocale.text("CERRAR"))
	close_button.custom_minimum_size = Vector2(170, 48)
	close_button.pressed.connect(request_close)
	header.add_child(close_button)

	var intro := AuroraUi.make_label(
		AuroraLocale.text(
			"CREA UN SOLO ARCHIVO .AURORA CON EL NIVEL, SUS NOTAS Y SUS MEDIOS. DESPUÉS PUEDES ENVIARLO POR EL MEDIO QUE PREFIERAS."
		),
		15,
		AuroraUi.MUTED
	)
	layout.add_child(intro)

	var selector_row := HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 18)
	layout.add_child(selector_row)
	var selector_label := AuroraUi.make_pixel_label(
		AuroraLocale.text("NIVEL DE TU BIBLIOTECA"),
		12,
		AuroraUi.TEAL
	)
	selector_label.custom_minimum_size = Vector2(310, 48)
	selector_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selector_row.add_child(selector_label)
	song_selector = OptionButton.new()
	song_selector.custom_minimum_size = Vector2(0, 48)
	song_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AuroraUi.apply_pixel_font(song_selector, 11)
	song_selector.item_selected.connect(_on_song_selected)
	selector_row.add_child(song_selector)

	var summary_panel := AuroraUi.make_panel(Color(0.04, 0.045, 0.1, 0.98))
	summary_panel.custom_minimum_size = Vector2(0, 200)
	layout.add_child(summary_panel)
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 12)
	summary_panel.add_child(summary)
	title_value = _add_summary_row(summary, "TÍTULO")
	artist_value = _add_summary_row(summary, "ARTISTA")
	details_value = _add_summary_row(summary, "CONTENIDO")
	files_value = _add_summary_row(summary, "ARCHIVOS")

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 14)
	layout.add_child(action_row)
	export_button = AuroraUi.make_button(
		AuroraLocale.text("CREAR ARCHIVO .AURORA"),
		true
	)
	export_button.custom_minimum_size = Vector2(310, 56)
	export_button.pressed.connect(_choose_export_path)
	action_row.add_child(export_button)
	open_folder_button = AuroraUi.make_button(
		AuroraLocale.text("ABRIR CARPETA")
	)
	open_folder_button.custom_minimum_size = Vector2(230, 56)
	open_folder_button.disabled = true
	open_folder_button.pressed.connect(_open_export_folder)
	action_row.add_child(open_folder_button)
	copy_path_button = AuroraUi.make_button(
		AuroraLocale.text("COPIAR UBICACIÓN")
	)
	copy_path_button.custom_minimum_size = Vector2(250, 56)
	copy_path_button.disabled = true
	copy_path_button.pressed.connect(_copy_export_path)
	action_row.add_child(copy_path_button)

	status_label = AuroraUi.make_pixel_label(
		AuroraLocale.text("SELECCIONA UN NIVEL"),
		11,
		AuroraUi.TEAL
	)
	status_label.custom_minimum_size = Vector2(0, 34)
	layout.add_child(status_label)

	var notice := AuroraUi.make_label(
		AuroraLocale.text(
			"AURORA NO SUBE EL ARCHIVO A INTERNET. COMPARTE ÚNICAMENTE CONTENIDO QUE TENGAS PERMITIDO COMPARTIR."
		),
		12,
		AuroraUi.GOLD
	)
	layout.add_child(notice)

	save_dialog = FileDialog.new()
	save_dialog.name = "SharePackageDialog"
	save_dialog.title = AuroraLocale.text("GUARDAR NIVEL .AURORA")
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.use_native_dialog = true
	save_dialog.filters = PackedStringArray([
		"*.aurora ; Aurora Song Package",
	])
	save_dialog.file_selected.connect(_begin_export)
	add_child(save_dialog)


func _add_summary_row(parent: VBoxContainer, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var label := AuroraUi.make_pixel_label(
		AuroraLocale.text(caption),
		10,
		AuroraUi.TEAL
	)
	label.custom_minimum_size = Vector2(220, 42)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var value := AuroraUi.make_label("—", 16)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	return value


func _refresh_songs(initial_song: SongData) -> void:
	songs.clear()
	song_selector.clear()
	for song in song_manager.get_all_songs():
		if song_manager.can_share_song_package(song):
			songs.append(song)
			song_selector.add_item("%s  //  %s" % [song.title, song.artist])
	if songs.is_empty():
		selected_song = null
		song_selector.add_item(AuroraLocale.text("NO HAY NIVELES PARA COMPARTIR"))
		song_selector.disabled = true
		export_button.disabled = true
		status_label.text = AuroraLocale.text(
			"CREA UN NIVEL EN EL EDITOR O INSTALA UN PAQUETE .AURORA."
		)
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
	if index >= 0 and index < songs.size():
		_load_song(songs[index])


func _load_song(song: SongData) -> void:
	selected_song = song
	exported_path = ""
	open_folder_button.disabled = true
	copy_path_button.disabled = true
	title_value.text = song.title
	artist_value.text = song.artist
	var modes: PackedStringArray = []
	var note_total := 0
	for chart in song.charts:
		modes.append("%dK %s %02d" % [
			chart.key_count,
			chart.difficulty_name,
			chart.difficulty_level,
		])
		note_total += chart.load_notes(song.bpm, song.duration_seconds).size()
	details_value.text = AuroraLocale.text("%s // %d NOTAS // DURACIÓN %s") % [
		" · ".join(modes),
		note_total,
		_format_time(song.duration_seconds),
	]
	files_value.text = AuroraLocale.text(
		"PAQUETE LOCAL INSTALADO"
		if song_manager.is_local_package_song(song)
		else "PROYECTO DEL EDITOR"
	)
	status_label.text = AuroraLocale.text("LISTO PARA CREAR EL ARCHIVO")
	export_button.disabled = false


func _choose_export_path() -> void:
	if selected_song == null or export_thread != null:
		return
	var last_directory := str(
		settings_manager.get_setting("last_package_export_directory", "")
	).strip_edges()
	if not last_directory.is_empty() and DirAccess.dir_exists_absolute(last_directory):
		save_dialog.current_dir = last_directory
	save_dialog.current_file = "%s.aurora" % _safe_file_name(selected_song.title)
	save_dialog.popup_centered_ratio(0.72)


func _begin_export(path: String) -> void:
	if selected_song == null or export_thread != null:
		return
	var output_path := path
	if output_path.get_extension().to_lower() != "aurora":
		output_path += ".aurora"
	if FileAccess.file_exists(output_path):
		status_label.text = AuroraLocale.text(
			"YA EXISTE UN ARCHIVO CON ESE NOMBRE. ELIGE OTRO NOMBRE."
		)
		return
	var descriptor := song_manager.make_song_package_share_descriptor(selected_song)
	if descriptor.is_empty():
		status_label.text = AuroraLocale.text(
			"ESTE NIVEL NO SE PUEDE COMPARTIR COMO PAQUETE LOCAL."
		)
		return
	settings_manager.set_setting(
		"last_package_export_directory",
		output_path.get_base_dir(),
		false
	)
	export_thread = Thread.new()
	_set_actions_disabled(true)
	status_label.text = AuroraLocale.text("CREANDO Y VERIFICANDO ARCHIVO...")
	var start_error := export_thread.start(
		Callable(share_service, "export_descriptor").bind(
			descriptor,
			output_path
		)
	)
	if start_error != OK:
		export_thread = null
		_set_actions_disabled(false)
		status_label.text = AuroraLocale.text(
			"NO SE PUDO INICIAR LA CREACIÓN DEL ARCHIVO."
		)


func _process(_delta: float) -> void:
	if export_thread == null or export_thread.is_alive():
		return
	var result_value = export_thread.wait_to_finish()
	export_thread = null
	_set_actions_disabled(false)
	var result: Dictionary = result_value if result_value is Dictionary else {}
	if not bool(result.get("ok", false)):
		status_label.text = str(
			result.get("message", AuroraLocale.text("NO SE PUDO CREAR EL ARCHIVO."))
		)
		return
	exported_path = str(result.get("package_path", ""))
	status_label.text = AuroraLocale.text("ARCHIVO CREADO Y VERIFICADO // %s") % exported_path.get_file()
	open_folder_button.disabled = exported_path.is_empty()
	copy_path_button.disabled = exported_path.is_empty()


func _set_actions_disabled(disabled: bool) -> void:
	song_selector.disabled = disabled or songs.is_empty()
	export_button.disabled = disabled or selected_song == null
	close_button.disabled = disabled
	if disabled:
		open_folder_button.disabled = true
		copy_path_button.disabled = true


func _open_export_folder() -> void:
	if exported_path.is_empty():
		return
	OS.shell_open(ProjectSettings.globalize_path(exported_path.get_base_dir()))


func _copy_export_path() -> void:
	if exported_path.is_empty():
		return
	DisplayServer.clipboard_set(ProjectSettings.globalize_path(exported_path))
	status_label.text = AuroraLocale.text("UBICACIÓN COPIADA")


func _safe_file_name(value: String) -> String:
	var safe := value.strip_edges()
	for character in ['<', '>', ':', '"', '/', '\\', '|', '?', '*']:
		safe = safe.replace(character, "_")
	return "nivel_aurora" if safe.is_empty() else safe


func _format_time(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _exit_tree() -> void:
	if export_thread != null:
		export_thread.wait_to_finish()
		export_thread = null
