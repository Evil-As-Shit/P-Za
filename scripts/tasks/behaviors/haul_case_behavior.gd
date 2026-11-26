class_name HaulCaseBehavior
extends TaskBehavior
## Restocking (a shop job the WorkManager opens while it's needed): a pawn takes a supply
## case off a delivery drop-off and puts it away where its supply is kept, once there's room
## for the whole case: its units go into storage (e.g. 3 cheese bags on a Cheese rack), or
## it's poured into its bulk tub (e.g. sauce into the bulk sauce bucket). Several pawns can
## haul cases at once.


## A case is waiting with room for it somewhere.
func is_needed(work: WorkManager) -> bool:
	return not _find_case(work).is_empty()


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	var found: Array = _find_case(work)
	if found.is_empty():
		return false
	var source: Station = found[0]
	var supply: SupplyItem = found[1]
	var destination: Station = found[2]
	var stops: Array[JobStop] = [JobStop.take_case(source, supply)]
	if not work.start_job(pawn, job, WorkSpot.new(destination, 0), stops):
		return false
	_claim_room(destination, supply)
	job.destination = destination
	job.supply = supply
	work.add_shop_job(job)
	return true


func get_carried(job: Job) -> Item:
	return job.target


## At the drop-off: the case comes off it and into the pawn's hands.
func on_stop_reached(job: Job, stop: JobStop, pawn: Pawn, work: WorkManager) -> void:
	if stop.action != JobStop.Action.TAKE_CASE:
		return
	stop.station.get_dock_cases().take(stop.supply)
	job.supply_source = stop.station
	job.target = work.spawn_item(stop.supply.case_texture)
	job.target.display_name = "%s Case" % stop.supply.display_name
	pawn.hold_item(job.target)


## At storage: the case is put away (its units stored, or poured into the tub).
func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var item: Item = pawn.release_item()
	if item != null:
		item.queue_free()
	job.target = null
	var supply: SupplyItem = job.supply
	if supply.bulk_station != null:
		job.destination.add_bulk(supply.units_per_case)
	else:
		for i: int in supply.units_per_case:
			job.destination.add_stock(job.supply.storage_kind)
	if job.supply_source != null and is_instance_valid(job.supply_source):
		job.supply_source.get_dock_cases().finish(supply)
	job.supply = null
	job.supply_source = null
	job.destination = null


## Interrupted: the room at storage is handed back, and a case already taken goes back on
## its drop-off (it's taken again later).
func on_withdrawn(job: Job, work: WorkManager) -> void:
	if job.supply != null and job.destination != null and is_instance_valid(job.destination):
		_unclaim_room(job.destination, job.supply)
	if job.target != null and is_instance_valid(job.target):
		if job.target.station != null:
			job.target.station.take_item(job.target.spot)
		job.target.queue_free()
	if job.supply_source != null and is_instance_valid(job.supply_source) \
			and job.supply_source.get_dock_cases() != null:
		job.supply_source.get_dock_cases().put_back(job.supply)
	job.target = null
	job.supply = null
	job.supply_source = null
	job.destination = null
	work.cancel_shop_job(job)


## [drop-off, supply, destination] for a case waiting with room for it, or empty.
func _find_case(work: WorkManager) -> Array:
	for source: Station in work.get_stations():
		var cases: DockCases = source.get_dock_cases()
		if cases == null:
			continue
		for supply: SupplyItem in cases.get_free():
			for destination: Station in work.get_stations():
				if supply.has_room_for_case(destination) and not destination.is_reserved(0):
					return [source, supply, destination]
	return []


static func _claim_room(station: Station, supply: SupplyItem) -> void:
	if supply.bulk_station != null:
		station.claim_bulk_room(supply.units_per_case)
	else:
		for i: int in supply.units_per_case:
			station.claim_room(supply.storage_kind)


static func _unclaim_room(station: Station, supply: SupplyItem) -> void:
	if supply.bulk_station != null:
		station.unclaim_bulk_room(supply.units_per_case)
	else:
		for i: int in supply.units_per_case:
			station.unclaim_room(supply.storage_kind)
