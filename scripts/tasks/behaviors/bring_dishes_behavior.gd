class_name BringDishesBehavior
extends TaskBehavior
## Restocking (a shop job the WorkManager opens while it's needed): an empty ingredient
## container stored for empties (e.g. Empty Dough, the overflow while the sinks are full) is
## carried to a dish sink's dirty drainboard. One pawn at a time.

@export var ingredient: IngredientContainer


## There's an empty one in storage, room for it at a sink, and nobody bringing one already.
func is_needed(work: WorkManager) -> bool:
	return (
		not is_under_way(work) and work.find_supply(ingredient.empty_kind) != null
		and work.find_dish_room() != null
	)


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if is_under_way(work):
		return false
	var source: Station = work.find_supply(ingredient.empty_kind)
	var sink: Station = work.find_dish_room()
	if source == null or sink == null:
		return false
	var spot := WorkSpot.new(sink, sink.data.dish_sink.dirty_spot)
	if not work.start_job(pawn, job, spot, [JobStop.take_supply(source)] as Array[JobStop]):
		return false
	sink.get_dish_boards().claim_dirty_room()
	job.destination = sink
	work.add_shop_job(job)
	return true


func on_supply_taken(job: Job, _station: Station, pawn: Pawn, work: WorkManager) -> void:
	job.target = IngredientBehavior.spawn_container(ingredient, work, 0)
	job.target.set_lid(null)
	pawn.hold_item(job.target)


## At the sink: set down on the dirty board.
func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var item: Item = pawn.release_item()
	if item == null:
		return
	item.queue_free()
	job.target = null
	job.destination.get_dish_boards().add_dirty(ingredient.dish)


## Interrupted: the room at the sink is handed back. An empty container already taken is set
## down where the pawn is, and put away again later (see PutAwayContainerBehavior).
func on_withdrawn(job: Job, work: WorkManager) -> void:
	if job.destination != null and is_instance_valid(job.destination):
		job.destination.get_dish_boards().unclaim_dirty_room()
	job.target = null
	work.cancel_shop_job(job)
