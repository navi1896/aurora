extends Node

class_name UiFeedbackManager

const SOUNDS := preload("res://src/audio/GameSoundBank.gd")
const SAMPLE_RATE := 22050
const GAP_SECONDS := 0.018

var feedback_player: AudioStreamPlayer
var feedback_streams: Dictionary = {}
var last_navigation_msec := -1000
var last_confirmation_msec := -1000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	feedback_player = AudioStreamPlayer.new()
	feedback_player.name = "AuroraUiFeedback"
	feedback_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	feedback_player.volume_db = -2.0
	add_child(feedback_player)
	feedback_streams = {
		"navigation": SOUNDS.MENU_SELECT,
		"song_navigation": SOUNDS.SONG_SELECT,
		"cabinet_click": SOUNDS.CONFIRM,
		"confirm": SOUNDS.CONFIRM,
		"resume": SOUNDS.RESUME,
		"loading": SOUNDS.LOADING,
		"pause": SOUNDS.PAUSE,
		"clear": SOUNDS.STAGE_CLEAR,
	}
	get_tree().node_added.connect(_on_node_added)
	_bind_existing_buttons(get_tree().current_scene)


func _on_node_added(node: Node) -> void:
	if node is Button:
		call_deferred("_bind_button", node)


func _bind_existing_buttons(node: Node) -> void:
	if node == null:
		return
	if node is Button:
		_bind_button(node)
	for child in node.get_children():
		_bind_existing_buttons(child)


func _bind_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	if not button.mouse_entered.is_connected(play_navigation):
		button.mouse_entered.connect(play_navigation)
	if not button.focus_entered.is_connected(play_navigation):
		button.focus_entered.connect(play_navigation)
	if not button.pressed.is_connected(play_confirm):
		button.pressed.connect(play_confirm)


func play_navigation() -> void:
	_play("navigation")


func play_cabinet_click() -> void:
	_play("cabinet_click")


func play_song_navigation() -> void:
	_play("song_navigation")


func play_confirm() -> void:
	_play("confirm")


func play_resume() -> void:
	_play("resume")


func play_loading() -> void:
	_play("loading")


func play_pause() -> void:
	_play("pause")


func play_clear() -> void:
	_play("clear")


func _play(kind: String) -> void:
	if feedback_player == null:
		return
	var now := Time.get_ticks_msec()
	if kind in ["navigation", "song_navigation"]:
		if now - last_navigation_msec < 75 or now - last_confirmation_msec < 180:
			return
		last_navigation_msec = now
	elif kind in ["confirm", "cabinet_click", "resume"]:
		# Explicit screen callbacks and the generic button hook share one event.
		if now - last_confirmation_msec < 100:
			return
		last_confirmation_msec = now
	elif kind == "loading" and now - last_confirmation_msec < 180:
		return
	var stream := feedback_streams.get(kind, null) as AudioStreamWAV
	if stream == null:
		return
	feedback_player.stop()
	feedback_player.stream = stream
	feedback_player.play()


func _create_sequence(steps: Array) -> AudioStreamWAV:
	var safe_steps: Array[Array] = []
	var total_duration := 0.0
	for raw_step in steps:
		if not raw_step is Array or raw_step.size() < 3:
			continue
		var frequency := maxf(float(raw_step[0]), 1.0)
		var duration := maxf(float(raw_step[1]), 0.01)
		var amplitude := clampf(float(raw_step[2]), 0.0, 0.35)
		safe_steps.append([frequency, duration, amplitude, total_duration])
		total_duration += duration + GAP_SECONDS
	var sample_count := maxi(1, roundi(total_duration * float(SAMPLE_RATE)))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for sample_index in range(sample_count):
		var time := float(sample_index) / float(SAMPLE_RATE)
		var value := 0.0
		for step in safe_steps:
			var step_start := float(step[3])
			var duration := float(step[1])
			if time < step_start or time > step_start + duration:
				continue
			var local_time := time - step_start
			var attack := clampf(local_time / 0.008, 0.0, 1.0)
			var release := clampf((duration - local_time) / 0.045, 0.0, 1.0)
			var envelope := attack * release
			var phase := TAU * float(step[0]) * local_time
			var wave := sin(phase) * 0.88 + sin(phase * 2.0) * 0.12
			value = wave * envelope * float(step[2])
			break
		var sample := clampi(roundi(value * 32767.0), -32768, 32767)
		bytes.encode_s16(sample_index * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
