extends RefCounted

class_name ChartEditHistory

const DEFAULT_LIMIT := 100

var _history_limit := DEFAULT_LIMIT
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _current_state := EditorChartState.new()
var _saved_state := EditorChartState.new()


func _init(max_entries: int = DEFAULT_LIMIT) -> void:
	_history_limit = maxi(max_entries, 1)


func initialize(initial_state: EditorChartState) -> void:
	_current_state = (
		initial_state.duplicate_state()
		if initial_state != null
		else EditorChartState.new()
	)
	_saved_state = _current_state.duplicate_state()
	_undo_stack.clear()
	_redo_stack.clear()


func clear(initial_state: EditorChartState = null) -> void:
	initialize(initial_state)


func commit(next_state: EditorChartState, label: String = "") -> bool:
	if next_state == null or _current_state.state_equals(next_state):
		return false
	_undo_stack.append(
		{
			"before": _current_state.duplicate_state(),
			"after": next_state.duplicate_state(),
			"label": label,
		}
	)
	_current_state = next_state.duplicate_state()
	_redo_stack.clear()
	_trim_undo_stack()
	return true


func undo() -> EditorChartState:
	if not can_undo():
		return get_current_state()
	var entry: Dictionary = _undo_stack.pop_back()
	_redo_stack.append(entry)
	var previous_state := entry.get("before") as EditorChartState
	_current_state = previous_state.duplicate_state()
	return get_current_state()


func redo() -> EditorChartState:
	if not can_redo():
		return get_current_state()
	var entry: Dictionary = _redo_stack.pop_back()
	_undo_stack.append(entry)
	var next_state := entry.get("after") as EditorChartState
	_current_state = next_state.duplicate_state()
	_trim_undo_stack()
	return get_current_state()


func get_current_state() -> EditorChartState:
	return _current_state.duplicate_state()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func get_undo_label() -> String:
	if not can_undo():
		return ""
	return str(_undo_stack.back().get("label", ""))


func get_redo_label() -> String:
	if not can_redo():
		return ""
	return str(_redo_stack.back().get("label", ""))


func mark_saved() -> void:
	_saved_state = _current_state.duplicate_state()


func is_dirty() -> bool:
	return not _current_state.document_equals(_saved_state)


func set_history_limit(max_entries: int) -> void:
	_history_limit = maxi(max_entries, 1)
	_trim_undo_stack()


func get_history_limit() -> int:
	return _history_limit


func get_undo_count() -> int:
	return _undo_stack.size()


func get_redo_count() -> int:
	return _redo_stack.size()


func _trim_undo_stack() -> void:
	while _undo_stack.size() > _history_limit:
		_undo_stack.pop_front()
