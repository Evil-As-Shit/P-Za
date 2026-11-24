class_name SchedulePanel
extends PanelContainer
## HUD window for staff shifts and the shop's hours: a Work/Off color key over a
## ScheduleGrid. Passes the player's changes up; it changes nothing itself.

signal slot_change_requested(pawn: Pawn, slot: int, on: bool)
signal mark_change_requested(mark: ShopHours.Mark, minute: int)

@onready var _grid: ScheduleGrid = %Grid


func _ready() -> void:
	# The key's swatches use the grid's own cell colors.
	(%WorkSwatch as ColorRect).color = ScheduleGrid.WORK_COLOR
	(%OffSwatch as ColorRect).color = ScheduleGrid.OFF_COLOR
	_grid.slot_change_requested.connect(slot_change_requested.emit)
	_grid.mark_change_requested.connect(mark_change_requested.emit)


func show_schedules(pawns: Array[Pawn], hours: ShopHours, now_minute: int) -> void:
	_grid.show_schedules(pawns, hours, now_minute)
