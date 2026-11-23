class_name WalkIn
extends Resource
## Makes a station a walk-in cooler: a room pawns walk into through its door. Its walls
## stand on the outer edges of its footprint, so its whole footprint is floor, where the
## player builds racks and such. Cells are at facing 0, from the footprint's origin, like
## StationSpot cells.

const STEPS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## The edge cell whose outer edge is left open as the doorway. Pick one that isn't a corner.
@export var door_cell: Vector2i = Vector2i(1, 2)
@export var wall_style: WallStyle
## Floor art for one cell, centered on the cell.
@export var floor_texture: Texture2D


## Walls at facing 0: each footprint cell on the edge paired with the outside cell across
## its wall, as (x, y, outside x, outside y). The door's edge is left open.
func get_wall_edges(size: Vector2i) -> Array[Vector4i]:
	var edges: Array[Vector4i] = []
	var area := Rect2i(Vector2i.ZERO, size)
	for x: int in size.x:
		for y: int in size.y:
			var cell := Vector2i(x, y)
			if cell == door_cell:
				continue
			for step: Vector2i in STEPS:
				var outside: Vector2i = cell + step
				if not area.has_point(outside):
					edges.append(Vector4i(cell.x, cell.y, outside.x, outside.y))
	return edges
