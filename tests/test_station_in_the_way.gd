extends "res://tests/test_base.gd"
## A station put down across a walking pawn's path: the pawn goes around it instead of
## walking onto it (which used to leave them stuck on a blocked cell, and stopped anything
## else from being placed).

const WATCH_FRAMES: int = 600

var _build: BuildMode
var _floor: ShopFloor
var _placed_frame: int = -1


func _start() -> void:
	stop_random_orders()
	_build = world.get_node("BuildMode")
	_floor = world.get_node("ShopFloor")
	var pawn: Pawn = null
	for candidate: Pawn in work.get_pawns():
		if not candidate.has_job():
			pawn = candidate
			break
	if pawn == null:
		fail("no pawn without a job to walk")
		return
	# Off all work, so putting the can down doesn't hand them a job with a fresh path.
	pawn.priorities.clear()
	var path: PackedVector2Array = _longest_walk(pawn)
	if path.size() < 6:
		fail("no long enough walk for %s" % pawn.display_name)
		return
	pawn.follow_path(path)

	world._set_build_mode(true)
	var can: Station = world.get_node("Entities/GarbageCan")
	if not _build.pick_up(can):
		fail("couldn't pick up the garbage can")
		return
	var placed: bool = false
	for i: int in range(3, path.size() - 1):
		_build.hover(_floor.global_to_cell(path[i]))
		if _build.fits() and _build.confirm():
			placed = true
			break
	if not placed:
		_build.cancel()
		fail("the garbage can didn't fit anywhere on %s's path" % pawn.display_name)
		return
	world._set_build_mode(false)

	var footprint: Array[Vector2i] = can.get_footprint_cells()
	for leg: PackedVector2Array in pawn.get_route():
		for point: Vector2 in leg:
			if footprint.has(_floor.global_to_cell(point)):
				fail("%s still walks through the garbage can at %s" % [pawn.display_name, footprint])
				return
	_placed_frame = frame


func _step() -> void:
	if _placed_frame < 0:
		return
	for pawn: Pawn in work.get_pawns():
		var cell: Vector2i = _floor.global_to_cell(pawn.global_position)
		if not _floor.is_walkable(cell):
			fail("%s is standing on blocked cell %s" % [pawn.display_name, cell])
			return
	if frame - _placed_frame >= WATCH_FRAMES:
		pass_test("a pawn walked around a garbage can put down across their path")


## The longest walk the pawn could take from where they stand.
func _longest_walk(pawn: Pawn) -> PackedVector2Array:
	var from: Vector2i = _floor.global_to_cell(pawn.global_position)
	var best := PackedVector2Array()
	for cell: Vector2i in _floor.get_used_cells():
		var path: PackedVector2Array = _floor.get_path_points(from, cell)
		if path.size() > best.size():
			best = path
	return best
