extends "res://tests/test_base.gd"
## Schedules and shop hours: the day runs from the first shift (or prep) to the last (or
## closing). Pawns off shift are at home; their shift starts and they walk in, it ends and
## they finish up and walk out. Each takes one break a day (30 min for 8 hours), when tired
## or once it's due. Orders only come between opening and last orders, quoted by whoever
## covers while the manager is out. Wages pay scheduled hours. Hours snap to half hours and
## stay in order; painting a shift later in the day makes the day longer.

var _manager: Pawn
var _opener: Pawn
var _saw_manager_in: bool = false
var _opener_left_at: int = -1
var _opener_took_break: bool = false


func _init() -> void:
	keep_schedules = true


func _start() -> void:
	stop_random_orders()
	_manager = work.get_manager()
	_opener = world.get_node("Entities/Pawn2")
	var hours: ShopHours = clock.hours
	if clock.day_start_minute != 8 * 60 or clock.day_end_minute != 22 * 60:
		fail("day 1 runs %s to %s, expected 08:00 to 22:00" % [ShopClock.format_time(clock.day_start_minute), ShopClock.format_time(clock.day_end_minute)])
		return
	if clock.get_minute_of_day() != 8 * 60:
		fail("day 1 starts at %s" % ShopClock.format_time(clock.get_minute_of_day()))
		return
	if not _manager.is_away() or _opener.is_away() or not _opener.on_shift:
		fail("at 08:00 the manager should be home and the opener in")
		return
	if hours.is_taking_orders(clock.get_minute_of_day()):
		fail("orders are taken during prep")
		return
	# The openers are in; one of them covers quoting while the manager is out.
	var openers: Array[Pawn] = [_opener, world.get_node("Entities/Pawn5") as Pawn]
	var quoting: Pawn = work.get_quoting_pawn()
	if quoting == null or not openers.has(quoting):
		fail("nobody covers quoting for the manager")
		return
	if _opener.mood.break_length != 30.0 or work.get_pawns_on_shift() != openers:
		fail("the opener's break is %.0f min; %d on shift" % [_opener.mood.break_length, work.get_pawns_on_shift().size()])
		return

	# Hours snap to half hours and stay in order.
	hours.set_mark(ShopHours.Mark.OPEN, 9 * 60 + 10)
	if hours.open_minute != 9 * 60:
		fail("opening snapped to %s" % ShopClock.format_time(hours.open_minute))
		return
	hours.set_mark(ShopHours.Mark.PREP, 12 * 60)
	if hours.prep_minute != 9 * 60:
		fail("prep moved past opening, to %s" % ShopClock.format_time(hours.prep_minute))
		return
	hours.set_mark(ShopHours.Mark.PREP, 8 * 60)
	hours.set_mark(ShopHours.Mark.OPEN, 10 * 60)

	# Pawns starting on the same shift (Pawn 2 and 5, Pawn 4 and 6) are painted on their own.
	for pair: Array in [["Pawn2", "Pawn5"], ["Pawn4", "Pawn6"]]:
		var painted: Pawn = world.get_node("Entities/" + pair[0])
		var other: Pawn = world.get_node("Entities/" + pair[1])
		world._on_schedule_change_requested(painted, 2, true)
		var shared: bool = other.schedule.is_working(2)
		world._on_schedule_change_requested(painted, 2, false)
		if shared:
			fail("painting %s's schedule also changed %s's" % [painted.display_name, other.display_name])
			return

	# A shift painted later makes the day longer, until it's painted off again.
	world._on_schedule_change_requested(_opener, 46, true)
	if clock.day_end_minute != 23 * 60 + 30:
		fail("a shift to 23:30 ends the day at %s" % ShopClock.format_time(clock.day_end_minute))
		return
	world._on_schedule_change_requested(_opener, 46, false)
	if clock.day_end_minute != 22 * 60:
		fail("the day still ends at %s" % ShopClock.format_time(clock.day_end_minute))
		return
	clock.set_speed(12)


func _step() -> void:
	keep_flat_boxes_stocked()
	var minute: int = clock.get_minute_of_day()
	if clock.day == 1:
		if minute >= 10 * 60 + 30 and not _manager.is_away() and _manager.on_shift:
			_saw_manager_in = true
		if _opener.mood.break_taken:
			_opener_took_break = true
		if _opener_left_at < 0 and _opener.is_away():
			_opener_left_at = minute
			if minute < 16 * 60:
				fail("the opener went home at %s, before their shift ended" % ShopClock.format_time(minute))
		if minute >= 21 * 60 + 30 and not _manager.is_away():
			fail("the manager is still in at %s" % ShopClock.format_time(minute))
		return
	# Day 2 started: day 1 closed.
	if not _saw_manager_in:
		fail("the manager never came in for their 10:00 shift")
		return
	if _opener_left_at < 0 or _opener_left_at > 17 * 60:
		fail("the opener left at %s" % ShopClock.format_time(_opener_left_at))
		return
	if not _opener_took_break:
		fail("the opener never took their break")
		return
	var report: DayReport = (world.get_node("Hud") as Hud)._last_report
	if report == null or not is_equal_approx(report.wages, 6 * 8 * 15.0) or not is_equal_approx(report.staff_hours, 48.0):
		fail("day 1 paid %.0f in wages for %.0f h, expected 720 for 48 h" % [report.wages if report else 0.0, report.staff_hours if report else 0.0])
		return
	if clock.get_minute_of_day() != 8 * 60 or _opener.mood.break_taken:
		fail("day 2 should start at 08:00 with a break to take")
		return
	pass_test("shifts come and go, one break, opener left at %s, wages $%.0f" % [ShopClock.format_time(_opener_left_at), report.wages])
