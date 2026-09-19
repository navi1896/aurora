extends Control

class_name MainMenu

const DEVELOPER_RELEASE_SERVICE_TYPE := preload(
	"res://src/managers/DeveloperReleaseService.gd"
)

@onready var main_buttons: MainMenuButtons = $MenuMargins/PageLayout/MenuBody/MainButtons
@onready var character_idle: CharacterIdleRig = (
	$MenuMargins/PageLayout/MenuBody/CharacterShowcase/IdleRig
)
@onready var update_status: Label = $MenuMargins/PageLayout/Footer/UpdateStatus
@onready var update_button: Button = $MenuMargins/PageLayout/Footer/UpdateButton
@onready var developer_publish_button: Button = $MenuMargins/PageLayout/Footer/DeveloperPublishButton
@onready var version_label: Label = $MenuMargins/PageLayout/Footer/VersionLabel

var scene_manager: SceneManager
var online_manager: Node
var ui_feedback
var developer_release_service = DEVELOPER_RELEASE_SERVICE_TYPE.new()
var developer_publish_dialog: ConfirmationDialog
var developer_publish_active := false


func _ready() -> void:
	# Connects presentation actions to the application's navigation layer.
	var app := get_tree().current_scene
	if app != null and app.has_node("Managers/SceneManager"):
		scene_manager = app.get_node("Managers/SceneManager")
	if app != null and app.has_node("Managers/OnlineContentManager"):
		online_manager = app.get_node("Managers/OnlineContentManager")
	if app != null:
		ui_feedback = app.get_node_or_null("Managers/UiFeedbackManager")
	version_label.text = "- -  v%s  - -" % str(
		ProjectSettings.get_setting("application/config/version", "")
	)
	main_buttons.action_selected.connect(_on_menu_action_selected)
	main_buttons.focus_changed.connect(character_idle.trigger_selection_pulse)
	update_button.pressed.connect(_on_update_button_pressed)
	_setup_developer_publish_action()
	if online_manager != null:
		online_manager.update_checked.connect(_on_update_checked)
		online_manager.update_download_progress.connect(_on_update_download_progress)
		online_manager.update_download_finished.connect(_on_update_download_finished)
		_refresh_update_state()
		if not online_manager.has_checked_latest:
			call_deferred("_check_for_updates")
	main_buttons.focus_default_button()


func _process(_delta: float) -> void:
	if not developer_publish_active:
		return
	var result: Dictionary = developer_release_service.poll_result()
	if result.is_empty():
		return
	developer_publish_active = false
	developer_publish_button.disabled = false
	if bool(result.get("ok", false)):
		update_status.text = AuroraLocale.text("PUBLICACIÓN COMPLETADA")
		developer_publish_button.text = AuroraLocale.text("PUBLICAR ESTA VERSION")
	else:
		update_status.text = AuroraLocale.text(
			"PUBLICACIÓN DETENIDA // %s" % str(result.get("message", ""))
		)
		developer_publish_button.text = AuroraLocale.text("REVISAR Y REINTENTAR")


func _setup_developer_publish_action() -> void:
	var setup: Dictionary = developer_release_service.refresh()
	if not bool(setup.get("enabled", false)):
		developer_publish_button.hide()
		return
	developer_publish_button.show()
	developer_publish_button.pressed.connect(_on_developer_publish_pressed)
	# Cuando está disponible, se desplaza el estado para que los dos botones no
	# se encimen. Sin perfil local, las copias compartidas siguen igual.
	update_status.offset_left = -810.0
	update_status.offset_right = -520.0
	developer_publish_dialog = ConfirmationDialog.new()
	developer_publish_dialog.title = AuroraLocale.text("PUBLICAR VERSION")
	developer_publish_dialog.dialog_text = AuroraLocale.text(
		"Se exportará Aurora v%s y se creará una publicación en GitHub. Antes se comprobará que el repositorio esté limpio y que tu sesión local de GitHub siga activa. No se guardan contraseñas en el juego."
		% str(ProjectSettings.get_setting("application/config/version", ""))
	)
	developer_publish_dialog.ok_button_text = AuroraLocale.text("PUBLICAR")
	developer_publish_dialog.confirmed.connect(_confirm_developer_publish)
	add_child(developer_publish_dialog)


func _on_developer_publish_pressed() -> void:
	if ui_feedback != null:
		ui_feedback.play_confirm()
	if developer_publish_active or developer_publish_dialog == null:
		return
	developer_publish_dialog.popup_centered(Vector2i(690, 220))


func _confirm_developer_publish() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var result: Dictionary = developer_release_service.start_publish(version)
	if not bool(result.get("ok", false)):
		update_status.text = AuroraLocale.text(str(result.get("message", "")))
		return
	developer_publish_active = true
	developer_publish_button.disabled = true
	developer_publish_button.text = AuroraLocale.text("PUBLICANDO...")
	update_status.text = AuroraLocale.text("PREPARANDO PUBLICACIÓN v%s") % version


func _on_menu_action_selected(action: StringName) -> void:
	if ui_feedback != null:
		ui_feedback.play_confirm()
	match action:
		&"play":
			_load_screen(&"song_select")
		&"settings":
			_load_screen(&"settings")
		&"editor":
			_load_screen(&"editor")
		&"quit":
			get_tree().quit()


func _load_screen(screen_name: StringName) -> void:
	if scene_manager != null:
		scene_manager.load_scene(String(screen_name))


func _check_for_updates() -> void:
	if online_manager == null:
		return
	update_button.disabled = true
	update_button.text = AuroraLocale.text("COMPROBANDO...")
	update_status.text = ""
	if online_manager.request_latest_release() != OK:
		update_button.disabled = false
		update_button.text = AuroraLocale.text("REINTENTAR")


func _on_update_button_pressed() -> void:
	if ui_feedback != null:
		ui_feedback.play_confirm()
	if online_manager == null:
		return
	if not online_manager.downloaded_update_path.is_empty():
		var result: Dictionary = online_manager.apply_downloaded_update()
		if not bool(result.get("ok", false)):
			update_status.text = str(result.get("message", "NO SE PUDO INSTALAR"))
		return
	if bool(online_manager.latest_release.get("update_available", false)):
		if bool(online_manager.latest_release.get("download_available", false)):
			update_button.disabled = true
			update_button.text = AuroraLocale.text("DESCARGANDO...")
			online_manager.download_latest_update()
		else:
			online_manager.open_release_page()
		return
	_check_for_updates()


func _on_update_checked(result: Dictionary) -> void:
	update_button.disabled = false
	if not bool(result.get("ok", false)):
		update_status.text = AuroraLocale.text("SIN CONEXIÓN")
		update_button.text = AuroraLocale.text("REINTENTAR")
		return
	if bool(result.get("no_public_release", false)):
		update_status.text = AuroraLocale.text("SIN VERSIÓN PUBLICADA")
		update_button.text = AuroraLocale.text("BUSCAR ACTUALIZACIÓN")
		return
	_refresh_update_state()


func _refresh_update_state() -> void:
	if online_manager == null:
		return
	var release: Dictionary = online_manager.latest_release
	if release.is_empty():
		update_status.text = ""
		update_button.text = AuroraLocale.text("BUSCAR ACTUALIZACIÓN")
		return
	var version := str(release.get("version", ""))
	if not bool(release.get("update_available", false)):
		update_status.text = AuroraLocale.text("AURORA AL DÍA")
		update_button.text = AuroraLocale.text("BUSCAR ACTUALIZACIÓN")
		return
	update_status.text = AuroraLocale.text("v%s DISPONIBLE") % version
	update_button.text = (
		AuroraLocale.text("DESCARGAR v%s") % version
		if bool(release.get("download_available", false))
		else AuroraLocale.text("VER v%s") % version
	)


func _on_update_download_progress(downloaded: int, total: int) -> void:
	if total <= 0:
		return
	var percent := clampi(roundi(float(downloaded) * 100.0 / float(total)), 0, 100)
	update_status.text = AuroraLocale.text("DESCARGANDO // %d%%") % percent


func _on_update_download_finished(result: Dictionary) -> void:
	update_button.disabled = false
	if not bool(result.get("ok", false)):
		update_status.text = str(result.get("message", "DESCARGA FALLIDA"))
		update_button.text = AuroraLocale.text("REINTENTAR")
		return
	var version := str(online_manager.latest_release.get("version", ""))
	update_status.text = AuroraLocale.text("DESCARGA VERIFICADA")
	update_button.text = AuroraLocale.text("INSTALAR v%s") % version
