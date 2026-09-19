extends Control

## End-of-song celebration; owned by Gameplay so audio stops on exit/retry.
signal finished

const DURATION := 4.0
const SAMPLE_RATE := 22050
var elapsed := 0.0
var reduced_motion := false
var running := false
var audio_player: AudioStreamPlayer
var display_font: SystemFont


static func qualifies(result: Dictionary) -> bool:
	var total := int(result.get("total_notes", 0))
	var hits := int(result.get("perfect", 0)) + int(result.get("great", 0)) + int(result.get("good", 0))
	return total > 0 and int(result.get("miss", 0)) == 0 and hits == total and int(result.get("max_combo", 0)) >= total


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["Arial", "Helvetica", "sans-serif"])
	display_font.font_weight = 900
	display_font.font_stretch = 75
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "PerfectPlaySound"
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	audio_player.stream = _create_celebration_stream()
	audio_player.volume_db = -6.0
	add_child(audio_player)
	set_process(false)


func play(reduce_motion: bool = false) -> void:
	if running:
		return
	reduced_motion = reduce_motion
	elapsed = 0.0
	running = true
	show()
	audio_player.play()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= DURATION:
		complete()


func complete() -> void:
	if not running:
		return
	running = false
	set_process(false)
	audio_player.stop()
	hide()
	queue_redraw()
	finished.emit()


func _draw() -> void:
	if not running or display_font == null:
		return
	var fade := clampf((DURATION - elapsed) / 0.45, 0.0, 1.0)
	var enter := clampf(elapsed / 0.16, 0.0, 1.0)
	var settle := smoothstep(1.45, 1.9, elapsed)
	var unit := minf(size.x / 1920.0, size.y / 1080.0)
	var center := Vector2(size.x * 0.5, size.y * 0.40)
	var zoom := lerpf(1.0, 0.70, settle)
	if not reduced_motion:
		zoom *= lerpf(1.18, 1.0, 1.0 - pow(1.0 - enter, 3.0))
	else:
		zoom = 0.85
	# A restrained stage wash keeps the original playfield visible underneath.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.015, 0.34 * enter * fade))
	var tint_alpha := enter * fade
	draw_set_transform(center, 0.0, Vector2.ONE * unit * zoom)
	var badge := enter if reduced_motion else settle
	if badge > 0.0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-225, -110), Vector2(220, -174), Vector2(154, 8),
			Vector2(197, 177), Vector2(-16, 128), Vector2(-228, 203), Vector2(-167, 25),
		]), Color(0.95, 0.02, 0.43, badge * tint_alpha))
		draw_colored_polygon(PackedVector2Array([
			Vector2(35, -147), Vector2(220, -174), Vector2(154, 8),
			Vector2(197, 177), Vector2(-16, 128),
		]), Color(0.46, 0.02, 0.85, badge * tint_alpha))
		var crown := PackedVector2Array([
			Vector2(-89, -175), Vector2(-127, -248), Vector2(-56, -212),
			Vector2(-20, -272), Vector2(14, -219), Vector2(79, -267), Vector2(46, -185),
		])
		draw_colored_polygon(crown, Color(1.0, 0.92, 0.13, badge * tint_alpha))
	# Both baselines rise to the right like the checked DJMAX reference.
	var skew := Transform2D(Vector2(0.80, -0.22), Vector2(0.0, 1.0), center)
	skew.x *= unit * zoom
	skew.y *= unit * zoom
	draw_set_transform_matrix(skew)
	_draw_word("PERFECT", Vector2(-230, -12), 94, tint_alpha)
	_draw_word("PLAY", Vector2(-145, 94), 108, tint_alpha)
	draw_set_transform(center, 0.0, Vector2.ONE * unit * zoom)
	if not reduced_motion:
		var sparkle := maxf(0.0, 1.0 - absf(elapsed - 0.42) / 0.38) * fade
		if sparkle > 0.0:
			var at := Vector2(5, -5)
			draw_line(at - Vector2(85, 0), at + Vector2(85, 0), Color(1, 0.86, 0.42, sparkle), 3.0)
			draw_line(at - Vector2(0, 30), at + Vector2(0, 30), Color(1, 1, 1, sparkle), 3.0)
			draw_circle(at, 7.0, Color(1, 1, 1, sparkle))
	draw_set_transform(Vector2.ZERO)


func _draw_word(word: String, position: Vector2, font_size: int, alpha: float) -> void:
	draw_string_outline(display_font, position + Vector2(3, 4), word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, Color(0.025, 0.005, 0.045, 0.8 * alpha))
	draw_string(display_font, position, word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, alpha))


func _create_celebration_stream() -> AudioStreamWAV:
	# Efecto original de Aurora: una celebración luminosa de la misma duración
	# que la animación, sin audio de DJMAX.
	const DURATION_SECONDS := DURATION
	var sample_count := roundi(DURATION_SECONDS * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / SAMPLE_RATE
		var envelope := minf(time / 0.018, 1.0) * pow(maxf(0.0, 1.0 - time / DURATION_SECONDS), 1.35)
		var sweep := lerpf(540.0, 1680.0, clampf(time / 0.34, 0.0, 1.0))
		var tone := sin(TAU * sweep * time) + 0.26 * sin(TAU * sweep * 2.01 * time)
		var shimmer := sin(TAU * 2460.0 * time) * exp(-pow((time - 0.31) / 0.11, 2.0)) * 0.22
		var chime := sin(TAU * 1320.0 * time) * exp(-time * 1.5) * 0.10
		var value := (tone * 0.12 + shimmer + chime) * envelope
		bytes.encode_s16(sample_index * 2, clampi(roundi(value * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
