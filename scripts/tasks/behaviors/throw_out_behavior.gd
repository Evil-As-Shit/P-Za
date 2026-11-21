class_name ThrowOutBehavior
extends TaskBehavior
## Takes the job's target item (e.g. a cancelled order's pizza) to a station that does the
## task (the garbage can), where it's gone once the work is done.


func on_finished(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	job.station.take_item(job.spot)
	job.target.queue_free()
