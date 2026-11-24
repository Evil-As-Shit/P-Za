extends "res://tests/test_base.gd"
## Spills: a sauce step that spills (chance forced to 1) leaves a spill where the pawn stood
## at the prep table, and a Cleaning pawn standing on that cell cleans it up.

var _sauce: TaskType = load("res://resources/tasks/sauce.tres")
var _dirt: FloorDirt
var _spill_cell := Vector2i.ZERO
var _spilled: bool = false
var _clean_job: Job = null
var _stood_on_cell: bool = false
var _old_chance: float = 0.0


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_dirt = world.get_node("FloorDirt")
	_old_chance = _sauce.spill_chance
	_sauce.spill_chance = 1.0
	order_pizzas(1)


func _step() -> void:
	if not _spilled:
		var spills: Array[Vector2i] = _dirt.get_spills()
		if spills.is_empty():
			return
		_spilled = true
		_spill_cell = spills[0]
		# One spill is enough to check.
		_sauce.spill_chance = _old_chance
		var prep: Station = world.get_node("Entities/PrepTable")
		var at_prep: bool = false
		for spot: int in prep.get_spot_count():
			if prep.get_work_cell(spot) == _spill_cell:
				at_prep = true
		if spills.size() != 1:
			fail("one sauce step left %d spills" % spills.size())
		elif not at_prep:
			fail("the spill wasn't where the pawn stood at the prep table")
		return
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job != null and job.task_type.id == &"clean_spill" and job.floor_cell == _spill_cell:
			_clean_job = job
			if pawn.is_working() and work.get_cell(pawn) == _spill_cell:
				_stood_on_cell = true
	if _clean_job == null or _dirt.has_spill(_spill_cell):
		return
	if not _stood_on_cell:
		fail("the spill was cleaned without a pawn working on it")
	elif not is_equal_approx(_clean_job.extra_minutes, 0.5):
		fail("cleaning a spill took %.2f minutes, not 0.5" % _clean_job.extra_minutes)
	else:
		pass_test("a sauce spill appeared where the pawn stood and was cleaned up")
