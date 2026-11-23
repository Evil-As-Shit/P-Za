class_name ShopFloor
extends TileMapLayer
## The shop's floor. Painted cells are walkable; this node owns the pathfinding grid.

var _astar := WalledGrid.new()
## Cells covered by furniture. Kept separately so a navigation rebuild doesn't lose them.
var _blocked: Dictionary[Vector2i, bool] = {}
## Walkable cells idle pawns don't wander to or start on (inside a walk-in).
var _no_wander: Dictionary[Vector2i, bool] = {}


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
	var cells: Array[Vector2i] = _astar.get_id_path(from_cell, to_cell)
	for i: int in cells.size():
		# A wall is only crossed when there's no other way: that's no way at all.
		if i > 0 and _astar.is_wall(cells[i - 1], cells[i]):
			return PackedVector2Array()
		points.append(cell_to_global(cells[i]))
	return points


## Puts a wall on the edge between two neighbouring cells (or takes one down): pawns can't
## cross it. Walls are counted, so two walls on one edge need taking down twice.
func set_edge_blocked(cell: Vector2i, neighbour: Vector2i, blocked: bool) -> void:
	_astar.set_wall(cell, neighbour, blocked)


## True if a wall stands between two neighbouring cells.
func is_edge_blocked(cell: Vector2i, neighbour: Vector2i) -> bool:
	return _astar.is_wall(cell, neighbour)


## Keeps idle pawns from wandering to a cell (or lets them again).
func set_no_wander(cell: Vector2i, on: bool) -> void:
	if on:
		_no_wander[cell] = true
	else:
		_no_wander.erase(cell)


## A random walkable cell idle pawns may wander to.
func get_random_walkable_cell() -> Vector2i:
	var cells: Array[Vector2i] = []
	cells.assign(get_used_cells().filter(
		func(cell: Vector2i) -> bool: return is_walkable(cell) and not _no_wander.has(cell)
	))
	if cells.is_empty():
		return Vector2i.ZERO
	return cells.pick_random()


func cell_to_global(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))


func global_to_cell(global_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(global_pos))


## The pathfinding grid, with walls on some edges between cells (a walk-in's). Crossing one
## costs so much that a path only does it when there's no other way, and such a path is
## thrown away (see get_path_points()).
class WalledGrid extends AStarGrid2D:
	const WALL_COST: float = 1000000.0

	## Walls per edge, keyed both ways round (from x, from y, to x, to y).
	var _walls: Dictionary[Vector4i, int] = {}

	func set_wall(a: Vector2i, b: Vector2i, on: bool) -> void:
		for key: Vector4i in [Vector4i(a.x, a.y, b.x, b.y), Vector4i(b.x, b.y, a.x, a.y)]:
			var count: int = _walls.get(key, 0) + (1 if on else -1)
			if count > 0:
				_walls[key] = count
			else:
				_walls.erase(key)

	func is_wall(a: Vector2i, b: Vector2i) -> bool:
		return _walls.has(Vector4i(a.x, a.y, b.x, b.y))

	func _compute_cost(from_id: Vector2i, to_id: Vector2i) -> float:
		var cost: float = Vector2(from_id).distance_to(Vector2(to_id))
		return WALL_COST if is_wall(from_id, to_id) else cost

	func _estimate_cost(from_id: Vector2i, end_id: Vector2i) -> float:
		return Vector2(from_id).distance_to(Vector2(end_id))