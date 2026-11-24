extends "res://tests/test_base.gd"
## The walk-in cooler: its walls stand on its outer edges, so its whole floor is open and
## pawns get in only through the door. Racks are built inside it; only one inside can store
## dough, and one moved out loses the role. Nothing can straddle its wall. Moving it
## brings the racks inside along, stock and layout kept, and it can't be sold with anything
## inside. Then a pawn walks in for dough and the order goes out.

const RACK := preload("res://resources/stations/box_rack.tres")
const DOUGH_STORAGE := preload("res://resources/station_roles/dough_storage.tres")
## Where the test moves the walk-in: free floor on the right, door facing into the shop.
const MOVE_TO := Vector2i(13, 5)

var _walk_in: Station
var _rack: Station
var _floor: ShopFloor
var _build: BuildMode
var _ticket: Ticket
var _walked_in: bool = false


func _start() -> void:
	stop_random_orders()
	_walk_in = world.get_node("Entities/WalkIn")
	_rack = world.get_node("Entities/DoughRack")
	_floor = world.get_node("ShopFloor")
	_build = world.get_node("BuildMode")
	var problem: String = _check_room()
	if problem != "":
		fail("at the start: " + problem)
		return
	for i: int in 300:
		if _walk_in.get_footprint_cells().has(_floor.get_random_walkable_cell()):
			fail("idle pawns can wander into the walk-in")
			return
	var pawns: Array[Pawn] = work.get_pawns()
	for i: int in pawns.size():
		pawns[i].global_position = _floor.cell_to_global(Vector2i(6 + i, 7))
	world._set_build_mode(true)

	# A rack straddling the wall doesn't fit; one outside can't store dough.
	_build.choose(RACK)
	_build.hover(Vector2i(3, 3))
	while _build._ghost.facing != 1:
		_build.rotate()
	if _build.fits():
		fail("a rack fits across the walk-in's wall")
		return
	_build.cancel()
	if _rack.get_available_roles().has(DOUGH_STORAGE) == false:
		fail("the rack inside the walk-in can't store dough")
		return
	var box_rack: Station = world.get_node("Entities/BoxRack")
	if box_rack.get_available_roles().has(DOUGH_STORAGE):
		fail("a rack outside the walk-in offers Dough storage")
		return

	# Clear room where it's going.
	if not _build.pick_up(world.get_node("Entities/BreakTable")) or not _build.sell():
		fail("couldn't sell the break table")
		return
	# Move it with the rack partly emptied: the rack and its stock come along; no selling.
	_rack._stock = 2
	if not _build.pick_up(_walk_in):
		fail("couldn't pick up the walk-in")
		return
	if work.get_stations().has(_rack):
		fail("the rack inside stayed in use while the walk-in was picked up")
		return
	if _build.sell():
		fail("sold the walk-in with a rack inside")
		return
	var old_cells: Array[Vector2i] = _walk_in.get_footprint_cells()
	_build.hover(MOVE_TO)
	while _walk_in.facing != 0:
		_build.rotate()
	if not _build.confirm():
		fail("the walk-in didn't fit at %s" % MOVE_TO)
		return
	world._set_build_mode(false)
	for old_cell: Vector2i in old_cells:
		if not _floor.is_walkable(old_cell):
			fail("%s still blocks pawns after the walk-in moved" % old_cell)
			return
	problem = _check_room()
	if problem != "":
		fail("after the move: " + problem)
		return
	if _rack.get_stock() != 2 or _rack.role != DOUGH_STORAGE:
		fail("the rack lost its stock or role in the move")
		return

	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_ticket = order_pizzas(1)
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	if _walked_in:
		return
	for pawn: Pawn in work.get_pawns():
		if _walk_in.is_room_cell(work.get_cell(pawn)):
			_walked_in = true


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if not _walked_in:
		fail("the order went out without anyone walking into the walk-in")
		return
	pass_test("walls on edges, door only way in, rack inside stores dough and moves along")


## Its floor is open; the only way in from outside is through the door; the rack is inside,
## in use and storing dough.
func _check_room() -> String:
	var furniture: Array[Vector2i] = []
	for station: Station in world._stations:
		furniture.append_array(station.get_blocked_cells())
	for cell: Vector2i in _walk_in.get_footprint_cells():
		if not furniture.has(cell) and not _floor.is_walkable(cell):
			return "floor cell %s blocks pawns" % cell
	var door: Vector2i = _walk_in.cell + StationData.rotate_offset(
		_walk_in.data.walk_in.door_cell, _walk_in.facing
	)
	for edge: Vector4i in _walk_in.get_wall_edges():
		var inside := Vector2i(edge.x, edge.y)
		var outside := Vector2i(edge.z, edge.w)
		if not _floor.is_walkable(inside) or not _floor.is_walkable(outside):
			continue
		var path: PackedVector2Array = _floor.get_path_points(outside, inside)
		if path.size() == 2:
			return "pawns walk through the wall between %s and %s" % [outside, inside]
		if path.is_empty() or not path.has(_floor.cell_to_global(door)):
			return "no way in through the door from %s" % outside
	if not work.get_stations().has(_rack) or not _rack.in_walk_in:
		return "the rack inside isn't in use"
	if not _rack.get_footprint_cells().all(_walk_in.is_room_cell):
		return "the rack isn't inside the walk-in"
	return ""
