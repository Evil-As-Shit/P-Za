class_name Customer
extends Node2D
## A customer in the lobby. Walks where it's sent and carries its order out; the Lobby
## decides where it goes. Placeholder art: the pawn sprite with a recolored shirt.

## Reached the end of a walk.
signal arrived
## Walked onto a cell's center (a global position), e.g. to dirty the floor there.
signal cell_reached(at: Vector2)

enum State { IN_LINE, WAITING, PICKING_UP, LEAVING }

@export var move_speed: float = 50.0
## Height above the feet a carried order is held at.
@export var hold_height: float = 24.0
## How far in front of the customer a carried order is held, for a down-left facing.
@export var hold_reach: Vector2 = Vector2(-5.0, 3.0)

## Where the customer is in their visit (set by the Lobby).
var state: State = State.IN_LINE
## The order being taken at the register (until its ticket prints), or null.
var order_job: Job = null
## The customer's ticket once their order is taken, or null.
var ticket: Ticket = null
## True once the customer has stood at the register and their order can be taken.
var at_register: bool = false
## The cell the customer is walking to or standing on.
var target_cell: Vector2i = Vector2i.ZERO

var _path: PackedVector2Array = PackedVector2Array()
var _held_item: Item = null
var _facing_up: bool = false
var _facing_right: bool = false

@onready var _body: Node2D = $Body
@onready var _sprite: AnimatedSprite2D = $Body/Sprite
@onready var _hold_point: Marker2D = $Body/HoldPoint


func _ready() -> void:
	_play_idle()
	_place_hold_point()


func _process(delta: float) -> void:
	if not _path.is_empty():
		_step_along_path(delta)


## Recolors the customer's shirt.
func set_shirt_color(color: Color) -> void:
	var material := _sprite.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"shirt_color", color)


## Walks through each point in order (global positions), then emits arrived. An empty path
## arrives at once, where the customer stands.
func walk(points: PackedVector2Array) -> void:
	_path = points
	if _path.is_empty():
		_play_idle()
		arrived.emit()


func is_walking() -> bool:
	return not _path.is_empty()


## Turns to face a global point (e.g. the register while in line).
func look_toward(point: Vector2) -> void:
	_face(point - global_position)
	_play_idle()


## Carries `item` in front of the customer (their order, on the way out).
func hold_item(item: Item) -> void:
	_held_item = item
	item.reparent(_hold_point, false)
	item.position = Vector2.ZERO
	_place_hold_point()
	if not is_walking():
		_play_idle()


func get_held_item() -> Item:
	return _held_item


func _step_along_path(delta: float) -> void:
	var to_target: Vector2 = _path[0] - global_position
	var step: float = move_speed * delta
	if to_target.length() <= step:
		global_position = _path[0]
		_path.remove_at(0)
		# A path starts where the customer stands: that's not a step.
		if not to_target.is_zero_approx():
			cell_reached.emit(global_position)
		if _path.is_empty():
			_play_idle()
			arrived.emit()
		return
	_face(to_target)
	global_position += to_target.normalized() * step
	if _held_item != null:
		_sprite.play(&"hold_walk_up" if _facing_up else &"hold_walk_down")
	else:
		_sprite.play(&"walk_up" if _facing_up else &"walk_down")


func _face(direction: Vector2) -> void:
	if not is_zero_approx(direction.y):
		_facing_up = direction.y < 0.0
	if not is_zero_approx(direction.x):
		_facing_right = direction.x > 0.0
	# The sheet only has left-facing art; right-facing is a horizontal flip.
	_sprite.flip_h = _facing_right
	_place_hold_point()


## Holds the order in front of the customer, drawn behind them when facing away.
func _place_hold_point() -> void:
	if _held_item != null:
		_held_item.set_mirrored(not _facing_right)
	var reach: Vector2 = hold_reach
	if _facing_right:
		reach.x = -reach.x
	if _facing_up:
		reach.y = -reach.y
	_hold_point.position = reach + Vector2(0.0, -hold_height)
	_body.move_child(_hold_point, 0 if _facing_up else _sprite.get_index() + 1)


func _play_idle() -> void:
	if _held_item != null:
		_sprite.play(&"hold_idle_up" if _facing_up else &"hold_idle_down")
	else:
		_sprite.play(&"idle_up" if _facing_up else &"idle_down")
