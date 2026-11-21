extends "res://tests/test_base.gd"
## Stations can be moved while they're in use, with what's on them. Picked up, a station is
## out of use: pawns working at it or heading to it stop, and nobody starts a job there or
## takes anything off it. Put down somewhere else, its items are there with it, and the
## orders carry on: here a prep table is moved with a pizza on it while a pawn works it,
## an oven is moved while it bakes, and the box rack is moved while a pawn folds a box for
## it (the room set aside comes back, the stock stays). Both orders still go out.

const HOLD_FRAMES: int = 30

var _build: BuildMode
var _floor: ShopFloor
var _tickets: Array[Ticket] = []
var _finished: int = 0
var _phase: int = 0
var _held: Station = null
var _held_items: Array[Item] = []
var _held_frames: int = 0
var _moved_prep: bool = false
var _moved_oven: bool = false
var _moved_rack: bool = false
var _rack_stock: int = 0


func _start() -> void:
	stop_random_orders()
	_build = world.get_node("BuildMode")
	_floor = world.get_node("ShopFloor")
	clock.set_speed(6)
	rack.patience_minutes = 100000
	_tickets.append(order_pizzas(1))
	_tickets.append(order_pizzas(1))
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	if _held != null:
		_while_held()
		return
	# The box rack, while a pawn is folding a box for it (its room is set aside).
	var box_rack: Station = world.get_node("Entities/BoxRack")
	if not _moved_rack and box_rack._room_claimed > 0:
		_rack_stock = box_rack._stock
		_pick_up(box_rack)
		if box_rack._room_claimed != 0:
			fail("the interrupted folder's room on the rack wasn't handed back")
		return
	match _phase:
		0:
			# A prep table with a pizza on it and a pawn working there.
			for path: String in ["Entities/PrepTable", "Entities/PrepTable2"]:
				var prep: Station = world.get_node(path)
				if prep.has_items() and _pawn_working_at(prep) != null:
					_pick_up(prep)
					_phase = 1
					return
		1:
			# An oven baking.
			for path: String in ["Entities/SmallOven", "Entities/SmallOven2"]:
				var oven: Station = world.get_node(path)
				if oven._working.has(true):
					_pick_up(oven)
					_phase = 2
					return


func _pick_up(station: Station) -> void:
	world._set_build_mode(true)
	if not _build.pick_up(station):
		fail("couldn't pick up %s while it was in use" % station.name)
		return
	_held = station
	_held_items.clear()
	for spot: int in station.get_spot_count():
		if station.get_item(spot) != null:
			_held_items.append(station.get_item(spot))
	_held_frames = 0


## While held: nobody's job involves it. Then it's put down somewhere free.
func _while_held() -> void:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job != null and work._involves(job, _held):
			fail("%s has a %s job at %s while it's picked up" % [
				pawn.display_name, job.task_type.id, _held.name])
			return
	_held_frames += 1
	if _held_frames < HOLD_FRAMES:
		return
	var from: Vector2i = _held.cell
	if not _put_down_elsewhere(from):
		fail("found nowhere to put %s down" % _held.name)
		return
	for item: Item in _held_items:
		if item.station != _held or item.global_position != _held._item_positions[item.spot]:
			fail("an item on %s didn't move with it" % _held.name)
			return
	if _held.name.begins_with("Prep"):
		_moved_prep = true
	elif _held.name == "BoxRack":
		_moved_rack = true
		if _held._stock != _rack_stock:
			fail("the rack had %d boxes before the move and %d after" % [_rack_stock, _held._stock])
			return
	else:
		_moved_oven = true
	_held = null
	world._set_build_mode(false)


func _put_down_elsewhere(from: Vector2i) -> bool:
	for y: int in range(11, -1, -1):
		for x: int in range(0, 12):
			var cell := Vector2i(x, y)
			if cell == from:
				continue
			_build.hover(cell)
			if _build.fits() and _build.confirm():
				return true
	_build.cancel()
	return false


func _pawn_working_at(station: Station) -> Pawn:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job != null and job.station == station and pawn._state == Pawn.State.WORKING:
			return pawn
	return null


func _on_completed(ticket: Ticket) -> void:
	if not _tickets.has(ticket):
		return
	_finished += 1
	if _finished < _tickets.size():
		return
	if not _moved_prep or not _moved_oven or not _moved_rack:
		fail("the orders went out before every move happened (prep %s, oven %s, rack %s)" % [
			_moved_prep, _moved_oven, _moved_rack])
		return
	pass_test("moved a prep table mid-work, an oven mid-bake and the box rack mid-fold; both orders went out")
