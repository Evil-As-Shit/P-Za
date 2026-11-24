class_name ScheduleGrid
extends Control
## The schedule grid, drawn: hour numbers, the shop's hours bar (closed, prep, open, last
## orders, closed again) with a draggable marker at each change, then a row per pawn of
## half-hour cells, Work or Off. Clicking or dragging over cells paints them with the
## brush; dragging a marker moves it. The time now is a line down the grid. Reports
## requests; it changes nothing itself.

signal slot_change_requested(pawn: Pawn, slot: int, on: bool)
signal mark_change_requested(mark: ShopHours.Mark, minute: int)

const CELL := Vector2(12, 18)
const NAME_WIDTH: float = 70.0
const HEADER_HEIGHT: float = 14.0
const BAR_HEIGHT: float = 14.0
const GAP: float = 4.0
## How close (in pixels) a press on the bar must be to a marker to grab it.
const GRAB_DISTANCE: float = 6.0
const FONT_SIZE: int = 10

const WORK_COLOR := Color(0.55, 0.55, 0.22)
const OFF_COLOR := Color(0.2, 0.2, 0.24)
const LINE_COLOR := Color(0, 0, 0, 0.5)
const CLOSED_COLOR := Color(0.16, 0.16, 0.18)
const ZONE_COLORS: Array[Color] = [
	Color(0.3, 0.45, 0.7), Color(0.3, 0.6, 0.32), Color(0.8, 0.52, 0.2),
]
const MARKER_COLOR := Color(1, 1, 1, 0.9)
const NOW_COLOR := Color(1.0, 0.3, 0.3, 0.9)
const TEXT_COLOR := Color(0.85, 0.85, 0.85)

## What a left press paints: true for Work.
var brush: bool = true

var _pawns: Array[Pawn] = []
var _hours: ShopHours = null
var _now_minute: int = -1
## What's being dragged: a marker (its Mark), or painting (-1), or nothing (-2).
var _dragging: int = -2


func show_schedules(pawns: Array[Pawn], hours: ShopHours, now_minute: int) -> void:
	_pawns = pawns
	_hours = hours
	_now_minute = now_minute
	custom_minimum_size = Vector2(
		NAME_WIDTH + CELL.x * WorkSchedule.SLOTS,
		_get_rows_top() + CELL.y * pawns.size()
	)
	queue_redraw()


func _get_rows_top() -> float:
	return HEADER_HEIGHT + BAR_HEIGHT + GAP


## X of `minute` (since midnight) on the grid.
func _minute_x(minute: float) -> float:
	return NAME_WIDTH + minute / WorkSchedule.SLOT_MINUTES * CELL.x


func _draw() -> void:
	if _hours == null:
		return
	var font: Font = get_theme_default_font()
	var width: float = CELL.x * WorkSchedule.SLOTS
	# Hour numbers.
	for hour: int in 24:
		draw_string(font, Vector2(_minute_x(hour * 60) + 1, HEADER_HEIGHT - 3), str(hour),
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
	# The hours bar: closed, then each zone up to the next mark, then closed again.
	var bar := Rect2(NAME_WIDTH, HEADER_HEIGHT, width, BAR_HEIGHT)
	draw_rect(bar, CLOSED_COLOR)
	for zone: int in ZONE_COLORS.size():
		var from: float = _minute_x(_hours.get_mark(zone as ShopHours.Mark))
		var to: float = _minute_x(_hours.get_mark((zone + 1) as ShopHours.Mark))
		draw_rect(Rect2(from, HEADER_HEIGHT, to - from, BAR_HEIGHT), ZONE_COLORS[zone])
	draw_string(font, Vector2(0, HEADER_HEIGHT + BAR_HEIGHT - 3), "Hours",
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
	# A row of cells per pawn.
	var top: float = _get_rows_top()
	for row: int in _pawns.size():
		var pawn: Pawn = _pawns[row]
		var y: float = top + row * CELL.y
		draw_string(font, Vector2(0, y + CELL.y - 5), pawn.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, NAME_WIDTH - 4, FONT_SIZE, TEXT_COLOR)
		for slot: int in WorkSchedule.SLOTS:
			var on: bool = pawn.is_scheduled_at(slot * WorkSchedule.SLOT_MINUTES)
			var cell := Rect2(NAME_WIDTH + slot * CELL.x, y, CELL.x, CELL.y)
			draw_rect(cell, WORK_COLOR if on else OFF_COLOR)
			draw_rect(cell, LINE_COLOR, false)
	# The markers, down through the rows too, and the time now.
	var bottom: float = top + _pawns.size() * CELL.y
	for mark: int in ShopHours.Mark.size():
		var x: float = _minute_x(_hours.get_mark(mark as ShopHours.Mark))
		draw_line(Vector2(x, HEADER_HEIGHT), Vector2(x, bottom), MARKER_COLOR, 2.0)
	if _now_minute >= 0:
		var x: float = _minute_x(_now_minute)
		draw_line(Vector2(x, HEADER_HEIGHT), Vector2(x, bottom), NOW_COLOR, 1.0)


func _get_tooltip(at_position: Vector2) -> String:
	if _hours == null or at_position.x < NAME_WIDTH:
		return ""
	var minute: int = floori((at_position.x - NAME_WIDTH) / CELL.x) * WorkSchedule.SLOT_MINUTES
	var time: String = ShopClock.format_time(minute)
	if at_position.y >= HEADER_HEIGHT and at_position.y < HEADER_HEIGHT + BAR_HEIGHT:
		return "%s: %s\nDrag a white marker to move it." % [time, _get_zone_name(minute)]
	var row: int = _get_row(at_position.y)
	if row < 0:
		return time
	var on: bool = _pawns[row].is_scheduled_at(minute)
	return "%s at %s: %s" % [_pawns[row].display_name, time, "Work" if on else "Off"]


## What the shop is doing at `minute`, for the bar's tooltip.
func _get_zone_name(minute: int) -> String:
	if minute < _hours.prep_minute or minute >= _hours.close_minute:
		return "Closed"
	if minute < _hours.open_minute:
		return "Prep (staff only)"
	if minute < _hours.last_order_minute:
		return "Open"
	return "Last orders taken (no new orders)"


func _get_row(y: float) -> int:
	var row: int = floori((y - _get_rows_top()) / CELL.y)
	return row if y >= _get_rows_top() and row < _pawns.size() else -1


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not button.pressed:
			_dragging = -2
			return
		var at: Vector2 = button.position
		if at.y >= HEADER_HEIGHT and at.y < HEADER_HEIGHT + BAR_HEIGHT:
			_dragging = _find_marker(at.x)
		elif _get_row(at.y) >= 0:
			_dragging = -1
			_paint(at)
		return
	var motion := event as InputEventMouseMotion
	if motion == null or _dragging == -2:
		return
	accept_event()
	if _dragging == -1:
		_paint(motion.position)
	else:
		var minute: float = (motion.position.x - NAME_WIDTH) / CELL.x * WorkSchedule.SLOT_MINUTES
		mark_change_requested.emit(_dragging as ShopHours.Mark, roundi(minute))


## The marker nearest `x` on the bar, within GRAB_DISTANCE, or -2 for none. Where markers
## share a time, a press left of it grabs the earlier one and right of it the later, so
## they can be pulled apart either way.
func _find_marker(x: float) -> int:
	var best: int = -2
	var best_distance: float = GRAB_DISTANCE
	for mark: int in ShopHours.Mark.size():
		var marker_x: float = _minute_x(_hours.get_mark(mark as ShopHours.Mark))
		var distance: float = absf(marker_x - x)
		if distance < best_distance or (best != -2 and distance == best_distance and x >= marker_x):
			best = mark
			best_distance = distance
	return best


## Paints the cell at `at` with the brush.
func _paint(at: Vector2) -> void:
	var row: int = _get_row(at.y)
	var slot: int = floori((at.x - NAME_WIDTH) / CELL.x)
	if row < 0 or slot < 0 or slot >= WorkSchedule.SLOTS:
		return
	var pawn: Pawn = _pawns[row]
	if pawn.is_scheduled_at(slot * WorkSchedule.SLOT_MINUTES) != brush:
		slot_change_requested.emit(pawn, slot, brush)
