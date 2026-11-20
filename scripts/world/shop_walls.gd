class_name ShopWalls
extends Node2D
## Walls around the edge of the shop floor. A wall stands on every edge between a floor cell
## and empty space, except where a door is. Back walls are always full height; front walls
## can be cut away so the room behind them can be seen. Must sit under the y-sorted
## entities node so pawns and furniture sort against each wall piece.

enum Side { BACK_LEFT, BACK_RIGHT, FRONT_LEFT, FRONT_RIGHT }

## Step to the neighbouring cell across each side, indexed by Side (diamond-down: +x is
## down-right).
const SIDE_STEP: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]
## Point each piece sorts by, relative to its cell's center, indexed by Side: the middle of
## its edge. Joined pieces sort by their shared corner instead.
const SIDE_ANCHOR: Array[Vector2] = [Vector2(-8, -4), Vector2(8, -4), Vector2(-8, 4), Vector2(8, 4)]
const BACK_CORNER_ANCHOR := Vector2(0, -8)
const FRONT_CORNER_ANCHOR := Vector2(0, 8)

@export var style: WallStyle
## Edges left open as doorways, as (cell x, cell y, Side).
@export var doors: Array[Vector3i] = []
## Front walls are drawn short.
@export var cutaway: bool = true

var _floor: ShopFloor = null


## Builds the walls around the floor's painted cells.
func build(shop_floor: ShopFloor) -> void:
	_floor = shop_floor
	_rebuild()


func set_cutaway(on: bool) -> void:
	cutaway = on
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for cell: Vector2i in _floor.get_used_cells():
		var sides: Array[Side] = []
		for side: Side in Side.values():
			if _floor.get_cell_source_id(cell + SIDE_STEP[side]) == -1 and not _is_door(cell, side):
				sides.append(side)
		_add_cell_walls(cell, sides)


func _add_cell_walls(cell: Vector2i, sides: Array[Side]) -> void:
	var center: Vector2 = _floor.cell_to_global(cell)
	if sides.has(Side.BACK_LEFT) and sides.has(Side.BACK_RIGHT):
		_add_piece(center, BACK_CORNER_ANCHOR, style.back_corner, style.back_corner_offset)
	else:
		if sides.has(Side.BACK_LEFT):
			_add_piece(center, SIDE_ANCHOR[Side.BACK_LEFT], style.back_left, style.back_left_offset)
		if sides.has(Side.BACK_RIGHT):
			_add_piece(center, SIDE_ANCHOR[Side.BACK_RIGHT], style.back_right, style.back_right_offset)
	var front_both: bool = sides.has(Side.FRONT_LEFT) and sides.has(Side.FRONT_RIGHT)
	if front_both and not cutaway:
		_add_piece(center, FRONT_CORNER_ANCHOR, style.front_corner, style.front_corner_offset)
		return
	if sides.has(Side.FRONT_LEFT):
		if cutaway:
			_add_piece(center, SIDE_ANCHOR[Side.FRONT_LEFT], style.front_left_cut, style.front_left_cut_offset)
		else:
			_add_piece(center, SIDE_ANCHOR[Side.FRONT_LEFT], style.front_left, style.front_left_offset)
	if sides.has(Side.FRONT_RIGHT):
		if cutaway:
			_add_piece(center, SIDE_ANCHOR[Side.FRONT_RIGHT], style.front_right_cut, style.front_right_cut_offset)
		else:
			_add_piece(center, SIDE_ANCHOR[Side.FRONT_RIGHT], style.front_right, style.front_right_offset)


func _add_piece(center: Vector2, anchor: Vector2, texture: Texture2D, top_left: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = top_left - anchor
	add_child(sprite)
	sprite.global_position = center + anchor


func _is_door(cell: Vector2i, side: Side) -> bool:
	return doors.has(Vector3i(cell.x, cell.y, side))
