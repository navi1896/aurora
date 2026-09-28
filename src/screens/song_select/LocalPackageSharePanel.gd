extends Control

class_name LocalPackageSharePanel

const SHARE_SERVICE_TYPE := preload(
	"res://src/screens/song_select/LocalPackageShareService.gd"
)
const BATCH_PANEL_TYPE := preload(
	"res://src/screens/song_select/LocalPackageBatchPanel.gd"
)

signal close_requested
signal import_requested

var song_manager: SongManager
var settings_manager: SettingsManager
var songs: Array[SongData] = []
var selected_song: SongData
var share_service = SHARE_SERVICE_TYPE.new()
var export_thread: Thread
var exported_path := ""
var exported_is_directory := false
var pending_batch_directory := ""
var batch_report_panel: Control
var song_list: VBoxContainer
var song_search: LineEdit
var song_buttons: Array[Button] = []
var export_view: Control
var import_view: Control
var import_tab_button: Button
var export_tab_button: Button
var import_button: Button
var title_value: Label
var artist_value: Label
var details_value: Label
var files_value: Label
var status_label: Label
var export_button: Button
var export_all_button: Button
var open_folder_button: Button
var copy_path_button: Button
var close_button: Button
var save_dialog: FileDialog
var folder_dialog: FileDialog


func setup(
	manager: SongManager,
	settings: SettingsManager,
	initial_song: SongData = null,
	initial_tab := "export"
) -> void:
	song_manager = manager
	settings_manager = settings
	_build_interface()
	_refresh_songs(initial_song)
	_show_tab(initial_tab)


func request_close() -> void:
	if export_thread != null:
		status_label.text = AuroraLocale.text(
			"ESPERA A QUE TERMINE LA CREACIÓN DEL ARCHIVO."
		)
		return
	if batch_report_panel != null:
		_close_batch_report()
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

	var side_margin := clampi(roundi(get_viewport_rect().size.x * 0.05), 28, 90)
	var top_margin := clampi(roundi(get_viewport_rect().size.y * 0.055), 24, 60)
	var margins := AuroraUi.make_margin(side_margin, top_margin, side_margin, top_margin)
	add_child(margins)
	var panel := AuroraUi.make_panel(Color(0.025, 0.03, 0.075, 0.99))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 13)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := AuroraUi.make_pixel_label(AuroraLocale.text("ARCHIVOS DE CANCIONES"), 22)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	close_button = AuroraUi.make_button(AuroraLocale.text("CERRAR"))
	close_button.custom_minimum_size = Vector2(132, 44)
	close_button.pressed.connect(request_close)
	header.add_child(close_button)

	var intro := AuroraUi.make_label(
		AuroraLocale.text("IMPORTA VARIAS CANCIONES O EXPORTA UNA Y TODAS EN ARCHIVOS .AURORA."),
		14, AuroraUi.MUTED
	)
	layout.add_child(intro)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	layout.add_child(tabs)
	var tab_group := ButtonGroup.new()
	tab_group.allow_unpress = false
	import_tab_button = AuroraUi.make_button(AuroraLocale.text("IMPORTAR"))
	import_tab_button.custom_minimum_size = Vector2(190, 46)
	import_tab_button.toggle_mode = true
	import_tab_button.button_group = tab_group
	import_tab_button.add_theme_stylebox_override(
		"normal", AuroraUi.make_style(Color(0.04, 0.05, 0.12), AuroraUi.VIOLET)
	)
	import_tab_button.add_theme_stylebox_override(
		"pressed", AuroraUi.make_style(Color(0.06, 0.23, 0.29), AuroraUi.TEAL)
	)
	import_tab_button.pressed.connect(_show_tab.bind("import"))
	tabs.add_child(import_tab_button)
	export_tab_button = AuroraUi.make_button(AuroraLocale.text("EXPORTAR"))
	export_tab_button.custom_minimum_size = Vector2(190, 46)
	export_tab_button.toggle_mode = true
	export_tab_button.button_group = tab_group
	export_tab_button.add_theme_stylebox_override(
		"normal", AuroraUi.make_style(Color(0.04, 0.05, 0.12), AuroraUi.VIOLET)
	)
	export_tab_button.add_theme_stylebox_override(
		"pressed", AuroraUi.make_style(Color(0.06, 0.23, 0.29), AuroraUi.TEAL)
	)
	export_tab_button.pressed.connect(_show_tab.bind("export"))
	tabs.add_child(export_tab_button)

	export_view = HBoxContainer.new()
	export_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	export_view.add_theme_constant_override("separation", 18)
	layout.add_child(export_view)
	var library_panel := AuroraUi.make_panel(Color(0.03, 0.045, 0.11, 0.98))
	library_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_panel.size_flags_stretch_ratio = 0.95
	library_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	export_view.add_child(library_panel)
	var library_layout := VBoxContainer.new()
	library_layout.add_theme_constant_override("separation", 12)
	library_panel.add_child(library_layout)
	library_layout.add_child(AuroraUi.make_pixel_label(AuroraLocale.text("TU BIBLIOTECA"), 13, AuroraUi.TEAL))
	song_search = LineEdit.new()
	song_search.custom_minimum_size.y = 42
	song_search.placeholder_text = AuroraLocale.text("BUSCAR TÍTULO O ARTISTA")
	song_search.clear_button_enabled = true
	song_search.text_changed.connect(_filter_songs)
	library_layout.add_child(song_search)
	var song_scroll := ScrollContainer.new()
	song_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	song_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	library_layout.add_child(song_scroll)
	song_list = VBoxContainer.new()
	song_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	song_list.add_theme_constant_override("separation", 6)
	song_scroll.add_child(song_list)

	var export_panel := AuroraUi.make_panel(Color(0.03, 0.045, 0.11, 0.98))
	export_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_panel.size_flags_stretch_ratio = 1.05
	export_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	export_view.add_child(export_panel)
	var export_layout := VBoxContainer.new()
	export_layout.add_theme_constant_override("separation", 12)
	export_panel.add_child(export_layout)
	export_layout.add_child(AuroraUi.make_pixel_label(AuroraLocale.text("EXPORTAR UNA CANCIÓN"), 13, AuroraUi.TEAL))
	var summary_panel := AuroraUi.make_panel(Color(0.04, 0.045, 0.1, 0.98))
	export_layout.add_child(summary_panel)
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 2)
	summary_panel.add_child(summary)
	title_value = _add_summary_row(summary, "TÍTULO")
	artist_value = _add_summary_row(summary, "ARTISTA")
	details_value = _add_summary_row(summary, "CONTENIDO")
	files_value = _add_summary_row(summary, "ARCHIVOS")
	export_button = AuroraUi.make_button(AuroraLocale.text("CREAR ARCHIVO .AURORA"), true)
	export_button.custom_minimum_size = Vector2(0, 52)
	export_button.pressed.connect(_choose_export_path)
	export_layout.add_child(export_button)
	export_layout.add_child(AuroraUi.spacer(7))
	export_layout.add_child(AuroraUi.make_pixel_label(AuroraLocale.text("EXPORTAR TODA LA BIBLIOTECA"), 12, AuroraUi.VIOLET))
	var batch_hint := AuroraUi.make_label(
		AuroraLocale.text("UN ARCHIVO .AURORA POR CADA CANCIÓN EXPORTABLE."),
		14, AuroraUi.MUTED
	)
	export_layout.add_child(batch_hint)
	export_all_button = AuroraUi.make_button(AuroraLocale.text("ELEGIR CARPETA Y EXPORTAR"), true)
	export_all_button.custom_minimum_size = Vector2(0, 52)
	export_all_button.pressed.connect(_choose_batch_export_directory)
	export_layout.add_child(export_all_button)
	var export_spacer := Control.new()
	export_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	export_layout.add_child(export_spacer)
	var output_actions := HBoxContainer.new()
	output_actions.add_theme_constant_override("separation", 10)
	export_layout.add_child(output_actions)
	open_folder_button = AuroraUi.make_button(AuroraLocale.text("ABRIR CARPETA"))
	open_folder_button.custom_minimum_size = Vector2(0, 46)
	open_folder_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_folder_button.disabled = true
	open_folder_button.pressed.connect(_open_export_folder)
	output_actions.add_child(open_folder_button)
	copy_path_button = AuroraUi.make_button(AuroraLocale.text("COPIAR UBICACIÓN"))
	copy_path_button.custom_minimum_size = Vector2(0, 46)
	copy_path_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_path_button.disabled = true
	copy_path_button.pressed.connect(_copy_export_path)
	output_actions.add_child(copy_path_button)

	import_view = AuroraUi.make_panel(Color(0.03, 0.045, 0.11, 0.98))
	import_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(import_view)
	var import_layout := VBoxContainer.new()
	import_layout.add_theme_constant_override("separation", 16)
	import_view.add_child(import_layout)
	import_layout.add_child(AuroraUi.make_pixel_label(AuroraLocale.text("IMPORTAR CANCIONES"), 17, AuroraUi.TEAL))
	import_layout.add_child(AuroraUi.make_label(
		AuroraLocale.text("ELIGE UNO O VARIOS ARCHIVOS .AURORA. REVISARÁS LOS NIVELES ANTES DE INSTALARLOS."),
		16, AuroraUi.MUTED
	))
	var import_columns := HBoxContainer.new()
	import_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	import_columns.add_theme_constant_override("separation", 18)
	import_layout.add_child(import_columns)
	var choose_panel := AuroraUi.make_panel(Color(0.04, 0.07, 0.13, 1.0))
	choose_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_columns.add_child(choose_panel)
	var choose_layout := VBoxContainer.new()
	choose_layout.add_theme_constant_override("separation", 16)
	choose_panel.add_child(choose_layout)
	choose_layout.add_child(AuroraUi.make_pixel_label(
		AuroraLocale.text("01  SELECCIONAR ARCHIVOS"), 13, AuroraUi.TEAL
	))
	choose_layout.add_child(AuroraUi.make_label(
		AuroraLocale.text("PUEDES ELEGIR VARIOS PAQUETES .AURORA EN EL EXPLORADOR DE ARCHIVOS."),
		15, AuroraUi.MUTED
	))
	import_button = AuroraUi.make_button(AuroraLocale.text("SELECCIONAR ARCHIVOS .AURORA"), true)
	import_button.custom_minimum_size = Vector2(0, 58)
	import_button.pressed.connect(func() -> void: import_requested.emit())
	choose_layout.add_child(import_button)
	choose_layout.add_child(AuroraUi.make_label(
		AuroraLocale.text("UN ARCHIVO O TODA UNA SELECCIÓN EN LA MISMA OPERACIÓN."),
		14, AuroraUi.MUTED
	))
	var review_panel := AuroraUi.make_panel(Color(0.04, 0.07, 0.13, 1.0))
	review_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_columns.add_child(review_panel)
	var review_layout := VBoxContainer.new()
	review_layout.add_theme_constant_override("separation", 18)
	review_panel.add_child(review_layout)
	review_layout.add_child(AuroraUi.make_pixel_label(
		AuroraLocale.text("02  REVISAR E INSTALAR"), 13, AuroraUi.VIOLET
	))
	review_layout.add_child(AuroraUi.make_label(
		AuroraLocale.text("AURORA MOSTRARÁ QUÉ CANCIONES ESTÁN LISTAS, CUÁLES YA EXISTEN Y SI ALGÚN ARCHIVO TIENE UN ERROR."),
		15, AuroraUi.MUTED
	))
	review_layout.add_child(AuroraUi.make_label(
		AuroraLocale.text("PODRÁS CONFIRMAR LAS INSTALABLES ANTES DE CAMBIAR TU BIBLIOTECA."),
		15, AuroraUi.MUTED
	))

	status_label = AuroraUi.make_pixel_label(AuroraLocale.text("SELECCIONA UNA ACCIÓN"), 10, AuroraUi.TEAL)
	status_label.custom_minimum_size.y = 28
	layout.add_child(status_label)
	layout.add_child(AuroraUi.make_label(
		AuroraLocale.text("LOS ARCHIVOS SE GUARDAN EN TU EQUIPO; AURORA NO LOS SUBE A INTERNET."),
		12, AuroraUi.GOLD
	))

	save_dialog = FileDialog.new()
	save_dialog.name = "SharePackageDialog"
	save_dialog.title = AuroraLocale.text("GUARDAR NIVEL .AURORA")
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.use_native_dialog = true
	save_dialog.filters = PackedStringArray(["*.aurora ; Aurora Song Package"])
	save_dialog.file_selected.connect(_begin_export)
	add_child(save_dialog)
	folder_dialog = FileDialog.new()
	folder_dialog.name = "ShareAllPackagesFolderDialog"
	folder_dialog.title = AuroraLocale.text("ELEGIR CARPETA PARA EXPORTAR CANCIONES")
	folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.use_native_dialog = true
	folder_dialog.dir_selected.connect(_begin_batch_export)
	add_child(folder_dialog)


func _show_tab(tab_name: String) -> void:
	var show_import := tab_name == "import"
	import_view.visible = show_import
	export_view.visible = not show_import
	import_tab_button.set_pressed_no_signal(show_import)
	export_tab_button.set_pressed_no_signal(not show_import)
	if show_import:
		status_label.text = AuroraLocale.text("ELIGE ARCHIVOS PARA IMPORTAR")
		import_button.grab_focus()
	elif not song_buttons.is_empty():
		status_label.text = AuroraLocale.text("LISTO PARA CREAR EL ARCHIVO")
		song_buttons[0].grab_focus()


func _filter_songs(query: String) -> void:
	var normalized := query.strip_edges().to_lower()
	for index in range(song_buttons.size()):
		var song := songs[index]
		song_buttons[index].visible = (
			normalized.is_empty()
			or (song.title + " " + song.artist).to_lower().contains(normalized)
		)


func _add_summary_row(parent: VBoxContainer, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var label := AuroraUi.make_pixel_label(
		AuroraLocale.text(caption),
		10,
		AuroraUi.TEAL
	)
	label.custom_minimum_size = Vector2(130, 38)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var value := AuroraUi.make_label("—", 16)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	return value


func _refresh_songs(initial_song: SongData) -> void:
	songs.clear()
	song_buttons.clear()
	for child in song_list.get_children():
		child.queue_free()
	var selection_group := ButtonGroup.new()
	selection_group.allow_unpress = false
	for song in song_manager.get_all_songs():
		if song_manager.can_share_song_package(song):
			songs.append(song)
			var index := songs.size() - 1
			var button := AuroraUi.make_button("%s  //  %s" % [song.title, song.artist])
			button.custom_minimum_size = Vector2(0, 46)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.toggle_mode = true
			button.button_group = selection_group
			button.add_theme_stylebox_override(
				"normal", AuroraUi.make_style(Color(0.04, 0.05, 0.12), Color(0.28, 0.17, 0.5))
			)
			button.add_theme_stylebox_override(
				"hover", AuroraUi.make_style(Color(0.07, 0.1, 0.18), AuroraUi.VIOLET)
			)
			button.add_theme_stylebox_override(
				"pressed", AuroraUi.make_style(Color(0.06, 0.19, 0.24), AuroraUi.TEAL)
			)
			button.add_theme_stylebox_override(
				"focus", AuroraUi.make_style(Color(0.06, 0.19, 0.24), AuroraUi.TEAL)
			)
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			AuroraUi.apply_pixel_font(button, 10)
			button.pressed.connect(_on_song_selected.bind(index))
			song_list.add_child(button)
			song_buttons.append(button)
	if songs.is_empty():
		selected_song = null
		song_list.add_child(AuroraUi.make_label(
			AuroraLocale.text("NO HAY NIVELES PARA COMPARTIR"), 14, AuroraUi.MUTED
		))
		export_button.disabled = true
		export_all_button.disabled = true
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
	song_buttons[selected_index].set_pressed_no_signal(true)
	_load_song(songs[selected_index])


func _on_song_selected(index: int) -> void:
	if index >= 0 and index < songs.size():
		song_buttons[index].set_pressed_no_signal(true)
		_load_song(songs[index])


func _load_song(song: SongData) -> void:
	selected_song = song
	exported_path = ""
	exported_is_directory = false
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


func _choose_batch_export_directory() -> void:
	if songs.is_empty() or export_thread != null:
		return
	var last_directory := str(
		settings_manager.get_setting("last_package_export_directory", "")
	).strip_edges()
	if not last_directory.is_empty() and DirAccess.dir_exists_absolute(last_directory):
		folder_dialog.current_dir = last_directory
	folder_dialog.popup_centered_ratio(0.72)


func _begin_batch_export(directory: String) -> void:
	if songs.is_empty() or export_thread != null or not DirAccess.dir_exists_absolute(directory):
		return
	var entries: Array[Dictionary] = []
	var used_names: Dictionary = {}
	for song in songs:
		var descriptor := song_manager.make_song_package_share_descriptor(song)
		if descriptor.is_empty():
			continue
		var base_name := _safe_file_name(song.title)
		var file_name := base_name
		var suffix := 2
		while used_names.has(file_name.to_lower()):
			file_name = "%s (%d)" % [base_name, suffix]
			suffix += 1
		used_names[file_name.to_lower()] = true
		entries.append({
			"descriptor": descriptor,
			"path": directory.path_join("%s.aurora" % file_name),
		})
	if entries.is_empty():
		status_label.text = AuroraLocale.text("NO HAY NIVELES EXPORTABLES.")
		return
	settings_manager.set_setting("last_package_export_directory", directory, false)
	pending_batch_directory = directory
	export_thread = Thread.new()
	_set_actions_disabled(true)
	status_label.text = AuroraLocale.text("EXPORTANDO %d CANCIONES, UNA POR ARCHIVO...") % entries.size()
	var start_error := export_thread.start(
		Callable(share_service, "export_batch").bind(entries)
	)
	if start_error != OK:
		export_thread = null
		pending_batch_directory = ""
		_set_actions_disabled(false)
		status_label.text = AuroraLocale.text("NO SE PUDO INICIAR LA EXPORTACIÓN.")


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
	if bool(result.get("batch", false)):
		exported_path = pending_batch_directory
		pending_batch_directory = ""
		exported_is_directory = true
		status_label.text = AuroraLocale.text("%d EXPORTADOS · %d OMITIDOS · %d ERRORES") % [
			int(result.get("exported", 0)),
			int(result.get("skipped", 0)),
			int(result.get("failed", 0)),
		]
		open_folder_button.disabled = exported_path.is_empty()
		copy_path_button.disabled = exported_path.is_empty()
		batch_report_panel = BATCH_PANEL_TYPE.new()
		batch_report_panel.name = "LocalPackageBatchExportResults"
		batch_report_panel.z_index = 120
		batch_report_panel.close_requested.connect(_close_batch_report)
		add_child(batch_report_panel)
		var results: Array[Dictionary] = []
		for item in result.get("results", []):
			results.append(item)
		batch_report_panel.show_export_results(results)
		return
	if not bool(result.get("ok", false)):
		status_label.text = str(
			result.get("message", AuroraLocale.text("NO SE PUDO CREAR EL ARCHIVO."))
		)
		return
	exported_path = str(result.get("package_path", ""))
	exported_is_directory = false
	status_label.text = AuroraLocale.text("ARCHIVO CREADO Y VERIFICADO // %s") % exported_path.get_file()
	open_folder_button.disabled = exported_path.is_empty()
	copy_path_button.disabled = exported_path.is_empty()


func _set_actions_disabled(disabled: bool) -> void:
	for button in song_buttons:
		button.disabled = disabled
	song_search.editable = not disabled
	import_tab_button.disabled = disabled
	export_tab_button.disabled = disabled
	import_button.disabled = disabled
	export_button.disabled = disabled or selected_song == null
	export_all_button.disabled = disabled or songs.is_empty()
	close_button.disabled = disabled
	if disabled:
		open_folder_button.disabled = true
		copy_path_button.disabled = true


func _close_batch_report() -> void:
	if batch_report_panel == null:
		return
	batch_report_panel.queue_free()
	batch_report_panel = null
	open_folder_button.grab_focus()


func _open_export_folder() -> void:
	if exported_path.is_empty():
		return
	var directory := exported_path if exported_is_directory else exported_path.get_base_dir()
	OS.shell_open(ProjectSettings.globalize_path(directory))


func _copy_export_path() -> void:
	if exported_path.is_empty():
		return
	DisplayServer.clipboard_set(ProjectSettings.globalize_path(exported_path))
	status_label.text = AuroraLocale.text("UBICACIÓN COPIADA")


func _safe_file_name(value: String) -> String:
	var safe := value.strip_edges()
	for character in ['<', '>', ':', '"', '/', '\\', '|', '?', '*']:
		safe = safe.replace(character, "_")
	while safe.ends_with("."):
		safe = safe.trim_suffix(".").strip_edges()
	if safe.length() > 100:
		safe = safe.substr(0, 100).strip_edges()
	var reserved := ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
	if safe.is_empty() or safe.get_slice(".", 0).to_upper() in reserved:
		return "nivel_aurora"
	return safe


func _format_time(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _exit_tree() -> void:
	if export_thread != null:
		export_thread.wait_to_finish()
		export_thread = null
