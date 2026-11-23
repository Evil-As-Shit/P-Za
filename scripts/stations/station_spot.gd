class_name StationSpot
extends Resource
## One place to use a station: where a pawn stands and where its item sits.
## Cells are relative to the station's origin at facing 0.

## Cell a pawn stands on to work this spot.
@export var work_cell: Vector2i = Vector2i(0, 1)
## Footprint cell the spot's item sits over. Usually the cell in front of the work cell.
@export var item_cell: Vector2i = Vector2i.ZERO
## Slots of the surface the spot's item takes (see SlotGrid), at facing 0. Empty means the
## whole item cell, with the item in its middle.
@export var work_area: Rect2i = Rect2i()
## Pixels the spot's item sits above the station's item offset (e.g. a pizza rack's slots).
## Higher items draw over lower ones on the same cell.
@export var item_height: float = 0.0


## The slots the spot's item takes, at facing 0.
func get_work_area() -> Rect2i:
	if work_area.has_area():
		return work_area
	return SlotGrid.cell_area(item_cell)
