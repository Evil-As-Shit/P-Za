class_name ShopWalls
extends Node2D
## Walls around the edge of the shop floor. A wall stands on every edge between a floor cell
## and empty space, except where a door is. The view mode decides which walls are drawn
## short so the rooms behind them can be seen. Must sit under the y-sorted entities node so
## pawns and furniture sort against each wall piece.

enum Side { BACK_LEFT, BACK_RIGHT, FRONT_LEFT, FRONT_RIGHT }
## FULL: every wall full height. CUTAWAY: front walls short. DOWN: every wall short.
enum ViewMode { FULL, CUTAWAY, DOWN }

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
@export var view_mode: ViewMode = ViewMode.CUTAWAY

var _floor: ShopFloor = null


## Builds the walls around the floor's painted cells.
func build(shop_floor: ShopFloor) -> void:
	_floor = shop_floor
	_rebuild()


func set_view_mode(mode: ViewMode) -> void:
	view_mode = mode
	_rebuild()


## Full -> cutaway -> walls down -> full.
func cycle_view_mode() -> void:
	set_view_mode(((view_mode + 1) % ViewMode.size()) as ViewMode)


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
	var back_short: bool = view_mode == ViewMode.DOWN
	var front_short: bool = view_mode != ViewMode.FULL
	var back_left: bool = sides.has(Side.BACK_LEFT)
	var back_right: bool = sides.has(Side.BACK_RIGHT)
	var front_left: bool = sides.has(Side.FRONT_LEFT)
	var front_right: bool = sides.has(Side.FRONT_RIGHT)

	if back_left and back_right:
		_add(center, BACK_CORNER_ANCHOR, style.back_corner_short if back_short else style.back_corner)
	else:
		if back_left:
			_add(center, SIDE_ANCHOR[Side.BACK_LEFT], style.back_left_short if back_short else style.back_left)
		if back_right:
			_add(center, SIDE_ANCHOR[Side.BACK_RIGHT], style.back_right_short if back_short else style.back_right)

	if front_left and front_right:
		_add(center, FRONT_CORNER_ANCHOR, style.front_corner_short if front_short else style.front_corner)
		return
	# Where a front wall meets a back wall (the room's side corners), the capped piece covers
	# the join, as long as both walls are the same height.
	var capped: bool = back_short == front_short
	if front_left:
		var piece: WallPiece
		if back_left and capped:
			piece = style.left_corner_short if front_short else style.left_corner
		else:
			piece = style.front_left_short if front_short else style.front_left
		_add(center, SIDE_ANCHOR[Side.FRONT_LEFT], piece)
	if front_right:
		var piece: WallPiece
		if back_right and capped:
			piece = style.right_corner_short if front_short else style.right_corner
		else:
			piece = style.front_right_short if front_short else style.front_right
		_add(center, SIDE_ANCHOR[Side.FRONT_RIGHT], piece)


func _add(center: Vector2, anchor: Vector2, piece: WallPiece) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = piece.texture
	sprite.centered = false
	sprite.offset = piece.offset - anchor
	add_child(sprite)
	sprite.global_position = center + anchor


func _is_door(cell: Vector2i, side: Side) -> bool:
	return doors.has(Vector3i(cell.x, cell.y, side))
