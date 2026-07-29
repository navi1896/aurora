extends SceneTree

const OUTPUT_SPECS := [
	{
		"source": "res://assets/menu/_sources/aurora_logo_chroma.png",
		"output": "res://assets/menu/logo/aurora_logo.png",
		"size": Vector2i(1200, 360),
		"padding": 16,
	},
	{
		"source": "res://assets/menu/_sources/menu_character_chroma.png",
		"output": "res://assets/menu/character/menu_character.png",
		"size": Vector2i(512, 880),
		"padding": 20,
	},
	{
		"source": "res://assets/menu/_sources/button_normal_chroma.png",
		"output": "res://assets/menu/buttons/button_normal.png",
		"size": Vector2i(720, 180),
		"padding": 6,
	},
	{
		"source": "res://assets/menu/_sources/button_selected_chroma.png",
		"output": "res://assets/menu/buttons/button_selected.png",
		"size": Vector2i(720, 180),
		"padding": 6,
	},
	{
		"source": "res://assets/menu/_sources/selector_arrow_chroma.png",
		"output": "res://assets/menu/ui/selector_arrow.png",
		"size": Vector2i(96, 96),
		"padding": 8,
	},
]


func _init() -> void:
	# Rebuilds final menu textures from the editable source images.
	_resize_background()
	for spec: Dictionary in OUTPUT_SPECS:
		_process_chroma_asset(spec)
	quit()


func _resize_background() -> void:
	var image := Image.load_from_file("res://assets/menu/background/menu_background.png")
	if image == null or image.is_empty():
		push_error("Could not load the menu background.")
		return
	image.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("res://assets/menu/background/menu_background.png")
	if error != OK:
		push_error("Could not save the resized menu background.")


func _process_chroma_asset(spec: Dictionary) -> void:
	var image := Image.load_from_file(spec.source)
	if image == null or image.is_empty():
		push_error("Could not load %s." % spec.source)
		return

	image.convert(Image.FORMAT_RGBA8)
	_remove_green_screen(image)
	image = _trim_transparent_edges(image)
	image = _fit_in_canvas(image, spec.size, spec.padding)

	var error := image.save_png(spec.output)
	if error != OK:
		push_error("Could not save %s." % spec.output)


func _remove_green_screen(image: Image) -> void:
	# Removes the flat green source while preserving cyan logo and UI pixels.
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var green_excess := color.g - maxf(color.r, color.b)
			if color.g > 0.48 and green_excess > 0.28:
				color = Color.TRANSPARENT
			elif color.g > 0.38 and green_excess > 0.10:
				color.a *= 1.0 - inverse_lerp(0.10, 0.28, green_excess)
				color.g = minf(color.g, maxf(color.r, color.b))
			image.set_pixel(x, y, color)


func _trim_transparent_edges(image: Image) -> Image:
	var min_point := Vector2i(image.get_width(), image.get_height())
	var max_point := Vector2i(-1, -1)

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_point.x = mini(min_point.x, x)
			min_point.y = mini(min_point.y, y)
			max_point.x = maxi(max_point.x, x)
			max_point.y = maxi(max_point.y, y)

	if max_point.x < 0:
		return image

	var region := Rect2i(min_point, max_point - min_point + Vector2i.ONE)
	return image.get_region(region)


func _fit_in_canvas(image: Image, canvas_size: Vector2i, padding: int) -> Image:
	var available := canvas_size - Vector2i(padding * 2, padding * 2)
	var scale_factor := minf(
		float(available.x) / float(image.get_width()),
		float(available.y) / float(image.get_height())
	)
	var fitted_size := Vector2i(
		maxi(1, roundi(image.get_width() * scale_factor)),
		maxi(1, roundi(image.get_height() * scale_factor))
	)
	image.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_NEAREST)

	var canvas := Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var destination := (canvas_size - fitted_size) / 2
	canvas.blit_rect(image, Rect2i(Vector2i.ZERO, fitted_size), destination)
	return canvas
