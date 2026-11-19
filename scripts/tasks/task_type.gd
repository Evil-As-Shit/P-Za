class_name TaskType
extends Resource
## A kind of work pawns can do (assembly, oven, boxing...).

@export var id: StringName
@export var display_name: String
## Seconds of work at normal speed. Skill and mood will scale this later.
@export var base_work_time: float = 5.0
