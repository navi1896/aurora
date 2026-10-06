extends Control

var tint := Color(0.08, 0.86, 1.0)
var pressed := false
var holding := false
var effects_enabled := true
var reduced_motion := false
var energy := 0.0
var miss_energy := 0.0
var particle_clock := 0.0
var particles: Array[Dictionary] = []
var body_texture: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
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
	pressed = value
	queue_redraw()


func set_holding(value: bool) -> void:
	holding = value
	queue_redraw()


func flash_hit(quality: float) -> void:
	energy = quality
	if effects_enabled and not reduced_motion:
		_emit_particles(roundi(7.0 + quality * 9.0), quality)
	queue_redraw()


func flash_miss() -> void:
	miss_energy = 1.0
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
	for particle in particles:
		particle["position"] += particle["velocity"] * delta
		particle["life"] -= delta
	particles = particles.filter(func(particle: Dictionary) -> bool: return float(particle["life"]) > 0.0)
	if was_animating or holding or not particles.is_empty():
		queue_redraw()


func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0:
		return
	var lit := maxf(energy, 0.55 if pressed or holding else 0.0)
	var color := tint.lerp(Color(1.0, 0.18, 0.28), miss_energy)
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
	for particle in particles:
		var alpha := minf(float(particle["life"]) * 3.0, 1.0)
		var point: Vector2 = particle["position"]
		var width: float = particle["size"]
		draw_rect(Rect2(point - Vector2.ONE * 2.0, Vector2.ONE * (width + 4)), Color(color, alpha * 0.14))
		draw_rect(Rect2(point, Vector2.ONE * width), Color(color.lerp(Color.WHITE, 0.78), alpha))
