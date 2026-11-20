class_name StationData
extends Resource
## Static description of a station type: its art, footprint and where a pawn works it.
## Offsets are given for facing 0 and rotated in 90° steps on the map grid.

@export var display_name: String
## Task types a pawn can do here.
@export var task_types: Array[TaskType] = []
## Size in cells at facing 0. The origin cell is the footprint's first cell.
@export var footprint: Vector2i = Vector2i.ONE
## Sprite for each facing (0-3). Each texture's left edge and bottom row must line up
## with the footprint's leftmost corner and floor-level bottom corner.
@export var facing_textures: Array[Texture2D] = []
## Optional art drawn over the station's item (e.g. an oven's top half), per facing.
## Lined up the same way as facing_textures, so make them the same height.
@export var cover_textures: Array[Texture2D] = []
## Cell, relative to the origin at facing 0, where a pawn stands to work.
@export var work_spot: Vector2i = Vector2i(0, 1)
## Footprint cell, relative to the origin at facing 0, that an item sits over.
## Usually the cell in front of the work spot.
@export var item_spot: Vector2i = Vector2i.ZERO
## Where an item sits, relative to the item spot's floor center (e.g. up on the tabletop).
@export var item_offset: Vector2 = Vector2.ZERO


## Rotates a map-grid offset by `facing` quarter turns.
static func rotate_offset(offset: Vector2i, facing: int) -> Vector2i:
	match posmod(facing, 4):
		1:
			return Vector2i(-offset.y, offset.x)
		2:
			return Vector2i(-offset.x, -offset.y)
		3:
			return Vector2i(offset.y, -offset.x)
	return offset


func get_footprint_cells(origin: Vector2i, facing: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in footprint.x:
		for y: int in footprint.y:
			cells.append(origin + rotate_offset(Vector2i(x, y), facing))
	return cells


func get_work_cell(origin: Vector2i, facing: int) -> Vector2i:
	return origin + rotate_offset(work_spot, facing)


func get_item_cell(origin: Vector2i, facing: int) -> Vector2i:
	return origin + rotate_offset(item_spot, facing)


func get_texture(facing: int) -> Texture2D:
	return _pick(facing_textures, facing)


func get_cover_texture(facing: int) -> Texture2D:
	return _pick(cover_textures, facing)


static func _pick(textures: Array[Texture2D], facing: int) -> Texture2D:
	if textures.is_empty():
		return null
	return textures[posmod(facing, textures.size())]
