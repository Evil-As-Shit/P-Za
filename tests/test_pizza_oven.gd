extends "res://tests/test_base.gd"
## The 2x2 pizza oven: it replaces the small ovens, bakes two pizzas side by side (its
## cover shows the lit window while baking), and the order still goes out.

const PIZZA_OVEN := preload("res://resources/stations/pizza_oven.tres")

var _oven: Station
var _ticket: Ticket
var _saw_lit: bool = false
var _saw_both: bool = false


func _start() -> void:
	stop_random_orders()
	var build: BuildMode = world.get_node("BuildMode")
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	var pawns: Array[Pawn] = work.get_pawns()
	for i: int in pawns.size():
		pawns[i].global_position = shop_floor.cell_to_global(Vector2i(i, 0))
	if PIZZA_OVEN.get_facings() != [0, 1, 2, 3]:
		fail("pizza oven can face %s, expected all four" % [PIZZA_OVEN.get_facings()])
		return

	world._set_build_mode(true)
	for path: String in ["Entities/SmallOven", "Entities/SmallOven2"]:
		if not build.pick_up(world.get_node(path)) or not build.sell():
			fail("couldn't sell %s" % path)
			return

	# Put the pizza oven down where the small ovens were, at whichever facing fits.
	build.choose(PIZZA_OVEN)
	var placed: bool = false
	for turn: int in 4:
		for cell: Vector2i in [Vector2i(8, 5), Vector2i(9, 6), Vector2i(8, 6), Vector2i(9, 5)]:
			build.hover(cell)
			if build.fits():
				placed = build.confirm()
				break
		if placed:
			break
		build.rotate()
	build.cancel()
	if not placed:
		fail("the pizza oven didn't fit where the small ovens were")
		return
	for station: Station in world._stations:
		if station.data == PIZZA_OVEN:
			_oven = station
	if _oven == null or _oven.get_footprint_cells().size() != 4:
		fail("the pizza oven wasn't set up with a 2x2 footprint")
		return
	world._set_build_mode(false)

	clock.set_speed(6)
	rack.patience_minutes = 100000
	_ticket = order_pizzas(2)
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	if _oven == null:
		return
	var lit: Texture2D = PIZZA_OVEN.get_cover_texture(_oven.facing, true)
	var cover: Sprite2D = _oven._cover
	if _oven._working.has(true):
		if cover.texture != lit:
			fail("the oven was baking but its cover wasn't lit")
			return
		_saw_lit = true
	elif cover.texture == lit:
		fail("the oven's cover stayed lit with nothing baking")
		return
	if _oven.get_item(0) != null and _oven.get_item(1) != null:
		_saw_both = true


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if not _saw_lit:
		fail("never saw the pizza oven baking")
		return
	if not _saw_both:
		fail("never saw two pizzas in the pizza oven at once")
		return
	pass_test("two pizzas baked side by side in the pizza oven at facing %d" % _oven.facing)
