class_name Recipe
extends Resource
## Something on the menu, made by working its steps in order.

@export var display_name: String
## Tasks to perform, in order (e.g. stretch, sauce, cheese, bake).
@export var steps: Array[TaskType] = []
## How the item looks as it's made: index 0 before any step, index i after step i.
@export var stage_textures: Array[Texture2D] = []


## Look of the item once `steps_done` steps are finished.
func get_stage_texture(steps_done: int) -> Texture2D:
	if stage_textures.is_empty():
		return null
	return stage_textures[clampi(steps_done, 0, stage_textures.size() - 1)]
