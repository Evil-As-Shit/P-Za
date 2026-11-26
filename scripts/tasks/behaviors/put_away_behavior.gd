class_name PutAwayBehavior
extends TaskBehavior
## Carries the job's target (e.g. a just-folded box) to its destination storage, whose
## room was claimed for it, and stores it there. Several pawns can put things away at the
## same storage at once: its room is already claimed, so nobody waits for the spot.


func get_spots(job: Job, _work: WorkManager) -> Array[WorkSpot]:
	var spots: Array[WorkSpot] = []
	if job.destination != null:
		spots.append(WorkSpot.new(job.destination, 0))
	return spots


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if pawn.get_held_item() != job.target:
		return super(pawn, job, work)
	# Already in hand (e.g. just folded it): straight to storage.
	for spot: WorkSpot in get_spots(job, work):
		if work.start_job(pawn, job, spot, [] as Array[JobStop]):
			return true
	return false


func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var item: Item = pawn.release_item()
	if item != null:
		item.queue_free()
	job.target = null
	job.destination.add_stock(job.destination_kind)
