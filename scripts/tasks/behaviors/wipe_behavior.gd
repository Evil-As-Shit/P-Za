class_name WipeBehavior
extends TaskBehavior
## A chore (see WorkManager.chore_tasks): a pawn wipes down the nearest station that's dirty
## enough and nobody is wiping, at one of its free spots. No tools yet.

## A station needs wiping once it's at least this dirty (0 to 1). Placeholder.
@export var min_dirt: float = 0.5
## Shop minutes to wipe down a fully dirty station; a less dirty one takes less. Placeholder.
@export var minutes_when_full: float = 0.5


func is_needed(work: WorkManager) -> bool:
	return not _get_open_stations(work).is_empty()


## The nearest open station (by grid distance to a free spot) the pawn can walk to.
func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	var from: Vector2i = work.get_cell(pawn)
	var spots: Array[WorkSpot] = []
	for station: Station in _get_open_stations(work):
		for index: int in station.get_spot_count():
			if not station.is_reserved(index):
				spots.append(WorkSpot.new(station, index))
	spots.sort_custom(func(a: WorkSpot, b: WorkSpot) -> bool:
		return _distance(from, a.station.get_work_cell(a.index)) \
				< _distance(from, b.station.get_work_cell(b.index)))
	for spot: WorkSpot in spots:
		# How long it takes is set by how dirty it is now.
		job.extra_minutes = minutes_when_full * spot.station.get_dirt()
		job.destination = spot.station
		if work.start_job(pawn, job, spot, [] as Array[JobStop]):
			work.add_shop_job(job)
			return true
	job.destination = null
	return false


## The work is all in extra_minutes (see try_start()).
func get_work_seconds(_job: Job) -> float:
	return 0.0


## Nothing is set down: the pawn just wipes.
func on_work_started(_job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	pass


func on_finished(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	if is_instance_valid(job.destination):
		job.destination.clean()


func on_withdrawn(job: Job, work: WorkManager) -> void:
	work.cancel_shop_job(job)


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Stations dirty enough that nobody is wiping.
func _get_open_stations(work: WorkManager) -> Array[Station]:
	var taken: Array[Station] = []
	for job: Job in work.get_shop_jobs():
		if job.task_type.get_behavior() == self:
			taken.append(job.destination)
	var stations: Array[Station] = []
	for station: Station in work.get_stations():
		if station.get_dirt() >= min_dirt and not taken.has(station):
			stations.append(station)
	return stations
