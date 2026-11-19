extends Node2D
## Prototype shop scene. Until the task system exists, pawns wander between random floor cells.

@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0

@onready var _floor: ShopFloor = $ShopFloor
@onready var _entities: Node2D = $Entities
@onready var _camera: ShopCamera = $ShopCamera


func _ready() -> void:
	_camera.position = _floor.cell_to_global(_floor.get_used_rect().get_center())
	for child: Node in _entities.get_children():
		var pawn := child as Pawn
		if pawn == null:
			continue
		pawn.global_position = _floor.cell_to_global(_floor.get_random_walkable_cell())
		pawn.path_finished.connect(_on_pawn_path_finished.bind(pawn))
		_send_to_random_cell(pawn)


func _send_to_random_cell(pawn: Pawn) -> void:
	var from_cell: Vector2i = _floor.global_to_cell(pawn.global_position)
	var path: PackedVector2Array = _floor.get_path_points(
		from_cell, _floor.get_random_walkable_cell()
	)
	if path.size() < 2:
		_wait_then_wander(pawn)
		return
	pawn.follow_path(path)


func _wait_then_wander(pawn: Pawn) -> void:
	var wait: float = randf_range(idle_time_min, idle_time_max)
	get_tree().create_timer(wait).timeout.connect(_send_to_random_cell.bind(pawn))


func _on_pawn_path_finished(pawn: Pawn) -> void:
	_wait_then_wander(pawn)
