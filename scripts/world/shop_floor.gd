class_name ShopFloor
extends TileMapLayer
## The shop's floor. Painted cells are walkable; this node owns the pathfinding grid.

var _astar: AStarGrid2D = AStarGrid2D.new()
## Cells covered by furniture. Kept separately so a navigation rebuild doesn't lose them.
var _blocked: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	rebuild_navigation()


## Rebuilds the pathfinding grid from the currently painted cells.
## Call this after painting or erasing cells at runtime.
func rebuild_navigation() -> void:
	_astar.region = get_used_rect()
	# Moving only along the map axes keeps pawns on the four iso diagonals their sprites cover.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for x: int in range(_astar.region.position.x, _astar.region.end.x):
		for y: int in range(_astar.region.position.y, _astar.region.end.y):
			var cell := Vector2i(x, y)
			_astar.set_point_solid(cell, get_cell_source_id(cell) == -1 or _blocked.has(cell))


## Marks a cell as covered by furniture (or clears it).
func set_cell_blocked(cell: Vector2i, blocked: bool) -> void:
	if blocked:
		_blocked[cell] = true
	else:
		_blocked.erase(cell)
	if _astar.is_in_boundsv(cell):
		_astar.set_point_solid(cell, blocked or get_cell_source_id(cell) == -1)


## True if the cell is part of the floor (painted), blocked or not.
func has_floor(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) != -1


func is_walkable(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell)


## Returns the global positions of each cell center along a path, including both ends.
## Returns an empty array when no path exists.
func get_path_points(from_cell: Vector2i, to_cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not is_walkable(from_cell) or not is_walkable(to_cell):
		return points
	for cell: Vector2i in _astar.get_id_path(from_cell, to_cell):
		points.append(cell_to_global(cell))
	return points


func get_random_walkable_cell() -> Vector2i:
	var cells: Array[Vector2i] = []
	cells.assign(get_used_cells().filter(is_walkable))
	if cells.is_empty():
		return Vector2i.ZERO
	return cells.pick_random()


func cell_to_global(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))


func global_to_cell(global_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(global_pos))
