class_name StationRole
extends Resource
## A job a general-purpose station (like a table or rack) can be assigned: work, e.g. Prep
## or Boxing, which decides the task types done there, or storage of one kind of thing.

@export var id: StringName
@export var display_name: String
@export var task_types: Array[TaskType] = []
## Kind of thing stored here (e.g. &"box"), or empty for a work role. The station needs a
## StorageLayout for it.
@export var stores: StringName
