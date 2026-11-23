class_name RackWhenFullBehavior
extends TaskBehavior
## Carries the item to a free spot like the default behavior (e.g. loading the oven). When
## every spot is taken, the pawn parks the item on a free rack slot instead (a station that
## does `rack_task`), freeing where it was made; the step stays open and the item is taken
## from the rack once a spot frees up.

## What a station holding parked items does (e.g. the pizza rack's "Rack pizza").
@export var rack_task: TaskType

## Job.part while the pawn is parking the item rather than doing the step.
const PARKING: int = 1


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	job.part = 0
	if super(pawn, job, work):
		return true
	if not _should_park(job, work):
		return false
	var carried: Item = get_carried(job)
	for spot: WorkSpot in work.get_free_spots(rack_task, carried):
		var stops: Array[JobStop] = [JobStop.pick_up(work.get_pickup_cell(carried))]
		job.part = PARKING
		if work.start_job(pawn, job, spot, stops):
			return true
	job.part = 0
	return false


## Parks only when there are stations for the step and all are full, and the item isn't
## parked already or still being worked.
func _should_park(job: Job, work: WorkManager) -> bool:
	if rack_task == null:
		return false
	var carried: Item = get_carried(job)
	if carried == null or carried.busy or not work.is_available(carried):
		return false
	var outer: Item = carried.get_outermost()
	if outer.station == null or outer.station.can_do(rack_task):
		return false
	for station: Station in work.get_stations():
		if station.can_do(job.task_type):
			return true
	return false


## A spot may have freed up while the pawn came for the item: they take it there instead.
func on_picked_up(job: Job, pawn: Pawn, work: WorkManager) -> void:
	if job.part != PARKING:
		return
	for spot: WorkSpot in work.get_free_spots(job.task_type, get_carried(job)):
		job.part = 0
		if work.redirect(job, pawn, spot):
			return
		job.part = PARKING


## Parking isn't the step: the job opens again once the item is on the rack.
func is_step_done(job: Job) -> bool:
	return job.part != PARKING


func on_withdrawn(job: Job, _work: WorkManager) -> void:
	job.part = 0
