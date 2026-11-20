class_name StationRole
extends Resource
## A job a general-purpose station (like a table) can be assigned, e.g. Prep or Boxing.
## It decides which task types are done there.

@export var id: StringName
@export var display_name: String
@export var task_types: Array[TaskType] = []
