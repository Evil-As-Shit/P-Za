class_name BreakBehavior
extends TaskBehavior
## A pawn's break at a break table (a table with the Break role): they walk to a free spot
## and rest there for their break's length (see PawnMood.break_length; the task's own time
## without one). WorkManager hands these out to tired pawns; nobody takes them from the
## priority grid.


func get_work_seconds(job: Job) -> float:
	var pawn: Pawn = job.claimed_by
	if pawn != null and pawn.mood != null:
		return ShopClock.minutes_to_seconds(pawn.mood.break_length)
	return super(job)


func on_finished(_job: Job, pawn: Pawn, _work: WorkManager) -> void:
	pawn.finish_break()
