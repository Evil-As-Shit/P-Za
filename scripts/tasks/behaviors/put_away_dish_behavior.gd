class_name PutAwayDishBehavior
extends TaskBehavior
## Restocking (a shop job the WorkManager opens while it's needed): a washed ingredient
## container is taken off a dish sink's clean drainboard and put away in storage for full
## ones (e.g. Dough), where it counts as full again (standing in for refilling it). One pawn
## at a time.

@export var ingredient: IngredientContainer


## A clean one is waiting at a sink, there's room for it in storage, and nobody is putting
## one away already.
func is_needed(work: WorkManager) -> bool:
	return (
		not is_under_way(work) and _find_sink(work) != null
		and work.find_room(ingredient.dish.put_away_kind) != null
	)


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if is_under_way(work):
		return false
	var sink: Station = _find_sink(work)
	var storage: Station = work.find_room(ingredient.dish.put_away_kind)
	if sink == null or storage == null:
		return false
	var stops: Array[JobStop] = [JobStop.take_dish(sink, ingredient.dish)]
	if not work.start_job(pawn, job, WorkSpot.new(storage, 0), stops):
		return false
	storage.claim_room()
	job.destination = storage
	work.add_shop_job(job)
	return true


func on_stop_reached(job: Job, stop: JobStop, pawn: Pawn, work: WorkManager) -> void:
	if stop.action != JobStop.Action.TAKE_DISH:
		return
	stop.station.get_dish_boards().take_clean(stop.dish)
	job.target = IngredientBehavior.spawn_container(ingredient, work, 0)
	pawn.hold_item(job.target)


## At storage: stored as a full one.
func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var item: Item = pawn.release_item()
	if item == null:
		return
	item.queue_free()
	job.target = null
	job.destination.add_stock()


## Interrupted: the room in storage is handed back. A container already taken is set down
## where the pawn is; it counts as empty and goes back to the sink.
func on_withdrawn(job: Job, work: WorkManager) -> void:
	if job.destination != null and is_instance_valid(job.destination):
		job.destination.unclaim_room()
	if job.target != null and is_instance_valid(job.target):
		job.target.set_lid(null)
	job.target = null
	work.cancel_shop_job(job)


## A sink with an unclaimed clean one of this ingredient's dish. Null if there's none.
func _find_sink(work: WorkManager) -> Station:
	for sink: Station in work.get_sinks():
		if sink.get_dish_boards().get_free_clean().has(ingredient.dish):
			return sink
	return null
