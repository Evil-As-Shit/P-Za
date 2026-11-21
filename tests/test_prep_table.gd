extends "res://tests/test_base.gd"
## The prep table: a 3x2 Prep station with three spots along its cutting board. Its lids
## are closed while nobody uses it and open while it's in use (a spot reserved or holding
## something). Pizzas are made on it, and an order of three goes out.

var _table: Station
var _closed: Texture2D
var _open: Texture2D
var _ticket: Ticket
var _saw_open: bool = false
var _spots_used: Dictionary[int, bool] = {}


func _start() -> void:
	stop_random_orders()
	_table = world.get_node("Entities/PrepTable")
	if _table.get_footprint_cells().size() != 6 or _table.get_spot_count() != 3:
		fail("expected a 3x2 prep table with 3 spots")
		return
	_closed = _table.data.get_texture(_table.facing)
	_open = _table.data.get_texture(_table.facing, true)
	if _closed == _open:
		fail("the prep table has no lids-open art")
		return
	if _table._sprite.texture != _closed:
		fail("the prep table's lids should start closed")
		return
	clock.set_speed(6)
	rack.patience_minutes = 100000
	_ticket = order_pizzas(3)
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	var in_use: bool = _table._reserved.has(true) or _table.has_items()
	var expected: Texture2D = _open if in_use else _closed
	if _table._sprite.texture != expected:
		fail("the lids are %s while the table is %s" % [
			"open" if _table._sprite.texture == _open else "closed",
			"in use" if in_use else "free"])
		return
	if in_use:
		_saw_open = true
	for spot: int in _table.get_spot_count():
		if _table.get_item(spot) != null:
			_spots_used[spot] = true


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if not _saw_open:
		fail("never saw the prep table in use")
		return
	if _spots_used.size() < 2:
		fail("only %d of the prep table's spots were used for 3 pizzas" % _spots_used.size())
		return
	pass_test("3 pizzas made on the prep table using %d spots; lids open only while in use" % _spots_used.size())
