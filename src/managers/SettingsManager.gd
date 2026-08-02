extends Node

class_name SettingsManager

const SUPPORTED_LANGUAGES := ["es", "en"]

signal setting_changed(key: String, value)
signal settings_reset

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_SAVE_DEBOUNCE_SECONDS := 0.25

const DEFAULT_SETTINGS := {
	"language": "es",
	"master_volume": 1.0,
	"menu_music_volume": 0.58,
	"music_volume": 0.85,
	"sfx_volume": 0.9,
	"note_speed": 5.5,
	"key_sounds_enabled": false,
	"background_animation_enabled": true,
	"background_animation_intensity": 3,
	"background_dim": 0.46,
	"lane_opacity": 0.82,
	"show_lane_labels": true,
	"show_hit_effects": true,
	"timing_offset_ms": 0,
	"screen_shake_enabled": true,
	"reduced_motion": false,
	"window_mode": "windowed",
	"resolution": "1280x720",
	"vsync_enabled": true,
	"fps_limit": 120,
	"graphics_quality": "high",
	"favorite_song_ids": [],
	"recent_song_ids": [],
	"last_video_directory": "",
	"last_audio_directory": "",
	"last_package_directory": "",
	"last_package_export_directory": "",
	"lane_bindings": {
		"4": [KEY_D, KEY_F, KEY_J, KEY_K],
		"6": [KEY_S, KEY_D, KEY_F, KEY_J, KEY_K, KEY_L],
		"8": [KEY_A, KEY_S, KEY_D, KEY_F, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON],
	},
	"controller_bindings": {
		"actions": {
			"confirm": JOY_BUTTON_A,
			"back": JOY_BUTTON_B,
			"pause": JOY_BUTTON_START,
			"preview": JOY_BUTTON_Y,
			"delete": JOY_BUTTON_X,
		},
		"4": [
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_RIGHT,
			JOY_BUTTON_X,
			JOY_BUTTON_B,
		],
		"6": [
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_RIGHT,
			JOY_BUTTON_X,
			JOY_BUTTON_Y,
			JOY_BUTTON_B,
		],
		"8": [
			JOY_BUTTON_LEFT_SHOULDER,
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_RIGHT,
			JOY_BUTTON_X,
			JOY_BUTTON_Y,
			JOY_BUTTON_B,
			JOY_BUTTON_RIGHT_SHOULDER,
		],
	},
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var settings_save_timer: Timer
var settings_save_pending := false


func _ready() -> void:
	settings_save_timer = Timer.new()
	settings_save_timer.one_shot = true
	settings_save_timer.wait_time = SETTINGS_SAVE_DEBOUNCE_SECONDS
	settings_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_save_timer.timeout.connect(save_settings)
	add_child(settings_save_timer)
	load_settings()
	apply_language_setting()
	call_deferred("apply_all_settings")


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in parsed.keys():
			settings[key] = parsed[key]
	_validate_settings()


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(settings, "\t"))
	file.flush()
	settings_save_pending = false


func _queue_settings_save() -> void:
	settings_save_pending = true
	if settings_save_timer == null or not is_inside_tree():
		save_settings()
		return
	settings_save_timer.start()


func get_setting(key: String, default = null):
	return settings.get(key, default)


func set_setting(key: String, value, apply_immediately: bool = true) -> void:
	settings[key] = value
	_validate_setting(key)
	_queue_settings_save()
	if apply_immediately:
		_apply_setting(key)
	setting_changed.emit(key, settings[key])


func reset_to_defaults() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	if settings_save_timer != null:
		settings_save_timer.stop()
	save_settings()
	apply_all_settings()
	settings_reset.emit()


func _exit_tree() -> void:
	if settings_save_pending:
		save_settings()


func apply_all_settings() -> void:
	apply_language_setting()
	apply_audio_settings()
	apply_display_settings()
	apply_graphics_settings()


func apply_language_setting() -> void:
	TranslationServer.set_locale(str(get_setting("language", "es")))


func apply_audio_settings() -> void:
	_set_bus_volume("Master", float(get_setting("master_volume", 1.0)))
	_set_bus_volume("MenuMusic", float(get_setting("menu_music_volume", 0.58)))
	_set_bus_volume("Music", float(get_setting("music_volume", 0.85)))
	_set_bus_volume("SFX", float(get_setting("sfx_volume", 0.9)))


func apply_display_settings() -> void:
	var mode := str(get_setting("window_mode", "windowed"))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, mode == "borderless")
	match mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if mode == "windowed":
				var requested_resolution := _parse_resolution(str(get_setting("resolution", "1280x720")))
				var screen_index := DisplayServer.window_get_current_screen()
				var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
				var safe_resolution := _fit_resolution_to_rect(requested_resolution, usable_rect)
				DisplayServer.window_set_size(safe_resolution)
				var centered_position := usable_rect.position + Vector2i(
					int((usable_rect.size.x - safe_resolution.x) / 2.0),
					int((usable_rect.size.y - safe_resolution.y) / 2.0)
				)
				DisplayServer.window_set_position(centered_position)

	var vsync_mode := DisplayServer.VSYNC_ENABLED if bool(get_setting("vsync_enabled", true)) else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	Engine.max_fps = int(get_setting("fps_limit", 120))


func apply_graphics_settings() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	match str(get_setting("graphics_quality", "high")):
		"low":
			viewport.msaa_2d = Viewport.MSAA_DISABLED
			viewport.use_debanding = false
		"medium":
			viewport.msaa_2d = Viewport.MSAA_2X
			viewport.use_debanding = true
		_:
			viewport.msaa_2d = Viewport.MSAA_4X
			viewport.use_debanding = true


func _apply_setting(key: String) -> void:
	if key == "language":
		apply_language_setting()
	elif key in ["master_volume", "menu_music_volume", "music_volume", "sfx_volume"]:
		apply_audio_settings()
	elif key in ["window_mode", "resolution", "vsync_enabled", "fps_limit"]:
		apply_display_settings()
	elif key == "graphics_quality":
		apply_graphics_settings()


func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var safe_value := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, safe_value <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(safe_value, 0.001)))


func _parse_resolution(value: String) -> Vector2i:
	var parts := value.to_lower().split("x")
	if parts.size() != 2:
		return Vector2i(1280, 720)
	var width := maxi(int(parts[0]), 960)
	var height := maxi(int(parts[1]), 540)
	return Vector2i(width, height)


func _fit_resolution_to_rect(requested: Vector2i, usable_rect: Rect2i) -> Vector2i:
	return Vector2i(
		mini(requested.x, usable_rect.size.x),
		mini(requested.y, usable_rect.size.y)
	)


func _validate_settings() -> void:
	for key in settings.keys():
		_validate_setting(str(key))


func _validate_setting(key: String) -> void:
	match key:
		"language":
			if str(settings[key]) not in SUPPORTED_LANGUAGES:
				settings[key] = "es"
		"master_volume", "menu_music_volume", "music_volume", "sfx_volume":
			settings[key] = clampf(float(settings[key]), 0.0, 1.0)
		"note_speed":
			settings[key] = clampf(float(settings[key]), 1.0, 10.0)
		"background_animation_intensity":
			settings[key] = clampi(int(settings[key]), 1, 5)
		"background_dim":
			settings[key] = clampf(float(settings[key]), 0.0, 0.9)
		"lane_opacity":
			settings[key] = clampf(float(settings[key]), 0.25, 1.0)
		"timing_offset_ms":
			settings[key] = clampi(int(settings[key]), -200, 200)
		"fps_limit":
			settings[key] = int(settings[key])
			if int(settings[key]) not in [0, 60, 120, 144, 240]:
				settings[key] = 120
		"window_mode":
			if str(settings[key]) not in ["windowed", "borderless", "fullscreen"]:
				settings[key] = "windowed"
		"resolution":
			if str(settings[key]) not in ["1280x720", "1600x900", "1920x1080", "2560x1440"]:
				settings[key] = "1280x720"
		"graphics_quality":
			if str(settings[key]) not in ["low", "medium", "high"]:
				settings[key] = "high"
		"favorite_song_ids", "recent_song_ids":
			if not (settings[key] is Array):
				settings[key] = []
			else:
				var normalized_ids: Array[String] = []
				for raw_id in settings[key]:
					var song_id := str(raw_id).strip_edges()
					if not song_id.is_empty() and song_id not in normalized_ids:
						normalized_ids.append(song_id)
				settings[key] = normalized_ids
		"last_video_directory", "last_audio_directory", "last_package_directory", "last_package_export_directory":
			settings[key] = str(settings[key]).strip_edges()
		"lane_bindings":
			if not (settings[key] is Dictionary):
				settings[key] = DEFAULT_SETTINGS["lane_bindings"].duplicate(true)
		"controller_bindings":
			_validate_controller_bindings()


func _validate_controller_bindings() -> void:
	var defaults: Dictionary = DEFAULT_SETTINGS["controller_bindings"]
	if not (settings.get("controller_bindings") is Dictionary):
		settings["controller_bindings"] = defaults.duplicate(true)
		return

	var bindings: Dictionary = settings["controller_bindings"].duplicate(true)
	var default_actions: Dictionary = defaults["actions"]
	var actions = bindings.get("actions", {})
	if not (actions is Dictionary):
		actions = default_actions.duplicate(true)
	else:
		actions = actions.duplicate(true)
		for action_name in default_actions:
			var button := int(actions.get(action_name, default_actions[action_name]))
			actions[action_name] = clampi(button, JOY_BUTTON_A, JOY_BUTTON_MAX - 1)
	bindings["actions"] = actions

	for mode in [4, 6, 8]:
		var mode_key := str(mode)
		var values = bindings.get(mode_key, defaults[mode_key])
		if not (values is Array) or values.size() != mode:
			bindings[mode_key] = defaults[mode_key].duplicate()
			continue
		var validated: Array[int] = []
		for value in values:
			validated.append(clampi(int(value), JOY_BUTTON_A, JOY_BUTTON_MAX - 1))
		bindings[mode_key] = validated
	settings["controller_bindings"] = bindings
