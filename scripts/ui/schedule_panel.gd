class_name SchedulePanel
extends PanelContainer
## HUD window for staff shifts and the shop's hours: Work and Off brushes over a
## ScheduleGrid. Passes the player's changes up; it changes nothing itself.

signal slot_change_requested(pawn: Pawn, slot: int, on: bool)
signal mark_change_requested(mark: ShopHours.Mark, minute: int)

@onready var _grid: ScheduleGrid = %Grid
@onready var _work_brush: Button = %WorkBrush
@onready var _off_brush: Button = %OffBrush


func _ready() -> void:
	# The two brushes share a ButtonGroup: one is always picked.
	_work_brush.pressed.connect(func() -> void: _grid.brush = true)
	_off_brush.pressed.connect(func() -> void: _grid.brush = false)
	_grid.slot_change_requested.connect(slot_change_requested.emit)
	_grid.mark_change_requested.connect(mark_change_requested.emit)


func show_schedules(pawns: Array[Pawn], hours: ShopHours, now_minute: int) -> void:
	_grid.show_schedules(pawns, hours, now_minute)
