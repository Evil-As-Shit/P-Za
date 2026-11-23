class_name Station
extends Node2D
## A piece of kitchen equipment placed on the floor grid. Each of its spots holds one
## item and is worked by one pawn at a time. Storage stations also hold a supply stock.

## Drawn on the floor where pawns stand to use the station, while it's selected or placed.
## Drawn on the 3x3 guide: one 96 px frame per side, the station in the middle cell.
const WORK_SPOT_SHEET: Texture2D = preload("res://Assets/Sprites/work_spot_sheet.png")
const WORK_SPOT_FRAME := Vector2i(96, 96)
## Spawned for a station's own side items (see StationData.side_items).
const ITEM_SCENE: PackedScene = preload("res://scenes/items/item.tscn")
## Pixel in each frame where the middle cell's center is.
const WORK_SPOT_CENTER := Vector2(48, 72)
## Frame for each pawn side: down-left, up-left, up-right, down-right.
const WORK_SPOT_SIDES: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]

## Draw order. The station's layers draw in node order: the art, stock inside it, items,
## its cover, then stock on top. A one-cell station draws them all at one depth, one pixel
## above its cell's center, so a pawn on that row (beside or in front of it) draws over it.
## A multi-cell station draws its layers into its own canvas instead, and shows that picture
## in 16 px wide strips, each sorted one pixel above the front-most cell under it. Pawns and
## other stations then sort against each part of it, wherever they stand around it.
const STRIP_WIDTH: int = 16
const SORT_OFFSET: float = -1.0
## Room in the canvas above and beside the art, for things stacked on the station.
const CANVAS_HEADROOM: int = 48
const CANVAS_MARGIN: int = 16

@export var data: StationData
## Origin cell on the floor grid.
@export var cell: Vector2i = Vector2i.ZERO
## Quarter turns (0-3).
@export_range(0, 3) var facing: int = 0
## Assigned role, for stations that take one (see StationData.roles). Null means unused.
@export var role: StationRole = null

## True while it stands inside a walk-in (set by the owner when it's put to work).
var in_walk_in: bool = false

var _footprint: Array[Vector2i] = []
var _item_positions: Array[Vector2] = []
## Floor-level depth (y) of each spot's work area, for drawing items back to front.
var _item_floor_y: Array[float] = []
## Items in the side areas (see StationData.side_areas) and the slots each takes, at
## facing 0.
var _side_items: Dictionary[Item, Rect2i] = {}
## The side items set out for the role (see StationRole.side_items).
var _role_side_items: Array[Item] = []
var _items: Array[Item] = []
var _reserved: Array[bool] = []
## Spots being worked by a task that opens the station (see TaskType.opens_station).
var _opened: Array[bool] = []
## Stored units (of the storage role's kind), how many are promised to pawns on their way to
## take one, and how many free places are promised to pawns bringing one.
var _stock: int = 0
var _stock_claimed: int = 0
var _room_claimed: int = 0
## How much is left in each partly used unit in stock (e.g. a dough container put back
## with 4 balls); the rest of the stock is full. Taken out first.
var _partial: Array[int] = []
## For storage that holds dishes (see StorageLayout.holds_dishes): each unit's dish, bottom
## of the stock first.
var _stock_dishes: Array[Dish] = []
## One array of unit nodes per pile, bottom to top. Inside piles first, then on-top piles.
var _pile_units: Array[Array] = []
var _origin_center: Vector2 = Vector2.ZERO
## Placed at least once (later placements are moves, which keep the stock).
var _placed: bool = false
var _floor: ShopFloor = null
## One marker per spot, on the floor where its pawn stands.
var _work_spot_markers: Array[Sprite2D] = []
## Top edge of the station's art, for placing the work bars above it.
var _art_top: float = 0.0
## Bottom-left corner the art is lined up on (see _line_up()).
var _art_corner := Vector2.ZERO
## One work bar per spot (the scene's WorkBar is spot 0's), and which spots are being
## worked on the station's own (e.g. baking).
var _work_bars: Array[ProgressBar] = []
var _working: Array[bool] = []
## A multi-cell station's own canvas, which its layers draw into (see STRIP_WIDTH), and
## where the canvas's top-left corner is on the floor. Null for a one-cell station.
var _canvas: SubViewport = null
var _canvas_origin := Vector2.ZERO
## A dish sink's drainboards (see StationData.dish_sink), or null.
var _dish_boards: DishBoards = null
## A walk-in's room, with its shelves (see StationData.walk_in), or null.
var _room: WalkInRoom = null

## All the station's art and what's on it, in draw order. Positions are floor positions,
## also inside the canvas.
@onready var _layers: Node2D = $Layers
@onready var _sprite: Sprite2D = $Layers/Sprite
@onready var _supply_inside: Node2D = $Layers/SupplyInside
## Items are parented here so they draw between the station art and its cover.
@onready var _item_slot: Node2D = $Layers/ItemSlot
@onready var _cover: Sprite2D = $Layers/Cover
@onready var _supply_on_top: Node2D = $Layers/SupplyOnTop
## A multi-cell station's canvas, shown in strips.
@onready var _strips: Node2D = $Strips
## Shown while the station works an item on its own (e.g. baking).
@onready var _work_bar: ProgressBar = $WorkBar
## Names the assigned role on the floor in front of the station.
@onready var _role_label: Label = $RoleLabel


## Snaps the station onto the floor and lines its art up with its footprint. Call again
## after changing cell or facing to move it; stored stock comes along.
func place(shop_floor: ShopFloor) -> void:
	_floor = shop_floor
	_footprint = data.get_footprint_cells(cell, facing)
	var corner: Vector2 = _get_art_corner(_footprint)
	var left: float = corner.x
	var bottom: float = corner.y
	var front_y: float = -INF
	var centroid := Vector2.ZERO
	for footprint_cell: Vector2i in _footprint:
		var center: Vector2 = shop_floor.cell_to_global(footprint_cell)
		front_y = maxf(front_y, center.y)
		centroid += center
	centroid /= float(_footprint.size())

	# Each item sits in the middle of its spot's work area, up on the surface.
	_item_positions.clear()
	_item_floor_y.clear()
	for spot: int in data.spots.size():
		var on_floor: Vector2 = _area_on_floor(data.spots[spot].get_work_area())
		_item_floor_y.append(on_floor.y)
		_item_positions.append(
			on_floor + data.item_offset - Vector2(0.0, data.spots[spot].item_height)
		)
	_items.resize(data.spots.size())
	_reserved.resize(data.spots.size())
	_opened.resize(data.spots.size())
	# What's on it comes along (it may have been turned, too).
	for spot: int in data.spots.size():
		if _items[spot] != null:
			_items[spot].global_position = _item_positions[spot]
			_items[spot].face_toward(get_pawn_side(spot))
	_place_side_items()
	_sort_items()
	_working.resize(data.spots.size())
	if _work_bars.is_empty():
		_work_bars.append(_work_bar)
	while _work_bars.size() < data.spots.size():
		var bar: ProgressBar = _work_bar.duplicate()
		add_child(bar)
		_work_bars.append(bar)
	# Neighbouring spots are 16 px apart, as wide as a bar: narrow them so there's a gap.
	if _work_bars.size() > 1:
		for bar: ProgressBar in _work_bars:
			bar.size.x = 12.0

	# The footprint's middle, at the front (its parts sort on their own, see SORT_OFFSET).
	global_position = Vector2(centroid.x, front_y + SORT_OFFSET)
	# A walk-in has no art of its own (its room's parts sort on their own), so no canvas.
	if _footprint.size() == 1 or data.walk_in != null:
		_layers.global_position = global_position
	elif _canvas == null:
		_make_canvas()

	var mirrored: bool = data.is_mirrored(facing)
	_art_corner = corner
	_line_up(_sprite, data.get_texture(facing, _is_in_use()), left, bottom, mirrored)
	_line_up(_cover, data.get_cover_texture(facing, is_working()), left, bottom, mirrored)
	if _canvas != null:
		_fit_canvas()
	_art_top = bottom
	for art: Sprite2D in [_sprite, _cover]:
		if art.texture != null:
			_art_top = minf(_art_top, art.global_position.y + _opaque_top(art.texture))
	_origin_center = shop_floor.cell_to_global(cell)
	_build_piles(_placed)
	_place_dish_boards()
	_place_room()
	_placed = true
	_place_work_spot_markers()
	# On the tabletop, over the middle of the footprint.
	_role_label.size = Vector2(48.0, 12.0)
	_role_label.global_position = centroid + data.item_offset - Vector2(24.0, 6.0)
	_update_role_label()


## Assigns a role (or null for unused). Only for stations that take roles.
func set_role(new_role: StationRole) -> void:
	var old_kind: StorageKind = get_stored_kind()
	role = new_role
	_update_role_label()
	if _placed:
		_set_out_role_side_items()
	if get_stored_kind() != old_kind:
		_build_piles()


## Highlights the station and shows its work spots while it's selected.
func set_selected(selected: bool) -> void:
	modulate = Color(1.2, 1.2, 0.9) if selected else Color.WHITE
	show_work_spots(selected)


## Tints the station while it's being placed (green if it fits there, red if not) and
## shows its work spots. Call end_ghost() when it's put down or let go.
func show_as_ghost(fits: bool) -> void:
	modulate = Color(0.6, 1.0, 0.6, 0.75) if fits else Color(1.0, 0.45, 0.45, 0.75)
	show_work_spots(true)


func end_ghost() -> void:
	modulate = Color.WHITE
	show_work_spots(false)


## Shows or hides the markers on the floor where pawns stand to use the station.
func show_work_spots(shown: bool) -> void:
	for marker: Sprite2D in _work_spot_markers:
		marker.visible = shown


func _place_work_spot_markers() -> void:
	var shown: bool = not _work_spot_markers.is_empty() and _work_spot_markers[0].visible
	for marker: Sprite2D in _work_spot_markers:
		marker.queue_free()
	_work_spot_markers.clear()
	for spot: int in get_spot_count():
		var marker := Sprite2D.new()
		var side: Vector2i = get_pawn_side(spot)
		marker.texture = WORK_SPOT_SHEET
		marker.region_enabled = true
		var frame: int = maxi(WORK_SPOT_SIDES.find(side), 0)
		marker.region_rect = Rect2(Vector2(frame * WORK_SPOT_FRAME.x, 0), WORK_SPOT_FRAME)
		marker.centered = false
		marker.offset = -WORK_SPOT_CENTER
		marker.visible = shown
		# An overlay: drawn over anything standing in front, so the spot is always visible.
		marker.z_index = 1
		add_child(marker)
		# Anchored on the cell the pawn faces; the frame puts the circle on the pawn's side.
		marker.global_position = _floor.cell_to_global(get_work_cell(spot) - side)
		_work_spot_markers.append(marker)


## True if nothing is on it or on its way to or from it.
func is_idle() -> bool:
	if _stock_claimed > 0 or _room_claimed > 0:
		return false
	for spot: int in get_spot_count():
		if _items[spot] != null or _reserved[spot]:
			return false
	return true


## Where pawns stand to use each spot.
func get_work_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for spot: int in get_spot_count():
		cells.append(get_work_cell(spot))
	return cells


## Footprint cells pawns can't walk on (none for a walk-in: its floor is open).
func get_blocked_cells() -> Array[Vector2i]:
	return data.get_blocked_cells(cell, facing)


## A walk-in's walls, each between two cells (see StationData.get_wall_edges()).
func get_wall_edges() -> Array[Vector4i]:
	return data.get_wall_edges(cell, facing)


## True if this is a walk-in and `at` is on its floor.
func is_room_cell(at: Vector2i) -> bool:
	return data.walk_in != null and _footprint.has(at)


## The roles the player can give it here: a role that needs a walk-in only inside one.
func get_available_roles() -> Array[StationRole]:
	var roles: Array[StationRole] = []
	for each: StationRole in data.roles:
		if in_walk_in or not each.needs_walk_in:
			roles.append(each)
	return roles


## Draws a walk-in's walls to match the shop's (see ShopWalls.ViewMode).
func set_wall_view(mode: ShopWalls.ViewMode) -> void:
	if _room != null:
		_room.set_view_mode(mode)


func _place_room() -> void:
	if data.walk_in == null:
		return
	if _room == null:
		_room = WalkInRoom.new()
		_room.name = "Room"
		_room.walk_in = data.walk_in
		add_child(_room)
	_room.arrange(_floor, data.footprint, cell, facing)


## Shows the role name on the station (only for stations that take roles).
func show_role_label(shown: bool) -> void:
	_role_label.visible = shown and has_roles()


func _update_role_label() -> void:
	_role_label.text = role.display_name if role != null else "Unused"


## The art's bottom-left corner for a footprint: its leftmost corner and floor-level bottom.
func _get_art_corner(cells: Array[Vector2i]) -> Vector2:
	var half_tile: Vector2 = Vector2(_floor.tile_set.tile_size) / 2.0
	var corner := Vector2(INF, -INF)
	for footprint_cell: Vector2i in cells:
		var center: Vector2 = _floor.cell_to_global(footprint_cell)
		corner.x = minf(corner.x, center.x - half_tile.x)
		corner.y = maxf(corner.y, center.y + half_tile.y)
	return corner


## Places a texture so its left edge and bottom row meet the footprint's corners, flipped
## if it's drawn for the mirror-image facing.
static func _line_up(
	sprite: Sprite2D, texture: Texture2D, left: float, bottom: float, mirrored: bool = false
) -> void:
	sprite.texture = texture
	sprite.flip_h = mirrored
	sprite.centered = false
	if texture != null:
		sprite.global_position = Vector2(left, bottom - texture.get_height())


## First row of a texture with any visible pixels (textures often have empty space on top).
static func _opaque_top(texture: Texture2D) -> float:
	var top: float = 0.0
	if texture is AtlasTexture:
		top = (texture as AtlasTexture).margin.position.y
	var used: Rect2i = texture.get_image().get_used_rect()
	return top + float(used.position.y) if used.size.y > 0 else top


## Shows a spot's work bar, filled to `progress` (0-1), while the station works its item on
## its own. The cover switches to its working art (if any) while any spot is worked.
func show_work(spot: int, progress: float) -> void:
	var bar: ProgressBar = _work_bars[spot]
	bar.value = progress
	bar.global_position = Vector2(
		_item_positions[spot].x - bar.size.x / 2.0, _art_top - bar.size.y - 3.0
	)
	bar.show()
	if not _working[spot]:
		_working[spot] = true
		_update_cover()


## True while the station works an item on its own at any spot (e.g. baking).
func is_working() -> bool:
	return _working.has(true)


func hide_work(spot: int) -> void:
	_work_bars[spot].hide()
	if _working[spot]:
		_working[spot] = false
		_update_cover()


func _update_cover() -> void:
	_line_up(
		_cover, data.get_cover_texture(facing, is_working()),
		_art_corner.x, _art_corner.y, data.is_mirrored(facing)
	)


## Moves the layers into a canvas of their own (see STRIP_WIDTH).
func _make_canvas() -> void:
	_canvas = SubViewport.new()
	_canvas.name = "Canvas"
	_canvas.transparent_bg = true
	_canvas.disable_3d = true
	_canvas.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_canvas)
	_layers.reparent(_canvas, false)
	_layers.position = Vector2.ZERO


## Sizes the canvas around the art (with room for what's stacked on it) and cuts it into
## strips, each sorted one pixel above the front-most footprint cell under it. The outer
## strips run to the canvas edges, catching anything that overhangs the footprint.
func _fit_canvas() -> void:
	var art_size := Vector2.ZERO
	for texture: Texture2D in [
		data.get_texture(facing), data.get_texture(facing, true), _cover.texture
	]:
		if texture != null:
			art_size = art_size.max(texture.get_size())
	_canvas_origin = Vector2(
		floorf(_art_corner.x) - CANVAS_MARGIN,
		floorf(_art_corner.y - art_size.y) - CANVAS_HEADROOM
	)
	var canvas_size := Vector2i(
		int(art_size.x) + 2 * CANVAS_MARGIN, int(art_size.y) + CANVAS_HEADROOM
	)
	_canvas.size = canvas_size
	_canvas.canvas_transform = Transform2D(0.0, -_canvas_origin)

	for strip: Node in _strips.get_children():
		_strips.remove_child(strip)
		strip.queue_free()
	var centers: Array[Vector2] = []
	var left: float = INF
	var right: float = -INF
	for footprint_cell: Vector2i in _footprint:
		var center: Vector2 = _floor.cell_to_global(footprint_cell)
		centers.append(center)
		left = minf(left, center.x - STRIP_WIDTH)
		right = maxf(right, center.x + STRIP_WIDTH)
	var count: int = int(round((right - left) / STRIP_WIDTH))
	for index: int in count:
		var from_x: float = left + index * STRIP_WIDTH
		var to_x: float = from_x + STRIP_WIDTH
		var front_y: float = -INF
		for center: Vector2 in centers:
			if center.x - STRIP_WIDTH < to_x and center.x + STRIP_WIDTH > from_x:
				front_y = maxf(front_y, center.y)
		if index == 0:
			from_x = _canvas_origin.x
		if index == count - 1:
			to_x = _canvas_origin.x + canvas_size.x
		var sort_y: float = front_y + SORT_OFFSET
		var strip := Sprite2D.new()
		strip.texture = _canvas.get_texture()
		strip.centered = false
		strip.region_enabled = true
		strip.region_rect = Rect2(from_x - _canvas_origin.x, 0.0, to_x - from_x, canvas_size.y)
		strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_strips.add_child(strip)
		strip.global_position = Vector2(from_x, sort_y)
		strip.offset = Vector2(0.0, _canvas_origin.y - sort_y)


func can_do(task_type: TaskType) -> bool:
	if has_roles():
		return role != null and role.task_types.has(task_type)
	return data.task_types.has(task_type)


## True if the player can assign this station a role.
func has_roles() -> bool:
	return not data.roles.is_empty()


func get_display_name() -> String:
	if role != null:
		return "%s (%s)" % [data.display_name, role.display_name]
	return data.display_name


func get_spot_count() -> int:
	return data.spots.size()


## Item sitting on the spot, or null.
func get_item(spot: int) -> Item:
	return _items[spot]


## Sets an item on a spot's surface, facing the spot's pawn. The spot must be empty.
func put_item(spot: int, item: Item) -> void:
	_items[spot] = item
	item.station = self
	item.spot = spot
	item.reparent(_item_slot, false)
	_sort_items()
	item.global_position = _item_positions[spot]
	item.face_toward(get_pawn_side(spot))
	if data.item_underlay != null:
		item.set_under(data.item_underlay)


## Draws the items on the spots and side areas back to front: by how far forward their slots
## are on the floor, then lower before higher (see StationSpot.item_height).
func _sort_items() -> void:
	var placed: Array[Item] = []
	for item: Item in _items:
		if item != null and item.get_parent() == _item_slot:
			placed.append(item)
	placed.append_array(_side_items.keys())
	placed.sort_custom(func(a: Item, b: Item) -> bool:
		if _get_floor_y(a) != _get_floor_y(b):
			return _get_floor_y(a) < _get_floor_y(b)
		return _get_height(a) < _get_height(b)
	)
	for item: Item in placed:
		_item_slot.move_child(item, -1)


func _get_floor_y(item: Item) -> float:
	if _side_items.has(item):
		return _area_on_floor(_side_items[item]).y
	return _item_floor_y[item.spot]


func _get_height(item: Item) -> float:
	return 0.0 if _side_items.has(item) else data.spots[item.spot].item_height


## Where the middle of a slot area (at facing 0) is on the floor.
func _area_on_floor(area: Rect2i) -> Vector2:
	var origin_center: Vector2 = _floor.cell_to_global(cell)
	var step_x: Vector2 = _floor.cell_to_global(cell + Vector2i.RIGHT) - origin_center
	var step_y: Vector2 = _floor.cell_to_global(cell + Vector2i.DOWN) - origin_center
	var point: Vector2 = StationData.get_area_point(area, facing)
	return origin_center + step_x * point.x + step_y * point.y


#region Side areas

## Items sitting in the side areas (e.g. a sauce bucket).
func get_side_items() -> Array[Item]:
	var items: Array[Item] = []
	items.assign(_side_items.keys())
	return items


## Sets `item` down in the first free slots of the side areas that fit `size`. Returns
## false if there's no room.
func put_side_item(item: Item, size: Vector2i) -> bool:
	for side: Rect2i in data.side_areas:
		for y: int in range(side.position.y, side.end.y - size.y + 1):
			for x: int in range(side.position.x, side.end.x - size.x + 1):
				var area := Rect2i(Vector2i(x, y), size)
				if data.is_side_area(area) and _is_side_free(area):
					_side_items[item] = area
					item.station = self
					item.spot = -1
					item.reparent(_item_slot, false)
					_show_side_item(item)
					_sort_items()
					return true
	return false


## Takes `item` out of the side areas (e.g. an empty sauce bucket a pawn carries off). The
## node stays where it is until the caller moves it.
func take_side_item(item: Item) -> void:
	_side_items.erase(item)
	item.station = null


func _is_side_free(area: Rect2i) -> bool:
	for taken: Rect2i in _side_items.values():
		if taken.intersects(area):
			return false
	return true


## The first time: sets out the station's own side items (see StationData.side_items) and
## its role's. After a move: lines the side items up with the turned surface.
func _place_side_items() -> void:
	if not _placed:
		for kind: SideItem in data.side_items:
			_set_out_side_item(kind)
		_set_out_role_side_items()
	for item: Item in _side_items:
		_show_side_item(item)


## Takes away the side items set out for the previous role and sets out the current role's.
func _set_out_role_side_items() -> void:
	for item: Item in _role_side_items:
		_side_items.erase(item)
		item.queue_free()
	_role_side_items.clear()
	if role == null:
		return
	# A role's side items are left out where they don't fit (e.g. no cutter on a one-spot
	# table).
	for kind: SideItem in role.side_items:
		var item: Item = _set_out_side_item(kind, false)
		if item != null:
			_role_side_items.append(item)


## Makes a side item of `kind` and puts it in the side areas. Returns null if there's no room
## (with a warning if `warn`).
func _set_out_side_item(kind: SideItem, warn: bool = true) -> Item:
	var item := ITEM_SCENE.instantiate() as Item
	_item_slot.add_child(item)
	kind.set_up(item)
	if not put_side_item(item, kind.slot_size):
		if warn:
			push_warning("%s has no room for its %s" % [data.display_name, kind.display_name])
		item.queue_free()
		return null
	return item


## Places a side item in its slots, turned toward the worker if it faces them (see
## SideItem.faces_worker).
func _show_side_item(item: Item) -> void:
	item.global_position = _area_on_floor(_side_items[item]) + data.item_offset
	if item.side_item != null and item.side_item.faces_worker and get_spot_count() > 0:
		item.face_toward(get_pawn_side(0))

#endregion


## Frees the spot and returns its item. The node stays where it is until the caller
## moves it.
func take_item(spot: int) -> Item:
	var item: Item = _items[spot]
	_items[spot] = null
	if item != null:
		item.station = null
		item.spot = -1
		if data.item_underlay != null:
			item.set_under(null)
	set_opened(spot, false)
	return item


func is_reserved(spot: int) -> bool:
	return _reserved[spot]


## Claims a spot for one pawn's job. Call release() when the job ends or is dropped.
func reserve(spot: int) -> void:
	_reserved[spot] = true


func release(spot: int) -> void:
	_reserved[spot] = false


## Opens the station at a spot for tasks that open it (e.g. the prep table's lids from the
## first ingredient to the last), and closes it again. Taking the spot's item closes it too.
func set_opened(spot: int, opened: bool) -> void:
	_opened[spot] = opened
	_update_in_use_art()


## In use: a task that opens the station is worked at one of its spots (see
## StationData.in_use_textures).
func _is_in_use() -> bool:
	return _opened.has(true)


func _update_in_use_art() -> void:
	if _floor == null:
		return
	var texture: Texture2D = data.get_texture(facing, _is_in_use())
	if _sprite.texture != texture:
		_line_up(_sprite, texture, _art_corner.x, _art_corner.y, data.is_mirrored(facing))


func get_footprint_cells() -> Array[Vector2i]:
	return _footprint


func get_work_cell(spot: int) -> Vector2i:
	return data.get_work_cell(cell, facing, spot)


## True if anything sits on its spots (stored stock doesn't count).
func has_items() -> bool:
	return _items.any(func(item: Item) -> bool: return item != null)


## Grid step from a spot's item cell to where its pawn stands.
func get_pawn_side(spot: int) -> Vector2i:
	return data.get_work_cell(cell, facing, spot) - data.get_item_cell(cell, facing, spot)


## Global point a pawn working the spot faces.
## On the floor (not the raised item point), so the pawn turns along the grid toward it.
func get_work_target(spot: int) -> Vector2:
	return _floor.cell_to_global(data.get_item_cell(cell, facing, spot))


## Kind of thing the station stores (from its role, or else its built-in storage), or null
## if it stores nothing.
func get_stored_kind() -> StorageKind:
	var layout: StorageLayout = get_storage_layout()
	return layout.kind if layout != null else null


func get_storage_layout() -> StorageLayout:
	if role != null and role.stores != null:
		return data.get_storage_layout(role.stores)
	return data.built_in_storage


## A dish sink's drainboards, or null if the station isn't a sink.
func get_dish_boards() -> DishBoards:
	return _dish_boards


## Makes a sink's drainboards the first time, and lines their piles up with its spots. Dishes
## on them stay through moves.
func _place_dish_boards() -> void:
	var sink: DishSink = data.dish_sink
	if sink == null:
		return
	if _dish_boards == null:
		_dish_boards = DishBoards.new()
		_dish_boards.name = "DishBoards"
		_dish_boards.sink = sink
		_supply_on_top.add_child(_dish_boards)
	_dish_boards.arrange(
		_item_positions[sink.dirty_spot], _item_positions[sink.clean_spot], data.is_mirrored(facing)
	)


## Stored units (promised or not).
func get_stock() -> int:
	return _stock


## True if one unit of `kind` is in stock and not already promised to a pawn.
func has_supply(kind: StorageKind) -> bool:
	return kind != null and get_stored_kind() == kind and _stock - _stock_claimed > 0


## Promises one unit to a pawn on its way. Undo with unclaim_supply() if it never arrives.
func claim_supply() -> void:
	_stock_claimed += 1


func unclaim_supply() -> void:
	_stock_claimed -= 1


## Removes a claimed unit from stock and returns how much is left in it: -1 for a full one,
## or the count put back with it (see add_stock()). Partly used ones go out first. For
## storage that holds dishes, get_top_dish() beforehand says which one this is, or `dish`
## picks one (the top-most of its kind).
## Placeholder until deliveries: storage that starts full refills the moment it runs out.
func take_supply(dish: Dish = null) -> int:
	_stock_claimed -= 1
	_stock -= 1
	var left: int = _partial.pop_back() if not _partial.is_empty() else -1
	if dish != null and _stock_dishes.has(dish):
		_stock_dishes.remove_at(_stock_dishes.rfind(dish))
	elif not _stock_dishes.is_empty():
		_stock_dishes.pop_back()
	var layout: StorageLayout = get_storage_layout()
	if _stock == 0 and layout != null and layout.starts_full and layout.refills:
		_stock = _get_capacity()
		_partial.clear()
	_update_piles()
	return left


## The dish the next take_supply() takes, for storage that holds dishes; else null.
func get_top_dish() -> Dish:
	return _stock_dishes.back() if not _stock_dishes.is_empty() else null


## The dishes in stock, for storage that holds dishes, bottom first.
func get_stock_dishes() -> Array[Dish]:
	return _stock_dishes.duplicate()


func _get_capacity() -> int:
	var total: int = 0
	for pile: Array in _pile_units:
		total += pile.size()
	return total


## True if there's a free place for one unit of `kind` not already promised to a pawn.
func has_room(kind: StorageKind) -> bool:
	return (
		kind != null and get_stored_kind() == kind
		and _stock + _room_claimed < _get_capacity()
	)


## Promises a free place to a pawn bringing a unit. Undo with unclaim_room().
func claim_room() -> void:
	_room_claimed += 1


func unclaim_room() -> void:
	_room_claimed -= 1


## Stores a unit in a claimed place. `left` is how much is still in it, for a partly used
## one (e.g. a dough container with 4 of its 6 balls); -1 for a full one. Storage that clears
## when full (see StorageLayout.clears_when_full) does so the moment it fills. `dish` is the
## unit, for storage that holds dishes (see StorageLayout.holds_dishes).
func add_stock(left: int = -1, dish: Dish = null) -> void:
	_room_claimed -= 1
	_stock += 1
	if left >= 0:
		_partial.append(left)
	var layout: StorageLayout = get_storage_layout()
	if dish != null and layout != null and layout.holds_dishes:
		_stock_dishes.append(dish)
	if layout != null and layout.clears_when_full and _stock >= _get_capacity():
		_stock = 0
		_partial.clear()
		_stock_dishes.clear()
	_update_piles()


## How much is left in each partly used unit in stock (see add_stock()).
func get_partial_stock() -> Array[int]:
	return _partial.duplicate()


## Lays out the piles for the stored kind. With `keep_stock` (after a move) the stock stays;
## otherwise it starts full or empty (see StorageLayout.starts_full) until there are
## deliveries. Units and places promised to pawns stay promised until they hand them back
## (a role change interrupts them, see world.gd).
func _build_piles(keep_stock: bool = false) -> void:
	for pile: Array in _pile_units:
		for unit: Node2D in pile:
			unit.queue_free()
	_pile_units.clear()
	var kept: int = _stock
	_stock = 0
	var layout: StorageLayout = get_storage_layout()
	if layout == null:
		return
	if layout.piles_at_spots:
		for item_position: Vector2 in _item_positions:
			_pile_units.append(
				_make_pile(layout, _supply_inside, item_position, _pile_units.size())
			)
	else:
		_make_piles(layout, layout.piles, _supply_inside, 0)
		_make_piles(layout, layout.piles_on_top, _supply_on_top, layout.piles.size())
	if keep_stock:
		_stock = mini(kept, _get_capacity())
		_partial.resize(mini(_partial.size(), _stock))
		_stock_dishes.resize(mini(_stock_dishes.size(), _stock))
	else:
		_partial.clear()
		_stock_dishes.clear()
		if layout.starts_full:
			_stock = _get_capacity()
	_update_piles()


## Adds a pile at each of `offsets` (see StorageLayout.piles), numbered from `first_index`.
## They're built back to front, so nearer piles draw over farther ones at any facing.
func _make_piles(
	layout: StorageLayout, offsets: Array[Vector3], parent: Node2D, first_index: int
) -> void:
	var step_x: Vector2 = _floor.cell_to_global(cell + Vector2i.RIGHT) - _origin_center
	var step_y: Vector2 = _floor.cell_to_global(cell + Vector2i.DOWN) - _origin_center
	var bases: Array[Vector2] = []
	for offset: Vector3 in offsets:
		var turned: Vector2 = StationData.rotate_point(Vector2(offset.x, offset.y), facing)
		bases.append(_origin_center + step_x * turned.x + step_y * turned.y - Vector2(0.0, offset.z))
	var order: Array[int] = []
	for i: int in offsets.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return bases[a].y < bases[b].y)
	_pile_units.resize(first_index + offsets.size())
	for i: int in order:
		_pile_units[first_index + i] = _make_pile(layout, parent, bases[i], first_index + i)


func _make_pile(layout: StorageLayout, parent: Node2D, base: Vector2, index: int) -> Array[Node2D]:
	var pile: Array[Node2D] = []
	for level: int in layout.get_pile_size(index):
		var unit := Node2D.new()
		for texture: Texture2D in layout.textures:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.offset = Vector2(-16, -56)
			# Stored things turn with a mirrored station.
			sprite.flip_h = data.is_mirrored(facing)
			unit.add_child(sprite)
		parent.add_child(unit)
		unit.global_position = base - Vector2(0.0, level * layout.pile_step)
		pile.append(unit)
	return pile


## Shows the first `_stock` units, filling piles in order, bottom up. A unit that's a dish
## is drawn with its dish's art.
func _update_piles() -> void:
	var shown: int = 0
	for pile: Array in _pile_units:
		for unit: Node2D in pile:
			unit.visible = shown < _stock
			if unit.visible and shown < _stock_dishes.size():
				_show_dish_unit(unit, _stock_dishes[shown])
			shown += 1


## Draws a stored unit as `dish`: its back and front art on the unit's first two sprites.
func _show_dish_unit(unit: Node2D, dish: Dish) -> void:
	var textures: Array[Texture2D] = [dish.back_texture, dish.front_texture]
	for i: int in unit.get_child_count():
		(unit.get_child(i) as Sprite2D).texture = textures[i] if i < textures.size() else null
