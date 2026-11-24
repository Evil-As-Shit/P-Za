class_name BreakBehavior
extends TaskBehavior
## A pawn's break at a break table (a table with the Break role): they walk to a free spot
## and rest there for the task's time (see TaskType.rest). WorkManager hands these out to
## tired pawns; nobody takes them from the priority grid.


func on_finished(_job: Job, pawn: Pawn, _work: WorkManager) -> void:
	pawn.finish_break()
