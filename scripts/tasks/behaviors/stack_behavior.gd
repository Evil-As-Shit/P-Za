class_name StackBehavior
extends TaskBehavior
## Moves a finished item (e.g. a closed box) onto its order's stack, worked where the stack
## stands.

## Pixels each item sits above the one below it.
@export var stack_step: float = 2.0


func get_spots(job: Job, _work: WorkManager) -> Array[WorkSpot]:
	var result: Array[WorkSpot] = []
	var base: Item = job.ticket.stack_base.item
	if base.station != null and not base.station.is_reserved(base.spot):
		result.append(WorkSpot.new(base.station, base.spot))
	return result


func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var item: Item = pawn.release_item()
	if item == null:
		return
	var stack: Item = job.ticket.stack_base.item
	stack.put_in(item, Vector2(0.0, -stack_step * (stack.get_units().size() + 1)))
