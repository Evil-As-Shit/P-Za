class_name StationData
extends Resource
## Static description of a station type: its art, footprint and where pawns use it.
## Offsets are given for facing 0 and rotated in 90° steps on the map grid.

@export var display_name: String
## Task types a pawn can do here.
@export var task_types: Array[TaskType] = []
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

@export_group("Storage")
## Kind of supply stored here (e.g. &"box"), or empty. Pawns fetch it from spot 0.
@export var supply: StringName
## How one stored unit looks, in the item frame layout.
@export var supply_texture: Texture2D
## Pile positions drawn under the cover, back to front, relative to the origin cell's
## floor center.
@export var supply_piles: Array[Vector2] = []
## Pile positions drawn over the cover (e.g. on a top shelf), back to front.
@export var supply_piles_on_top: Array[Vector2] = []
@export var supply_per_pile: int = 3
## Pixels each stacked unit sits above the one below it.
@export var supply_pile_step: float = 3.0


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


func get_supply_capacity() -> int:
	return (supply_piles.size() + supply_piles_on_top.size()) * supply_per_pile


func get_texture(facing: int) -> Texture2D:
	return _pick(facing_textures, facing)


func get_cover_texture(facing: int) -> Texture2D:
	return _pick(cover_textures, facing)


static func _pick(textures: Array[Texture2D], facing: int) -> Texture2D:
	if textures.is_empty():
		return null
	return textures[posmod(facing, textures.size())]
