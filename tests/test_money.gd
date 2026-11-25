extends "res://tests/test_base.gd"
## Money stakes: the shop starts with its starting cash. Building a station pays its price
## (shown on the day report as Equipment) and selling it pays it all back; moving is free.
## A station the shop can't afford doesn't fit and its build button is greyed out. Closing
## a day below zero is game over: the game pauses on the report, titled "Out of money", and
## its button asks for a restart.

const OVEN := preload("res://resources/stations/small_oven.tres")
const BIG_WALK_IN := preload("res://resources/stations/walk_in_5x4.tres")
const SPOT := Vector2i(17, 0)


func _start() -> void:
	stop_random_orders()
	var build: BuildMode = world.get_node("BuildMode")
	var hud: Hud = world.get_node("Hud")
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	for i: int in work.get_pawns().size():
		work.get_pawns()[i].global_position = shop_floor.cell_to_global(Vector2i(12 + i, 6))
	var start: float = finances.starting_cash
	if start <= 0.0 or not is_equal_approx(finances.cash, start):
		fail("cash starts at %.2f, starting cash %.2f" % [finances.cash, start])
		return
	world._set_build_mode(true)
	var panel: BuildPanel = hud.get_node("BuildPanel")
	if not panel._buttons_by_data[BIG_WALK_IN].disabled or panel._buttons_by_data[OVEN].disabled:
		fail("build buttons don't match what's affordable")
		return

	# Buy an oven.
	build.choose(OVEN)
	build.hover(SPOT)
	if not build.confirm():
		fail("an affordable oven didn't fit at %s" % SPOT)
		return
	build.cancel()
	if not is_equal_approx(finances.cash, start - OVEN.price) \
			or not is_equal_approx(finances.get_today().equipment, OVEN.price):
		fail("buying the oven left cash %.2f, equipment %.2f" % [finances.cash, finances.get_today().equipment])
		return

	# Moving is free; selling pays it all back.
	var oven: Station = null
	for station: Station in world._stations:
		if station.cell == SPOT:
			oven = station
	build.pick_up(oven)
	build.hover(SPOT + Vector2i(0, 2))
	if not build.confirm() or not is_equal_approx(finances.cash, start - OVEN.price):
		fail("moving the oven failed or cost money (cash %.2f)" % finances.cash)
		return
	build.pick_up(oven)
	if not build.sell() or not is_equal_approx(finances.cash, start) \
			or not is_equal_approx(finances.get_today().equipment, 0.0):
		fail("selling the oven didn't pay its price back (cash %.2f)" % finances.cash)
		return

	# Can't afford it: it doesn't fit, and its button is greyed out.
	finances._change_cash(OVEN.price - 1.0 - finances.cash)
	if not panel._buttons_by_data[OVEN].disabled:
		fail("the oven's button works without the cash for it")
		return
	build.choose(OVEN)
	build.hover(SPOT)
	if build.fits() or build.confirm():
		fail("placed an oven the shop can't afford")
		return
	build.cancel()
	world._set_build_mode(false)

	# Closing below zero: game over.
	finances._change_cash(-finances.cash)
	world._close_day(1)
	var report_panel: DayReportPanel = hud.get_node("DayReportPanel")
	if not paused or not report_panel.visible or not report_panel.report.is_out_of_money():
		fail("closing in debt didn't pause on the game-over report (paused %s)" % paused)
		return
	var title: Label = report_panel.get_node("%Title")
	var button: Button = report_panel.get_node("%Continue")
	if title.text != "Out of money" or button.text != "Restart":
		fail("game-over report reads '%s' / '%s'" % [title.text, button.text])
		return
	hud.restart_requested.disconnect(world._restart)
	var asked: Array[bool] = [false]
	hud.restart_requested.connect(func() -> void: asked[0] = true)
	button.pressed.emit()
	paused = false
	if not asked[0]:
		fail("Restart didn't ask for a restart")
		return
	pass_test("built, moved and sold for the right money; unaffordable blocked; game over in debt")
