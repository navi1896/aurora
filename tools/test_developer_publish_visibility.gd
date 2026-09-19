extends SceneTree

const DeveloperRelease = preload("res://src/managers/DeveloperReleaseService.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := DeveloperRelease.new()
	var setup: Dictionary = service.refresh()
	_expect(setup.get("enabled", false), "El perfil local habilita las herramientas de desarrollador")
	_expect(
		service.get_publisher_name() == "Navi1896 / Aurora Project",
		"El perfil local conserva el nombre de publicación"
	)
	var app := (load("res://src/App.tscn") as PackedScene).instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	await process_frame
	await process_frame
	var scene_manager := app.get_node("Managers/SceneManager") as SceneManager
	var menu := scene_manager.current_scene as MainMenu
	_expect(menu != null, "Carga el menú principal")
	if menu != null:
		_expect(
			menu.developer_publish_button.visible,
			"El botón de publicar solo aparece con el perfil local"
		)
		_expect(
			menu.developer_publish_button.text == "PUBLICAR ESTA VERSION",
			"El botón explica la acción de forma clara"
		)
	app.queue_free()
	await process_frame
	print("DEVELOPER PUBLISH VISIBILITY %s" % ("PASSED" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, label: String) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
