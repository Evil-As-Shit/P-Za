class_name RefillPanBehavior
extends TaskBehavior
## Restocking (a shop job the WorkManager opens while it's needed), done in two parts by
## one pawn: they take a bag from storage (see IngredientPan.bag_kind), refill a station's
## pan that's running low (standing at one of its free spots), then throw the empty bag in
## the garbage. One pawn at a time.

enum Part { REFILL, THROW_OUT }

@export var pan: IngredientPan
## Shop minutes to throw the bag out once at the garbage.
@export var throw_out_minutes: float = 0.1


## A pan is running low, there's a bag in storage, and nobody is refilling one already.
func is_needed(work: WorkManager) -> bool:
	return not is_under_way(work) and _find_low(work) != null and work.find_supply(pan.bag_kind) != null


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if is_under_way(work):
		return false
	var station: Station = _find_low(work)
	var storage: Station = work.find_supply(pan.bag_kind)
	if station == null or storage == null:
		return false
	job.part = Part.REFILL
	for spot: int in station.get_spot_count():
		if station.is_reserved(spot):
			continue
		var stops: Array[JobStop] = [JobStop.take_supply(storage)]
		if work.start_job(pawn, job, WorkSpot.new(station, spot), stops):
			work.add_shop_job(job)
			return true
	return false


func get_carried(job: Job) -> Item:
	return job.target


func get_work_seconds(job: Job) -> float:
	if job.part == Part.THROW_OUT:
		return ShopClock.minutes_to_seconds(throw_out_minutes)
	return ShopClock.minutes_to_seconds(pan.refill_minutes)


func on_supply_taken(job: Job, _station: Station, pawn: Pawn, work: WorkManager) -> void:
	job.target = work.spawn_item(pan.bag_texture)
	pawn.hold_item(job.target)


## Refilling is done in hand; at the garbage, the bag is set down in it.
func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	if job.part != Part.THROW_OUT:
		return
	var bag: Item = pawn.release_item()
	if bag != null:
		job.station.put_item(job.spot, bag)


func on_finished(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	if job.part == Part.REFILL:
		job.station.fill_pan(pan)
		return
	job.station.take_item(job.spot)
	if job.target != null and is_instance_valid(job.target):
		job.target.queue_free()
	job.target = null


## Refilled: the same pawn takes the empty bag to the garbage. If they can't get there,
## they set it down and it's thrown out later.
func continue_job(job: Job, pawn: Pawn, work: WorkManager) -> bool:
	if job.part != Part.REFILL:
		return false
	job.station.release(job.spot)
	job.station = null
	job.spot = -1
	job.part = Part.THROW_OUT
	job.work_done = 0.0
	for spot: WorkSpot in work.get_free_spots(work.throw_out_task, job.target):
		if work.start_job(pawn, job, spot, [] as Array[JobStop]):
			return true
	var bag: Item = pawn.release_item()
	job.target = null
	if bag != null:
		work.drop_on_floor(bag, work.get_cell(pawn))
		work.throw_out(bag)
	return false


## Interrupted: a bag already taken was set down where the pawn is, and is thrown out (a
## bag that wasn't used yet is wasted for now); one already in the garbage is gone.
func on_withdrawn(job: Job, work: WorkManager) -> void:
	var bag: Item = job.target
	if bag != null and is_instance_valid(bag):
		if bag.station != null:
			bag.station.take_item(bag.spot)
			bag.queue_free()
		else:
			work.throw_out(bag)
	job.target = null
	work.cancel_shop_job(job)


## A station whose pan is running low, or null.
func _find_low(work: WorkManager) -> Station:
	for station: Station in work.get_stations():
		var left: int = station.get_pan_left(pan)
		if left >= 0 and left <= pan.refill_at:
			return station
	return null
