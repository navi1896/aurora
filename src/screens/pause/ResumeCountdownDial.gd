extends Control

## A small progress arc like the reference, in Aurora's existing palette.
var elapsed := 0.0
var step_seconds := 1.0
var reduced_motion := false
var go := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func begin_step(value: int, seconds: float, reduce_motion: bool) -> void:
	elapsed = 0.0
	step_seconds = maxf(seconds, 0.01)
	reduced_motion = reduce_motion
	go = value == 0
	set_process(not reduced_motion and not go)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if go:
		return
	var unit := minf(size.x / 1672.0, size.y / 941.0)
	var center := size * 0.5
	var progress := 1.0 if reduced_motion else clampf(elapsed / step_seconds, 0.0, 1.0)
	draw_arc(center, 86.0 * unit, -PI * 0.5, PI * 1.5, 64, Color(0.05, 0.80, 1.0, 0.14), 2.0 * unit, true)
	if progress > 0.005:
		draw_arc(center, 86.0 * unit, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, AuroraUi.TEAL, 3.0 * unit, true)
