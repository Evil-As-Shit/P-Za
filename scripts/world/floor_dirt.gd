class_name FloorDirt
extends Node2D
## How dirty each floor cell is (0 clean to 1 filthy). Every step a pawn or customer takes
## onto a cell dirties it a little; a Mop floor chore (MopBehavior) cleans it. Drawn as a
## placeholder tint over the floor, so this node sits between the floor and the entities.

## Dirt added each time someone steps onto a cell (placeholder).
@export var dirt_per_step: float = 0.02
## Tint drawn over a fully dirty cell; cleaner cells get a fainter one (placeholder art).
@export var dirty_color: Color = Color(0.3, 0.2, 0.1, 0.55)

var _floor: ShopFloor = null
## Dirty cells only (clean ones aren't kept).
var _dirt: Dictionary[Vector2i, float] = {}


func setup(shop_floor: ShopFloor) -> void:
	_floor = shop_floor


## Someone stepped onto the floor at `global_pos`: that cell gets a little dirtier.
func add_step(global_pos: Vector2) -> void:
	if _floor == null:
		return
	var cell: Vector2i = _floor.global_to_cell(global_pos)
	if _floor.has_floor(cell):
		add_dirt(cell, dirt_per_step)


func add_dirt(cell: Vector2i, amount: float) -> void:
	var dirt: float = minf(get_dirt(cell) + amount, 1.0)
	if dirt <= 0.0:
		_dirt.erase(cell)
	else:
		_dirt[cell] = dirt
	queue_redraw()


func get_dirt(cell: Vector2i) -> float:
	return _dirt.get(cell, 0.0)


func clean(cell: Vector2i) -> void:
	if _dirt.erase(cell):
		queue_redraw()


## Cells at least `min_dirt` dirty, dirtiest first.
func get_dirty_cells(min_dirt: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _dirt:
		if _dirt[cell] >= min_dirt:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _dirt[a] > _dirt[b])
	return cells


func _draw() -> void:
	if _floor == null:
		return
	var half := Vector2(_floor.tile_set.tile_size) / 2.0
	for cell: Vector2i in _dirt:
		var center: Vector2 = to_local(_floor.cell_to_global(cell))
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -half.y), center + Vector2(half.x, 0.0),
			center + Vector2(0.0, half.y), center + Vector2(-half.x, 0.0),
		])
		var color: Color = dirty_color
		color.a *= _dirt[cell]
		draw_colored_polygon(diamond, color)
