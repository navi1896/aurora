extends VBoxContainer

signal sections_changed(sections: Array)
signal seek_requested(seconds: float)

var sections: Array[Dictionary] = []
var duration := 120.0
var heading: Button
var body: VBoxContainer
var section_list: ItemList
var start_spin: SpinBox
var end_spin: SpinBox
var update_button: Button
var remove_button: Button
var message: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	heading = AuroraUi.make_button(AuroraLocale.text("TRAMOS DE CINEMÁTICA"))
	heading.custom_minimum_size = Vector2(0, 40)
	AuroraUi.apply_pixel_font(heading, 8)
	heading.toggle_mode = true
	add_child(heading)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	body.hide()
	heading.toggled.connect(func(open: bool) -> void: body.visible = open)
	var help := AuroraUi.make_label(AuroraLocale.text(
		"Oculta la pista central entre estos tiempos. El video continúa y la pista vuelve antes de las notas. Los tramos se marcan en dorado en la línea de tiempo."
	), 13, AuroraUi.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(help)
	section_list = ItemList.new()
	section_list.name = "SectionList"
	section_list.custom_minimum_size.y = 88
	section_list.add_theme_font_size_override("font_size", 14)
	section_list.item_selected.connect(_select_section)
	body.add_child(section_list)
	start_spin = _time_control("INICIO (s)")
	end_spin = _time_control("FIN (s)")
	end_spin.value = 5.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)
	_button(row, "AÑADIR", _add_section)
	update_button = _button(row, "APLICAR", _update_section)
	remove_button = _button(row, "QUITAR", _remove_section)
	_button(body, "VER INICIO", func() -> void: seek_requested.emit(start_spin.value))
	message = AuroraUi.make_label("", 13, AuroraUi.CORAL)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(message)
	set_sections(sections, duration)


func _time_control(title: String) -> SpinBox:
	var row := HBoxContainer.new()
	body.add_child(row)
	var label := AuroraUi.make_label(AuroraLocale.text(title), 14, AuroraUi.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 0.0
	spin.max_value = duration
	spin.step = 0.01
	spin.custom_minimum_size = Vector2(150, 34)
	row.add_child(spin)
	return spin


func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := AuroraUi.make_button(AuroraLocale.text(title))
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AuroraUi.apply_pixel_font(button, 8)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func set_sections(value: Array, total_seconds: float) -> void:
	sections = ChartData.CINEMATICS.normalize(value)
	duration = maxf(total_seconds, 1.0)
	if section_list == null:
		return
	heading.text = "%s (%d)" % [AuroraLocale.text("TRAMOS DE CINEMÁTICA"), sections.size()]
	var selected := _selected_index()
	section_list.clear()
	for section in sections:
		section_list.add_item("%s — %s" % [_time_text(float(section.start)), _time_text(float(section.end))])
	if selected >= 0 and selected < sections.size():
		section_list.select(selected)
	start_spin.max_value = duration
	end_spin.max_value = duration
	update_button.disabled = _selected_index() < 0
	remove_button.disabled = _selected_index() < 0


func _time_text(seconds: float) -> String:
	return "%02d:%05.2f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]


func _selected_index() -> int:
	var selected := section_list.get_selected_items()
	return int(selected[0]) if not selected.is_empty() else -1


func _select_section(index: int) -> void:
	start_spin.value = float(sections[index].start)
	end_spin.value = float(sections[index].end)
	update_button.disabled = false
	remove_button.disabled = false


func _valid_input() -> bool:
	if end_spin.value - start_spin.value < 0.7 or end_spin.value > duration:
		message.text = AuroraLocale.text("El tramo debe durar al menos 0.7 s y quedar dentro de la canción.")
		return false
	message.text = ""
	return true


func _add_section() -> void:
	if not _valid_input():
		return
	var updated := sections.duplicate(true)
	updated.append({"start": start_spin.value, "end": end_spin.value})
	sections_changed.emit(ChartData.CINEMATICS.normalize(updated))


func _update_section() -> void:
	var index := _selected_index()
	if index < 0 or not _valid_input():
		return
	var updated := sections.duplicate(true)
	updated[index] = {"start": start_spin.value, "end": end_spin.value}
	sections_changed.emit(ChartData.CINEMATICS.normalize(updated))


func _remove_section() -> void:
	var index := _selected_index()
	if index < 0:
		return
	var updated := sections.duplicate(true)
	updated.remove_at(index)
	sections_changed.emit(updated)
