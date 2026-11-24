extends "res://tests/test_base.gd"
## Build mode: placing a new station, refusing spots that don't fit, moving and selling idle
## stations, refusing to sell one with something on it, and work carrying on with the new
## layout. (Moving busy stations mid-order: test_move_busy.)

const OVEN := preload("res://resources/stations/small_oven.tres")

var _build: BuildMode
var _floor: ShopFloor
var _ticket: Ticket
var _busy_checked: bool = false


func _start() -> void:
	stop_random_orders()
	_build = world.get_node("BuildMode")
	_floor = world.get_node("ShopFloor")
	# Pawns start on random cells, and a pawn standing where we build blocks it. Line them
	# up along the back wall, out of the way.
	var pawns: Array[Pawn] = work.get_pawns()
	for i: int in pawns.size():
		pawns[i].global_position = _floor.cell_to_global(Vector2i(13 + i, 0))
	world._set_build_mode(true)
	var station_count: int = world._stations.size()

	# Facings: art for one front view gives its mirror image too.
	var expected: Dictionary = {
		"res://resources/stations/small_oven.tres": [0, 3],
		"res://resources/stations/pizza_oven.tres": [0, 1, 2, 3],
		"res://resources/stations/box_rack.tres": [0, 1, 2, 3],
		"res://resources/stations/counter.tres": [0, 1, 2, 3],
	}
	for path: String in expected:
		var facings: Array[int] = (load(path) as StationData).get_facings()
		if facings != Array(expected[path], TYPE_INT, &"", null):
			fail("%s can face %s, expected %s" % [path.get_file(), facings, expected[path]])
			return

	# On top of the prep table: doesn't fit.
	_build.choose(OVEN)
	_build.hover(Vector2i(6, 1))
	if _build.fits() or _build.confirm():
		fail("an oven fit on top of the prep table")
		return
	# Free floor in a corner: fits, and the tool stays ready for another.
	_build.hover(Vector2i(11, 0))
	if not _build.confirm():
		fail("an oven didn't fit on free floor at (11, 0)")
		return
	if world._stations.size() != station_count + 1 or _floor.is_walkable(Vector2i(11, 0)):
		fail("the new oven wasn't set up")
		return
	if not _build.has_ghost():
		fail("no ghost ready to place another oven")
		return
	_build.cancel()

	# Move the garbage can (idle) to the other side of the shop.
	var can: Station = world.get_node("Entities/GarbageCan")
	if not _build.pick_up(can):
		fail("couldn't pick up the idle garbage can")
		return
	_build.hover(Vector2i(16, 8))
	if not _build.confirm():
		fail("the garbage can didn't fit at (16, 8)")
		return
	if can.cell != Vector2i(16, 8) or not _floor.is_walkable(Vector2i(8, 5)) \
			or _floor.is_walkable(Vector2i(16, 8)) or not world._stations.has(can):
		fail("the garbage can didn't move properly")
		return

	# Sell the oven we built: it's gone and its cell is free again.
	var built: Station = null
	for station: Station in world._stations:
		if station.cell == Vector2i(11, 0):
			built = station
	if built == null or not _build.pick_up(built) or not _build.sell():
		fail("couldn't pick up and sell the new oven")
		return
	if world._stations.has(built) or work.get_stations().has(built) \
			or not _floor.is_walkable(Vector2i(11, 0)):
		fail("the sold oven is still in use or still blocks its cell")
		return
	if _build.sell():
		fail("sold something with nothing picked up")
		return

	world._set_build_mode(false)
	clock.set_speed(6)
	_ticket = order_pizzas(1)
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	# With the pizza on the prep table, the table can be picked up but not sold; let go,
	# it goes back where it was with the pizza on it.
	if _busy_checked:
		return
	var prep: Station = world.get_node("Entities/PrepTable")
	if not prep.has_items():
		return
	_busy_checked = true
	world._set_build_mode(true)
	if not _build.pick_up(prep):
		fail("couldn't pick up the prep table with a pizza on it")
		return
	if _build.sell():
		fail("sold a prep table with a pizza on it")
		return
	_build.cancel()
	world._set_build_mode(false)
	if not prep.has_items() or not world._stations.has(prep):
		fail("the prep table didn't go back to work with its pizza")


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if not _busy_checked:
		fail("never saw the prep table in use")
		return
	pass_test("placed and sold an oven, moved the garbage can, kept a busy table, and an order still went out")
