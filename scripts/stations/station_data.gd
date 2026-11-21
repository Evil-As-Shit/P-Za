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
## Facing a newly built one starts at. Stations with art for only one facing always use it.
@export_range(0, 3) var default_facing: int = 0
## Size in cells at facing 0. The origin cell is the footprint's first cell.
@export var footprint: Vector2i = Vector2i.ONE
## Sprite for each facing, by index (0-3); leave a facing empty if there's no art for it.
## Each texture's left edge and bottom row must line up with the footprint's leftmost corner
## and floor-level bottom corner. The working side faces down-left at facing 0, up-left at
## 1, up-right at 2 and down-right at 3.
@export var facing_textures: Array[Texture2D] = []
## Optional art drawn over the station's items (e.g. an oven's top half), per facing, laid
## out like facing_textures. Make each the same height as its facing texture.
@export var cover_textures: Array[Texture2D] = []
## If true, a facing with no art uses its mirror image's art flipped: facings 0 and 3 are
## mirror images (working side down-left / down-right), and so are 1 and 2. The lighting
## flips too.
@export var mirror_facings: bool = true
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


## Facings the station can be placed at: those with art, or whose mirror image has art.
func get_facings() -> Array[int]:
	var facings: Array[int] = []
	for facing: int in 4:
		if get_art_facing(facing) != -1:
			facings.append(facing)
	return facings


## True if the station can be turned (it can be placed at more than one facing).
func can_rotate() -> bool:
	return get_facings().size() > 1


## The facing whose art is drawn for `facing`: itself, or its mirror image (flipped, see
## is_mirrored()). -1 if there's no art for it.
func get_art_facing(facing: int) -> int:
	if _has_art(facing):
		return facing
	if mirror_facings and _has_art(3 - facing):
		return 3 - facing
	return -1


## True if `facing` is drawn as its mirror image's art flipped.
func is_mirrored(facing: int) -> bool:
	return get_art_facing(facing) != facing


func get_texture(facing: int) -> Texture2D:
	return _pick(facing_textures, get_art_facing(facing))


func get_cover_texture(facing: int) -> Texture2D:
	return _pick(cover_textures, get_art_facing(facing))


func _has_art(facing: int) -> bool:
	return facing < facing_textures.size() and facing_textures[facing] != null


static func _pick(textures: Array[Texture2D], facing: int) -> Texture2D:
	if facing < 0 or facing >= textures.size():
		return null
	return textures[facing]
