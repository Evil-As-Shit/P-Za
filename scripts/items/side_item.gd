class_name SideItem
extends Resource
## Something that sits in a station's side area (see StationData.side_areas), set out with
## the station (e.g. the prep table's sauce bucket) or with its role (e.g. a Boxing table's
## pizza cutter).

@export var display_name: String
## Its art, in the item frame layout.
@export var texture: Texture2D
## Surface slots it takes at facing 0 (see SlotGrid).
@export var slot_size: Vector2i = Vector2i.ONE
## If true, it's turned toward the station's worker like the items on its spots (e.g. the
## cutter's handle): drawn for a pawn down-right, with turned art in the item's RotatedArt
## for a pawn behind it. Otherwise it's always drawn as is.
@export var faces_worker: bool = false


## Makes `item` one of these.
func set_up(item: Item) -> void:
	item.side_item = self
	item.set_texture(texture)
