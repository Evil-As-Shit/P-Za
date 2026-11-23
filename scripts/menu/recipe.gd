class_name Recipe
extends Resource
## Something on the menu, made by working its steps in order.

@export var display_name: String
## What a customer pays for one.
@export var price: float = 0.0
## Tasks to perform, in order (e.g. stretch, sauce, cheese, bake).
@export var steps: Array[TaskType] = []
## How the item looks as it's made: index 0 before any step, index i after step i.
## Repeat the previous look for steps that don't change it (e.g. setting out a box).
@export var stage_textures: Array[Texture2D] = []


## What a customer pays for an order of `recipes` (one entry per item).
static func get_total_price(recipes: Array[Recipe]) -> float:
	var total: float = 0.0
	for recipe: Recipe in recipes:
		total += recipe.price
	return total


## Look of the item once `steps_done` steps are finished.
func get_stage_texture(steps_done: int) -> Texture2D:
	if stage_textures.is_empty():
		return null
	return stage_textures[clampi(steps_done, 0, stage_textures.size() - 1)]
