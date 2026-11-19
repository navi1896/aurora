extends Control

const NEON_NOTE := preload("res://src/screens/gameplay/NeonGameplayNote.gd")

var tint := Color(0.08, 0.86, 1.0)
var style_profile := "aurora"
var lane_direction := 2
var custom_note_border := Color.WHITE
var custom_note_shape := "rectangle"
var custom_outline_width := 2
var pressed := false
var holding := false
var effects_enabled := true
var reduced_motion := false
var energy := 0.0
var miss_energy := 0.0
var particle_clock := 0.0
var particles: Array[Dictionary] = []
var body_texture: GradientTexture2D
var _custom_style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	rebuild_body_texture()


func rebuild_body_texture() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([tint.darkened(0.42), tint, tint.lerp(Color.WHITE, 0.20)])
	gradient.offsets = PackedFloat32Array([0.0, 0.60, 1.0])
	body_texture = GradientTexture2D.new()
	body_texture.gradient = gradient
	body_texture.width = 8
	body_texture.height = 64
	body_texture.fill_from = Vector2(0.5, 0.0)
	body_texture.fill_to = Vector2(0.5, 1.0)


func set_pressed(value: bool) -> void:
	if pressed == value:
		return
	pressed = value
	if value:
		set_process(true)
	queue_redraw()


func set_holding(value: bool) -> void:
	if holding == value:
		return
	holding = value
	if value:
		set_process(true)
	queue_redraw()


func flash_hit(quality: float) -> void:
	energy = quality
	set_process(true)
	if effects_enabled and not reduced_motion:
		_emit_particles(roundi(7.0 + quality * 9.0), quality)
	queue_redraw()


func flash_miss() -> void:
	miss_energy = 1.0
	set_process(true)
	queue_redraw()


func _emit_particles(count: int, quality: float) -> void:
	for index in range(count):
		particles.append({
			"position": Vector2(randf_range(size.x * 0.22, size.x * 0.78), -8.0),
			"velocity": Vector2(randf_range(-28.0, 28.0), -randf_range(45.0, 125.0) * quality),
			"life": randf_range(0.25, 0.65),
			"size": randf_range(2.0, 4.0),
		})
	# Dense chords and long holds should have a bounded visual cost.
	while particles.size() > 64:
		particles.pop_front()


func _process(delta: float) -> void:
	var was_animating := energy > 0.0 or miss_energy > 0.0 or holding or not particles.is_empty()
	energy = maxf(energy - delta * 3.5, 0.0)
	miss_energy = maxf(miss_energy - delta * 4.5, 0.0)
	if holding and effects_enabled and not reduced_motion:
		particle_clock += delta
		if particle_clock >= 0.06:
			particle_clock = 0.0
			_emit_particles(2, 0.85)
	var write_index := 0
	for index in range(particles.size()):
		var particle: Dictionary = particles[index]
		var life := float(particle["life"]) - delta
		if life <= 0.0:
			continue
		particle["life"] = life
		particle["position"] += particle["velocity"] * delta
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)
	if was_animating or holding or not particles.is_empty():
		queue_redraw()
	elif energy <= 0.0 and miss_energy <= 0.0 and not holding and not pressed and particles.is_empty():
		set_process(false)


func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0:
		return
	var lit := maxf(energy, 0.55 if pressed or holding else 0.0)
	var color := tint.lerp(Color(1.0, 0.18, 0.28), miss_energy)
	if style_profile == "djmax":
		_draw_djmax_receptor(color, lit)
		_draw_particles(color)
		return
	if style_profile == "quaver":
		_draw_quaver_receptor(color, lit)
		_draw_particles(color)
		return
	if style_profile == "fnf":
		_draw_fnf_receptor(color, lit)
		_draw_particles(color)
		return
	if style_profile == "custom":
		_draw_custom_receptor(color, lit)
		_draw_particles(color)
		return
	var rect := Rect2(4, 3.0 + (1.5 if pressed else 0.0), size.x - 8.0, size.y - 7.0)
	var bevel := PackedVector2Array([
		Vector2(0, 7), Vector2(6, 0), Vector2(size.x - 6, 0), Vector2(size.x, 7),
		Vector2(size.x, size.y - 2), Vector2(size.x - 6, size.y + 5), Vector2(6, size.y + 5), Vector2(0, size.y - 2),
	])
	draw_colored_polygon(bevel, color.darkened(0.70))
	for spread in [7.0, 4.0, 2.0]:
		draw_rect(rect.grow(spread), Color(color, 0.03 + lit * 0.035), false, spread)
	draw_rect(rect, color, false, 2.0)
	if body_texture != null:
		draw_texture_rect(body_texture, rect.grow(-2.0), false, Color(1.0 + lit * 0.20, 1.0 + lit * 0.20, 1.0 + lit * 0.20).lerp(Color(1.0, 0.24, 0.35), miss_energy))
	draw_rect(Rect2(rect.position + Vector2(2, 0), Vector2(rect.size.x - 4, 2)), Color.WHITE)
	draw_rect(Rect2(rect.position + Vector2(0, 2), Vector2(2, rect.size.y - 4)), color.lerp(Color.WHITE, 0.55))
	draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 2), Vector2(rect.size.x - 4, 2)), color.lerp(Color.WHITE, 0.35))
	var indicator := Rect2(size.x * 0.5 - 13.0, 13.0 + (1.5 if pressed else 0.0), 26.0, 9.0)
	draw_rect(indicator.grow(4), Color(color, 0.15))
	draw_rect(indicator, Color.WHITE)
	if lit > 0.0 and effects_enabled:
		for spread in [12.0, 7.0, 3.0]:
			draw_rect(Rect2(size.x * 0.17, -10.0 - spread, size.x * 0.66, spread * 2.0), Color(color, lit * 0.10))
		draw_rect(Rect2(size.x * 0.22, -11, size.x * 0.56, 3), Color(1, 1, 1, lit * 0.95))
	_draw_particles(color)


func _draw_djmax_receptor(color: Color, lit: float) -> void:
	var drop := 1.5 if pressed else 0.0
	var rect := Rect2(2.0, 3.0 + drop, size.x - 4.0, size.y - 6.0)
	draw_rect(rect.grow(5.0), Color(color, 0.07 + lit * 0.10))
	draw_rect(rect, color.darkened(0.28))
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size - Vector2(4, 6)), color)
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 3)), Color.WHITE)
	draw_rect(Rect2(rect.position.x + 3, rect.end.y - 4, rect.size.x - 6, 2), color.darkened(0.55))
	var keybar := Rect2(size.x * 0.32, size.y * 0.42 + drop, size.x * 0.36, 7.0)
	draw_rect(keybar, Color(0.02, 0.02, 0.06, 0.75))
	draw_rect(keybar.grow(-2.0), Color.WHITE.lerp(color, 0.38))
	if lit > 0.0 and effects_enabled:
		draw_rect(rect.grow(9.0), Color(color, lit * 0.08), false, 2.0)


func _draw_quaver_receptor(color: Color, lit: float) -> void:
	var drop := 1.0 if pressed else 0.0
	var rect := Rect2(3.0, 3.0 + drop, size.x - 6.0, size.y - 6.0)
	draw_rect(rect.grow(4.0), Color(color, 0.04 + lit * 0.08))
	draw_rect(rect, Color(0.008, 0.018, 0.034, 0.96))
	draw_rect(rect, color.lerp(Color.WHITE, 0.10), false, 2.0)
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 3)), Color.WHITE)
	draw_rect(Rect2(rect.position.x + 3, rect.position.y + 7, 3, rect.size.y - 14), color)
	draw_rect(Rect2(rect.end.x - 6, rect.position.y + 7, 3, rect.size.y - 14), color)
	var center := Rect2(size.x * 0.34, size.y * 0.48 + drop, size.x * 0.32, 4.0)
	draw_rect(center, color.lerp(Color.WHITE, 0.60))
	if lit > 0.0 and effects_enabled:
		draw_rect(rect.grow(7.0), Color(color, lit * 0.06), false, 1.5)


func _draw_fnf_receptor(color: Color, lit: float) -> void:
	var drop := 2.0 if pressed else 0.0
	var center := Vector2(size.x * 0.5, size.y * 0.5 + drop)
	var half_extent := minf(size.x * 0.34, size.y * 0.44)
	if lit > 0.0:
		var glow := lit if effects_enabled else minf(lit, 0.55)
		NEON_NOTE.draw_fnf_arrow(
			self,
			center,
			half_extent * (0.96 if pressed else 1.02),
			lane_direction,
			color.lerp(Color.WHITE, glow * 0.30),
			Color.WHITE,
			2.0,
			glow * 0.28 if effects_enabled else 0.0,
			true
		)
		return
	NEON_NOTE.draw_fnf_arrow(
		self,
		center,
		half_extent,
		lane_direction,
		Color(0.08, 0.10, 0.15, 0.72).lerp(Color(color.r, color.g, color.b, 0.72), 0.14),
		Color(0.58, 0.64, 0.76, 0.92),
		2.0,
		0.0,
		false
	)


func _draw_custom_receptor(color: Color, lit: float) -> void:
	var drop := 1.5 if pressed else 0.0
	var rect := Rect2(3.0, 3.0 + drop, size.x - 6.0, size.y - 6.0)
	_custom_style.bg_color = color.lerp(Color.WHITE, lit * 0.10)
	_custom_style.border_color = custom_note_border
	_custom_style.set_border_width_all(clampi(custom_outline_width, 0, 5))
	match custom_note_shape:
		"rounded":
			_custom_style.set_corner_radius_all(6)
		"pill":
			_custom_style.set_corner_radius_all(mini(24, int(rect.size.y * 0.5)))
		_:
			_custom_style.set_corner_radius_all(0)
	draw_style_box(_custom_style, rect)
	draw_rect(Rect2(rect.position.x + 3.0, rect.position.y + 2.0, maxf(rect.size.x - 6.0, 1.0), 2.0), Color.WHITE)
	if lit > 0.0 and effects_enabled:
		draw_rect(rect.grow(7.0), Color(color, lit * 0.07), false, 2.0)


func _draw_particles(color: Color) -> void:
	for particle in particles:
		var alpha := minf(float(particle["life"]) * 3.0, 1.0)
		var point: Vector2 = particle["position"]
		var width: float = particle["size"]
		draw_rect(Rect2(point - Vector2.ONE * 2.0, Vector2.ONE * (width + 4)), Color(color, alpha * 0.14))
		draw_rect(Rect2(point, Vector2.ONE * width), Color(color.lerp(Color.WHITE, 0.78), alpha))
