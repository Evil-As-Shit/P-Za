class_name SlotGrid
extends RefCounted
## Station surfaces are split into slots: SLOTS_PER_CELL × SLOTS_PER_CELL per floor cell,
## each a 4×2 px diamond. Slot areas (Rect2i, in slots) are given at facing 0 from the
## station origin cell's back corner, like StationSpot cells, and turn with the station.
## Their centers fall on whole pixels.

const SLOTS_PER_CELL: int = 8


## The slot area covering a whole floor cell (a footprint cell at facing 0).
static func cell_area(cell: Vector2i) -> Rect2i:
	return Rect2i(cell * SLOTS_PER_CELL, Vector2i.ONE * SLOTS_PER_CELL)


## Where an area's middle is, in cells from the origin cell's center at facing 0 (so it
## turns like a cell offset, see StationData.rotate_point()).
static func get_center(area: Rect2i) -> Vector2:
	var middle := Vector2(area.position) + Vector2(area.size) / 2.0
	return middle / float(SLOTS_PER_CELL) - Vector2(0.5, 0.5)
