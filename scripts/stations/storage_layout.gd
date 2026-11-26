class_name StorageLayout
extends Resource
## One kind of stored thing (e.g. boxes, dough containers) a station type can keep on its
## storage surfaces (see StationData.storage_surfaces): how each item looks, and whether the
## starting shop's are full.

## Kind stored (e.g. Boxes).
@export var kind: StorageKind
## One item's art, drawn in order (e.g. a container's back, front and lid), in the item
## frame layout. None keeps it hidden (e.g. the prep table's cooler).
@export var textures: Array[Texture2D] = []
## The starting shop's stations open with this storage full (see Station.stock_up()).
## Storage built or assigned later starts empty and is filled by deliveries or pawns.
@export var stocked_at_start: bool = false
## Items are dishes of different kinds (e.g. Empty Dishes), each drawn with its own dish's
## art (see Dish) instead of `textures`, and stacked only with the same dish.
@export var holds_dishes: bool = false
