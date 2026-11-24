class_name FloorCleanBehavior
extends TaskBehavior
## A chore (see WorkManager.chore_tasks) cleaning something off a floor cell (see FloorDirt):
## a pawn walks onto the nearest cell that needs it and nobody is cleaning, and works there
## standing on it (WorkManager.start_floor_job()). No tools yet. Subclasses say which cells
## need it, how long it takes and what's cleaned.


func is_needed(work: WorkManager) -> bool:
	return not _get_open_cells(work).is_empty()


## The nearest open cell the pawn can walk to (by grid distance; on a tie, the one
## _get_cells() puts first).
func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	var from: Vector2i = work.get_cell(pawn)
	var cells: Array[Vector2i] = _get_open_cells(work)
	var order: Array[int] = []
	order.assign(range(cells.size()))
	order.sort_custom(func(a: int, b: int) -> bool:
		var dist_a: int = _distance(from, cells[a])
		var dist_b: int = _distance(from, cells[b])
		return dist_a < dist_b or (dist_a == dist_b and a < b))
	for index: int in order:
		var cell: Vector2i = cells[index]
		# How long it takes is set now, not by steps taken there while cleaning.
		job.extra_minutes = _get_minutes(cell, work)
		if work.start_floor_job(pawn, job, cell):
			work.add_shop_job(job)
			return true
	return false


## The work is all in extra_minutes (see try_start()).
func get_work_seconds(_job: Job) -> float:
	return 0.0


## Nothing is set down: the pawn just cleans.
func on_work_started(_job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	pass


func on_finished(job: Job, _pawn: Pawn, work: WorkManager) -> void:
	_clean(job.floor_cell, work)


func on_withdrawn(job: Job, work: WorkManager) -> void:
	work.cancel_shop_job(job)


## Override: cells that need cleaning, in tie-break order.
func _get_cells(_work: WorkManager) -> Array[Vector2i]:
	return []


## Override: shop minutes to clean the cell.
func _get_minutes(_cell: Vector2i, _work: WorkManager) -> float:
	return 0.0


## Override: the cell is cleaned.
func _clean(_cell: Vector2i, _work: WorkManager) -> void:
	pass


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Cells from _get_cells() that pawns can stand on and nobody is cleaning this way.
func _get_open_cells(work: WorkManager) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if work.floor_dirt == null:
		return cells
	var taken: Array[Vector2i] = []
	for job: Job in work.get_shop_jobs():
		if job.task_type.get_behavior() == self:
			taken.append(job.floor_cell)
	for cell: Vector2i in _get_cells(work):
		if not taken.has(cell) and work.is_walkable(cell):
			cells.append(cell)
	return cells
