class_name MopBehavior
extends TaskBehavior
## A chore (see WorkManager.chore_tasks): a pawn walks onto the nearest floor cell (see
## FloorDirt) that's dirty enough and nobody is mopping, and mops it clean. No tools yet.

## A cell needs mopping once it's at least this dirty (0 to 1). Placeholder.
@export var min_dirt: float = 0.5
## Shop minutes to mop a fully dirty cell; a less dirty one takes less. Placeholder.
@export var minutes_when_full: float = 0.5


func is_needed(work: WorkManager) -> bool:
	return not _get_open_cells(work).is_empty()


## The nearest open cell the pawn can walk to (by grid distance; dirtier first on a tie).
func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	var from: Vector2i = work.get_cell(pawn)
	var cells: Array[Vector2i] = _get_open_cells(work)
	# Stable from dirtiest-first, so a tie keeps the dirtier cell first.
	var order: Array[int] = []
	order.assign(range(cells.size()))
	order.sort_custom(func(a: int, b: int) -> bool:
		var dist_a: int = _distance(from, cells[a])
		var dist_b: int = _distance(from, cells[b])
		return dist_a < dist_b or (dist_a == dist_b and a < b))
	for index: int in order:
		var cell: Vector2i = cells[index]
		# How long it takes is set by how dirty it is now, not by steps while mopping.
		job.extra_minutes = minutes_when_full * work.floor_dirt.get_dirt(cell)
		if work.start_floor_job(pawn, job, cell):
			work.add_shop_job(job)
			return true
	return false


## The work is all in extra_minutes (see try_start()).
func get_work_seconds(_job: Job) -> float:
	return 0.0


func on_work_started(_job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	pass


func on_finished(job: Job, _pawn: Pawn, work: WorkManager) -> void:
	work.floor_dirt.clean(job.floor_cell)


func on_withdrawn(job: Job, work: WorkManager) -> void:
	work.cancel_shop_job(job)


## Steps between two cells walking along the grid (ignoring what's in the way).
static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Dirty enough cells, dirtiest first, that pawns can stand on and nobody is mopping.
func _get_open_cells(work: WorkManager) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if work.floor_dirt == null:
		return cells
	var taken: Array[Vector2i] = []
	for job: Job in work.get_shop_jobs():
		if job.task_type.get_behavior() == self:
			taken.append(job.floor_cell)
	for cell: Vector2i in work.floor_dirt.get_dirty_cells(min_dirt):
		if not taken.has(cell) and work.is_walkable(cell):
			cells.append(cell)
	return cells
