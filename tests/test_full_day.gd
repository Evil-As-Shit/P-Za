extends "res://tests/test_base.gd"
## A whole day of random orders at 6x: nothing stalls, every order is accounted for, the
## day report pauses the game, and Continue starts the next day.

var _placed: int = 0
var _report_frame: int = -1


func _start() -> void:
	timeout_frames = 60 * 60 * 10
	clock.set_speed(6)
	(world.get_node("OrderSource") as OrderSource).order_placed.connect(
		func(_recipes: Array[Recipe]) -> void: _placed += 1
	)
	clock.day_started.connect(func(_day: int) -> void: _report_frame = frame)


func _step() -> void:
	if _report_frame < 0:
		return
	var panel: DayReportPanel = world.get_node("Hud/DayReportPanel")
	if frame == _report_frame + 2:
		var report: DayReport = panel.report
		if not panel.visible or clock.speed != 0:
			fail("the day report didn't pause the game")
			return
		var counted: int = report.orders_served + report.orders_missed + report.orders_open
		if counted != _placed:
			fail("%d orders placed but the report accounts for %d" % [_placed, counted])
			return
		if report.orders_served == 0:
			fail("no orders were served")
			return
		print("  served %d, missed %d, open %d, profit %s" % [
			report.orders_served, report.orders_missed, report.orders_open,
			ShopFinances.format_money(report.get_profit()),
		])
		(panel.get_node("%Continue") as Button).pressed.emit()
	elif frame == _report_frame + 4:
		if panel.visible or clock.speed != 6:
			fail("Continue didn't start the next day at 6x")
			return
		pass_test("a full day ran and every order is accounted for")
