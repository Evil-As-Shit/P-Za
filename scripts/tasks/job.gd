class_name Job
extends RefCounted
## One unit of work at a station, claimed and worked by a single pawn.

signal completed

var task_type: TaskType
var station: Station
var claimed_by: Pawn = null
var work_done: float = 0.0


func _init(p_task_type: TaskType, p_station: Station) -> void:
	task_type = p_task_type
	station = p_station


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
