class_name PutAwayDishBehavior
extends TaskBehavior
## Restocking (a shop job the WorkManager opens while it's needed): a clean dish is taken
## from storage for clean dishes (see StoreCleanDishBehavior) and put away in its storage
## (see Dish.put_away_kind, e.g. Dough, or a prep table's sauce cooler), where it counts as
## full again. A dish that's filled first (see Dish.filled_at, e.g. a sauce bucket at the
## bulk sauce bucket, a dough container at the bulk dough tub) is filled there on the way,
## in hand, using up some of the tub. One pawn at a time; a dish with nowhere to be filled
## (no tub, or an empty one) waits.

enum Part { PUT_AWAY, FILL }

## Storage clean dishes wait in.
@export var clean_kind: StorageKind
@export var dishes: DishCatalog
## Shop minutes to fill one (placeholder).
@export var fill_minutes: float = 0.5


## A clean dish is waiting with room for it in storage (and somewhere to fill it, if it's
## filled), and nobody is putting one away already.
func is_needed(work: WorkManager) -> bool:
	return not is_under_way(work) and not _find_clean(work).is_empty()


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if is_under_way(work):
		return false
	var found: Array = _find_clean(work)
	if found.is_empty():
		return false
	var source: Station = found[0]
	var dish: Dish = found[1]
	var storage: Station = found[2]
	var filler: Station = found[3]
	job.part = Part.FILL if filler != null else Part.PUT_AWAY
	var spot := WorkSpot.new(filler if filler != null else storage, 0)
	var stops: Array[JobStop] = [JobStop.take_supply(source, dish)]
	if not work.start_job(pawn, job, spot, stops):
		return false
	storage.claim_room()
	job.destination = storage
	work.add_shop_job(job)
	return true


func get_work_seconds(job: Job) -> float:
	if job.part == Part.FILL:
		return ShopClock.minutes_to_seconds(fill_minutes)
	return super(job)


## Taken from storage. One to be filled is still empty.
func on_supply_taken(job: Job, _station: Station, pawn: Pawn, work: WorkManager) -> void:
	if job.taken_dish == null:
		return
	job.target = dishes.spawn(job.taken_dish, work, job.part == Part.PUT_AWAY)
	pawn.hold_item(job.target)


## Filling is done in hand; at storage, it's stored as a full one.
func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	if job.part == Part.FILL:
		return
	var item: Item = pawn.release_item()
	if item == null:
		job.destination.unclaim_room()
		job.destination = null
		return
	item.queue_free()
	job.target = null
	job.destination.add_stock()
	job.destination = null


## Filled: the bulk tub's level drops, and the dish in hand is full (a dough container is
## swapped for a full one, with its dough balls).
func on_finished(job: Job, pawn: Pawn, work: WorkManager) -> void:
	if job.part != Part.FILL:
		return
	job.station.use_fill()
	if job.target == null or not is_instance_valid(job.target):
		return
	if job.target.portions != null:
		job.target.fill_portions(job.target.portions)
	elif job.target.ingredient != null:
		var full: Item = IngredientBehavior.spawn_container(job.target.ingredient, work)
		pawn.release_item().queue_free()
		job.target = full
		pawn.hold_item(full)


## Filled: the same pawn carries it to storage. If they can't get there, they set it down
## and it's taken there later (see ReturnBucketBehavior).
func continue_job(job: Job, pawn: Pawn, work: WorkManager) -> bool:
	if job.part != Part.FILL:
		return false
	job.station.release(job.spot)
	job.station = null
	job.spot = -1
	job.part = Part.PUT_AWAY
	job.work_done = 0.0
	if work.start_job(pawn, job, WorkSpot.new(job.destination, 0), [] as Array[JobStop]):
		return true
	job.destination.unclaim_room()
	job.destination = null
	job.target = null
	work.drop_on_floor(pawn.release_item(), work.get_cell(pawn))
	return false


## Interrupted: the room in storage is handed back. A dish already taken is set down where
## the pawn is: a dough container counts as empty and goes back to the sink, a sauce bucket
## goes back to the sink if it wasn't filled yet, or to a cooler if it was (see
## ReturnBucketBehavior).
func on_withdrawn(job: Job, work: WorkManager) -> void:
	if job.destination != null and is_instance_valid(job.destination):
		job.destination.unclaim_room()
	if job.target != null and is_instance_valid(job.target) and job.target.ingredient != null:
		job.target.set_lid(null)
	job.target = null
	job.destination = null
	work.cancel_shop_job(job)


## [source, dish, storage, filler]: storage for clean dishes holding `dish`, storage with
## room for it, and where to fill it (null if it isn't filled). Empty if there's none.
func _find_clean(work: WorkManager) -> Array:
	for source: Station in work.get_stations():
		if not source.has_supply(clean_kind):
			continue
		var seen: Array[Dish] = []
		for dish: Dish in source.get_stock_dishes():
			if seen.has(dish):
				continue
			seen.append(dish)
			var storage: Station = work.find_room(dish.put_away_kind)
			if storage == null:
				continue
			var filler: Station = null
			if dish.filled_at != null:
				filler = _find_filler(dish.filled_at, work)
				if filler == null:
					continue
			return [source, dish, storage, filler]
	return []


static func _find_filler(type: StationData, work: WorkManager) -> Station:
	for station: Station in work.get_stations():
		if station.data == type and not station.is_reserved(0) \
				and (type.bulk_tub == null or station.can_fill()):
			return station
	return null
