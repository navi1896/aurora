extends Node

class_name UiFeedbackManager

const SAMPLE_RATE := 22050
const GAP_SECONDS := 0.018

var feedback_player: AudioStreamPlayer
var feedback_streams: Dictionary = {}


func _ready() -> void:
	feedback_player = AudioStreamPlayer.new()
	feedback_player.name = "AuroraUiFeedback"
	feedback_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	feedback_player.volume_db = -8.0
	add_child(feedback_player)
	feedback_streams = {
		"navigation": _create_sequence([[980.0, 0.022, 0.075], [1280.0, 0.032, 0.045]]),
		"cabinet_click": _create_sequence([[1600.0, 0.008, 0.18], [220.0, 0.032, 0.16]]),
		"confirm": _create_sequence([[330.0, 0.022, 0.06], [780.0, 0.045, 0.12], [1180.0, 0.070, 0.11]]),
		"loading": _create_sequence([[220.0, 0.030, 0.05], [510.0, 0.045, 0.09], [940.0, 0.075, 0.11]]),
		"pause": _create_sequence([[430.0, 0.060, 0.13], [320.0, 0.070, 0.11]]),
		"clear": _create_sequence([
			[620.0, 0.050, 0.12],
			[830.0, 0.060, 0.14],
			[1040.0, 0.110, 0.16],
		]),
	}


func play_navigation() -> void:
	_play("navigation")


func play_cabinet_click() -> void:
	_play("cabinet_click")


func play_confirm() -> void:
	_play("confirm")


func play_loading() -> void:
	_play("loading")


func play_pause() -> void:
	_play("pause")


func play_clear() -> void:
	_play("clear")


func _play(kind: String) -> void:
	if feedback_player == null:
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
