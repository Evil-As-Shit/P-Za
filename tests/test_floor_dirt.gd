extends "res://tests/test_base.gd"
## Floor dirt:
## 1. Pawns walking dirty the cells they step on.
## 2. A cell dirty enough gets mopped clean by a Cleaning pawn standing on it, with work
##    time set by how dirty it was; a cell below the threshold is left alone.

var _dirt: FloorDirt
var _floor: ShopFloor
var _filthy := Vector2i.ZERO
var _light := Vector2i.ZERO
var _mop_job: Job = null
var _stood_on_cell: bool = false
var _seeded: float = 0.0


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_dirt = world.get_node("FloorDirt")
	_floor = world.get_node("ShopFloor")
	_filthy = _floor.get_random_walkable_cell()
	_light = _floor.get_random_walkable_cell()
	while _light == _filthy:
		_light = _floor.get_random_walkable_cell()
	_dirt.add_dirt(_filthy, 1.0)
	_dirt.add_dirt(_light, 0.3)
	_seeded = 1.3
	work.assign_all()


func _step() -> void:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null or job.task_type.id != &"mop_floor":
			continue
		if job.floor_cell == _light:
			fail("mopped a cell below the threshold")
			return
		if job.floor_cell == _filthy:
			_mop_job = job
			if pawn.is_working() and work.get_cell(pawn) == _filthy:
				_stood_on_cell = true
	# Done once the filthy cell is clean and walking has dirtied some other cell.
	if _mop_job == null or _dirt.get_dirt(_filthy) > 0.0 or not _walked_dirt():
		return
	if not _stood_on_cell:
		fail("the cell was cleaned without a pawn working on it")
	elif not is_equal_approx(_mop_job.extra_minutes, 0.5):
		fail("mopping a fully dirty cell took %.2f minutes, not 0.5" % _mop_job.extra_minutes)
	else:
		pass_test("walking dirties the floor; a filthy cell was mopped, a light one left")


func _walked_dirt() -> bool:
	for cell: Vector2i in _dirt.get_dirty_cells(0.001):
		if cell != _filthy and cell != _light:
			return true
	return false
