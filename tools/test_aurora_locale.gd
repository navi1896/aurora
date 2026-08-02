extends SceneTree

const AuroraLocaleType := preload("res://src/ui/AuroraLocale.gd")
const SOURCE_ROOT := "res://src"
const LOCALE_CALL := "AuroraLocale.text("
const IGNORED_LITERAL_KEYS := ["▶", "◀"]

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_literal_coverage()
	_test_placeholder_compatibility()
	_test_representative_english_copy()
	_finish()


func _test_literal_coverage() -> void:
	var script_paths: PackedStringArray = []
	_collect_scripts(SOURCE_ROOT, script_paths)
	var missing: PackedStringArray = []
	var checked := 0
	for script_path in script_paths:
		var source := FileAccess.get_file_as_string(script_path)
		for expression in _extract_locale_call_expressions(source):
			for key in _translation_keys_from_expression(expression):
				if key in IGNORED_LITERAL_KEYS:
					continue
				checked += 1
				if not AuroraLocaleType.ENGLISH.has(key):
					missing.append("%s :: %s" % [script_path, key])
	_expect(
		checked >= 250,
		"La prueba inspecciona todos los textos literales de la interfaz"
	)
	_expect(
		missing.is_empty(),
		"Cada texto literal traducible tiene una entrada inglesa"
	)
	if not missing.is_empty():
		for entry in missing:
			printerr("MISSING LOCALE: %s" % entry)


func _test_placeholder_compatibility() -> void:
	var mismatches: PackedStringArray = []
	for source_key in AuroraLocaleType.ENGLISH:
		var translated := str(AuroraLocaleType.ENGLISH[source_key])
		var source_placeholders := _placeholder_signature(str(source_key))
		var translated_placeholders := _placeholder_signature(translated)
		if source_placeholders != translated_placeholders:
			mismatches.append(
				"%s -> %s" % [source_key, translated]
			)
	_expect(
		mismatches.is_empty(),
		"Las traducciones conservan todos los marcadores de formato"
	)
	if not mismatches.is_empty():
		for entry in mismatches:
			printerr("PLACEHOLDER MISMATCH: %s" % entry)


func _test_representative_english_copy() -> void:
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_expect(
		AuroraLocaleType.text("FORMA DE ONDA") == "WAVEFORM"
		and AuroraLocaleType.text("LISTA") == "READY"
		and AuroraLocaleType.text("MOSTRAR U OCULTAR LA FORMA DE ONDA")
		== "SHOW OR HIDE THE WAVEFORM",
		"La forma de onda y sus estados se muestran en inglés"
	)
	_expect(
		AuroraLocaleType.text("VALIDANDO CALIDAD VISUAL")
		== "CHECKING VISUAL QUALITY"
		and AuroraLocaleType.text("CONVERSIÓN CANCELADA")
		== "CONVERSION CANCELED",
		"La conversión de video informa sus fases en inglés"
	)
	_expect(
		AuroraLocaleType.text("FAVORITAS") == "FAVORITES"
		and AuroraLocaleType.text("PREPARANDO VISTA PREVIA...")
		== "PREPARING PREVIEW...",
		"Los filtros y la vista previa de la biblioteca se traducen"
	)
	TranslationServer.set_locale("es")
	_expect(
		AuroraLocaleType.text("FORMA DE ONDA") == "FORMA DE ONDA",
		"El español continúa usando el texto original"
	)
	TranslationServer.set_locale(previous_locale)


func _collect_scripts(directory_path: String, output: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failures.append("No se pudo abrir %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var child_path := "%s/%s" % [directory_path, entry]
		if directory.current_is_dir():
			_collect_scripts(child_path, output)
		elif entry.ends_with(".gd"):
			output.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _extract_locale_call_expressions(source: String) -> PackedStringArray:
	var expressions: PackedStringArray = []
	var cursor := 0
	while true:
		var call_start := source.find(LOCALE_CALL, cursor)
		if call_start < 0:
			break
		var expression_start := call_start + LOCALE_CALL.length()
		var expression_end := _find_call_end(source, expression_start)
		if expression_end < 0:
			break
		expressions.append(
			source.substr(expression_start, expression_end - expression_start)
		)
		cursor = expression_end + 1
	return expressions


func _find_call_end(source: String, expression_start: int) -> int:
	var depth := 1
	var in_string := false
	var escaped := false
	for index in range(expression_start, source.length()):
		var character := source.substr(index, 1)
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				in_string = false
			continue
		if character == "\"":
			in_string = true
		elif character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return index
	return -1


func _translation_keys_from_expression(expression: String) -> PackedStringArray:
	var constant_value := _constant_string_value(expression)
	if bool(constant_value["valid"]):
		return PackedStringArray([str(constant_value["value"])])
	var candidates: PackedStringArray = []
	for value in _extract_string_literals(expression):
		if _looks_like_inline_translation_key(value):
			candidates.append(value)
	return candidates


func _constant_string_value(expression: String) -> Dictionary:
	var cursor := 0
	var combined := ""
	var found_literal := false
	while true:
		cursor = _skip_whitespace(expression, cursor)
		if cursor >= expression.length() or expression.substr(cursor, 1) != "\"":
			return {"valid": false, "value": ""}
		var literal := _read_string_literal(expression, cursor)
		if not bool(literal["valid"]):
			return {"valid": false, "value": ""}
		found_literal = true
		combined += str(literal["value"])
		cursor = _skip_whitespace(expression, int(literal["end"]) + 1)
		if cursor >= expression.length():
			return {"valid": found_literal, "value": combined}
		if expression.substr(cursor, 1) != "+":
			return {"valid": false, "value": ""}
		cursor += 1
	return {"valid": false, "value": ""}


func _extract_string_literals(expression: String) -> PackedStringArray:
	var values: PackedStringArray = []
	var cursor := 0
	while cursor < expression.length():
		if expression.substr(cursor, 1) != "\"":
			cursor += 1
			continue
		var literal := _read_string_literal(expression, cursor)
		if not bool(literal["valid"]):
			break
		values.append(str(literal["value"]))
		cursor = int(literal["end"]) + 1
	return values


func _read_string_literal(source: String, start: int) -> Dictionary:
	var escaped := false
	for index in range(start + 1, source.length()):
		var character := source.substr(index, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\":
			escaped = true
		elif character == "\"":
			var raw := source.substr(start, index - start + 1)
			var decoded = JSON.parse_string(raw)
			return {
				"valid": typeof(decoded) == TYPE_STRING,
				"value": str(decoded) if typeof(decoded) == TYPE_STRING else "",
				"end": index,
			}
	return {"valid": false, "value": "", "end": source.length()}


func _looks_like_inline_translation_key(value: String) -> bool:
	if value in IGNORED_LITERAL_KEYS or value.is_empty():
		return false
	if value != value.to_upper():
		return false
	for character in value:
		if character.to_lower() != character.to_upper():
			return true
	return false


func _skip_whitespace(source: String, start: int) -> int:
	var cursor := start
	while cursor < source.length() and source.substr(cursor, 1) in [" ", "\t", "\r", "\n"]:
		cursor += 1
	return cursor


func _placeholder_signature(value: String) -> PackedStringArray:
	var expression := RegEx.new()
	var compile_error := expression.compile("%(?:[-+0 #]*\\d*(?:\\.\\d+)?)?[sdif%]")
	if compile_error != OK:
		return PackedStringArray()
	var signature: PackedStringArray = []
	for match_result in expression.search_all(value):
		signature.append(match_result.get_string())
	return signature


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		printerr("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("AURORA LOCALE TESTS PASSED")
		quit(0)
	else:
		printerr("AURORA LOCALE TESTS FAILED: %s" % ", ".join(failures))
		quit(1)
