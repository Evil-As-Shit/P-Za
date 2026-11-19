class_name Job
extends RefCounted
## One step of a ticket, claimed and worked by a single pawn at one station.
## Progress is kept if the job is dropped and picked up again later.

signal completed

var task_type: TaskType
var ticket: Ticket
## Station reserved for this job while it is claimed.
var station: Station = null
var claimed_by: Pawn = null
var work_done: float = 0.0


func _init(p_task_type: TaskType, p_ticket: Ticket) -> void:
	task_type = p_task_type
	ticket = p_ticket


func get_work_required() -> float:
	return task_type.base_work_time


func is_complete() -> bool:
	return work_done >= get_work_required()


## Adds work and returns true once the job is complete.
func add_work(amount: float) -> bool:
	if is_complete():
		return true
	work_done += amount
	if is_complete():
		completed.emit()
		return true
	return false
