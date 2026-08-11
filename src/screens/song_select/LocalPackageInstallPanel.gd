extends Control

class_name LocalPackageInstallPanel

const PACKAGE_SERVICE_TYPE := preload(
	"res://src/packages/SongPackageService.gd"
)

signal install_confirmed(package_path: String)
signal close_requested

var package_path := ""
var install_button: Button
var close_button: Button


func setup(
	selected_package_path: String,
	manifest: Dictionary,
	installed_version: String = ""
) -> void:
	package_path = selected_package_path
	_build_interface(manifest, installed_version)


func request_close() -> void:
	close_requested.emit()


func _build_interface(manifest: Dictionary, installed_version: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 110
	process_mode = Node.PROCESS_MODE_ALWAYS

	var shade := ColorRect.new()
	AuroraUi.fill(shade)
	shade.color = Color(0.005, 0.008, 0.025, 0.95)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var margins := AuroraUi.make_margin(220, 90, 220, 90)
	add_child(margins)
	var panel := AuroraUi.make_panel(Color(0.025, 0.03, 0.075, 0.99))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var song: Dictionary = manifest.get("song", {})
	var incoming_version := str(manifest.get("package_version", "1.0.0"))
	var heading := AuroraUi.make_pixel_label(
		AuroraLocale.text(
			"ACTUALIZAR NIVEL" if not installed_version.is_empty() else "INSTALAR NIVEL"
		),
		23
	)
	layout.add_child(heading)
	var explanation := AuroraUi.make_label(
		AuroraLocale.text(
			"REVISA EL CONTENIDO ANTES DE AÑADIRLO A TU BIBLIOTECA."
		),
		15,
		AuroraUi.MUTED
	)
	layout.add_child(explanation)

	_add_detail(layout, "TÍTULO", str(song.get("title", "Paquete Aurora")))
	_add_detail(layout, "ARTISTA", str(song.get("artist", "Aurora Creator")))
	_add_detail(layout, "DURACIÓN", _format_time(float(song.get("duration_seconds", 0.0))))
	_add_detail(layout, "MODOS", _chart_summary(song.get("charts", [])))
	_add_detail(
		layout,
		"VERSIÓN",
		(
			"%s → %s" % [installed_version, incoming_version]
			if not installed_version.is_empty()
			else incoming_version
		)
	)

	var already_installed := (
		not installed_version.is_empty()
		and PACKAGE_SERVICE_TYPE.compare_package_versions(
			incoming_version,
			installed_version
		) <= 0
	)
	var notice := AuroraUi.make_label(
		AuroraLocale.text(
			"ESTA VERSIÓN YA ESTÁ INSTALADA O ES MÁS ANTIGUA."
			if already_installed
			else "AURORA COMPROBARÁ EL TAMAÑO, LAS RUTAS, EL CHART Y LA INTEGRIDAD DE TODOS LOS ARCHIVOS ANTES DE INSTALAR."
		),
		13,
		AuroraUi.GOLD
	)
	layout.add_child(notice)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 14)
	layout.add_child(actions)
	close_button = AuroraUi.make_button(AuroraLocale.text("CANCELAR"))
	close_button.custom_minimum_size = Vector2(210, 54)
	close_button.pressed.connect(request_close)
	actions.add_child(close_button)
	install_button = AuroraUi.make_button(
		AuroraLocale.text(
			"YA INSTALADO"
			if already_installed
			else (
				"ACTUALIZAR NIVEL"
				if not installed_version.is_empty()
				else "INSTALAR NIVEL"
			)
		),
		true
	)
	install_button.custom_minimum_size = Vector2(250, 54)
	install_button.disabled = already_installed
	install_button.pressed.connect(_confirm)
	actions.add_child(install_button)
	install_button.grab_focus()


func _add_detail(parent: VBoxContainer, caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)
	var caption_label := AuroraUi.make_pixel_label(
		AuroraLocale.text(caption),
		10,
		AuroraUi.TEAL
	)
	caption_label.custom_minimum_size = Vector2(210, 38)
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption_label)
	var value_label := AuroraUi.make_label(value, 16)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)


func _chart_summary(charts_value: Variant) -> String:
	if not (charts_value is Array):
		return "—"
	var modes: PackedStringArray = []
	for value in charts_value:
		if value is Dictionary:
			var chart: Dictionary = value
			modes.append("%dK %s %02d" % [
				int(chart.get("key_count", 4)),
				str(chart.get("difficulty", "NORMAL")),
				int(chart.get("difficulty_level", 4)),
			])
	return " · ".join(modes) if not modes.is_empty() else "—"


func _format_time(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _confirm() -> void:
	install_confirmed.emit(package_path)
