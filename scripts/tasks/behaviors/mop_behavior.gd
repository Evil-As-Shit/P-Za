class_name MopBehavior
extends FloorCleanBehavior
## Mops the nearest floor cell that's dirty enough (see FloorDirt) clean.

## A cell needs mopping once it's at least this dirty (0 to 1). Placeholder.
@export var min_dirt: float = 0.5
## Shop minutes to mop a fully dirty cell; a less dirty one takes less. Placeholder.
@export var minutes_when_full: float = 0.5


## Dirtiest first, so a tie goes to the dirtier cell.
func _get_cells(work: WorkManager) -> Array[Vector2i]:
	return work.floor_dirt.get_dirty_cells(min_dirt)


func _get_minutes(cell: Vector2i, work: WorkManager) -> float:
	return minutes_when_full * work.floor_dirt.get_dirt(cell)


func _clean(cell: Vector2i, work: WorkManager) -> void:
	work.floor_dirt.clean(cell)
