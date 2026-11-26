class_name StorageKind
extends Resource
## A kind of thing kept in storage (boxes, full dough containers...). Storage filters,
## stacking layouts and the tasks that fetch from storage all point at the same one.

@export var id: StringName
@export var display_name: String
## Its heading in a storage station's filter, or null for one never listed there (e.g. the
## prep table's built-in sauce).
@export var group: StorageGroup
## Only kept in a station standing inside a walk-in (e.g. dough).
@export var needs_walk_in: bool = false
## Surface slots one stored item takes (see SlotGrid). A dish's own size wins for kinds that
## hold dishes (see Dish.slot_size).
@export var slot_size: Vector2i = Vector2i(6, 6)
## Pixels each item adds to its stack's height (see StorageSurface.clearance).
@export var stack_height: float = 2.0
## Pixels one item stands tall, counted for the top item of a stack (see
## StorageSurface.clearance). 0 means the same as stack_height.
@export var item_height: float = 0.0
## Units in one stored item (e.g. 12 flat boxes in a bundle). Stock is counted in units, and
## a unit taken comes off the top item.
@export var units_per_item: int = 1
