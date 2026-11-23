class_name StationSpot
extends Resource
## One place to use a station: where a pawn stands and where its item sits.
## Cells are relative to the station's origin at facing 0.

## Cell a pawn stands on to work this spot.
@export var work_cell: Vector2i = Vector2i(0, 1)
## Footprint cell the spot's item sits over. Usually the cell in front of the work cell.
@export var item_cell: Vector2i = Vector2i.ZERO
## Pixels the spot's item sits above the station's item offset (e.g. a pizza rack's slots).
## Higher items draw over lower ones on the same cell.
@export var item_height: float = 0.0
