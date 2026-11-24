class_name SpillBehavior
extends FloorCleanBehavior
## Cleans up the nearest spill on the floor (see FloorDirt and TaskType.spill_chance).

## Shop minutes to clean up a spill. Placeholder.
@export var minutes: float = 0.5


func _get_cells(work: WorkManager) -> Array[Vector2i]:
	return work.floor_dirt.get_spills()


func _get_minutes(_cell: Vector2i, _work: WorkManager) -> float:
	return minutes


func _clean(cell: Vector2i, work: WorkManager) -> void:
	work.floor_dirt.clean_spill(cell)
