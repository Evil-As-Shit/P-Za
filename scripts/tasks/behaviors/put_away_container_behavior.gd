class_name PutAwayContainerBehavior
extends TaskBehavior
## Restocking (a shop job the WorkManager opens while it's needed): once no pizzas are
## being made, an ingredient container left set out (e.g. the dough bucket on the prep
## table) gets its lid back on and goes back to its storage, keeping what's left in it.
## The next one taken out is that one (see Station.take_supply()).

@export var ingredient: IngredientContainer


## A container is set out with units left that nobody's after, nothing needs it now, there's
## room to store it, and nobody's putting one away already.
## An empty one left out (if the pawn who emptied it couldn't carry it off) goes to storage
## for empties instead, whenever there's room.
func is_needed(work: WorkManager) -> bool:
	if is_under_way(work):
		return false
	var container: Item = _find_idle_container(work)
	return container != null and _find_storage(container, work) != null


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
	var container: Item = _find_idle_container(work)
	if container == null:
		return false
	var storage: Station = _find_storage(container, work)
	if storage == null:
		return false
	job.target = container
	job.destination = storage
	if not super(pawn, job, work):
		job.target = null
		job.destination = null
		return false
	if storage.get_dish_boards() != null:
		storage.get_dish_boards().claim_dirty_room()
	else:
		job.destination_kind = (
			ingredient.empty_kind if container.get_units().is_empty() else ingredient.full_kind
		)
		job.destination_dish = ingredient.dish if container.get_units().is_empty() else null
		storage.claim_room(job.destination_kind, job.destination_dish)
	# Its units are spoken for now, so nobody comes to take one from it meanwhile.
	for i: int in container.get_units().size():
		container.claim_unit()
	work.add_shop_job(job)
	return true


func on_picked_up(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	job.target.set_lid(ingredient.lid_texture)


## At storage: stored with however many units are left in it. At a sink: set down on the
## dirty board.
func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var container: Item = pawn.release_item()
	if container == null:
		return
	var left: int = container.get_units().size()
	container.queue_free()
	job.target = null
	if job.destination.get_dish_boards() != null:
		job.destination.get_dish_boards().add_dirty(ingredient.dish)
	else:
		job.destination.add_stock(
			job.destination_kind, left if left > 0 else -1, ingredient.dish if left == 0 else null
		)


## Interrupted: the room at storage and the container's units are handed back. The
## container stays where it is (set down on the floor if it was being carried), and is put
## away later.
func on_withdrawn(job: Job, work: WorkManager) -> void:
	var container: Item = job.target
	if container != null and is_instance_valid(container):
		for i: int in container.get_units().size():
			container.unclaim_unit()
		if job.destination != null and is_instance_valid(job.destination):
			if job.destination.get_dish_boards() != null:
				job.destination.get_dish_boards().unclaim_dirty_room()
			else:
				job.destination.unclaim_room(job.destination_kind, job.destination_dish)
	job.target = null
	work.cancel_shop_job(job)


## A container of this ingredient left out (set out on a station, or on the floor): an
## empty one any time, or else one with units left and none of them promised to a pawn,
## while no pizza is waiting on this ingredient. Null otherwise.
func _find_idle_container(work: WorkManager) -> Item:
	var candidates: Array[Item] = work.get_floor_items()
	for station: Station in work.get_stations():
		for spot: int in station.get_spot_count():
			if station.get_item(spot) != null:
				candidates.append(station.get_item(spot))
	var idle: Item = null
	for item: Item in candidates:
		if item.ingredient != ingredient or not work.is_available(item):
			continue
		if item.get_units().is_empty():
			return item
		if idle == null and item.get_free_units() == item.get_units().size():
			idle = item
	if idle != null and _is_wanted(work):
		return null
	return idle


## Where it goes, with room for it: an empty one to a dish sink (or else storage for
## empties), one with units left to storage for full ones.
func _find_storage(container: Item, work: WorkManager) -> Station:
	if container.get_units().is_empty():
		var sink: Station = work.find_dish_room() if ingredient.dish != null else null
		return sink if sink != null else work.find_room(ingredient.empty_kind, ingredient.dish)
	return work.find_room(ingredient.full_kind)


## True if a pizza in Make still needs this ingredient's step, or a pawn is doing it.
func _is_wanted(work: WorkManager) -> bool:
	for ticket: Ticket in work.get_make_tickets():
		for order_item: OrderItem in ticket.order_items:
			var job: Job = order_item.current_job
			if job != null and _uses_ingredient(job):
				return true
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job != null and _uses_ingredient(job):
			return true
	return false


func _uses_ingredient(job: Job) -> bool:
	var behavior: TaskBehavior = job.task_type.get_behavior()
	return behavior is IngredientBehavior and (behavior as IngredientBehavior).ingredient == ingredient
