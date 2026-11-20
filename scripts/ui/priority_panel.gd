class_name PriorityPanel
extends PanelContainer
## HUD grid of work priorities: one row per pawn, one column per work type. Left-click a
## cell to cycle blank, 1, 2, 3, 4; right-click cycles the other way.

signal priority_change_requested(pawn: Pawn, work_type: WorkType, priority: int)

const CELL_SIZE := Vector2(52, 28)
const FIRST_COLOR := Color(0.45, 0.85, 0.4)

@onready var _grid: GridContainer = %Grid


func show_priorities(pawns: Array[Pawn], work_types: Array[WorkType]) -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_grid.columns = work_types.size() + 1

	_grid.add_child(Label.new())
	for work_type: WorkType in work_types:
		var header := Label.new()
		header.text = work_type.display_name
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grid.add_child(header)

	for pawn: Pawn in pawns:
		var name_label := Label.new()
		name_label.text = pawn.display_name
		_grid.add_child(name_label)
		for work_type: WorkType in work_types:
			_grid.add_child(_make_cell(pawn, work_type))


func _make_cell(pawn: Pawn, work_type: WorkType) -> Button:
	var priority: int = pawn.get_priority(work_type)
	var cell := Button.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.focus_mode = Control.FOCUS_NONE
	cell.text = str(priority) if priority > 0 else ""
	if priority == 1:
		cell.add_theme_color_override(&"font_color", FIRST_COLOR)
		cell.add_theme_color_override(&"font_hover_color", FIRST_COLOR)
	cell.tooltip_text = "%s: %s" % [
		work_type.display_name, "priority %d" % priority if priority > 0 else "never"
	]
	cell.gui_input.connect(_on_cell_input.bind(pawn, work_type))
	return cell


func _on_cell_input(event: InputEvent, pawn: Pawn, work_type: WorkType) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	var step: int = 0
	if click.button_index == MOUSE_BUTTON_LEFT:
		step = 1
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		step = -1
	else:
		return
	accept_event()
	var levels: int = Pawn.LOWEST_PRIORITY + 1
	var next: int = posmod(pawn.get_priority(work_type) + step, levels)
	priority_change_requested.emit(pawn, work_type, next)
