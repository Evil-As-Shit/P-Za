class_name WalkInRoom
extends Node2D
## A walk-in cooler's room (see WalkIn): its floor and walls, laid out on the station's
## footprint. Y-sorted, so pawns and stations inside sort against each wall piece.

var walk_in: WalkIn
var _floor_node := Node2D.new()
var _walls := Node2D.new()
var _view_mode: ShopWalls.ViewMode = ShopWalls.ViewMode.CUTAWAY
var _shop_floor: ShopFloor = null
var _origin: Vector2i
var _facing: int = 0
var _size: Vector2i


func _init() -> void:
	y_sort_enabled = true
	_floor_node.name = "Floor"
	_floor_node.y_sort_enabled = true
	add_child(_floor_node)
	_walls.name = "Walls"
	_walls.y_sort_enabled = true
	add_child(_walls)


## Lays the room out on the footprint of `size` at `origin`, turned to `facing`.
func arrange(shop_floor: ShopFloor, size: Vector2i, origin: Vector2i, facing: int) -> void:
	_shop_floor = shop_floor
	_size = size
	_origin = origin
	_facing = facing
	_lay_floor()
	_build_walls()


## Draws the walls full height, with the front ones short, or all short (see ShopWalls).
func set_view_mode(mode: ShopWalls.ViewMode) -> void:
	_view_mode = mode
	if _shop_floor != null:
		_build_walls()


func _to_cell(local: Vector2i) -> Vector2i:
	return _origin + StationData.rotate_offset(local, _facing)


func _get_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in _size.x:
		for y: int in _size.y:
			cells.append(_to_cell(Vector2i(x, y)))
	return cells


## Each cell drawn with the floor art. They all sort at the room's back corner, under
## anything standing in it.
func _lay_floor() -> void:
	for child: Node in _floor_node.get_children():
		_floor_node.remove_child(child)
		child.queue_free()
	if walk_in.floor_texture == null:
		return
	var cells: Array[Vector2i] = _get_cells()
	var back_y: float = INF
	for cell: Vector2i in cells:
		back_y = minf(back_y, _shop_floor.cell_to_global(cell).y)
	back_y -= float(_shop_floor.tile_set.tile_size.y) / 2.0
	for cell: Vector2i in cells:
		var center: Vector2 = _shop_floor.cell_to_global(cell)
		var sprite := Sprite2D.new()
		sprite.texture = walk_in.floor_texture
		_floor_node.add_child(sprite)
		sprite.global_position = Vector2(center.x, back_y)
		sprite.offset = Vector2(0.0, center.y - back_y)


## Walls on the footprint's outer edges, open at the door.
func _build_walls() -> void:
	for child: Node in _walls.get_children():
		_walls.remove_child(child)
		child.queue_free()
	var sides_by_cell: Dictionary[Vector2i, Array] = {}
	for edge: Vector4i in walk_in.get_wall_edges(_size):
		var cell: Vector2i = _to_cell(Vector2i(edge.x, edge.y))
		var step: Vector2i = _to_cell(Vector2i(edge.z, edge.w)) - cell
		if not sides_by_cell.has(cell):
			sides_by_cell[cell] = []
		sides_by_cell[cell].append(ShopWalls.SIDE_STEP.find(step))
	for cell: Vector2i in sides_by_cell:
		var sides: Array[int] = []
		sides.assign(sides_by_cell[cell])
		ShopWalls.add_cell_walls(
			_walls, walk_in.wall_style, _shop_floor.cell_to_global(cell), sides, _view_mode
		)
