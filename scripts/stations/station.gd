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
var _reserved: bool = false

@onready var _sprite: Sprite2D = $Sprite


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

	# Y-sort origin sits just above the front-most cell center, so pawns standing
	# on that row (beside or in front of the station) draw over it.
	global_position = Vector2(centroid.x, front_y - 1.0)

	var texture: Texture2D = data.get_texture(facing)
	_sprite.texture = texture
	_sprite.centered = false
	if texture != null:
		_sprite.global_position = Vector2(left, bottom - texture.get_height())


func get_task_type() -> TaskType:
	return data.task_type


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
