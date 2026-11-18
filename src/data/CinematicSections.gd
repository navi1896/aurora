extends RefCounted

const FADE_SECONDS := 0.35
const MIN_SECTION_SECONDS := 7.0


static func is_valid(value: Variant) -> bool:
	if not (value is Array):
		return false
	for section in value:
		if not (section is Dictionary):
			return false
		for key in ["start", "end"]:
			var number: Variant = section.get(key)
			if not (number is int or number is float) or not is_finite(float(number)):
				return false
		if float(section.start) < 0.0 or float(section.end) - float(section.start) < MIN_SECTION_SECONDS:
			return false
	return true


static func normalize(value: Array) -> Array[Dictionary]:
	return _normalize_ranges(value, MIN_SECTION_SECONDS)


static func _normalize_ranges(value: Array, minimum_length: float) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	for section in value:
		if not (section is Dictionary):
			continue
		var start_value: Variant = section.get("start", null)
		var end_value: Variant = section.get("end", null)
		if not (start_value is int or start_value is float) or not (end_value is int or end_value is float):
			continue
		var start := float(start_value)
		var end := float(end_value)
		if not is_finite(start) or not is_finite(end) or start < 0.0 or end - start < minimum_length or end <= start:
			continue
		sorted.append({"start": snappedf(start, 0.001), "end": snappedf(end, 0.001)})
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.start < b.start)
	var result: Array[Dictionary] = []
	for section in sorted:
		if not result.is_empty() and float(section.start) <= float(result.back().end):
			result.back().end = maxf(float(result.back().end), float(section.end))
		else:
			result.append(section)
	return result


static func safe_sections(sections: Array, notes: Array, travel: float, miss_window: float) -> Array[Dictionary]:
	# Reserve the whole approach and hold, even when a note is missed. Restore the
	# frame before the first note enters, independently of score or input timing.
	var blocked: Array = []
	for note in notes:
		blocked.append({"start": maxf(0.0, float(note.time) - travel),
			"end": float(note.time) + float(note.get("duration", 0.0)) + miss_window})
	var protected_ranges := _normalize_ranges(blocked, 0.0)
	var result: Array[Dictionary] = []
	for section in normalize(sections):
		var cursor := float(section.start)
		var end := float(section.end)
		for guard in protected_ranges:
			if float(guard.end) <= cursor:
				continue
			if float(guard.start) >= end:
				break
			if float(guard.start) - cursor >= MIN_SECTION_SECONDS:
				result.append({"start": cursor, "end": minf(float(guard.start), end)})
			cursor = maxf(cursor, float(guard.end))
			if cursor >= end:
				break
		if end - cursor >= MIN_SECTION_SECONDS:
			result.append({"start": cursor, "end": end})
	return result


static func opacity_at(sections: Array, seconds: float) -> float:
	for section in sections:
		var start := float(section.start)
		var end := float(section.end)
		if seconds >= start and seconds < end:
			var fade := minf(FADE_SECONDS, (end - start) * 0.5)
			return 1.0 - smoothstep(0.0, fade, minf(seconds - start, end - seconds))
	return 1.0
