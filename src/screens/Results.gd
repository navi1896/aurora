extends Control

class_name Results

var scene_manager: SceneManager
var game_manager: GameManager
var input_manager: InputManager
var buttons: Array[Button] = []
var actions: Array[String] = []
var selected_button := 0
var new_record_label: Label


func _ready() -> void:
	AuroraUi.fill(self)
	var managers := get_tree().current_scene.get_node("Managers")
	scene_manager = managers.get_node("SceneManager") as SceneManager
	game_manager = managers.get_node("GameManager") as GameManager
	input_manager = managers.get_node("InputManager") as InputManager
	setup_ui()
	update_button_selection()


func setup_ui() -> void:
	AuroraUi.clear(self)
	buttons.clear()
	actions.clear()
	new_record_label = null
	_build_background()
	_build_header()
	_build_result_card()
	_build_actions()
	_build_footer()


func _build_background() -> void:
	AuroraUi.add_background(self)
	if game_manager.current_song != null and game_manager.current_song.cover != null:
		var cover := TextureRect.new()
		AuroraUi.fill(cover)
		cover.texture = game_manager.current_song.cover
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cover.modulate = Color(0.48, 0.50, 0.66, 1.0)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cover)

	var wash := ColorRect.new()
	AuroraUi.fill(wash)
	wash.color = Color(0.002, 0.004, 0.020, 0.72)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var top_glow := ColorRect.new()
	top_glow.anchor_right = 1.0
	top_glow.offset_bottom = 8.0
	top_glow.color = AuroraUi.VIOLET
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_glow)

	var bottom_shade := ColorRect.new()
	bottom_shade.anchor_top = 0.78
	bottom_shade.anchor_right = 1.0
	bottom_shade.anchor_bottom = 1.0
	bottom_shade.color = Color(0.002, 0.004, 0.018, 0.80)
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_shade)


func _build_header() -> void:
	var header := HBoxContainer.new()
	header.anchor_left = 0.05
	header.anchor_top = 0.04
	header.anchor_right = 0.95
	header.anchor_bottom = 0.12
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	var title := AuroraUi.make_pixel_label(AuroraLocale.text("RESULTADOS"), 24, AuroraUi.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_box.add_child(title)
	var subtitle := AuroraUi.make_pixel_label("AURORA // PERFORMANCE LINK", 8, AuroraUi.TEAL)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_box.add_child(subtitle)

	var song_title := AuroraLocale.text("PRÁCTICA DE ENTRADA")
	var song_artist := "AURORA PROJECT"
	if game_manager.current_song != null:
		song_title = game_manager.current_song.title.to_upper()
		song_artist = game_manager.current_song.artist.to_upper()
	var song_box := VBoxContainer.new()
	song_box.custom_minimum_size.x = 520.0
	header.add_child(song_box)
	var song := AuroraUi.make_pixel_label(song_title, 13, AuroraUi.TEXT)
	song.autowrap_mode = TextServer.AUTOWRAP_OFF
	song.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	song.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	song_box.add_child(song)
	var artist := AuroraUi.make_pixel_label(song_artist, 8, AuroraUi.MUTED)
	artist.autowrap_mode = TextServer.AUTOWRAP_OFF
	artist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	song_box.add_child(artist)


func _build_result_card() -> void:
	var result := game_manager.last_result
	var accuracy := float(result.get("accuracy", 0.0))
	var rank := _get_rank(accuracy, int(result.get("miss", 0)))
	var rank_color := _get_rank_color(rank)

	var card := PanelContainer.new()
	card.anchor_left = 0.15
	card.anchor_top = 0.16
	card.anchor_right = 0.85
	card.anchor_bottom = 0.72
	var card_style := AuroraUi.make_style(
		Color(0.006, 0.010, 0.032, 0.91),
		Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.72),
		0
	)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.content_margin_left = 48.0
	card_style.content_margin_top = 34.0
	card_style.content_margin_right = 48.0
	card_style.content_margin_bottom = 34.0
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 44)
	card.add_child(body)

	var rank_box := VBoxContainer.new()
	rank_box.custom_minimum_size.x = 390.0
	rank_box.alignment = BoxContainer.ALIGNMENT_CENTER
	rank_box.add_theme_constant_override("separation", 8)
	body.add_child(rank_box)

	var clear_status := _get_clear_status(result)
	var complete := AuroraUi.make_pixel_label(
		clear_status,
		10,
		_get_clear_status_color(clear_status)
	)
	complete.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_box.add_child(complete)
	if bool(game_manager.last_record_update.get("is_new_record", false)):
		new_record_label = AuroraUi.make_pixel_label(
			AuroraLocale.text("NUEVO RÉCORD PERSONAL"),
			10,
			AuroraUi.GOLD
		)
		new_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_box.add_child(new_record_label)

	var rank_label := AuroraUi.make_pixel_label(rank, 128, rank_color)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.94))
	rank_label.add_theme_constant_override("shadow_offset_x", 6)
	rank_label.add_theme_constant_override("shadow_offset_y", 6)
	rank_box.add_child(rank_label)

	var accuracy_label := AuroraUi.make_pixel_label("%.2f%%" % accuracy, 24, AuroraUi.TEXT)
	accuracy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_box.add_child(accuracy_label)

	var mode_label := AuroraUi.make_pixel_label(str(result.get("mode", "4K")), 10, AuroraUi.VIOLET)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_box.add_child(mode_label)

	var divider := VSeparator.new()
	divider.modulate = Color(AuroraUi.TEAL.r, AuroraUi.TEAL.g, AuroraUi.TEAL.b, 0.44)
	body.add_child(divider)

	var data_box := VBoxContainer.new()
	data_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_box.alignment = BoxContainer.ALIGNMENT_CENTER
	data_box.add_theme_constant_override("separation", 14)
	body.add_child(data_box)

	var data_title := AuroraUi.make_pixel_label(
		AuroraLocale.text("DATOS DE RENDIMIENTO"),
		10,
		AuroraUi.VIOLET
	)
	data_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	data_box.add_child(data_title)
	_add_stat(
		data_box,
		AuroraLocale.text("PUNTUACIÓN"),
		"%07d" % int(result.get("score", 0)),
		AuroraUi.GOLD,
		24
	)
	_add_rule(data_box)

	var judgments := GridContainer.new()
	judgments.columns = 2
	judgments.add_theme_constant_override("h_separation", 42)
	judgments.add_theme_constant_override("v_separation", 14)
	data_box.add_child(judgments)
	_add_stat_cell(judgments, AuroraLocale.text("PERFECTO"), str(result.get("perfect", 0)), AuroraUi.TEAL)
	_add_stat_cell(judgments, AuroraLocale.text("GENIAL"), str(result.get("great", 0)), AuroraUi.GOLD)
	_add_stat_cell(judgments, AuroraLocale.text("BIEN"), str(result.get("good", 0)), AuroraUi.VIOLET)
	_add_stat_cell(judgments, AuroraLocale.text("FALLO"), str(result.get("miss", 0)), AuroraUi.CORAL)

	_add_rule(data_box)
	_add_stat(data_box, AuroraLocale.text("COMBO MÁXIMO"), str(result.get("max_combo", 0)), AuroraUi.TEXT)
	_add_timing_stat(data_box, result)
	_add_stat(
		data_box,
		AuroraLocale.text("TOTAL DE NOTAS"),
		str(result.get("total_notes", 0)),
		AuroraUi.MUTED
	)


func _build_actions() -> void:
	var action_row := HBoxContainer.new()
	action_row.anchor_left = 0.20
	action_row.anchor_top = 0.77
	action_row.anchor_right = 0.80
	action_row.anchor_bottom = 0.86
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 16)
	add_child(action_row)

	var retry := AuroraUi.make_button(AuroraLocale.text("REINTENTAR"), true)
	retry.pressed.connect(_on_button_pressed.bind("retry"))
	var return_action := "editor" if game_manager.editor_test_active else "select"
	var select := AuroraUi.make_button(
		AuroraLocale.text("VOLVER AL EDITOR")
		if game_manager.editor_test_active
		else AuroraLocale.text("BIBLIOTECA")
	)
	select.pressed.connect(_on_button_pressed.bind(return_action))
	var menu := AuroraUi.make_button(AuroraLocale.text("MENÚ PRINCIPAL"))
	menu.pressed.connect(_on_button_pressed.bind("menu"))

	for data in [[retry, "retry"], [select, return_action], [menu, "menu"]]:
		var button := data[0] as Button
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(250.0, 62.0)
		AuroraUi.apply_pixel_font(button, 10)
		action_row.add_child(button)
		buttons.append(button)
		actions.append(data[1])
		button.focus_entered.connect(
			_on_result_button_focused.bind(buttons.size() - 1)
		)


func _build_footer() -> void:
	var left_hint := AuroraUi.make_pixel_label(
		AuroraLocale.text("← → / D-PAD  SELECCIONAR    ENTER / %s  CONFIRMAR")
		% input_manager.get_controller_action_label("confirm"),
		8,
		AuroraUi.MUTED
	)
	left_hint.anchor_left = 0.04
	left_hint.anchor_top = 0.93
	left_hint.anchor_right = 0.55
	left_hint.anchor_bottom = 0.97
	left_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	left_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_hint)

	var right_hint := AuroraUi.make_pixel_label(
		(
			AuroraLocale.text("ESC / %s  VOLVER AL EDITOR")
			% input_manager.get_controller_action_label("back")
			if game_manager.editor_test_active
			else AuroraLocale.text("ESC / %s  BIBLIOTECA")
			% input_manager.get_controller_action_label("back")
		),
		8,
		AuroraUi.MUTED
	)
	right_hint.anchor_left = 0.70
	right_hint.anchor_top = 0.93
	right_hint.anchor_right = 0.96
	right_hint.anchor_bottom = 0.97
	right_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	right_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_hint)


func _add_rule(parent: VBoxContainer) -> void:
	var rule := HSeparator.new()
	rule.modulate = Color(AuroraUi.VIOLET.r, AuroraUi.VIOLET.g, AuroraUi.VIOLET.b, 0.42)
	parent.add_child(rule)


func _add_timing_stat(parent: VBoxContainer, result: Dictionary) -> void:
	var sample_count := int(result.get("timing_samples", 0))
	if sample_count <= 0:
		_add_stat(parent, AuroraLocale.text("SESGO DE TIEMPO"), "--", AuroraUi.MUTED, 12)
		return
	var average_ms := int(result.get("average_timing_ms", 0))
	if absi(average_ms) <= 8:
		_add_stat(
			parent,
			AuroraLocale.text("SESGO DE TIEMPO"),
			AuroraLocale.text("A TIEMPO  %dms") % absi(average_ms),
			AuroraUi.TEAL,
			12
		)
	elif average_ms < 0:
		_add_stat(
			parent,
			AuroraLocale.text("SESGO DE TIEMPO"),
			AuroraLocale.text("ANTICIPADO  %dms") % average_ms,
			AuroraUi.VIOLET,
			12
		)
	else:
		_add_stat(
			parent,
			AuroraLocale.text("SESGO DE TIEMPO"),
			AuroraLocale.text("TARDE  +%dms") % average_ms,
			AuroraUi.CORAL,
			12
		)
	_add_stat(
		parent,
		AuroraLocale.text("ANTICIPADO / A TIEMPO / TARDE"),
		_format_timing_distribution(result),
		AuroraUi.TEXT,
		11
	)


func _format_timing_distribution(result: Dictionary) -> String:
	return "%d / %d / %d" % [
		int(result.get("early_hits", 0)),
		int(result.get("on_time_hits", 0)),
		int(result.get("late_hits", 0)),
	]


func _add_stat(
	parent: VBoxContainer,
	stat_name: String,
	value: String,
	color: Color,
	value_size: int = 16
) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var left := AuroraUi.make_pixel_label(stat_name, 9, AuroraUi.MUTED)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(left)
	var right := AuroraUi.make_pixel_label(value, value_size, color)
	right.custom_minimum_size.x = 250.0
	right.autowrap_mode = TextServer.AUTOWRAP_OFF
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right)


func _add_stat_cell(parent: GridContainer, stat_name: String, value: String, color: Color) -> void:
	var cell := HBoxContainer.new()
	cell.custom_minimum_size.x = 260.0
	parent.add_child(cell)
	var label := AuroraUi.make_pixel_label(stat_name, 8, AuroraUi.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	cell.add_child(label)
	var number := AuroraUi.make_pixel_label(value, 15, color)
	number.custom_minimum_size.x = 92.0
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cell.add_child(number)


func _get_rank(accuracy: float, misses: int) -> String:
	return GameManager.get_rank(accuracy, misses)


func _get_rank_color(rank: String) -> Color:
	match rank:
		"S+", "S":
			return AuroraUi.TEAL
		"A":
			return AuroraUi.GOLD
		"B":
			return AuroraUi.VIOLET
		_:
			return AuroraUi.CORAL


func _get_clear_status(result: Dictionary) -> String:
	var total_notes := int(result.get("total_notes", 0))
	var perfect := int(result.get("perfect", 0))
	var misses := int(result.get("miss", 0))
	if total_notes > 0 and perfect >= total_notes and misses == 0:
		return AuroraLocale.text("PARTIDA PERFECTA")
	if total_notes > 0 and misses == 0:
		return AuroraLocale.text("COMBO COMPLETO")
	return AuroraLocale.text("PISTA COMPLETADA")


func _get_clear_status_color(clear_status: String) -> Color:
	if clear_status == AuroraLocale.text("PARTIDA PERFECTA"):
		return AuroraUi.GOLD
	if clear_status == AuroraLocale.text("COMBO COMPLETO"):
		return AuroraUi.TEAL
	return AuroraUi.VIOLET


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if input_manager.controller_event_matches(event, "back"):
			_return_from_results()
			get_viewport().set_input_as_handled()
		elif input_manager.controller_event_matches(event, "confirm"):
			if not actions.is_empty():
				_on_button_pressed(actions[selected_button])
				get_viewport().set_input_as_handled()
		else:
			match event.button_index:
				JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP:
					selected_button = maxi(0, selected_button - 1)
					update_button_selection()
					get_viewport().set_input_as_handled()
				JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN:
					selected_button = mini(buttons.size() - 1, selected_button + 1)
					update_button_selection()
					get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_return_from_results()
			KEY_LEFT, KEY_UP:
				selected_button = maxi(0, selected_button - 1)
				update_button_selection()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_DOWN:
				selected_button = mini(buttons.size() - 1, selected_button + 1)
				update_button_selection()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
				_on_button_pressed(actions[selected_button])


func _return_from_results() -> void:
	if game_manager.editor_test_active:
		scene_manager.load_scene("editor")
	else:
		game_manager.stop_song()
		scene_manager.load_scene("song_select")


func update_button_selection() -> void:
	if not buttons.is_empty():
		buttons[selected_button].grab_focus()


func _on_result_button_focused(index: int) -> void:
	selected_button = clampi(index, 0, maxi(buttons.size() - 1, 0))


func _on_button_pressed(action: String) -> void:
	match action:
		"retry":
			game_manager.last_result.clear()
			game_manager.is_playing = game_manager.current_song != null and game_manager.current_chart != null
			scene_manager.load_scene("gameplay")
		"select":
			game_manager.stop_song()
			scene_manager.load_scene("song_select")
		"editor":
			scene_manager.load_scene("editor")
		"menu":
			game_manager.stop_song()
			scene_manager.load_scene("main_menu")
