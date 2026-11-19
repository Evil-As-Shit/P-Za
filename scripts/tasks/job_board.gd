class_name JobBoard
extends Node
## Queue of open jobs, oldest first. Per-pawn work priorities will plug in here later.

signal job_posted(job: Job)

var _open_jobs: Array[Job] = []


func post(job: Job) -> void:
	_open_jobs.append(job)
	job_posted.emit(job)


## Removes and returns the oldest open job, or null if there are none.
func claim_next() -> Job:
	if _open_jobs.is_empty():
		return null
	return _open_jobs.pop_front()


## Puts a claimed job back at the front of the queue (e.g. its station was unreachable).
func return_job(job: Job) -> void:
	job.claimed_by = null
	_open_jobs.push_front(job)


func get_open_count() -> int:
	return _open_jobs.size()
