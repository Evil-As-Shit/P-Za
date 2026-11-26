class_name StationRole
extends Resource
## A job a general-purpose station (like a table or rack) can be assigned: work, e.g. Prep
## or Boxing, which decides the task types done there, or storage, whose kinds the station's
## filter picks (see Station.allowed_kinds).

@export var id: StringName
@export var display_name: String
@export var task_types: Array[TaskType] = []
## The station stores the kinds its filter allows (those it has a StorageLayout for).
@export var is_storage: bool = false
## Set out in the station's side areas while it has this role (e.g. a Boxing table's pizza
## cutter), and taken away when the role changes.
@export var side_items: Array[SideItem] = []
