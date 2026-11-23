class_name StationRole
extends Resource
## A job a general-purpose station (like a table or rack) can be assigned: work, e.g. Prep
## or Boxing, which decides the task types done there, or storage of one kind of thing.

@export var id: StringName
@export var display_name: String
@export var task_types: Array[TaskType] = []
## Kind of thing stored here (e.g. Boxes), or null for a work role. The station needs a
## StorageLayout for it.
@export var stores: StorageKind
## Set out in the station's side areas while it has this role (e.g. a Boxing table's pizza
## cutter), and taken away when the role changes.
@export var side_items: Array[SideItem] = []
## Only offered to a station standing inside a walk-in (e.g. Dough storage). One moved out
## loses it.
@export var needs_walk_in: bool = false
