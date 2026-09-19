extends Control

class_name CommunityCatalogPanel

const ONLINE_MANIFEST_SERVICE := preload("res://src/online/OnlineManifestService.gd")
const COMMUNITY_PUBLISH_PANEL := preload(
	"res://src/screens/song_select/CommunityPublishPanel.gd"
)

signal close_requested
signal install_requested(package_path: String)

var online_manager: Node
var song_manager: SongManager
var status_label: Label
var entries_container: VBoxContainer
var refresh_button: Button
var publish_button: Button
var close_button: Button
var catalog_scroll: ScrollContainer
var footer_label: Label
var publish_panel: CommunityPublishPanel
var showing_publish := false
var active_download_id := ""
var download_buttons: Dictionary = {}


func setup(
	online: Node,
	songs: SongManager,
	initial_song: SongData = null
) -> void:
	online_manager = online
	song_manager = songs
	_build_interface(initial_song)
	online_manager.catalog_received.connect(_on_catalog_received)
	online_manager.package_download_progress.connect(_on_package_download_progress)
	online_manager.package_download_finished.connect(_on_package_download_finished)
	request_refresh()


func request_refresh() -> void:
	if online_manager == null:
		return
	status_label.text = AuroraLocale.text("CARGANDO CATÁLOGO...")
	refresh_button.disabled = true
	if online_manager.request_catalog() != OK:
		status_label.text = AuroraLocale.text("LA CONSULTA YA ESTÁ EN CURSO")


func notify_install_started() -> void:
	status_label.text = AuroraLocale.text("VALIDANDO E INSTALANDO PAQUETE...")
	_set_actions_disabled(true)


func notify_install_finished(ok: bool, message: String) -> void:
	status_label.text = message
	active_download_id = ""
	_set_actions_disabled(false)
	_refresh_entry_states()


func _build_interface(initial_song: SongData) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var shade := ColorRect.new()
	AuroraUi.fill(shade)
	shade.color = Color(0.005, 0.008, 0.025, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var margins := AuroraUi.make_margin(150, 80, 150, 80)
	add_child(margins)
	var panel := AuroraUi.make_panel(Color(0.025, 0.03, 0.075, 0.99))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var title := AuroraUi.make_pixel_label(AuroraLocale.text("COMUNIDAD AURORA"), 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	refresh_button = AuroraUi.make_button(AuroraLocale.text("ACTUALIZAR LISTA"))
	refresh_button.custom_minimum_size = Vector2(210, 48)
	refresh_button.pressed.connect(request_refresh)
	header.add_child(refresh_button)
	publish_button = AuroraUi.make_button(AuroraLocale.text("PUBLICAR"), true)
	publish_button.custom_minimum_size = Vector2(250, 48)
	publish_button.pressed.connect(_toggle_publish_view)
	header.add_child(publish_button)
	close_button = AuroraUi.make_button(AuroraLocale.text("CERRAR"))
	close_button.custom_minimum_size = Vector2(150, 48)
	close_button.pressed.connect(request_close)
	header.add_child(close_button)

	var explanation := AuroraUi.make_label(
		AuroraLocale.text(
			"DESCARGA CHARTS REVISADOS O PREPARA UNA CANCIÓN DE TU BIBLIOTECA PARA REVISIÓN. "
			+ "AURORA VERIFICA TAMAÑO Y SHA-256 ANTES DE INSTALAR."
		),
		15,
		AuroraUi.MUTED
	)
	layout.add_child(explanation)
	status_label = AuroraUi.make_pixel_label(AuroraLocale.text("CARGANDO CATÁLOGO..."), 12, AuroraUi.TEAL)
	status_label.custom_minimum_size = Vector2(0, 28)
	layout.add_child(status_label)

	catalog_scroll = ScrollContainer.new()
	catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(catalog_scroll)
	entries_container = VBoxContainer.new()
	entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_container.add_theme_constant_override("separation", 10)
	catalog_scroll.add_child(entries_container)

	publish_panel = COMMUNITY_PUBLISH_PANEL.new()
	publish_panel.visible = false
	layout.add_child(publish_panel)
	publish_panel.setup(song_manager, initial_song)

	footer_label = AuroraUi.make_label(
		AuroraLocale.text(
			"DESCARGA E INSTALA PAQUETES REVISADOS SIN SALIR DE AURORA."
		),
		13,
		AuroraUi.MUTED
	)
	layout.add_child(footer_label)


func _on_catalog_received(result: Dictionary) -> void:
	refresh_button.disabled = false
	if not bool(result.get("ok", false)):
		status_label.text = AuroraLocale.text("NO SE PUDO CARGAR EL CATÁLOGO: %s") % str(result.get("message", "ERROR"))
		return
	var entries: Array = result.get("entries", [])
	_render_entries(entries)
	status_label.text = (
		AuroraLocale.text("CATÁLOGO VACÍO // TODAVÍA NO HAY CANCIONES PUBLICADAS")
		if entries.is_empty()
		else AuroraLocale.text("%d CANCIONES DISPONIBLES") % entries.size()
	)


func _render_entries(entries: Array) -> void:
	for child in entries_container.get_children():
		entries_container.remove_child(child)
		child.queue_free()
	download_buttons.clear()
	if entries.is_empty():
		var empty := AuroraUi.make_label(
			AuroraLocale.text("CUANDO SE APRUEBE EL PRIMER PAQUETE APARECERÁ AQUÍ."),
			18,
			AuroraUi.MUTED
		)
		empty.custom_minimum_size = Vector2(0, 120)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entries_container.add_child(empty)
		return
	for value in entries:
		if value is Dictionary:
			_add_entry_row(value)


func _add_entry_row(entry: Dictionary) -> void:
	var row := AuroraUi.make_panel(Color(0.04, 0.045, 0.1, 0.98))
	row.custom_minimum_size = Vector2(0, 104)
	entries_container.add_child(row)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	row.add_child(content)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 6)
	content.add_child(copy)
	var title := AuroraUi.make_pixel_label(
		"%s  //  v%s" % [entry.get("title", ""), entry.get("package_version", "")],
		15
	)
	copy.add_child(title)
	var meta := AuroraUi.make_label(
		"%s  ·  %s  ·  chart: %s" % [
			entry.get("artist", ""),
			entry.get("license", "LICENCIA NO INDICADA"),
			entry.get("author", ""),
		],
		14,
		AuroraUi.MUTED
	)
	copy.add_child(meta)
	var description := AuroraUi.make_label(str(entry.get("description", "")), 13, AuroraUi.MUTED)
	description.max_lines_visible = 2
	copy.add_child(description)
	var button := AuroraUi.make_button("", true)
	button.custom_minimum_size = Vector2(230, 56)
	button.pressed.connect(_download_entry.bind(entry))
	content.add_child(button)
	var package_id := str(entry.get("package_id", ""))
	download_buttons[package_id] = {"button": button, "entry": entry}
	_update_entry_button(package_id)


func _download_entry(entry: Dictionary) -> void:
	if not active_download_id.is_empty():
		return
	active_download_id = str(entry.get("package_id", ""))
	_set_actions_disabled(true)
	status_label.text = AuroraLocale.text("INICIANDO DESCARGA...")
	if online_manager.download_package(entry) != OK:
		active_download_id = ""
		_set_actions_disabled(false)


func _on_package_download_progress(downloaded: int, total: int) -> void:
	if active_download_id.is_empty() or total <= 0:
		return
	var percent := clampi(roundi(float(downloaded) * 100.0 / float(total)), 0, 100)
	status_label.text = AuroraLocale.text("DESCARGANDO // %d%%") % percent


func _on_package_download_finished(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		status_label.text = AuroraLocale.text("DESCARGA RECHAZADA: %s") % str(result.get("message", "ERROR"))
		active_download_id = ""
		_set_actions_disabled(false)
		return
	var path := str(result.get("package_path", ""))
	status_label.text = AuroraLocale.text("DESCARGA VERIFICADA // INSTALANDO...")
	install_requested.emit(path)


func _refresh_entry_states() -> void:
	for package_id in download_buttons:
		_update_entry_button(str(package_id))


func _update_entry_button(package_id: String) -> void:
	var record: Dictionary = download_buttons.get(package_id, {})
	var button := record.get("button") as Button
	var entry: Dictionary = record.get("entry", {})
	if button == null:
		return
	var installed_version := _installed_version(package_id)
	var remote_version := str(entry.get("package_version", "0.0.0"))
	if installed_version.is_empty():
		button.text = AuroraLocale.text("DESCARGAR")
	else:
		var comparison: int = ONLINE_MANIFEST_SERVICE.compare_versions(remote_version, installed_version)
		button.text = (
			AuroraLocale.text("ACTUALIZAR")
			if comparison > 0
			else AuroraLocale.text("INSTALADA v%s") % installed_version
		)
		button.disabled = comparison <= 0


func _installed_version(package_id: String) -> String:
	if song_manager == null:
		return ""
	for song in song_manager.get_all_songs():
		if str(song.song_id) == "package_%s" % package_id:
			return song.package_version
	return ""


func _set_actions_disabled(disabled: bool) -> void:
	refresh_button.disabled = disabled
	publish_button.disabled = disabled
	if publish_panel != null:
		publish_panel.set_actions_disabled(disabled)
	for record_value in download_buttons.values():
		if record_value is Dictionary:
			var button := (record_value as Dictionary).get("button") as Button
			if button != null:
				button.disabled = disabled
	if not disabled:
		_refresh_entry_states()


func _toggle_publish_view() -> void:
	showing_publish = not showing_publish
	catalog_scroll.visible = not showing_publish
	status_label.visible = not showing_publish
	refresh_button.visible = not showing_publish
	publish_panel.visible = showing_publish
	publish_button.text = AuroraLocale.text(
		"VER DESCARGAS" if showing_publish else "PUBLICAR"
	)
	footer_label.text = AuroraLocale.text(
		"SELECCIONA UNA CANCIÓN Y AURORA COMPLETARÁ LOS ARCHIVOS AUTOMÁTICAMENTE."
		if showing_publish
		else "DESCARGA E INSTALA PAQUETES REVISADOS SIN SALIR DE AURORA."
	)


func request_close() -> void:
	if publish_panel != null and publish_panel.is_busy():
		status_label.visible = true
		status_label.text = AuroraLocale.text("ESPERA A QUE TERMINE LA PREPARACIÓN")
	elif active_download_id.is_empty():
		close_requested.emit()
	else:
		status_label.text = AuroraLocale.text("ESPERA A QUE TERMINE LA DESCARGA")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()
