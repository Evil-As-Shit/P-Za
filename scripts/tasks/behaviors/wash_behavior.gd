class_name WashBehavior
extends TaskBehavior
## A chore (see WorkManager.chore_tasks) done in parts by one pawn at a dish sink: they take
## every dish on the dirty drainboard (as many as fit on the clean one), then wash them all,
## rinse them all and sanitize them all at each basin in turn, and set the batch down on the
## clean drainboard. The dishes aren't shown while they're being washed. One batch per sink
## at a time.

enum Part { TAKE, WASH, RINSE, SANITIZE, SET_DOWN }

## Shop minutes of work per dish at each basin, in DishSink.basin_spots order (wash, rinse,
## sanitize). Placeholders.
@export var basin_minutes: Array[float] = [0.5, 0.25, 0.25]


## A sink has dirty dishes, room on its clean board, and nobody washing there.
func is_needed(work: WorkManager) -> bool:
	return _find_sink(work) != null


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	var sink: Station = _find_sink(work)
	if sink == null:
		return false
	job.destination = sink
	if not work.start_job(pawn, job, WorkSpot.new(sink, sink.data.dish_sink.dirty_spot), [] as Array[JobStop]):
		job.destination = null
		return false
	work.add_shop_job(job)
	return true


## Taking and setting down are part of moving between basins; the basins take work per dish.
func get_work_seconds(job: Job) -> float:
	if job.part >= Part.WASH and job.part <= Part.SANITIZE:
		var minutes: float = basin_minutes[job.part - Part.WASH] * job.dishes.size()
		return ShopClock.minutes_to_seconds(minutes)
	return 0.0


func on_work_started(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	var boards: DishBoards = job.destination.get_dish_boards()
	match job.part:
		Part.TAKE:
			var count: int = mini(boards.get_dirty_count(), boards.get_clean_room())
			boards.claim_clean_room(count)
			job.dishes = boards.take_dirty(count)
		Part.SET_DOWN:
			boards.add_clean(job.dishes)
			job.dishes = []


## On to the next basin (or the clean board) at the same sink.
func continue_job(job: Job, pawn: Pawn, work: WorkManager) -> bool:
	if job.part == Part.SET_DOWN or job.dishes.is_empty():
		return false
	var sink: Station = job.destination
	var next: int = job.part + 1
	var spot: int = sink.data.dish_sink.clean_spot
	if next <= Part.SANITIZE:
		spot = sink.data.dish_sink.basin_spots[next - Part.WASH]
	if work.start_next_part(pawn, job, next, [WorkSpot.new(sink, spot)] as Array[WorkSpot]):
		return true
	_put_back(job)
	work.cancel_shop_job(job)
	return false


## Interrupted (e.g. the sink was picked up): the batch goes back on the dirty board,
## unwashed.
func on_withdrawn(job: Job, work: WorkManager) -> void:
	_put_back(job)
	work.cancel_shop_job(job)


func _put_back(job: Job) -> void:
	if job.dishes.is_empty() or not is_instance_valid(job.destination):
		return
	var boards: DishBoards = job.destination.get_dish_boards()
	boards.unclaim_clean_room(job.dishes.size())
	boards.put_back_dirty(job.dishes)
	job.dishes = []


## A sink with dirty dishes, room on its clean board, no batch being washed and its spots
## free. Null if there's none.
func _find_sink(work: WorkManager) -> Station:
	for sink: Station in work.get_sinks():
		var boards: DishBoards = sink.get_dish_boards()
		if boards.get_dirty_count() == 0 or boards.get_clean_room() <= 0 or _is_washing_at(sink, work):
			continue
		if not sink.is_reserved(sink.data.dish_sink.dirty_spot):
			return sink
	return null


func _is_washing_at(sink: Station, work: WorkManager) -> bool:
	for job: Job in work.get_shop_jobs():
		if job.task_type.get_behavior() == self and job.destination == sink:
			return true
	return false
