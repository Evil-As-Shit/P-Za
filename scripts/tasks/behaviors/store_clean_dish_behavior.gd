class_name StoreCleanDishBehavior
extends TaskBehavior
## Restocking (a shop job the WorkManager opens while it's needed): a washed dish is taken
## off a dish sink's clean drainboard and stored for clean dishes (e.g. a Clean Dishes
## rack), where it waits to be filled or put away (see PutAwayDishBehavior). One pawn at a
## time.

## Storage clean dishes wait in.
@export var clean_kind: StorageKind
@export var dishes: DishCatalog


## A clean dish is waiting at a sink with room for it in storage, and nobody is moving one
## already.
func is_needed(work: WorkManager) -> bool:
	return not is_under_way(work) and _find_clean(work).size() == 3


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if is_under_way(work):
		return false
	var found: Array = _find_clean(work)
	if found.size() < 3:
		return false
	var sink: Station = found[0]
	var dish: Dish = found[1]
	var storage: Station = found[2]
	var stops: Array[JobStop] = [JobStop.take_dish(sink, dish)]
	if not work.start_job(pawn, job, WorkSpot.new(storage, 0), stops):
		return false
	storage.claim_room(clean_kind, dish)
	job.destination = storage
	job.destination_dish = dish
	work.add_shop_job(job)
	return true


## At the sink: the dish is taken in hand. One that's filled later is carried empty, so if
## it's set down on the way it goes back to be washed.
func on_stop_reached(job: Job, stop: JobStop, pawn: Pawn, work: WorkManager) -> void:
	if stop.action != JobStop.Action.TAKE_DISH:
		return
	stop.station.get_dish_boards().take_clean(stop.dish)
	job.taken_dish = stop.dish
	job.target = dishes.spawn(stop.dish, work, stop.dish.filled_at == null)
	pawn.hold_item(job.target)


## At storage: stored as that dish.
func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var item: Item = pawn.release_item()
	if item == null:
		job.destination.unclaim_room(clean_kind, job.destination_dish)
		job.destination = null
		return
	item.queue_free()
	job.target = null
	job.destination.add_stock(clean_kind, -1, job.taken_dish)
	job.destination = null


## Interrupted: the room in storage is handed back. A dish already taken is set down where
## the pawn is: a dough container counts as empty and goes back to the sink, a sauce bucket
## too (see ReturnBucketBehavior).
func on_withdrawn(job: Job, work: WorkManager) -> void:
	if job.destination != null and is_instance_valid(job.destination):
		job.destination.unclaim_room(clean_kind, job.destination_dish)
	if job.target != null and is_instance_valid(job.target) and job.target.ingredient != null:
		job.target.set_lid(null)
	job.target = null
	work.cancel_shop_job(job)


## [sink, dish, storage]: a sink with an unclaimed clean dish, and storage with room for it.
## Empty if there's none.
func _find_clean(work: WorkManager) -> Array:
	for sink: Station in work.get_sinks():
		for dish: Dish in sink.get_dish_boards().get_free_clean():
			var storage: Station = work.find_room(clean_kind, dish)
			if storage != null:
				return [sink, dish, storage]
	return []
