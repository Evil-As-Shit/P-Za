class_name PortionBehavior
extends TaskBehavior
## Works the item at its spot like the default behavior, and takes portions from a container
## of `supply` sitting in the station's side areas (e.g. sauce from the sauce bucket on the
## prep table) when the work is done. A station that doesn't come with one (see
## StationData.side_items) works as before.
## When the container is empty (or gone), the pawn swaps it first: they carry the empty to a
## dish sink's dirty drainboard (or storage for empties), take a full one from storage (e.g.
## a prep table's cooler, this table's first) and set it out. Only one pawn swaps at a
## station at a time; with no full one in storage, the work there waits.

enum SupplyState {
	## Enough left for one more job (or the station doesn't come with a container).
	READY,
	## The last portions are promised to pawns on their way: wait for them.
	WAIT,
	## Missing or empty: swap it first.
	SWAP,
}

@export var supply: PortionContainer
## Portions one job uses.
@export var amount: int = 1


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	var carried: Item = get_carried(job)
	if carried != null and not work.is_available(carried):
		return false
	for spot: WorkSpot in get_spots(job, work):
		var stops: Array[JobStop] = []
		var at_spot: bool = carried == null or work.is_item_at(carried, spot)
		if not at_spot:
			stops.append(JobStop.pick_up(work.get_pickup_cell(carried)))
		elif carried != null and carried.busy:
			continue
		match _get_supply_state(spot.station, work):
			SupplyState.WAIT:
				continue
			SupplyState.SWAP:
				# The swap needs free hands, so the item must already be at the spot.
				if not at_spot or not _plan_swap(spot, work, stops):
					continue
		if work.start_job(pawn, job, spot, stops):
			return true
	return false


## Whether a new job at `station` can take its portions now.
func _get_supply_state(station: Station, work: WorkManager) -> SupplyState:
	if not station.data.side_items.has(supply):
		return SupplyState.READY
	var container: Item = get_container(station)
	if container == null:
		return SupplyState.SWAP
	var promised: int = count_jobs_at(station, work) * amount
	if container.portions_left - promised >= amount:
		return SupplyState.READY
	return SupplyState.WAIT if promised > 0 else SupplyState.SWAP


## The station's container of `supply` in its side areas, or null.
func get_container(station: Station) -> Item:
	for item: Item in station.get_side_items():
		if item.portions == supply:
			return item
	return null


## Adds the stops for swapping the container at `spot`'s station. Returns false if it can't
## be done now (someone's swapping there already, no full one in storage, or no room for
## the empty).
func _plan_swap(spot: WorkSpot, work: WorkManager, stops: Array[JobStop]) -> bool:
	var station: Station = spot.station
	if _is_swapping(station, work):
		return false
	var storage: Station = station if station.has_supply(supply.full_kind) else work.find_supply(supply.full_kind)
	if storage == null:
		return false
	var cell: Vector2i = station.get_work_cell(spot.index)
	var empty: Item = get_container(station)
	if empty != null:
		var drop: JobStop = _find_drop(work)
		if drop == null:
			return false
		stops.append(JobStop.take_side(empty, cell))
		stops.append(drop)
	stops.append(JobStop.take_supply(storage))
	stops.append(JobStop.set_side(station, cell))
	return true


## Where an empty one goes: a dish sink's dirty drainboard with room, else storage for
## empties with room. Null if neither has room.
func _find_drop(work: WorkManager) -> JobStop:
	var sink: Station = work.find_dish_room() if supply.dish != null else null
	if sink != null:
		return JobStop.drop_dish(sink)
	var empties: Station = work.find_room(supply.empty_kind)
	return JobStop.store_empty(empties) if empties != null else null


## True if a pawn is on their way to set a container out at `station`.
func _is_swapping(station: Station, work: WorkManager) -> bool:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null:
			continue
		for stop: JobStop in job.stops:
			if stop.action == JobStop.Action.SET_SIDE and stop.station == station:
				return true
	return false


func on_supply_taken(_job: Job, _station: Station, pawn: Pawn, work: WorkManager) -> void:
	pawn.hold_item(supply.spawn(work, true))


func on_stop_reached(_job: Job, stop: JobStop, pawn: Pawn, work: WorkManager) -> void:
	match stop.action:
		JobStop.Action.TAKE_SIDE:
			var empty: Item = stop.container
			if is_instance_valid(empty) and empty.station != null:
				empty.station.take_side_item(empty)
				pawn.hold_item(empty)
		JobStop.Action.DROP_DISH, JobStop.Action.STORE_EMPTY:
			var empty: Item = pawn.release_item()
			if empty == null:
				stop.release()
				return
			empty.queue_free()
			if stop.action == JobStop.Action.DROP_DISH:
				stop.station.get_dish_boards().add_dirty(supply.dish)
			else:
				stop.station.add_stock(-1, supply.dish)
		JobStop.Action.SET_SIDE:
			var full: Item = pawn.release_item()
			if full != null and not stop.station.put_side_item(full, supply.slot_size):
				work.drop_on_floor(full, stop.cell)
			work.assign_all()


func on_finished(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	if job.station == null:
		return
	var container: Item = get_container(job.station)
	if container != null:
		container.use_portions(amount)
