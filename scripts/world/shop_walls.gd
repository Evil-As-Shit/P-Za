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
## its edge. Joined corner pieces are drawn in halves, each sorted with its side.
const SIDE_ANCHOR: Array[Vector2] = [Vector2(-8, -4), Vector2(8, -4), Vector2(-8, 4), Vector2(8, 4)]

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
		var sides: Array[int] = []
		for side: Side in Side.values():
			if _floor.get_cell_source_id(cell + SIDE_STEP[side]) == -1 and not _is_door(cell, side):
				sides.append(side)
		add_cell_walls(self, style, _floor.cell_to_global(cell), sides, view_mode)


## Adds the wall pieces for one cell's walled `sides` (Side values) to `parent` (a y-sorted
## node, so each piece sorts on its own), drawn as `mode` says. `center` is the cell's global
## center. Also used for rooms inside the shop (see WalkInRoom), which have floor around
## them, so a joined corner piece is drawn in two halves, each sorted with its own wall:
## sorted as one at the corner, it would cover things standing beside it.
static func add_cell_walls(
	parent: Node2D, style: WallStyle, center: Vector2, sides: Array[int], mode: ViewMode
) -> void:
	var back_short: bool = mode == ViewMode.DOWN
	var front_short: bool = mode != ViewMode.FULL
	var back_left: bool = sides.has(Side.BACK_LEFT)
	var back_right: bool = sides.has(Side.BACK_RIGHT)
	var front_left: bool = sides.has(Side.FRONT_LEFT)
	var front_right: bool = sides.has(Side.FRONT_RIGHT)

	if back_left and back_right:
		var corner: WallPiece = style.back_corner_short if back_short else style.back_corner
		_add_halves(parent, center, corner, Side.BACK_LEFT, Side.BACK_RIGHT)
	else:
		if back_left:
			var piece: WallPiece = style.back_left_short if back_short else style.back_left
			_add(parent, center, SIDE_ANCHOR[Side.BACK_LEFT], piece)
		if back_right:
			var piece: WallPiece = style.back_right_short if back_short else style.back_right
			_add(parent, center, SIDE_ANCHOR[Side.BACK_RIGHT], piece)

	if front_left and front_right:
		var corner: WallPiece = style.front_corner_short if front_short else style.front_corner
		_add_halves(parent, center, corner, Side.FRONT_LEFT, Side.FRONT_RIGHT)
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
		_add(parent, center, SIDE_ANCHOR[Side.FRONT_LEFT], piece)
	if front_right:
		var piece: WallPiece
		if back_right and capped:
			piece = style.right_corner_short if front_short else style.right_corner
		else:
			piece = style.front_right_short if front_short else style.front_right
		_add(parent, center, SIDE_ANCHOR[Side.FRONT_RIGHT], piece)


static func _add(parent: Node2D, center: Vector2, anchor: Vector2, piece: WallPiece) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = piece.texture
	sprite.centered = false
	sprite.offset = piece.offset - anchor
	parent.add_child(sprite)
	sprite.global_position = center + anchor


## Adds a joined corner piece as its left and right halves (split where the walls meet, in
## the middle of the art), sorted at the `left` and `right` sides' anchors.
static func _add_halves(
	parent: Node2D, center: Vector2, piece: WallPiece, left: int, right: int
) -> void:
	var size: Vector2 = piece.texture.get_size()
	var half: float = size.x / 2.0
	for right_half: bool in [false, true]:
		var anchor: Vector2 = SIDE_ANCHOR[right if right_half else left]
		var sprite := Sprite2D.new()
		sprite.texture = piece.texture
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(half if right_half else 0.0, 0.0, half, size.y)
		sprite.offset = piece.offset + Vector2(half if right_half else 0.0, 0.0) - anchor
		parent.add_child(sprite)
		sprite.global_position = center + anchor


func _is_door(cell: Vector2i, side: Side) -> bool:
	return doors.has(Vector3i(cell.x, cell.y, side))
