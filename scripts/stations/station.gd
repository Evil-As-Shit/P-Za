class_name Station
extends Node2D
## A piece of kitchen equipment placed on the floor grid. Each of its spots holds one
## item and is worked by one pawn at a time. Storage stations also hold a supply stock.

@export var data: StationData
## Origin cell on the floor grid.
@export var cell: Vector2i = Vector2i.ZERO
## Quarter turns (0-3).
@export_range(0, 3) var facing: int = 0

var _footprint: Array[Vector2i] = []
var _item_positions: Array[Vector2] = []
var _items: Array[Item] = []
var _reserved: Array[bool] = []
var _supply_left: int = 0
var _supply_claimed: int = 0
## One array of sprites per pile, bottom to top. Inside piles first, then on-top piles.
var _pile_sprites: Array[Array] = []
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
	_build_piles(shop_floor.cell_to_global(cell))


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
	return data.task_types.has(task_type)


func get_spot_count() -> int:
	return data.spots.size()


## Item sitting on the spot, or null.
func get_item(spot: int) -> Item:
	return _items[spot]


## Sets an item on a spot's surface. The spot must be empty.
func put_item(spot: int, item: Item) -> void:
	_items[spot] = item
	item.station = self
	item.spot = spot
	item.reparent(_item_slot, false)
	item.global_position = _item_positions[spot]


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


## Global point a pawn working the spot faces.
func get_work_target(spot: int) -> Vector2:
	return _item_positions[spot]


## True if one unit of `kind` is in stock and not already promised to a pawn.
func has_supply(kind: StringName) -> bool:
	return kind != &"" and data.supply == kind and _supply_left - _supply_claimed > 0


## Promises one unit to a pawn on its way. Undo with unclaim_supply() if it never arrives.
func claim_supply() -> void:
	_supply_claimed += 1


func unclaim_supply() -> void:
	_supply_claimed -= 1


## Removes a claimed unit from stock.
func take_supply() -> void:
	_supply_claimed -= 1
	_supply_left -= 1
	_update_piles()


func _build_piles(origin_center: Vector2) -> void:
	_supply_left = data.get_supply_capacity()
	for pile_offset: Vector2 in data.supply_piles:
		_pile_sprites.append(_make_pile(_supply_inside, origin_center + pile_offset))
	for pile_offset: Vector2 in data.supply_piles_on_top:
		_pile_sprites.append(_make_pile(_supply_on_top, origin_center + pile_offset))
	_update_piles()


func _make_pile(parent: Node2D, base: Vector2) -> Array[Sprite2D]:
	var pile: Array[Sprite2D] = []
	for level: int in data.supply_per_pile:
		var sprite := Sprite2D.new()
		sprite.texture = data.supply_texture
		sprite.centered = false
		sprite.offset = Vector2(-16, -56)
		parent.add_child(sprite)
		sprite.global_position = base - Vector2(0.0, level * data.supply_pile_step)
		pile.append(sprite)
	return pile


## Shows the first `_supply_left` units, filling piles in order, bottom up.
func _update_piles() -> void:
	var shown: int = 0
	for pile: Array in _pile_sprites:
		for sprite: Sprite2D in pile:
			sprite.visible = shown < _supply_left
			shown += 1
