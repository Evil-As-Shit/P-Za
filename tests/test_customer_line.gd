extends "res://tests/test_base.gd"
## The register line: it snakes through the lobby, holds 10 customers, and the 11th turns
## around (sale lost, no review). With nobody on Cashier, everyone in line gives up and
## walks out the front door (a review each).

const CASHIER := preload("res://resources/work_types/cashier.tres")
const PATIENCE_PAST_QUOTE: int = 2

var _lobby: Lobby
var _reviews: int = 0


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_lobby = world.get_node("Lobby")
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	for pawn: Pawn in work.get_pawns():
		pawn.set_priority(CASHIER, 0)
	rack.patience_past_quote = PATIENCE_PAST_QUOTE
	(world.get_node("ShopReputation") as ShopReputation).rating_changed.connect(
		func(_r: float) -> void: _reviews += 1
	)

	var cells: Array[Vector2i] = _lobby.get_line_cells()
	if cells.size() != _lobby.max_line:
		fail("the line has room for %d, expected %d" % [cells.size(), _lobby.max_line])
		return
	var pickup: Station = world.get_node("Entities/PickupCounter")
	for i: int in cells.size():
		if not shop_floor.is_lobby(cells[i]) or not shop_floor.is_walkable(cells[i]):
			fail("line cell %s isn't open lobby floor" % cells[i])
			return
		if cells.find(cells[i]) != i:
			fail("line cell %s is used twice" % cells[i])
			return
		if i > 0 and absi(cells[i].x - cells[i - 1].x) + absi(cells[i].y - cells[i - 1].y) != 1:
			fail("the line jumps from %s to %s" % [cells[i - 1], cells[i]])
			return
		if cells[i] == pickup.cell + Vector2i(0, 1):
			fail("the line stands in front of the pickup counter")
			return

	for i: int in _lobby.max_line + 1:
		world._on_order_placed([world.debug_recipe] as Array[Recipe])
	if _lobby.get_line().size() != _lobby.max_line:
		fail("%d in line, expected %d" % [_lobby.get_line().size(), _lobby.max_line])
		return
	if finances.get_today().orders_missed != 1 or _reviews != 0:
		fail("the turned-away customer: %d missed, %d reviews (expected 1, 0)" % [finances.get_today().orders_missed, _reviews])
		return


func _step() -> void:
	if not _lobby.get_customers().is_empty():
		return
	if rack.get_ticket_count() != 0:
		fail("an order was taken with nobody on Cashier")
		return
	if _reviews != _lobby.max_line:
		fail("%d reviews, expected one per customer who gave up (%d)" % [_reviews, _lobby.max_line])
		return
	pass_test("line of %d, 11th turned away, all gave up and walked out" % _lobby.max_line)
