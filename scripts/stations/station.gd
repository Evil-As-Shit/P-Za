class_name Station
extends Node2D
## A piece of kitchen equipment placed on the floor grid. One pawn works it at a time.

@export var data: StationData
## Origin cell on the floor grid.
@export var cell: Vector2i = Vector2i.ZERO
## Quarter turns (0-3).
@export_range(0, 3) var facing: int = 0

var _footprint: Array[Vector2i] = []
var _work_target: Vector2 = Vector2.ZERO
var _item_position: Vector2 = Vector2.ZERO
var _reserved: bool = false
var _item: Item = null

@onready var _sprite: Sprite2D = $Sprite
## Items are parented here so they draw between the station art and its cover.
@onready var _item_slot: Node2D = $ItemSlot
@onready var _cover: Sprite2D = $Cover


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
	_work_target = centroid
	_item_position = (
		shop_floor.cell_to_global(data.get_item_cell(cell, facing)) + data.item_offset
	)

	# Y-sort origin sits just above the front-most cell center, so pawns standing
	# on that row (beside or in front of the station) draw over it.
	global_position = Vector2(centroid.x, front_y - 1.0)

	_line_up(_sprite, data.get_texture(facing), left, bottom)
	_line_up(_cover, data.get_cover_texture(facing), left, bottom)


## Places a texture so its left edge and bottom row meet the footprint's corners.
static func _line_up(sprite: Sprite2D, texture: Texture2D, left: float, bottom: float) -> void:
	sprite.texture = texture
	sprite.centered = false
	if texture != null:
		sprite.global_position = Vector2(left, bottom - texture.get_height())


func can_do(task_type: TaskType) -> bool:
	return data.task_types.has(task_type)


## Item sitting on the station, or null.
func get_item() -> Item:
	return _item


## Sets an item on the station's surface. The station must be empty.
func put_item(item: Item) -> void:
	_item = item
	item.station = self
	item.reparent(_item_slot, false)
	item.global_position = _item_position


## Frees the station's item slot and returns the item. The node stays where it is
## until the caller moves it.
func take_item() -> Item:
	var item: Item = _item
	_item = null
	if item != null:
		item.station = null
	return item


func is_reserved() -> bool:
	return _reserved


## Claims the station for one pawn's job. Call release() when the job ends or is dropped.
func reserve() -> void:
	_reserved = true


func release() -> void:
	_reserved = false


func get_footprint_cells() -> Array[Vector2i]:
	return _footprint


func get_work_cell() -> Vector2i:
	return data.get_work_cell(cell, facing)


## Global point a working pawn faces.
func get_work_target() -> Vector2:
	return _work_target
