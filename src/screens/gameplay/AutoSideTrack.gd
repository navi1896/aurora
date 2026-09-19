extends Control

## Imported side notes are automatic decorations, not judged inputs.
## Draw directly on narrow rails to keep the four playable lanes unchanged.

var notes: Array[Dictionary] = []
var playback_time := 0.0
var travel_time := 2.0
var deck_height := 150.0
var hit_offset := 94.0
var tint := Color(0.08, 0.86, 1.0)
var cursor := 0


func set_playback_time(value: float, travel: float) -> void:
	if value < playback_time:
		cursor = 0
	playback_time = value
	travel_time = maxf(travel, 0.001)
	while cursor < notes.size():
		var note: Dictionary = notes[cursor]
		if float(note["time"]) + float(note["duration"]) + 0.12 >= value:
			break
		cursor += 1
	queue_redraw()


func _draw() -> void:
	if notes.is_empty():
		return
	var bottom := maxf(size.y - deck_height, 100.0)
	var hit_y := maxf(bottom - hit_offset, 100.0)
	draw_rect(Rect2(0, 0, size.x, bottom), Color(tint, 0.08))
	draw_rect(Rect2(0, roundf(hit_y) - 2, size.x, 4), Color(tint, 0.5))
	for index in range(cursor, notes.size()):
		var note: Dictionary = notes[index]
		var start := float(note["time"])
		var duration := float(note["duration"])
		if start + duration + 0.12 < playback_time:
			continue
		if start - playback_time > travel_time:
			break
		var automatic := playback_time >= start
		var head := hit_y if automatic else lerpf(24.0, hit_y, 1.0 - (start - playback_time) / travel_time)
		var remaining := maxf(start + duration - playback_time, 0.0) if automatic else duration
		var height := maxf(remaining / travel_time * (hit_y - 24.0), 8.0)
		var top := maxf(head - height, 0.0)
		var rect := Rect2(2, roundf(top), maxf(size.x - 4, 1.0), maxf(roundf(head - top), 1.0))
		draw_rect(rect, Color(tint, 0.8 if automatic else 0.48))
		draw_rect(Rect2(2, roundf(head) - 2, maxf(size.x - 4, 1.0), 4), tint)
