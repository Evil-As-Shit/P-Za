class_name StationData
extends Resource
## Static description of a station type: its art, footprint and where pawns use it.
## Offsets are given for facing 0 and rotated in 90° steps on the map grid.

@export var display_name: String
## What building one costs; selling one pays it all back. The starting shop's are owned.
@export var price: float = 0.0
## Where it's listed in the build menu. Stations without one go under "Other".
@export var build_category: BuildCategory
## Task types a pawn can do here, for stations with a fixed purpose (e.g. an oven).
@export var task_types: Array[TaskType] = []
## Roles the player can assign (e.g. a table as Prep or Boxing). If set, the station's
## role decides its task types instead of task_types.
@export var roles: Array[StationRole] = []
## Role a newly built one starts with (e.g. a pallet storing flat boxes). Null means unused.
@export var default_role: StationRole = null
## Facing a newly built one starts at. Stations with art for only one facing always use it.
@export_range(0, 3) var default_facing: int = 0
## Size in cells at facing 0. The origin cell is the footprint's first cell.
@export var footprint: Vector2i = Vector2i.ONE
## Sprite for each facing, by index (0-3); leave a facing empty if there's no art for it.
## Each texture's left edge and bottom row must line up with the footprint's leftmost corner
## and floor-level bottom corner. The working side faces down-left at facing 0, up-left at
## 1, up-right at 2 and down-right at 3.
@export var facing_textures: Array[Texture2D] = []
## Optional art shown instead while the station is in use (a task that opens it, see
## TaskType.opens_station, is worked at one of its spots), e.g. a prep table with its lids
## up. Laid out like facing_textures.
@export var in_use_textures: Array[Texture2D] = []
## Optional art drawn over the station's items (e.g. an oven's top half), per facing, laid
## out like facing_textures. Make each the same height as its facing texture.
@export var cover_textures: Array[Texture2D] = []
## Optional cover art shown instead while the station works an item on its own (e.g. an
## oven's lit window while baking), laid out like cover_textures.
@export var working_cover_textures: Array[Texture2D] = []
## If true, a facing with no art uses its mirror image's art flipped: facings 0 and 3 are
## mirror images (working side down-left / down-right), and so are 1 and 2. The lighting
## flips too.
@export var mirror_facings: bool = true
## Places to use the station. Each holds one item and is worked by one pawn at a time.
@export var spots: Array[StationSpot] = []
## Where an item sits, relative to its spot's floor center (e.g. up on the tabletop).
@export var item_offset: Vector2 = Vector2.ZERO
## Surface slots (see SlotGrid) outside the spots' work areas where side items go (e.g.
## the sauce bucket between pizzas), at facing 0, in the order they're filled.
@export var side_areas: Array[Rect2i] = []
## Placed in the side areas when the station is built (e.g. a full sauce bucket). A role
## can add its own (see StationRole.side_items).
@export var side_items: Array[SideItem] = []
## Optional art drawn under each item sitting on its spots (e.g. a pizza screen on a rack),
## in the item frame layout.
@export var item_underlay: Texture2D

## How each kind of thing this station can store is stacked on it. Storage roles need a
## layout for their kind. Pawns fetch and drop off stored things at spot 0.
@export var storage_layouts: Array[StorageLayout] = []
## Storage built into the station, used whatever its role unless the role stores something
## itself (e.g. the prep table's cooler of spare sauce buckets). A layout with no textures
## or piles drawn keeps it hidden.
@export var built_in_storage: StorageLayout
## Ingredient pans built into the station (e.g. the prep table's cheese pan).
@export var pans: Array[IngredientPan] = []
## Makes the station a dish sink: drainboards for dirty and clean dishes, and basins.
@export var dish_sink: DishSink
## Makes the station a bulk tub (e.g. the bulk sauce bucket): dishes are filled from it and
## deliveries refill it.
@export var bulk_tub: BulkTub
## Makes the station a delivery drop-off (e.g. the delivery pallet) for supply cases.
@export var delivery_dock: DeliveryDock
## Makes the station a walk-in cooler: walls, a door and shelves, with open floor inside.
## It has no art of its own and turns to any facing.
@export var walk_in: WalkIn


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


## Rotates a map-grid offset (fractions of a cell allowed) by `facing` quarter turns.
static func rotate_point(offset: Vector2, facing: int) -> Vector2:
	match posmod(facing, 4):
		1:
			return Vector2(-offset.y, offset.x)
		2:
			return -offset
		3:
			return Vector2(offset.y, -offset.x)
	return offset


func get_footprint_cells(origin: Vector2i, facing: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in footprint.x:
		for y: int in footprint.y:
			cells.append(origin + rotate_offset(Vector2i(x, y), facing))
	return cells


## Footprint cells pawns can't walk on: all of them, or none for a walk-in (its walls stand
## on edges, see get_wall_edges()).
func get_blocked_cells(origin: Vector2i, facing: int) -> Array[Vector2i]:
	if walk_in == null:
		return get_footprint_cells(origin, facing)
	return []


## A walk-in's walls on the map: each as (cell x, cell y, outside x, outside y), the two
## cells it stands between. Empty for other stations.
func get_wall_edges(origin: Vector2i, facing: int) -> Array[Vector4i]:
	var edges: Array[Vector4i] = []
	if walk_in == null:
		return edges
	for edge: Vector4i in walk_in.get_wall_edges(footprint):
		var cell: Vector2i = origin + rotate_offset(Vector2i(edge.x, edge.y), facing)
		var outside: Vector2i = origin + rotate_offset(Vector2i(edge.z, edge.w), facing)
		edges.append(Vector4i(cell.x, cell.y, outside.x, outside.y))
	return edges


func get_work_cell(origin: Vector2i, facing: int, spot: int) -> Vector2i:
	return origin + rotate_offset(spots[spot].work_cell, facing)


func get_item_cell(origin: Vector2i, facing: int, spot: int) -> Vector2i:
	return origin + rotate_offset(spots[spot].item_cell, facing)


## Middle of the spot's work area, in cells from the origin cell's center, turned to
## `facing` (see SlotGrid).
func get_item_point(facing: int, spot: int) -> Vector2:
	return get_area_point(spots[spot].get_work_area(), facing)


## Middle of a slot area given at facing 0, in cells from the origin cell's center, turned
## to `facing`.
static func get_area_point(area: Rect2i, facing: int) -> Vector2:
	return rotate_point(SlotGrid.get_center(area), facing)


## True if `area` (slots at facing 0) lies inside a side area and clear of every spot's work
## area.
func is_side_area(area: Rect2i) -> bool:
	for spot: StationSpot in spots:
		if spot.get_work_area().intersects(area):
			return false
	for side: Rect2i in side_areas:
		if side.encloses(area):
			return true
	return false


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
	if walk_in != null or _has_art(facing):
		return facing
	if mirror_facings and _has_art(3 - facing):
		return 3 - facing
	return -1


## True if `facing` is drawn as its mirror image's art flipped.
func is_mirrored(facing: int) -> bool:
	return get_art_facing(facing) != facing


func get_texture(facing: int, in_use: bool = false) -> Texture2D:
	if in_use:
		var in_use_art: Texture2D = _pick(in_use_textures, get_art_facing(facing))
		if in_use_art != null:
			return in_use_art
	return _pick(facing_textures, get_art_facing(facing))


func get_cover_texture(facing: int, working: bool = false) -> Texture2D:
	if working:
		var working_cover: Texture2D = _pick(working_cover_textures, get_art_facing(facing))
		if working_cover != null:
			return working_cover
	return _pick(cover_textures, get_art_facing(facing))


func _has_art(facing: int) -> bool:
	return facing < facing_textures.size() and facing_textures[facing] != null


static func _pick(textures: Array[Texture2D], facing: int) -> Texture2D:
	if facing < 0 or facing >= textures.size():
		return null
	return textures[facing]
