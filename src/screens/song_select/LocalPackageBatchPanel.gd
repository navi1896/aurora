extends Control

class_name LocalPackageBatchPanel

signal install_confirmed(paths: PackedStringArray)
signal close_requested

var install_paths := PackedStringArray()
var action_button: Button


func show_selection(items: Array[Dictionary]) -> void:
	install_paths.clear()
	var lines := PackedStringArray()
	for item in items:
		if bool(item.get("installable", false)):
			install_paths.append(str(item.get("path", "")))
		lines.append("%s  //  %s" % [
			str(item.get("name", "")),
			str(item.get("status", "")),
		])
	_build(
		"INSTALAR VARIOS NIVELES",
		AuroraLocale.text("%d archivos seleccionados · %d se instalarán o actualizarán") % [
			items.size(), install_paths.size()
		],
		lines,
		AuroraLocale.text("INSTALAR %d") % install_paths.size()
	)


func show_results(results: Array[Dictionary]) -> void:
	install_paths.clear()
	var lines := PackedStringArray()
	var installed := 0
	var updated := 0
	var skipped := 0
	for item in results:
		var result: Dictionary = item.get("result", {})
		var status := ""
		if bool(result.get("ok", false)):
			if bool(result.get("updated", false)):
				updated += 1
				status = AuroraLocale.text("ACTUALIZADO")
			else:
				installed += 1
				status = AuroraLocale.text("INSTALADO")
		elif str(result.get("error_code", "")) in ["destination_exists", "selection_skipped"]:
			skipped += 1
			status = str(result.get("message", AuroraLocale.text("YA INSTALADO")))
		else:
			status = "ERROR: %s" % str(result.get("message", "Archivo no válido"))
		lines.append("%s  //  %s" % [
			str(item.get("path", "")).get_file(), status
		])
	_build(
		"RESULTADO DE IMPORTACIÓN",
		AuroraLocale.text("%d instalados · %d actualizados · %d omitidos · %d errores") % [
			installed, updated, skipped,
			results.size() - installed - updated - skipped
		],
		lines,
		""
	)


func show_export_results(results: Array[Dictionary]) -> void:
	install_paths.clear()
	var lines := PackedStringArray()
	var exported := 0
	var skipped := 0
	for item in results:
		var result: Dictionary = item.get("result", {})
		var status := ""
		if bool(result.get("ok", false)):
			exported += 1
			status = AuroraLocale.text("EXPORTADO")
		elif str(result.get("error_code", "")) == "destination_exists":
			skipped += 1
			status = AuroraLocale.text("YA EXISTE; NO SE SOBRESCRIBIÓ")
		else:
			status = "ERROR: %s" % str(result.get("message", "No se pudo exportar"))
		lines.append("%s  //  %s" % [
			str(item.get("path", "")).get_file(), status
		])
	_build(
		"RESULTADO DE EXPORTACIÓN",
		AuroraLocale.text("%d exportados · %d omitidos · %d errores") % [
			exported, skipped, results.size() - exported - skipped
		],
		lines,
		""
	)


func request_close() -> void:
	close_requested.emit()


func _build(title: String, summary: String, lines: PackedStringArray, action: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	AuroraUi.fill(shade)
	shade.color = Color(0.005, 0.008, 0.025, 0.95)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var margins := AuroraUi.make_margin(36, 28, 36, 28)
	add_child(margins)
	var panel := AuroraUi.make_panel(Color(0.025, 0.03, 0.075, 0.99))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)
	var heading := AuroraUi.make_pixel_label(AuroraLocale.text(title), 21)
	layout.add_child(heading)
	var summary_label := AuroraUi.make_label(AuroraLocale.text(summary), 16, AuroraUi.TEAL)
	layout.add_child(summary_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for line in lines:
		var label := AuroraUi.make_label(AuroraLocale.text(line), 14, AuroraUi.TEXT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 14)
	layout.add_child(actions)
	var close_button := AuroraUi.make_button(AuroraLocale.text("CERRAR"))
	close_button.custom_minimum_size = Vector2(170, 52)
	close_button.pressed.connect(request_close)
	actions.add_child(close_button)
	if not action.is_empty():
		action_button = AuroraUi.make_button(AuroraLocale.text(action), true)
		action_button.custom_minimum_size = Vector2(230, 52)
		action_button.disabled = install_paths.is_empty()
		action_button.pressed.connect(_confirm)
		actions.add_child(action_button)
		action_button.grab_focus()
	else:
		close_button.grab_focus()


func _confirm() -> void:
	install_confirmed.emit(install_paths)
