extends "res://tests/test_base.gd"
## The schedule window: the bottom bar's Schedule button opens it; clicking a cell flips it
## between Work and Off (dragging flips more), and dragging a marker on the Hours bar
## moves that hour.


func _init() -> void:
	keep_schedules = true


func _start() -> void:
	stop_random_orders()
	var hud: Hud = world.get_node("Hud")
	var bar: BottomBar = hud.get_node("BottomBar")
	var panel: SchedulePanel = hud.get_node("SchedulePanel")
	bar.get_button(BottomBar.SCHEDULE).toggled.emit(true)
	if not panel.visible or hud.get_node("PriorityPanel").visible:
		fail("the Schedule button didn't open the schedule window alone")
		return
	var grid: ScheduleGrid = panel.get_node("%Grid")
	var opener: Pawn = world.get_node("Entities/Pawn2")
	var row: int = work.get_pawns().find(opener)

	# The opener works 09:00: pressing there turns it Off, and dragging on to 09:30 does too.
	var y: float = grid._get_rows_top() + (row + 0.5) * ScheduleGrid.CELL.y
	_press(grid, Vector2(grid._minute_x(9 * 60 + 5), y), true)
	_move(grid, Vector2(grid._minute_x(9 * 60 + 35), y))
	_press(grid, Vector2(grid._minute_x(9 * 60 + 35), y), false)
	if opener.schedule.is_working_at(9 * 60) or opener.schedule.is_working_at(9 * 60 + 30) \
			or not opener.schedule.is_working_at(10 * 60):
		fail("clicking and dragging over 09:00-10:00 didn't take exactly those half hours off")
		return
	# Clicking the Off cell turns it back to Work.
	_press(grid, Vector2(grid._minute_x(9 * 60 + 5), y), true)
	_press(grid, Vector2(grid._minute_x(9 * 60 + 5), y), false)
	if not opener.schedule.is_working_at(9 * 60):
		fail("clicking an Off cell didn't put 09:00 back on")
		return

	# Drag the closing marker from 22:00 to 23:00.
	var bar_y: float = ScheduleGrid.HEADER_HEIGHT + ScheduleGrid.BAR_HEIGHT / 2.0
	_press(grid, Vector2(grid._minute_x(22 * 60), bar_y), true)
	_move(grid, Vector2(grid._minute_x(23 * 60), bar_y))
	_press(grid, Vector2(grid._minute_x(23 * 60), bar_y), false)
	if clock.hours.close_minute != 23 * 60 or clock.day_end_minute != 23 * 60:
		fail("dragging closing to 23:00 left it at %s (day ends %s)" % [ShopClock.format_time(clock.hours.close_minute), ShopClock.format_time(clock.day_end_minute)])
		return
	pass_test("the schedule window paints shifts and moves the hours")


func _press(grid: Control, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	grid._gui_input(event)


func _move(grid: Control, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	grid._gui_input(event)
