extends Node

class_name MenuMusicManager

const SAMPLE_RATE := 22050
const TEMPO_BPM := 112.0
const MENU_SCREENS: Array[String] = ["main_menu", "settings"]
const MELODY_MIDI: Array[int] = [
	72, 76, 79, 76, 74, 77, 81, 77,
	69, 72, 76, 72, 71, 74, 79, 74,
	72, 76, 79, 83, 81, 79, 76, 74,
	69, 72, 76, 79, 77, 74, 71, -1,
]
const BASS_MIDI: Array[int] = [36, 33, 41, 38]

var player: AudioStreamPlayer
var scene_manager: SceneManager


func _ready() -> void:
	scene_manager = get_parent().get_node("SceneManager") as SceneManager
	player = AudioStreamPlayer.new()
	player.name = "AuroraMenuMusic"
	player.bus = "MenuMusic" if AudioServer.get_bus_index("MenuMusic") >= 0 else "Master"
	player.volume_db = -8.0
	player.stream = _create_original_menu_loop()
	add_child(player)
	if scene_manager != null:
		scene_manager.scene_loaded.connect(_on_scene_loaded)
		if scene_manager.current_scene_name in MENU_SCREENS:
			_on_scene_loaded(scene_manager.current_scene_name)


func _on_scene_loaded(scene_name: String) -> void:
	if scene_name in MENU_SCREENS:
		if not player.playing:
			player.play()
	else:
		player.stop()


func _create_original_menu_loop() -> AudioStreamWAV:
	var step_seconds := 60.0 / TEMPO_BPM * 0.5
	var loop_seconds := step_seconds * float(MELODY_MIDI.size())
	var sample_count := roundi(loop_seconds * float(SAMPLE_RATE))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for sample_index in range(sample_count):
		var time := float(sample_index) / float(SAMPLE_RATE)
		var step_position := time / step_seconds
		var step_index := mini(int(step_position), MELODY_MIDI.size() - 1)
		var step_phase := fmod(time, step_seconds)
		var step_envelope := _note_envelope(step_phase, step_seconds)

		var melody := 0.0
		var melody_midi := MELODY_MIDI[step_index]
		if melody_midi >= 0:
			var melody_frequency := _midi_to_hz(melody_midi)
			var melody_phase := TAU * melody_frequency * time
			melody = (
				sin(melody_phase) * 0.64
				+ signf(sin(melody_phase)) * 0.20
				+ sin(melody_phase * 2.0) * 0.16
			) * step_envelope

		var bass_index := mini(step_index / 8, BASS_MIDI.size() - 1)
		var bass_frequency := _midi_to_hz(BASS_MIDI[bass_index])
		var bass_phase := TAU * bass_frequency * time
		var bass := (
			sin(bass_phase) * 0.82
			+ sin(bass_phase * 2.0) * 0.18
		) * (0.72 + step_envelope * 0.28)

		var beat_phase := fmod(time, step_seconds * 2.0)
		var kick := sin(TAU * (72.0 - beat_phase * 38.0) * beat_phase)
		kick *= exp(-beat_phase * 18.0)

		var shimmer_frequency := _midi_to_hz(84 + (step_index % 4) * 2)
		var shimmer_phase := fmod(time, step_seconds * 0.5)
		var shimmer := sin(TAU * shimmer_frequency * time)
		shimmer *= exp(-shimmer_phase * 22.0)

		var mixed := melody * 0.32 + bass * 0.20 + kick * 0.12 + shimmer * 0.055
		var sample := clampi(roundi(mixed * 32767.0), -32768, 32767)
		bytes.encode_s16(sample_index * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


func _note_envelope(time: float, duration: float) -> float:
	var attack := clampf(time / 0.018, 0.0, 1.0)
	var release := clampf((duration - time) / 0.075, 0.0, 1.0)
	return attack * release


func _midi_to_hz(midi_note: int) -> float:
	return 440.0 * pow(2.0, (float(midi_note) - 69.0) / 12.0)
