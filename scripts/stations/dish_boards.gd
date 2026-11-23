class_name DishBoards
extends Node2D
## The dirty and clean drainboards of one dish sink (see DishSink): which dishes sit on each,
## what's promised to pawns on their way, and the piles drawn there. The station makes one
## when its data has a DishSink.

## Pile art lines up like stored units (see Station._make_pile()).
const UNIT_OFFSET := Vector2(-16, -56)

var sink: DishSink
## Dishes on each board, bottom of the pile first.
var _dirty: Array[Dish] = []
var _clean: Array[Dish] = []
## Places on the dirty board promised to pawns bringing a dish.
var _dirty_room_claimed: int = 0
## Places on the clean board promised to a batch being washed.
var _clean_room_claimed: int = 0
## Clean dishes promised to pawns on their way to put them away.
var _clean_claimed: Array[Dish] = []
var _dirty_base := Vector2.ZERO
var _clean_base := Vector2.ZERO
var _mirrored: bool = false
@onready var _piles: Node2D = Node2D.new()


func _ready() -> void:
	add_child(_piles)


## Lines the piles up on the drainboards: `dirty_base` and `clean_base` are where an item
## would sit on each board's spot.
func arrange(dirty_base: Vector2, clean_base: Vector2, mirrored: bool) -> void:
	_dirty_base = dirty_base
	_clean_base = clean_base
	_mirrored = mirrored
	_redraw()


#region Dirty board

func get_dirty_count() -> int:
	return _dirty.size()


## True if there's a place on the dirty board nobody has been promised.
func has_dirty_room() -> bool:
	return _dirty.size() + _dirty_room_claimed < sink.board_capacity


## Promises a place to a pawn bringing a dish. Undo with unclaim_dirty_room().
func claim_dirty_room() -> void:
	_dirty_room_claimed += 1


func unclaim_dirty_room() -> void:
	_dirty_room_claimed -= 1


## Sets a dish down in a claimed place on the dirty board.
func add_dirty(dish: Dish) -> void:
	_dirty_room_claimed -= 1
	_dirty.append(dish)
	_redraw()


## Puts dishes back on the dirty board without a claim (a batch whose washing stopped). The
## board may go over capacity until they're washed.
func put_back_dirty(dishes: Array[Dish]) -> void:
	_dirty.append_array(dishes)
	_redraw()


## Takes up to `count` dishes off the dirty board (bottom of the pile first) for washing.
func take_dirty(count: int) -> Array[Dish]:
	var taken: Array[Dish] = _dirty.slice(0, count)
	_dirty = _dirty.slice(count)
	_redraw()
	return taken

#endregion


#region Clean board

## Places on the clean board nobody has been promised.
func get_clean_room() -> int:
	return sink.board_capacity - _clean.size() - _clean_room_claimed


func claim_clean_room(count: int) -> void:
	_clean_room_claimed += count


func unclaim_clean_room(count: int) -> void:
	_clean_room_claimed -= count


## Sets a washed batch down in its claimed places on the clean board.
func add_clean(dishes: Array[Dish]) -> void:
	_clean_room_claimed -= dishes.size()
	_clean.append_array(dishes)
	_redraw()


## Clean dishes nobody has been promised, one of each kind, in pile order.
func get_free_clean() -> Array[Dish]:
	var free: Array[Dish] = []
	var claimed: Array[Dish] = _clean_claimed.duplicate()
	for dish: Dish in _clean:
		if claimed.has(dish):
			claimed.erase(dish)
		elif not free.has(dish):
			free.append(dish)
	return free


func get_clean_count() -> int:
	return _clean.size()


## Promises a clean dish to a pawn on their way to put it away. Undo with unclaim_clean().
func claim_clean(dish: Dish) -> void:
	_clean_claimed.append(dish)


func unclaim_clean(dish: Dish) -> void:
	_clean_claimed.erase(dish)


## Takes a claimed clean dish off the board (the top-most of its kind).
func take_clean(dish: Dish) -> void:
	_clean_claimed.erase(dish)
	var index: int = _clean.rfind(dish)
	if index >= 0:
		_clean.remove_at(index)
	_redraw()

#endregion


func _redraw() -> void:
	if not is_node_ready():
		return
	for child: Node in _piles.get_children():
		child.queue_free()
	_draw_pile(_dirty, _dirty_base, true)
	_draw_pile(_clean, _clean_base, false)


func _draw_pile(dishes: Array[Dish], base: Vector2, dirty: bool) -> void:
	for level: int in dishes.size():
		var dish: Dish = dishes[level]
		var unit := Node2D.new()
		for texture: Texture2D in [dish.back_texture, dish.front_texture]:
			if texture == null:
				continue
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.offset = UNIT_OFFSET
			sprite.flip_h = _mirrored
			if dirty:
				sprite.modulate = dish.dirty_tint
			unit.add_child(sprite)
		_piles.add_child(unit)
		unit.global_position = base - Vector2(0.0, level * sink.pile_step)
