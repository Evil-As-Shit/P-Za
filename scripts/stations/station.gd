class_name Station
extends Node2D
## A piece of kitchen equipment placed on the floor grid. Each of its spots holds one
## item and is worked by one pawn at a time. Storage stations also hold a supply stock.

@export var data: StationData
## Origin cell on the floor grid.
@export var cell: Vector2i = Vector2i.ZERO
## Quarter turns (0-3).
@export_range(0, 3) var facing: int = 0
## Assigned role, for stations that take one (see StationData.roles). Null means unused.
@export var role: StationRole = null

var _footprint: Array[Vector2i] = []
var _item_positions: Array[Vector2] = []
var _items: Array[Item] = []
var _reserved: Array[bool] = []
## Stored units (of the storage role's kind), how many are promised to pawns on their way to
## take one, and how many free places are promised to pawns bringing one.
var _stock: int = 0
var _stock_claimed: int = 0
var _room_claimed: int = 0
## One array of unit nodes per pile, bottom to top. Inside piles first, then on-top piles.
var _pile_units: Array[Array] = []
var _origin_center: Vector2 = Vector2.ZERO
## Top edge of the station's art, for placing the work bar above it.
var _art_top: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _supply_inside: Node2D = $SupplyInside
## Items are parented here so they draw between the station art and its cover.
@onready var _item_slot: Node2D = $ItemSlot
@onready var _cover: Sprite2D = $Cover
@onready var _supply_on_top: Node2D = $SupplyOnTop
## Shown while the station works an item on its own (e.g. baking).
@onready var _work_bar: ProgressBar = $WorkBar
## Names the assigned role on the floor in front of the station.
@onready var _role_label: Label = $RoleLabel


## Snaps the station onto the floor and lines its art up with its footprint.
func place(shop_floor: ShopFloor) -> void:
	_footprint = data.get_footprint_cells(cell, facing)
	var half_tile: Vector2 = Vector2(shop_floor.tile_set.tile_size) / 2.0
	var left: float = INF
	var bottom: float = -INF
	var front_y: float = -INF
	var centroid := Vector2.ZERO
	for footprint_cell: Vector2i in _footprint:
		var center: Vector2 = shop_floor.cell_to_global(footprint_cell)
		left = minf(left, center.x - half_tile.x)
		bottom = maxf(bottom, center.y + half_tile.y)
		front_y = maxf(front_y, center.y)
		centroid += center
	centroid /= float(_footprint.size())

	_item_positions.clear()
	for spot: int in data.spots.size():
		_item_positions.append(
			shop_floor.cell_to_global(data.get_item_cell(cell, facing, spot)) + data.item_offset
		)
	_items.resize(data.spots.size())
	_reserved.resize(data.spots.size())

	# Y-sort origin sits just above the front-most cell center, so pawns standing
	# on that row (beside or in front of the station) draw over it.
	global_position = Vector2(centroid.x, front_y - 1.0)

	_line_up(_sprite, data.get_texture(facing), left, bottom)
	_line_up(_cover, data.get_cover_texture(facing), left, bottom)
	_art_top = bottom
	for art: Sprite2D in [_sprite, _cover]:
		if art.texture != null:
			_art_top = minf(_art_top, art.global_position.y + _opaque_top(art.texture))
	_origin_center = shop_floor.cell_to_global(cell)
	_build_piles()
	# On the tabletop, over the middle of the footprint.
	_role_label.size = Vector2(48.0, 12.0)
	_role_label.global_position = centroid + data.item_offset - Vector2(24.0, 6.0)
	_update_role_label()


## Assigns a role (or null for unused). Only for stations that take roles.
func set_role(new_role: StationRole) -> void:
	var old_kind: StorageKind = get_stored_kind()
	role = new_role
	_update_role_label()
	if get_stored_kind() != old_kind:
		_build_piles()


## Highlights the station while it's selected.
func set_selected(selected: bool) -> void:
	modulate = Color(1.2, 1.2, 0.9) if selected else Color.WHITE


## Shows the role name on the station (only for stations that take roles).
func show_role_label(shown: bool) -> void:
	_role_label.visible = shown and has_roles()


func _update_role_label() -> void:
	_role_label.text = role.display_name if role != null else "Unused"


## Places a texture so its left edge and bottom row meet the footprint's corners.
static func _line_up(sprite: Sprite2D, texture: Texture2D, left: float, bottom: float) -> void:
	sprite.texture = texture
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


## Shows the work bar over a spot, filled to `progress` (0-1).
func show_work(spot: int, progress: float) -> void:
	_work_bar.value = progress
	_work_bar.global_position = Vector2(
		_item_positions[spot].x - _work_bar.size.x / 2.0, _art_top - _work_bar.size.y - 3.0
	)
	_work_bar.show()


func hide_work() -> void:
	_work_bar.hide()


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
	item.global_position = _item_positions[spot]
	# Items can only face down-left or down-right, so pick the side nearer the pawn.
	var side: Vector2i = get_pawn_side(spot)
	item.set_mirrored(side.y > 0 or side.x < 0)


## Frees the spot and returns its item. The node stays where it is until the caller
## moves it.
func take_item(spot: int) -> Item:
	var item: Item = _items[spot]
	_items[spot] = null
	if item != null:
		item.station = null
		item.spot = -1
	return item


func is_reserved(spot: int) -> bool:
	return _reserved[spot]


## Claims a spot for one pawn's job. Call release() when the job ends or is dropped.
func reserve(spot: int) -> void:
	_reserved[spot] = true


func release(spot: int) -> void:
	_reserved[spot] = false


func get_footprint_cells() -> Array[Vector2i]:
	return _footprint


func get_work_cell(spot: int) -> Vector2i:
	return data.get_work_cell(cell, facing, spot)


## Grid step from a spot's item cell to where its pawn stands.
func get_pawn_side(spot: int) -> Vector2i:
	return data.get_work_cell(cell, facing, spot) - data.get_item_cell(cell, facing, spot)


## Global point a pawn working the spot faces.
func get_work_target(spot: int) -> Vector2:
	return _item_positions[spot]


## Kind of thing the station stores (from its role), or null if it isn't storage.
func get_stored_kind() -> StorageKind:
	return role.stores if role != null else null


func get_storage_layout() -> StorageLayout:
	var kind: StorageKind = get_stored_kind()
	return data.get_storage_layout(kind) if kind != null else null


## True if one unit of `kind` is in stock and not already promised to a pawn.
func has_supply(kind: StorageKind) -> bool:
	return kind != null and get_stored_kind() == kind and _stock - _stock_claimed > 0


## Promises one unit to a pawn on its way. Undo with unclaim_supply() if it never arrives.
func claim_supply() -> void:
	_stock_claimed += 1


func unclaim_supply() -> void:
	_stock_claimed -= 1


## Removes a claimed unit from stock. Placeholder until deliveries: storage that starts
## full refills the moment it runs out.
func take_supply() -> void:
	_stock_claimed -= 1
	_stock -= 1
	var layout: StorageLayout = get_storage_layout()
	if _stock == 0 and layout != null and layout.starts_full:
		_stock = _get_capacity()
	_update_piles()


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


## Stores a unit in a claimed place. Placeholder until a cleaning station: storage that
## clears when full does so the moment it fills.
func add_stock() -> void:
	_room_claimed -= 1
	_stock += 1
	var layout: StorageLayout = get_storage_layout()
	if layout != null and layout.clears_when_full and _stock >= _get_capacity():
		_stock = 0
	_update_piles()


## Lays out the piles for the stored kind. Stock starts full or empty (see
## StorageLayout.starts_full) until there are deliveries.
func _build_piles() -> void:
	for pile: Array in _pile_units:
		for unit: Node2D in pile:
			unit.queue_free()
	_pile_units.clear()
	_stock = 0
	_stock_claimed = 0
	_room_claimed = 0
	var layout: StorageLayout = get_storage_layout()
	if layout == null:
		return
	if layout.piles_at_spots:
		for item_position: Vector2 in _item_positions:
			_pile_units.append(
				_make_pile(layout, _supply_inside, item_position, _pile_units.size())
			)
	else:
		for pile_offset: Vector2 in layout.piles:
			_pile_units.append(_make_pile(
				layout, _supply_inside, _origin_center + pile_offset, _pile_units.size()
			))
		for pile_offset: Vector2 in layout.piles_on_top:
			_pile_units.append(_make_pile(
				layout, _supply_on_top, _origin_center + pile_offset, _pile_units.size()
			))
	if layout.starts_full:
		_stock = _get_capacity()
	_update_piles()


func _make_pile(layout: StorageLayout, parent: Node2D, base: Vector2, index: int) -> Array[Node2D]:
	var pile: Array[Node2D] = []
	for level: int in layout.get_pile_size(index):
		var unit := Node2D.new()
		for texture: Texture2D in layout.textures:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.offset = Vector2(-16, -56)
			unit.add_child(sprite)
		parent.add_child(unit)
		unit.global_position = base - Vector2(0.0, level * layout.pile_step)
		pile.append(unit)
	return pile


## Shows the first `_stock` units, filling piles in order, bottom up.
func _update_piles() -> void:
	var shown: int = 0
	for pile: Array in _pile_units:
		for unit: Node2D in pile:
			unit.visible = shown < _stock
			shown += 1
