class_name Recipe
extends Resource
## Something on the menu, made by working its steps in order.

@export var display_name: String
## Tasks to perform, in order (e.g. assembly, then oven).
@export var steps: Array[TaskType] = []
