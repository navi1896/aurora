extends Node

class_name MenuMusicManager

const SAMPLE_RATE := 22050
const TEMPO_BPM := 96.0
const MENU_SCREENS: Array[String] = ["main_menu", "settings"]
const ARPEGGIO_MIDI: Array[int] = [
	76, 79, 83, 86, 83, 79, 76, 79,
	74, 78, 81, 86, 81, 78, 74, 78,
	71, 74, 78, 83, 78, 74, 71, 74,
	69, 73, 76, 81, 76, 73, 69, -1,
	76, 79, 83, 88, 86, 83, 79, 76,
	74, 78, 81, 86, 88, 86, 81, 78,
	71, 74, 78, 83, 86, 83, 78, 74,
	69, 73, 76, 81, 83, 81, 76, -1,
]
const CHORD_ROOTS: Array[int] = [48, 45, 43, 41, 48, 45, 43, 41]

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
	var loop_seconds := step_seconds * float(ARPEGGIO_MIDI.size())
	var sample_count := roundi(loop_seconds * float(SAMPLE_RATE))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for sample_index in range(sample_count):
		var time := float(sample_index) / float(SAMPLE_RATE)
		var step_position := time / step_seconds
		var step_index := mini(int(step_position), ARPEGGIO_MIDI.size() - 1)
		var step_phase := fmod(time, step_seconds)
		var step_envelope := _note_envelope(step_phase, step_seconds)

		var arp := 0.0
		var arp_midi := ARPEGGIO_MIDI[step_index]
		if arp_midi >= 0:
			var arp_frequency := _midi_to_hz(arp_midi)
			var arp_phase := TAU * arp_frequency * time
			arp = (sin(arp_phase) * 0.72 + sin(arp_phase * 2.0) * 0.18) * step_envelope

		var bar_index := mini(int(step_index / 16), CHORD_ROOTS.size() - 1)
		var bass_frequency := _midi_to_hz(CHORD_ROOTS[bar_index])
		var bass_phase := TAU * bass_frequency * time
		var bass := (sin(bass_phase) * 0.78 + sin(bass_phase * 0.5) * 0.13) * 0.34
		var chord := 0.0
		for interval in [0, 3, 7, 12]:
			var pad_phase := TAU * _midi_to_hz(CHORD_ROOTS[bar_index] + interval + 12) * time
			chord += sin(pad_phase) * 0.25 + sin(pad_phase * 0.5) * 0.05
		chord *= 0.10 * (0.88 + sin(TAU * time / 7.5) * 0.12)

		var beat_phase := fmod(time, step_seconds * 4.0)
		var kick := sin(TAU * (74.0 - beat_phase * 44.0) * beat_phase) * exp(-beat_phase * 16.0)
		var hat_phase := fmod(time + step_seconds * 0.5, step_seconds * 2.0)
		var hat := (sin(TAU * 4900.0 * time) + sin(TAU * 7300.0 * time) * 0.35) * exp(-hat_phase * 43.0)
		var shimmer_phase := fmod(time, step_seconds * 4.0)
		var shimmer := sin(TAU * _midi_to_hz(91) * time) * exp(-shimmer_phase * 7.5)

		var mixed := arp * 0.22 + bass * 0.20 + chord + kick * 0.10 + hat * 0.018 + shimmer * 0.028
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
