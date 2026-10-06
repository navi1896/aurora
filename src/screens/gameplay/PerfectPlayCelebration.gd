extends Control

## MAX COMBO celebration using the cropped source animation atlas.
signal finished

const DURATION := 4.35 # 2.32 s sound cue plus about 2 s of visual tail from the reference.
const MAX_COMBO_ATLAS := preload("res://assets/gameplay/ui/max_combo_animation_atlas_rgba.png")
const SOUNDS := preload("res://src/audio/GameSoundBank.gd")
const DESIGN_SIZE := Vector2(1672.0, 941.0)
const FRAME_WIDTH := 480
const FRAME_HEIGHT := 425
const FRAME_COLUMNS := 8
const FRAME_COUNT := 104
const FRAME_RATE := 30.0
const BADGE_SIZE := Vector2(350.0, 310.0)
var elapsed := 0.0
var reduced_motion := false
var running := false
var audio_player: AudioStreamPlayer
var badge: TextureRect
var badge_texture: AtlasTexture


static func qualifies(result: Dictionary) -> bool:
	var total := int(result.get("total_notes", 0))
	var hits := int(result.get("perfect", 0)) + int(result.get("great", 0)) + int(result.get("good", 0))
	return total > 0 and int(result.get("miss", 0)) == 0 and hits == total and int(result.get("max_combo", 0)) >= total


func _ready() -> void:
	AuroraUi.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	z_as_relative = false
	badge_texture = AtlasTexture.new()
	badge_texture.atlas = MAX_COMBO_ATLAS
	badge_texture.region = Rect2(Vector2.ZERO, Vector2(FRAME_WIDTH, FRAME_HEIGHT))
	badge_texture.filter_clip = true
	badge = TextureRect.new()
	badge.name = "MaxComboBadgeImage"
	badge.texture = badge_texture
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.modulate = Color(1.0, 1.0, 1.0, 0.0)
	badge.pivot_offset = BADGE_SIZE * 0.5
	add_child(badge)
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "PerfectPlaySound"
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	audio_player.stream = SOUNDS.PERFECT_COMBO
	audio_player.volume_db = 5.8
	add_child(audio_player)
	set_process(false)


func play(reduce_motion: bool = false) -> void:
	if running:
		return
	reduced_motion = reduce_motion
	elapsed = 0.0
	running = true
	show()
	if audio_player.stream != null:
		audio_player.play()
	else:
		push_error("MAX COMBO cue failed to load from GameSoundBank.PERFECT_COMBO.")
	set_process(true)
	_update_badge()


func _process(delta: float) -> void:
	elapsed += delta
	_update_badge()
	if elapsed >= DURATION:
		complete()


func complete() -> void:
	if not running:
		return
	running = false
	set_process(false)
	audio_player.stop()
	hide()
	finished.emit()


func _update_badge() -> void:
	if badge == null:
		return
	var unit := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var fit_top := (size.y - DESIGN_SIZE.y * unit) * 0.5
	var enter := 1.0 if reduced_motion else smoothstep(0.0, 0.28, elapsed)
	var fade := clampf((DURATION - elapsed) / 0.45, 0.0, 1.0)
	var drift := 0.0 if reduced_motion else -9.0 * (1.0 - enter)
	var scale_factor := 1.0 if reduced_motion else 0.94 + 0.06 * enter
	var center := Vector2(size.x * 0.5, fit_top + (155.0 + drift) * unit)
	badge.size = BADGE_SIZE * unit
	badge.pivot_offset = badge.size * 0.5
	badge.position = center - badge.size * 0.5
	badge.scale = Vector2.ONE * scale_factor
	var frame_index := (
		FRAME_COUNT - 1
		if reduced_motion
		else mini(floori(elapsed * FRAME_RATE), FRAME_COUNT - 1)
	)
	var frame_column := frame_index % FRAME_COLUMNS
	var frame_row := int(frame_index / FRAME_COLUMNS)
	badge_texture.region = Rect2(
		Vector2(frame_column * FRAME_WIDTH, frame_row * FRAME_HEIGHT),
		Vector2(FRAME_WIDTH, FRAME_HEIGHT)
	)
	badge.modulate = Color(1.0, 1.0, 1.0, enter * fade)
