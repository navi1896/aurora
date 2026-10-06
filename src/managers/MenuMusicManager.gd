extends Node

class_name MenuMusicManager

signal featured_song_changed(song: SongData, has_audio: bool)

const MENU_SCREENS: Array[String] = ["main_menu", "settings"]
const PREVIEW_SILENT_DB := -48.0
const CROSSFADE_SECONDS := 0.65
const MANUAL_START_DELAY_SECONDS := 1.0

var players: Array[AudioStreamPlayer] = []
var video_players: Array[VideoStreamPlayer] = []
var scene_manager: SceneManager
var song_manager: SongManager
var featured_song: SongData
var featured_audio_available := false
var active_scene_name := ""
var active_player_index := -1
var using_video_preview := false
var active_video_player_index := -1
var fade_tween: Tween
var transition_tween: Tween
var preview_start := 0.0
var preview_end := 0.0
var pending_start_at_msec := 0


func _ready() -> void:
	scene_manager = get_parent().get_node_or_null("SceneManager") as SceneManager
	song_manager = get_parent().get_node_or_null("SongManager") as SongManager
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "AuroraMenuPreview%d" % (index + 1)
		player.bus = "MenuMusic" if AudioServer.get_bus_index("MenuMusic") >= 0 else "Master"
		player.volume_db = PREVIEW_SILENT_DB
		player.finished.connect(_on_player_finished.bind(index))
		add_child(player)
		players.append(player)
	for index in range(2):
		var video_player := VideoStreamPlayer.new()
		video_player.name = "AuroraMenuVideoAudio%d" % (index + 1)
		video_player.bus = "MenuMusic" if AudioServer.get_bus_index("MenuMusic") >= 0 else "Master"
		video_player.volume_db = PREVIEW_SILENT_DB
		video_player.position = Vector2(-4096.0, -4096.0)
		video_player.size = Vector2.ONE
		video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		video_player.focus_mode = Control.FOCUS_NONE
		video_player.finished.connect(_on_video_preview_finished.bind(index))
		add_child(video_player)
		video_players.append(video_player)
	if scene_manager != null:
		scene_manager.scene_loaded.connect(_on_scene_loaded)
		var transition = get_parent().get_node_or_null("LoadingTransitionManager")
		if transition != null:
			transition.transition_started.connect(_on_transition_started)
		active_scene_name = scene_manager.current_scene_name
		if active_scene_name in MENU_SCREENS:
			ensure_featured_song()
	set_process(true)


func get_menu_songs() -> Array[SongData]:
	var available: Array[SongData] = []
	if song_manager == null:
		return available
	for song in song_manager.get_all_songs():
		if song_manager.has_available_media(song):
			available.append(song)
	return available


func ensure_featured_song() -> void:
	if featured_song != null and featured_song in get_menu_songs():
		featured_song_changed.emit(featured_song, featured_audio_available)
		if active_scene_name in MENU_SCREENS and pending_start_at_msec == 0:
			_play_featured_song()
		return
	choose_random_song(0.0)


func choose_relative_song(direction: int) -> void:
	var catalog := get_menu_songs()
	if catalog.size() < 2:
		return
	var start_index := catalog.find(featured_song)
	for offset in range(1, catalog.size() + 1):
		var index := posmod(start_index + direction * offset, catalog.size())
		var candidate := catalog[index]
		if candidate != featured_song and _resolve_featured_audio(candidate):
			set_featured_song(candidate, MANUAL_START_DELAY_SECONDS)
			return


func choose_random_song(start_delay_seconds: float = 1.0) -> void:
	var catalog := get_menu_songs()
	if catalog.is_empty():
		set_featured_song(null)
		return
	catalog.shuffle()
	for candidate in catalog:
		if candidate != featured_song and _resolve_featured_audio(candidate):
			set_featured_song(candidate, start_delay_seconds)
			return
	if featured_song != null and _resolve_featured_audio(featured_song):
		set_featured_song(featured_song, start_delay_seconds, true)
		return
	for candidate in catalog:
		if _resolve_featured_audio(candidate):
			set_featured_song(candidate, start_delay_seconds)
			return
	set_featured_song(null)


func set_featured_song(song: SongData, start_delay_seconds: float = 0.0, restart_same: bool = false) -> void:
	if featured_song == song and not restart_same:
		return
	featured_song = song
	featured_audio_available = _resolve_featured_audio(song)
	if song_manager != null and song != null and featured_audio_available:
		song_manager.release_unselected_package_media(song)
	featured_song_changed.emit(featured_song, featured_audio_available)
	if active_scene_name in MENU_SCREENS:
		if song == null:
			pending_start_at_msec = 0
			_fade_out_players()
		elif start_delay_seconds > 0.0:
			pending_start_at_msec = Time.get_ticks_msec() + roundi(start_delay_seconds * 1000.0)
			_fade_out_players()
		else:
			pending_start_at_msec = 0
			_play_featured_song()


func _on_scene_loaded(scene_name: String) -> void:
	active_scene_name = scene_name
	if scene_name in MENU_SCREENS:
		if featured_song == null:
			ensure_featured_song()
		elif pending_start_at_msec == 0 or Time.get_ticks_msec() >= pending_start_at_msec:
			pending_start_at_msec = 0
			_play_featured_song()
	else:
		pending_start_at_msec = 0
		_fade_out_players()


func _on_transition_started(_target_scene: String) -> void:
	if active_scene_name not in MENU_SCREENS:
		return
	var playing_players: Array[AudioStreamPlayer] = []
	var playing_video_players: Array[VideoStreamPlayer] = []
	for player in players:
		if player.playing:
			playing_players.append(player)
	for player in video_players:
		if player.is_playing():
			playing_video_players.append(player)
	if playing_players.is_empty() and playing_video_players.is_empty():
		return
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	transition_tween.set_trans(Tween.TRANS_SINE)
	for player in playing_players:
		transition_tween.tween_property(player, "volume_db", -30.0, 0.25)
	for player in playing_video_players:
		transition_tween.tween_property(player, "volume_db", -30.0, 0.25)


func _restore_menu_volume() -> void:
	var target := clampf(featured_song.audio_gain_db, -18.0, 6.0) if featured_song != null else 0.0
	for index in range(players.size()):
		if index != active_player_index and players[index].playing:
			_stop_faded_player(players[index])
	for index in range(video_players.size()):
		if index != active_video_player_index and video_players[index].is_playing():
			_stop_faded_video_player(video_players[index])
	var active_player: AudioStreamPlayer
	var active_video_player: VideoStreamPlayer
	if active_player_index >= 0 and players[active_player_index].playing:
		active_player = players[active_player_index]
	if using_video_preview and active_video_player_index >= 0 and video_players[active_video_player_index].is_playing():
		active_video_player = video_players[active_video_player_index]
	if active_player == null and active_video_player == null:
		return
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	transition_tween.set_trans(Tween.TRANS_SINE)
	if active_player != null:
		transition_tween.tween_property(players[active_player_index], "volume_db", target, 0.55)
	if active_video_player != null:
		transition_tween.tween_property(video_players[active_video_player_index], "volume_db", target, 0.55)


func _play_featured_song() -> void:
	if featured_song == null or song_manager == null:
		_fade_out_players()
		return
	featured_audio_available = _resolve_featured_audio(featured_song)
	featured_song_changed.emit(featured_song, featured_audio_available)
	if featured_song.audio != null:
		var start := 0.0
		var end := _get_full_song_duration(featured_song)
		if active_player_index >= 0:
			var active := players[active_player_index]
			if active.playing and active.stream == featured_song.audio:
				preview_start = start
				preview_end = end
				_restore_menu_volume()
				return
		_start_crossfade(featured_song, start, end, CROSSFADE_SECONDS)
		return
	if featured_song.background_video != null:
		var video_start := maxf(featured_song.background_video_start_seconds, 0.0)
		var video_end := video_start + maxf(featured_song.duration_seconds, 0.0)
		var active_video := _get_active_video_player()
		if (
			using_video_preview
			and active_video != null
			and active_video.is_playing()
			and active_video.stream == featured_song.background_video
		):
			preview_start = video_start
			preview_end = video_end
			_restore_menu_volume()
			return
		_start_video_preview(featured_song, video_start, video_end)
		return
	if not featured_audio_available:
		_fade_out_players()
		return


func _resolve_featured_audio(song: SongData) -> bool:
	if song == null or song_manager == null:
		return false
	if song_manager.ensure_song_audio_loaded(song):
		return true
	song_manager.ensure_song_media_loaded(song)
	return song.background_video != null


func _start_crossfade(
	song: SongData,
	start_seconds: float,
	end_seconds: float,
	fade_seconds: float
) -> void:
	if players.is_empty() or song == null or song.audio == null:
		return
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	var next_index := 0 if active_player_index != 0 else 1
	var next_player := players[next_index]
	var previous_player: AudioStreamPlayer
	if active_player_index >= 0:
		previous_player = players[active_player_index]
	next_player.stop()
	next_player.stream = song.audio
	next_player.volume_db = PREVIEW_SILENT_DB
	next_player.play(start_seconds)
	active_player_index = next_index
	preview_start = start_seconds
	preview_end = end_seconds
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(
		next_player,
		"volume_db",
		clampf(song.audio_gain_db, -18.0, 6.0),
		fade_seconds
	)
	using_video_preview = false
	for video_player in video_players:
		if video_player.is_playing():
			fade_tween.tween_property(video_player, "volume_db", PREVIEW_SILENT_DB, fade_seconds)
			fade_tween.finished.connect(_stop_faded_video_player.bind(video_player))
	if previous_player != null and previous_player.playing:
		fade_tween.tween_property(
			previous_player,
			"volume_db",
			PREVIEW_SILENT_DB,
			fade_seconds
		)
		fade_tween.finished.connect(_stop_faded_player.bind(previous_player))


func _start_video_preview(song: SongData, start_seconds: float, end_seconds: float) -> void:
	if song == null or song.background_video == null:
		return
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	var previous_player: AudioStreamPlayer
	if active_player_index >= 0:
		previous_player = players[active_player_index]
	var previous_video_player := _get_active_video_player()
	var next_index := 0 if active_video_player_index != 0 else 1
	var next_video_player := video_players[next_index]
	next_video_player.stop()
	next_video_player.stream = song.background_video
	next_video_player.volume_db = PREVIEW_SILENT_DB
	next_video_player.play()
	next_video_player.stream_position = start_seconds
	active_video_player_index = next_index
	using_video_preview = true
	active_player_index = -1
	preview_start = start_seconds
	preview_end = end_seconds
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(
		next_video_player,
		"volume_db",
		clampf(song.audio_gain_db, -18.0, 6.0),
		CROSSFADE_SECONDS
	)
	if previous_video_player != null and previous_video_player.is_playing():
		fade_tween.tween_property(
			previous_video_player,
			"volume_db",
			PREVIEW_SILENT_DB,
			CROSSFADE_SECONDS
		)
		fade_tween.finished.connect(_stop_faded_video_player.bind(previous_video_player))
	if previous_player != null and previous_player.playing:
		fade_tween.tween_property(
			previous_player,
			"volume_db",
			PREVIEW_SILENT_DB,
			CROSSFADE_SECONDS
		)
		fade_tween.finished.connect(_stop_faded_player.bind(previous_player))


func _stop_faded_player(player: AudioStreamPlayer) -> void:
	if player != null and is_instance_valid(player):
		player.stop()
		player.stream = null
		player.volume_db = PREVIEW_SILENT_DB


func _stop_faded_video_player(player: VideoStreamPlayer) -> void:
	if player != null and is_instance_valid(player):
		player.stop()
		player.stream = null
		player.volume_db = PREVIEW_SILENT_DB
		for index in range(video_players.size()):
			if video_players[index] == player and active_video_player_index == index:
				active_video_player_index = -1


func _fade_out_players() -> void:
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	var playing_players: Array[AudioStreamPlayer] = []
	for player in players:
		if player.playing:
			playing_players.append(player)
	var playing_video_players: Array[VideoStreamPlayer] = []
	for player in video_players:
		if player.is_playing():
			playing_video_players.append(player)
	if playing_players.is_empty() and playing_video_players.is_empty():
		active_player_index = -1
		active_video_player_index = -1
		using_video_preview = false
		return
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	for player in playing_players:
		fade_tween.tween_property(player, "volume_db", PREVIEW_SILENT_DB, 0.3)
	for player in playing_video_players:
		fade_tween.tween_property(
			player,
			"volume_db",
			PREVIEW_SILENT_DB,
			0.3
		)
		fade_tween.finished.connect(_stop_faded_video_player.bind(player))
	fade_tween.finished.connect(_stop_all_players)


func _stop_all_players() -> void:
	for player in players:
		player.stop()
		player.stream = null
		player.volume_db = PREVIEW_SILENT_DB
	for video_player in video_players:
		video_player.stop()
		video_player.stream = null
		video_player.volume_db = PREVIEW_SILENT_DB
	active_player_index = -1
	active_video_player_index = -1
	using_video_preview = false


func _process(_delta: float) -> void:
	if active_scene_name not in MENU_SCREENS:
		return
	if pending_start_at_msec > 0:
		if Time.get_ticks_msec() >= pending_start_at_msec:
			pending_start_at_msec = 0
			_play_featured_song()
		return
	if using_video_preview:
		var active_video := _get_active_video_player()
		if (
			active_video != null
			and active_video.is_playing()
			and preview_end > preview_start
			and active_video.stream_position >= preview_end - 0.04
		):
			choose_random_song()
		return
	if active_player_index < 0:
		return
	var player := players[active_player_index]
	if not player.playing or preview_end <= preview_start:
		return
	if player.get_playback_position() >= preview_end - 0.04:
		choose_random_song()


func _on_player_finished(player_index: int) -> void:
	if (
		player_index == active_player_index
		and active_scene_name in MENU_SCREENS
		and featured_song != null
		and featured_audio_available
		and pending_start_at_msec == 0
	):
		choose_random_song()


func _on_video_preview_finished(player_index: int) -> void:
	if (
		player_index == active_video_player_index
		and using_video_preview
		and active_scene_name in MENU_SCREENS
		and pending_start_at_msec == 0
	):
		choose_random_song()


func _get_active_video_player() -> VideoStreamPlayer:
	if active_video_player_index < 0 or active_video_player_index >= video_players.size():
		return null
	return video_players[active_video_player_index]


func get_playback_position_seconds() -> float:
	if pending_start_at_msec > 0:
		return 0.0
	if using_video_preview:
		var active_video := _get_active_video_player()
		if active_video != null and active_video.is_playing():
			return maxf(active_video.stream_position - preview_start, 0.0)
	elif active_player_index >= 0 and players[active_player_index].playing:
		return maxf(players[active_player_index].get_playback_position(), 0.0)
	return 0.0


func get_featured_duration_seconds() -> float:
	if featured_song == null:
		return 0.0
	return _get_full_song_duration(featured_song)


func _get_full_song_duration(song: SongData) -> float:
	if song == null:
		return 0.0
	if song.audio != null:
		var stream_length := song.audio.get_length()
		if stream_length > 0.0:
			return stream_length
	return maxf(song.duration_seconds, 0.0)
