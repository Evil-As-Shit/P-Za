class_name StationData
extends Resource
## Static description of a station type: its art, footprint and where pawns use it.
## Offsets are given for facing 0 and rotated in 90° steps on the map grid.

@export var display_name: String
## Task types a pawn can do here, for stations with a fixed purpose (e.g. an oven).
@export var task_types: Array[TaskType] = []
## Roles the player can assign (e.g. a table as Prep or Boxing). If set, the station's
## role decides its task types instead of task_types.
@export var roles: Array[StationRole] = []
## Size in cells at facing 0. The origin cell is the footprint's first cell.
@export var footprint: Vector2i = Vector2i.ONE
## Sprite for each facing (0-3). Each texture's left edge and bottom row must line up
## with the footprint's leftmost corner and floor-level bottom corner.
@export var facing_textures: Array[Texture2D] = []
## Optional art drawn over the station's items (e.g. an oven's top half), per facing.
## Lined up the same way as facing_textures, so make them the same height.
@export var cover_textures: Array[Texture2D] = []
## Places to use the station. Each holds one item and is worked by one pawn at a time.
@export var spots: Array[StationSpot] = []
## Where an item sits, relative to its spot's floor center (e.g. up on the tabletop).
@export var item_offset: Vector2 = Vector2.ZERO

## How each kind of thing this station can store is stacked on it. Storage roles need a
## layout for their kind. Pawns fetch and drop off stored things at spot 0.
@export var storage_layouts: Array[StorageLayout] = []


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


func get_work_cell(origin: Vector2i, facing: int, spot: int) -> Vector2i:
	return origin + rotate_offset(spots[spot].work_cell, facing)


func get_item_cell(origin: Vector2i, facing: int, spot: int) -> Vector2i:
	return origin + rotate_offset(spots[spot].item_cell, facing)


## Layout for storing `kind` here, or null if this station can't store it.
func get_storage_layout(kind: StorageKind) -> StorageLayout:
	for layout: StorageLayout in storage_layouts:
		if layout.kind == kind:
			return layout
	return null


func get_texture(facing: int) -> Texture2D:
	return _pick(facing_textures, facing)


func get_cover_texture(facing: int) -> Texture2D:
	return _pick(cover_textures, facing)


static func _pick(textures: Array[Texture2D], facing: int) -> Texture2D:
	if textures.is_empty():
		return null
	return textures[posmod(facing, textures.size())]
