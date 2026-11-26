class_name StorageSurface
extends Resource
## A surface a station keeps stored things on (a rack shelf, a tabletop, a pallet): an area of
## slots (see SlotGrid) at a height, with room above it for stacks.

## Its slots at facing 0, from the origin cell's back corner (see SlotGrid).
@export var area: Rect2i = Rect2i(0, 0, 8, 8)
## Pixels above the floor its stacks stand at.
@export var height: float = 0.0
## Pixels of room above it: a stack's items below the top count their kind's stacked height,
## the top one its own height (see StorageKind.item_height), and together fit under this.
@export var clearance: float = 22.0
## Drawn over the station's cover (e.g. a rack's top shelf); else under it.
@export var on_top: bool = false
