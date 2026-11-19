extends Node

class_name SettingsManager

const SUPPORTED_LANGUAGES := ["es", "en"]

signal setting_changed(key: String, value)
signal settings_reset

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_SAVE_DEBOUNCE_SECONDS := 0.25

const DEFAULT_SETTINGS := {
	"language": "es",
	"master_volume": 0.5,
	"music_volume": 0.85,
	"sfx_volume": 0.9,
	"note_speed": 5.5,
	"gameplay_visual_profile": "aurora",
	"custom_gameplay_appearance": {
		"lane_fill": "#091525",
		"lane_divider": "#38d8f2",
		"lane_accent": "#ff62be",
		"left_rail": "#9977ff",
		"note_colors": ["#22ddff", "#ff56c7", "#ffd166", "#72e39a"],
		"note_border": "#f5f8ff",
		"note_shape": "rectangle",
		"note_size": 1.0,
		"lane_inset": 92.0,
		"lane_shape": "rectangle",
		"outline_width": 2,
	},
	"key_sounds_enabled": false,
	"background_animation_enabled": true,
	"background_animation_intensity": 3,
	"background_dim": 0.46,
	"lane_opacity": 0.82,
	"cinematic_sections_enabled": true,
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
	"cloud_sync_directory": "",
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
			"shift_left": JOY_BUTTON_LEFT_STICK,
			"shift_right": JOY_BUTTON_RIGHT_STICK,
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
var settings_loaded := false


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


func ensure_loaded() -> void:
	if not settings_loaded:
		load_settings()


func load_settings() -> void:
	settings_loaded = true
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	var settings_migrated := false
	if parsed is Dictionary:
		for key in parsed.keys():
			settings[key] = parsed[key]
		if parsed.has("menu_music_volume"):
			# Keep the established gameplay music level as the shared setting.
			# Older files without it inherit the former menu level instead.
			if not parsed.has("music_volume"):
				settings["music_volume"] = parsed["menu_music_volume"]
			settings.erase("menu_music_volume")
			settings_migrated = true
	_validate_settings()
	if settings_migrated:
		_queue_settings_save()


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
	_set_bus_volume("Master", float(get_setting("master_volume", 0.5)))
	var music_volume := float(get_setting("music_volume", 0.85))
	_set_bus_volume("MenuMusic", music_volume)
	_set_bus_volume("Music", music_volume)
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

	var vsync_on := bool(get_setting("vsync_enabled", true))
	var vsync_mode := DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	var configured_fps := int(get_setting("fps_limit", 120))
	Engine.max_fps = 0 if vsync_on else configured_fps


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
	elif key in ["master_volume", "music_volume", "sfx_volume"]:
		apply_audio_settings()
	elif key in ["window_mode", "resolution", "vsync_enabled", "fps_limit"]:
		apply_display_settings()
	elif key == "graphics_quality":
		apply_graphics_settings()
	elif key == "cloud_sync_directory":
		var parent := get_parent()
		var song_manager = parent.get_node_or_null("SongManager") if parent != null else null
		if song_manager != null and song_manager.has_method("load_songs"):
			song_manager.load_songs()


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
		"master_volume", "music_volume", "sfx_volume":
			settings[key] = clampf(float(settings[key]), 0.0, 1.0)
		"note_speed":
			settings[key] = clampf(float(settings[key]), 1.0, 10.0)
		"gameplay_visual_profile":
			if str(settings[key]) not in ["aurora", "djmax", "quaver", "fnf", "custom"]:
				settings[key] = "aurora"
		"custom_gameplay_appearance":
			_validate_custom_gameplay_appearance()
		"background_animation_intensity":
			settings[key] = clampi(int(settings[key]), 1, 5)
		"background_dim":
			settings[key] = clampf(float(settings[key]), 0.0, 1.0)
		"lane_opacity":
			settings[key] = clampf(float(settings[key]), 0.0, 1.0)
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
		"last_video_directory", "last_audio_directory", "last_package_directory", "last_package_export_directory", "cloud_sync_directory":
			settings[key] = str(settings[key]).strip_edges()
		"lane_bindings":
			if not (settings[key] is Dictionary):
				settings[key] = DEFAULT_SETTINGS["lane_bindings"].duplicate(true)
		"controller_bindings":
			_validate_controller_bindings()


func _validate_custom_gameplay_appearance() -> void:
	var defaults: Dictionary = DEFAULT_SETTINGS["custom_gameplay_appearance"]
	var raw = settings.get("custom_gameplay_appearance", {})
	var custom: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	for key in defaults:
		if not custom.has(key):
			custom[key] = defaults[key]

	for color_key in ["lane_fill", "lane_divider", "lane_accent", "left_rail", "note_border"]:
		var fallback := Color.from_string(str(defaults[color_key]), Color.WHITE)
		custom[color_key] = Color.from_string(str(custom[color_key]), fallback).to_html(false)

	var default_note_colors: Array = defaults["note_colors"]
	var raw_note_colors = custom.get("note_colors", default_note_colors)
	var note_colors: Array[String] = []
	for index in range(4):
		var fallback := Color.from_string(str(default_note_colors[index]), Color.WHITE)
		var raw_color = raw_note_colors[index] if raw_note_colors is Array and raw_note_colors.size() > index else default_note_colors[index]
		note_colors.append(Color.from_string(str(raw_color), fallback).to_html(false))
	custom["note_colors"] = note_colors
	if str(custom["note_shape"]) not in ["rectangle", "rounded", "pill"]:
		custom["note_shape"] = "rectangle"
	if str(custom["lane_shape"]) not in ["rectangle", "rounded"]:
		custom["lane_shape"] = "rectangle"
	custom["note_size"] = clampf(float(custom["note_size"]), 0.8, 1.5)
	custom["lane_inset"] = clampf(float(custom["lane_inset"]), 48.0, 150.0)
	custom["outline_width"] = clampi(int(custom["outline_width"]), 0, 5)
	settings["custom_gameplay_appearance"] = custom


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
