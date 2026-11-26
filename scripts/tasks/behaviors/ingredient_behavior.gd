class_name IngredientBehavior
extends TaskBehavior
## Starts from one unit of an ingredient (e.g. a dough ball), which becomes the order
## item's item. The pawn takes it from an open container on a station that does the task;
## if none is open, they first fetch a full one from storage and set it out (lid off) on a
## free spot. Only one container is set out at a time. Whoever takes the last unit carries
## the empty container to a dish sink (or storage for empties) on the way, if there's room.

@export var ingredient: IngredientContainer


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if get_carried(job) != null:
		# Already taken (e.g. dropped when the job was pulled): carry it on as usual.
		return super(pawn, job, work)
	var spots: Array[WorkSpot] = get_spots(job, work)
	var container: Item = _find_open_container(job, work)
	if container != null:
		# Whoever ends up taking the last unit is decided on arrival (see TAKE_UNIT).
		var stops: Array[JobStop] = [JobStop.take_unit(container)]
		for spot: WorkSpot in spots:
			if work.start_job(pawn, job, spot, stops):
				return true
		return false
	if _is_setting_out(work):
		return false
	var storage: Station = work.find_supply(ingredient.full_kind)
	if storage == null:
		return false
	for set_out_spot: WorkSpot in spots:
		for spot: WorkSpot in spots:
			if spot.is_same(set_out_spot):
				continue
			var stops: Array[JobStop] = [
				JobStop.take_supply(storage, ingredient.full_kind),
				JobStop.set_out(set_out_spot.station, set_out_spot.index),
			]
			if work.start_job(pawn, job, spot, stops):
				return true
	return false


func on_supply_taken(job: Job, _station: Station, pawn: Pawn, work: WorkManager) -> void:
	pawn.hold_item(spawn_container(ingredient, work, job.taken_left))


func on_stop_reached(job: Job, stop: JobStop, pawn: Pawn, work: WorkManager) -> void:
	match stop.action:
		JobStop.Action.SET_OUT:
			# Lid off, onto the spot, and the first unit out.
			stop.station.release(stop.spot)
			var held: Item = pawn.get_held_item()
			if held.get_units().size() == 1 and _detour_to_store_empty(job, pawn, work):
				# A partly used one with just one unit left (see Station.take_supply()):
				# it'd be empty once set out, so it's carried off with its unit instead.
				held.set_lid(null)
				job.order_item.item = held.get_units().back()
				work.assign_all()
				return
			var container: Item = pawn.release_item()
			container.set_lid(null)
			stop.station.put_item(stop.spot, container)
			container.claim_unit()
			_take_unit(job, container, pawn)
			work.assign_all()
		JobStop.Action.TAKE_UNIT:
			var container: Item = stop.container
			if container.get_units().size() == 1 and _detour_to_store_empty(job, pawn, work):
				# The last unit: carry the container off with it, and take it out there.
				job.order_item.item = container.get_units().back()
				container.unclaim_unit()
				container.station.take_item(container.spot)
				pawn.hold_item(container)
				work.assign_all()
			else:
				_take_unit(job, container, pawn)
		JobStop.Action.STORE_EMPTY, JobStop.Action.DROP_DISH:
			var container: Item = pawn.release_item()
			var unit: Item = job.order_item.item
			container.take_out(unit)
			pawn.hold_item(unit)
			container.queue_free()
			if stop.action == JobStop.Action.DROP_DISH:
				stop.station.get_dish_boards().add_dirty(ingredient.dish)
			else:
				stop.station.add_stock(stop.kind, -1, ingredient.dish)
			work.assign_all()


## A container set out on a station that does the job's task, with a unit no one has
## claimed. Null if there's none.
func _find_open_container(job: Job, work: WorkManager) -> Item:
	for station: Station in work.get_stations():
		if not station.can_do(job.task_type):
			continue
		for index: int in station.get_spot_count():
			var item: Item = station.get_item(index)
			if item != null and item.ingredient == ingredient and item.get_free_units() > 0:
				return item
	return null


## True if a pawn is on their way to set out a container of this ingredient.
func _is_setting_out(work: WorkManager) -> bool:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null:
			continue
		var behavior: TaskBehavior = job.task_type.get_behavior()
		if not behavior is IngredientBehavior or (behavior as IngredientBehavior).ingredient != ingredient:
			continue
		for stop: JobStop in job.stops:
			if stop.action == JobStop.Action.SET_OUT:
				return true
	return false


## A container of `kind`, lid on, with `left` units in it (-1 for full). Units are taken
## from the front, so a partly used one keeps the ones at the back.
static func spawn_container(kind: IngredientContainer, work: WorkManager, left: int = -1) -> Item:
	var container: Item = work.spawn_item(null)
	container.ingredient = kind
	container.set_wrap(kind.back_texture, kind.front_texture)
	container.set_lid(kind.lid_texture)
	var count: int = kind.unit_offsets.size() if left < 0 else mini(left, kind.unit_offsets.size())
	for i: int in count:
		var unit: Item = work.spawn_item(kind.unit_texture)
		unit.display_name = kind.full_kind.display_name if kind.full_kind != null else kind.display_name
		unit.is_ingredient = true
		container.put_in(unit, kind.unit_offsets[i])
	return container


## Takes a claimed unit out of the container; it becomes the order item's item.
func _take_unit(job: Job, container: Item, pawn: Pawn) -> void:
	var unit: Item = container.take_unit()
	unit.display_name = job.order_item.recipe.display_name
	job.order_item.item = unit
	pawn.hold_item(unit)


## Adds a stop to drop the empty off before the pawn goes on to work: at a dish sink's dirty
## drainboard if one has room, else at storage for empties. Returns false if there's no room
## or they can't get there (the empty container stays where it is).
func _detour_to_store_empty(job: Job, pawn: Pawn, work: WorkManager) -> bool:
	var stop: JobStop = null
	var sink: Station = work.find_dish_room() if ingredient.dish != null else null
	if sink != null:
		stop = JobStop.drop_dish(sink)
	else:
		var empties: Station = work.find_room(ingredient.empty_kind, ingredient.dish)
		if empties == null:
			return false
		stop = JobStop.store_empty(empties, ingredient.empty_kind, ingredient.dish)
	var to_stop: PackedVector2Array = work.get_walk_path(work.get_cell(pawn), stop.cell)
	var to_work: PackedVector2Array = work.get_walk_path(
		stop.cell, job.station.get_work_cell(job.spot)
	)
	if to_stop.is_empty() or to_work.is_empty() or not pawn.detour(to_stop, to_work):
		return false
	stop.claim()
	job.stops.push_front(stop)
	return true
