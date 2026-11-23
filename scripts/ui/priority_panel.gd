class_name PriorityPanel
extends PanelContainer
## HUD grid of work priorities: one row per pawn, one column per work type. Left-click a
## cell to cycle blank, 1, 2, 3, 4; right-click cycles the other way. Each cell's corner
## shows the pawn's skill level in that work. A Manager checkbox by each name picks the
## manager (one at a time), with their Managing level beside it.

signal priority_change_requested(pawn: Pawn, work_type: WorkType, priority: int)
## The player ticked (on) or unticked a pawn's Manager box.
signal manager_change_requested(pawn: Pawn, on: bool)

const CELL_SIZE := Vector2(52, 28)
const FIRST_COLOR := Color(0.45, 0.85, 0.4)
const SKILL_COLOR := Color(0.65, 0.7, 0.8)
const SKILL_FONT_SIZE: int = 10

## The grid's cells, with the pawn and work type of each (same order), so their tooltips can
## keep up with practice.
var _cells: Array[Button] = []
var _cell_pawns: Array[Pawn] = []
var _cell_types: Array[WorkType] = []

@onready var _grid: GridContainer = %Grid


func _process(_delta: float) -> void:
	if not visible:
		return
	for i: int in _cells.size():
		if _cells[i] is CheckBox:
			_cells[i].tooltip_text = _manager_tooltip(_cell_pawns[i], _cell_types[i])
		else:
			_cells[i].tooltip_text = _tooltip(_cell_pawns[i], _cell_types[i])


## `managing` is the Managing skill, shown by each Manager box (null hides the boxes).
func show_priorities(pawns: Array[Pawn], work_types: Array[WorkType], managing: WorkType = null) -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cells.clear()
	_cell_pawns.clear()
	_cell_types.clear()
	var manager_column: int = 1 if managing != null else 0
	_grid.columns = work_types.size() + 1 + manager_column

	_grid.add_child(Label.new())
	if managing != null:
		var manager_header := Label.new()
		manager_header.text = "Manager"
		manager_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grid.add_child(manager_header)
	for work_type: WorkType in work_types:
		var header := Label.new()
		header.text = work_type.display_name
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grid.add_child(header)

	for pawn: Pawn in pawns:
		var name_label := Label.new()
		name_label.text = pawn.display_name
		_grid.add_child(name_label)
		if managing != null:
			_grid.add_child(_make_manager_box(pawn, managing))
		for work_type: WorkType in work_types:
			_grid.add_child(_make_cell(pawn, work_type))


## A checkbox making the pawn the manager, with their Managing level in the corner.
func _make_manager_box(pawn: Pawn, managing: WorkType) -> CheckBox:
	var box := CheckBox.new()
	box.custom_minimum_size = CELL_SIZE
	box.focus_mode = Control.FOCUS_NONE
	box.button_pressed = pawn.is_manager
	box.tooltip_text = _manager_tooltip(pawn, managing)
	_add_skill_label(box, pawn.get_skill(managing))
	box.toggled.connect(func(on: bool) -> void: manager_change_requested.emit(pawn, on))
	_cells.append(box)
	_cell_pawns.append(pawn)
	_cell_types.append(managing)
	return box


func _add_skill_label(cell: Control, level: int) -> void:
	var skill := Label.new()
	skill.text = str(level)
	skill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill.add_theme_font_size_override(&"font_size", SKILL_FONT_SIZE)
	skill.add_theme_color_override(&"font_color", SKILL_COLOR)
	skill.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 3)
	cell.add_child(skill)


func _make_cell(pawn: Pawn, work_type: WorkType) -> Button:
	var priority: int = pawn.get_priority(work_type)
	var cell := Button.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.focus_mode = Control.FOCUS_NONE
	cell.text = str(priority) if priority > 0 else ""
	if priority == 1:
		cell.add_theme_color_override(&"font_color", FIRST_COLOR)
		cell.add_theme_color_override(&"font_hover_color", FIRST_COLOR)
	cell.tooltip_text = _tooltip(pawn, work_type)
	_cells.append(cell)
	_cell_pawns.append(pawn)
	_cell_types.append(work_type)
	if work_type.has_skill:
		_add_skill_label(cell, pawn.get_skill(work_type))
	cell.gui_input.connect(_on_cell_input.bind(pawn, work_type))
	return cell


## The cell's tooltip: priority, then skill level and practice toward the next level.
func _tooltip(pawn: Pawn, work_type: WorkType) -> String:
	var priority: int = pawn.get_priority(work_type)
	var text: String = "%s: %s" % [
		work_type.display_name, "priority %d" % priority if priority > 0 else "never"
	]
	if work_type.has_skill:
		text += "\n" + _skill_text(pawn, work_type)
	return text


func _manager_tooltip(pawn: Pawn, managing: WorkType) -> String:
	var role: String = "Manager" if pawn.is_manager else "Not the manager"
	return "%s (quotes each order's wait)\n%s %s" % [role, managing.display_name, _skill_text(pawn, managing)]


## "Skill 5 (12/60 min practice to next)", or just the level at the top.
func _skill_text(pawn: Pawn, work_type: WorkType) -> String:
	var level: int = pawn.get_skill(work_type)
	var text: String = "Skill %d" % level
	if level < pawn.skill_rules.max_level:
		text += " (%d/%d min practice to next)" % [
			int(pawn.get_practice(work_type)), int(pawn.skill_rules.minutes_to_next(level))
		]
	return text


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
