extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app_scene := load("res://src/App.tscn") as PackedScene
	_expect(app_scene != null, "App se puede cargar para probar servicios en línea")
	if app_scene == null:
		_finish()
		return
	var app := app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	var online := app.get_node("Managers/OnlineContentManager") as OnlineContentManager
	_expect(online != null, "OnlineContentManager está disponible")
	if online == null:
		_finish()
		return

	var catalog_start := online.request_catalog()
	_expect(catalog_start == OK, "La consulta del catálogo puede iniciarse")
	if catalog_start == OK:
		var catalog_result: Dictionary = await online.catalog_received
		_expect(bool(catalog_result.get("ok", false)), "El catálogo remoto o su respaldo local se valida")
		_expect(catalog_result.get("entries", null) is Array, "El catálogo entrega una lista de canciones")

	var update_start := OK if online.has_checked_latest else online.request_latest_release()
	_expect(update_start in [OK, ERR_BUSY], "La comprobación de versiones puede iniciarse")
	if update_start in [OK, ERR_BUSY]:
		var update_result: Dictionary = (
			{"ok": true, "no_public_release": online.latest_release.is_empty()}
			if online.has_checked_latest
			else await online.update_checked
		)
		_expect(bool(update_result.get("ok", false)), "GitHub responde aunque todavía no haya una Release pública")
		_expect(
			bool(update_result.get("no_public_release", false))
			or update_result.has("update_available"),
			"La respuesta distingue ausencia de Release y disponibilidad de actualización"
		)
	current_scene = null
	app.queue_free()
	await process_frame
	await process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures.is_empty():
		print("ONLINE HTTP INTEGRATION TESTS PASSED")
		quit(0)
	else:
		push_error("ONLINE HTTP INTEGRATION TESTS FAILED: %s" % failures)
		quit(1)
