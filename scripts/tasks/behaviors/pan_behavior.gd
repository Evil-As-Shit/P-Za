class_name PanBehavior
extends TaskBehavior
## Works the item at its spot like the default behavior, and takes portions from an
## ingredient pan built into the station (e.g. cheese from the prep table's cheese pan) when
## the work is done. With too little left for another job, the work there waits until a
## pawn refills it (see RefillPanBehavior). A station without the pan works as before.

@export var pan: IngredientPan
## Portions one job uses.
@export var amount: int = 1


func get_spots(job: Job, work: WorkManager) -> Array[WorkSpot]:
	var spots: Array[WorkSpot] = []
	for spot: WorkSpot in super(job, work):
		var left: int = spot.station.get_pan_left(pan)
		if left < 0 or left - _count_jobs_at(spot.station, work) * amount >= amount:
			spots.append(spot)
	return spots


## Pawns with a job of this task at `station` that will take portions there.
func _count_jobs_at(station: Station, work: WorkManager) -> int:
	var count: int = 0
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job != null and job.station == station and job.task_type.get_behavior() == self:
			count += 1
	return count


func on_finished(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	if job.station != null and job.station.get_pan_left(pan) >= 0:
		job.station.use_pan(pan, amount)
