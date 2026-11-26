class_name ReturnBucketBehavior
extends TaskBehavior
## Restocking (a shop job the WorkManager opens while it's needed): a portion container left
## on the floor (e.g. a sauce bucket set down when a swap or put-away was interrupted) is
## taken where it belongs: an empty one to a dish sink's dirty drainboard (or storage for
## empties), a full one to storage for full ones (e.g. a prep table's cooler). One pawn at a
## time.

@export var supply: PortionContainer


func is_needed(work: WorkManager) -> bool:
	if is_under_way(work):
		return false
	for item: Item in _find_loose(work):
		if _find_destination(item, work) != null:
			return true
	return false


func get_carried(job: Job) -> Item:
	return job.target


func get_spots(job: Job, _work: WorkManager) -> Array[WorkSpot]:
	var spots: Array[WorkSpot] = []
	if job.destination != null:
		var sink: DishSink = job.destination.data.dish_sink
		spots.append(WorkSpot.new(job.destination, sink.dirty_spot if sink != null else 0))
	return spots


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if is_under_way(work):
		return false
	for item: Item in _find_loose(work):
		var destination: Station = _find_destination(item, work)
		if destination == null:
			continue
		job.target = item
		job.destination = destination
		if not super(pawn, job, work):
			continue
		if destination.get_dish_boards() != null:
			destination.get_dish_boards().claim_dirty_room()
		else:
			job.destination_kind = (
				supply.full_kind if item.portions_left > 0 else supply.empty_kind
			)
			job.destination_dish = null if item.portions_left > 0 else supply.dish
			destination.claim_room(job.destination_kind, job.destination_dish)
		work.add_shop_job(job)
		return true
	job.target = null
	job.destination = null
	return false


## At the sink: set down on the dirty board. At storage: stored.
func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var item: Item = pawn.release_item()
	if item == null:
		return
	item.queue_free()
	job.target = null
	if job.destination.get_dish_boards() != null:
		job.destination.get_dish_boards().add_dirty(supply.dish)
	elif job.destination_kind == supply.full_kind:
		job.destination.add_stock(job.destination_kind)
	else:
		job.destination.add_stock(job.destination_kind, -1, supply.dish)


## Interrupted: the room is handed back; the container stays where it is for later.
func on_withdrawn(job: Job, work: WorkManager) -> void:
	if job.destination != null and is_instance_valid(job.destination):
		if job.destination.get_dish_boards() != null:
			job.destination.get_dish_boards().unclaim_dirty_room()
		else:
			job.destination.unclaim_room(job.destination_kind, job.destination_dish)
	job.target = null
	work.cancel_shop_job(job)


## Containers of `supply` lying on the floor.
func _find_loose(work: WorkManager) -> Array[Item]:
	var loose: Array[Item] = []
	for item: Item in work.get_floor_items():
		if item.portions == supply:
			loose.append(item)
	return loose


## Where `item` goes, with room for it, or null.
func _find_destination(item: Item, work: WorkManager) -> Station:
	if item.portions_left > 0:
		return work.find_room(supply.full_kind)
	var sink: Station = work.find_dish_room() if supply.dish != null else null
	return sink if sink != null else work.find_room(supply.empty_kind, supply.dish)
