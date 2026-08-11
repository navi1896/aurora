extends Control

class_name CharacterIdleRig

const BLINK_DURATION_SECONDS := 0.11
const SELECTION_PULSE_SECONDS := 0.24
const BREATH_CYCLE_SECONDS := 3.4
const SWAY_CYCLE_SECONDS := 6.8
const MAX_BREATH_PIXELS := 2
const MAX_SWAY_PIXELS := 1
const LEFT_EYE_RECT := Rect2i(250, 178, 62, 46)
const RIGHT_EYE_RECT := Rect2i(326, 178, 32, 46)

@onready var character: TextureRect = $MenuCharacter
@onready var headphone_pulse: Line2D = $MenuCharacter/HeadphonePulse

var settings_manager: SettingsManager
var original_texture: Texture2D
var blink_texture: ImageTexture
var rest_scale := Vector2.ONE
var rest_character_position := Vector2.ZERO
var elapsed_seconds := 0.0
var next_blink_seconds := 3.2
var blink_remaining_seconds := 0.0
var selection_pulse_remaining_seconds := 0.0


func _ready() -> void:
	set_process(false)
	original_texture = character.texture
	blink_texture = _build_blink_texture(original_texture)
	_find_settings_manager()
	await get_tree().process_frame
	pivot_offset = Vector2(size.x * 0.5, size.y)
	rest_scale = scale
	rest_character_position = character.position
	set_process(true)


func _exit_tree() -> void:
	if (
		settings_manager != null
		and settings_manager.setting_changed.is_connected(_on_setting_changed)
	):
		settings_manager.setting_changed.disconnect(_on_setting_changed)


func _process(delta: float) -> void:
	if _is_reduced_motion_enabled():
		_apply_rest_pose()
		return

	elapsed_seconds += delta
	var breath_phase := sin(elapsed_seconds * TAU / BREATH_CYCLE_SECONDS)
	var breath_pixels := roundi(
		remap(breath_phase, -1.0, 1.0, 0.0, float(MAX_BREATH_PIXELS))
	)
	var safe_height := maxf(size.y, 1.0)
	scale = Vector2(
		rest_scale.x,
		rest_scale.y * (1.0 + float(breath_pixels) / safe_height)
	)

	var sway_pixels := roundi(
		sin(elapsed_seconds * TAU / SWAY_CYCLE_SECONDS) * float(MAX_SWAY_PIXELS)
	)
	character.position = rest_character_position + Vector2(float(sway_pixels), 0.0)
	_update_blink(delta)
	_update_selection_pulse(delta)


func _find_settings_manager() -> void:
	var app := get_tree().current_scene
	if app == null:
		return
	settings_manager = app.get_node_or_null("Managers/SettingsManager") as SettingsManager
	if (
		settings_manager != null
		and not settings_manager.setting_changed.is_connected(_on_setting_changed)
	):
		settings_manager.setting_changed.connect(_on_setting_changed)


func _is_reduced_motion_enabled() -> bool:
	return (
		settings_manager != null
		and bool(settings_manager.get_setting("reduced_motion", false))
	)


func _on_setting_changed(key: String, _value) -> void:
	if key == "reduced_motion" and _is_reduced_motion_enabled():
		_apply_rest_pose()


func trigger_selection_pulse(_action: StringName = &"") -> void:
	if _is_reduced_motion_enabled():
		headphone_pulse.visible = false
		selection_pulse_remaining_seconds = 0.0
		return
	selection_pulse_remaining_seconds = SELECTION_PULSE_SECONDS
	headphone_pulse.visible = true
	headphone_pulse.modulate.a = 1.0


func _update_selection_pulse(delta: float) -> void:
	if selection_pulse_remaining_seconds <= 0.0:
		headphone_pulse.visible = false
		return
	selection_pulse_remaining_seconds = maxf(
		selection_pulse_remaining_seconds - delta,
		0.0
	)
	var progress := selection_pulse_remaining_seconds / SELECTION_PULSE_SECONDS
	headphone_pulse.modulate.a = snappedf(progress, 0.25)
	if selection_pulse_remaining_seconds <= 0.0:
		headphone_pulse.visible = false


func _update_blink(delta: float) -> void:
	if blink_remaining_seconds > 0.0:
		blink_remaining_seconds = maxf(blink_remaining_seconds - delta, 0.0)
		if blink_remaining_seconds <= 0.0:
			character.texture = original_texture
			next_blink_seconds = 3.8 + fmod(elapsed_seconds, 2.1)
		return

	next_blink_seconds -= delta
	if next_blink_seconds <= 0.0 and blink_texture != null:
		blink_remaining_seconds = BLINK_DURATION_SECONDS
		character.texture = blink_texture


func _apply_rest_pose() -> void:
	scale = rest_scale
	character.position = rest_character_position
	character.texture = original_texture
	blink_remaining_seconds = 0.0
	selection_pulse_remaining_seconds = 0.0
	headphone_pulse.visible = false


func _build_blink_texture(source_texture: Texture2D) -> ImageTexture:
	if source_texture == null:
		return null
	var source_image := source_texture.get_image()
	if source_image == null or source_image.is_empty():
		return null
	if source_image.is_compressed():
		source_image.decompress()

	var closed_image: Image = source_image.duplicate()
	_paint_closed_eye(closed_image, source_image, LEFT_EYE_RECT)
	_paint_closed_eye(closed_image, source_image, RIGHT_EYE_RECT)
	return ImageTexture.create_from_image(closed_image)


func _paint_closed_eye(target: Image, source: Image, eye_rect: Rect2i) -> void:
	var source_y := mini(eye_rect.end.y + 8, source.get_height() - 1)
	var ellipse_center := Vector2(
		float(eye_rect.position.x) + float(eye_rect.size.x - 1) * 0.5,
		float(eye_rect.position.y) + float(eye_rect.size.y - 1) * 0.5
	)
	var ellipse_radius := Vector2(
		maxf(float(eye_rect.size.x - 1) * 0.5, 1.0),
		maxf(float(eye_rect.size.y - 1) * 0.5, 1.0)
	)
	for x in range(eye_rect.position.x, eye_rect.end.x):
		var sample_x := clampi(x, 0, source.get_width() - 1)
		for y in range(eye_rect.position.y, eye_rect.end.y):
			var normalized := Vector2(
				(float(x) - ellipse_center.x) / ellipse_radius.x,
				(float(y) - ellipse_center.y) / ellipse_radius.y
			)
			if normalized.length_squared() > 1.0:
				continue
			var sample_offset := mini((y - eye_rect.position.y) / 9, 3)
			var skin_color := source.get_pixel(
				sample_x,
				mini(source_y + sample_offset, source.get_height() - 1)
			)
			target.set_pixel(x, y, skin_color)

	var eyelid_color := Color8(24, 13, 38, 255)
	var center_x := float(eye_rect.position.x) + float(eye_rect.size.x - 1) * 0.5
	var half_width := maxf(float(eye_rect.size.x - 1) * 0.5, 1.0)
	var base_y := eye_rect.position.y + roundi(float(eye_rect.size.y) * 0.54)
	for x in range(eye_rect.position.x + 2, eye_rect.end.x - 2):
		var normalized_distance := absf(float(x) - center_x) / half_width
		var curve_offset := roundi(normalized_distance * normalized_distance * 3.0)
		for thickness in range(3):
			target.set_pixel(x, base_y + curve_offset + thickness, eyelid_color)


func has_blink_frame() -> bool:
	return (
		blink_texture != null
		and original_texture != null
		and blink_texture.get_size() == original_texture.get_size()
	)


func uses_pixel_safe_motion() -> bool:
	return (
		texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and MAX_BREATH_PIXELS <= 2
		and MAX_SWAY_PIXELS <= 1
		and not headphone_pulse.antialiased
	)


func has_interactive_headphone_pulse() -> bool:
	if (
		headphone_pulse == null
		or not headphone_pulse.closed
		or headphone_pulse.antialiased
		or not headphone_pulse.show_behind_parent
		or headphone_pulse.points.size() < 16
		or not is_equal_approx(headphone_pulse.width, roundf(headphone_pulse.width))
	):
		return false

	for point_index in range(headphone_pulse.points.size()):
		var current_point := headphone_pulse.points[point_index]
		var next_point := headphone_pulse.points[
			(point_index + 1) % headphone_pulse.points.size()
		]
		var horizontal := is_equal_approx(current_point.y, next_point.y)
		var vertical := is_equal_approx(current_point.x, next_point.x)
		if not horizontal and not vertical:
			return false
	return true
