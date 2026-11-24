extends "res://tests/test_base.gd"
## The starting shop's shifts: from prep to close at least two pawns are on shift every half
## hour, and while the shop is open (open to close, so orders taken before last orders get
## finished) the pawns on shift can do every step of an order between them: take it, make the
## pizza, and stack and hand it off.

const MIN_ON_SHIFT: int = 2
## Shifts and shop hours move in half hours.
const STEP_MINUTES: int = 30


func _init() -> void:
	keep_schedules = true


func _step() -> void:
	if frame < 60:
		return
	var hours := clock.hours
	var tasks: Array[TaskType] = [work.take_order_task, rack.stack_task, rack.hand_off_task]
	tasks.append_array(world.debug_recipe.steps)
	if work.get_manager() == null:
		fail("the starting shop has no manager, so no orders come in")
		return

	for minute: int in range(hours.prep_minute, hours.close_minute, STEP_MINUTES):
		var on_shift: Array[Pawn] = []
		for pawn: Pawn in work.get_pawns():
			if pawn.is_scheduled_at(minute):
				on_shift.append(pawn)
		if on_shift.size() < MIN_ON_SHIFT:
			fail("only %d pawn(s) on shift at minute %d" % [on_shift.size(), minute])
			return
		if minute < hours.open_minute:
			continue
		for task: TaskType in tasks:
			if not _anyone_can_do(on_shift, task):
				fail("nobody on shift at minute %d can %s" % [minute, task.id])
				return

	pass_test("%d+ pawns on shift from prep to close, and every order step is covered while open" % MIN_ON_SHIFT)


## True if one of `pawns` does `task`'s work (tasks with no work type, like baking, need nobody).
func _anyone_can_do(pawns: Array[Pawn], task: TaskType) -> bool:
	if task == null or task.work_type == null:
		return true
	for pawn: Pawn in pawns:
		if pawn.get_priority(task.work_type) > 0:
			return true
	return false
