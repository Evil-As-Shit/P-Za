class_name DockCases
extends Node2D
## The supply cases on one delivery drop-off (see DeliveryDock): which are there, which are
## promised to pawns on their way, and which are being carried away (still counted until
## they're put away). The station makes one when its data has a DeliveryDock.

## Pile art lines up like stored units (see Station._make_pile()).
const UNIT_OFFSET := Vector2(-16, -56)

var dock: DeliveryDock
## Cases on it, bottom of the piles first.
var _cases: Array[SupplyItem] = []
## Cases promised to pawns on their way to take one.
var _claimed: Array[SupplyItem] = []
## Cases taken off and on their way to storage.
var _out: Array[SupplyItem] = []
var _bases: Array[Vector2] = []
var _mirrored: bool = false
@onready var _piles: Node2D = Node2D.new()


func _ready() -> void:
	add_child(_piles)


## Lines the piles up: `bases` is where each pile's bottom case sits.
func arrange(bases: Array[Vector2], mirrored: bool) -> void:
	_bases = bases
	_mirrored = mirrored
	_redraw()


## Free places for new cases (cases being carried away still take theirs).
func get_room() -> int:
	return dock.capacity - _cases.size() - _out.size()


## Sets a delivered case down. Returns false if there's no room.
func add_case(supply: SupplyItem) -> bool:
	if get_room() <= 0:
		return false
	_cases.append(supply)
	_redraw()
	return true


## Cases of `supply` here or being carried away (not yet put away).
func count(supply: SupplyItem) -> int:
	return _cases.count(supply) + _out.count(supply)


## True if there's anything on it or on its way off it.
func has_cases() -> bool:
	return not _cases.is_empty() or not _out.is_empty()


## Kinds of case here that nobody has been promised, one of each, bottom first.
func get_free() -> Array[SupplyItem]:
	var free: Array[SupplyItem] = []
	var claimed: Array[SupplyItem] = _claimed.duplicate()
	for supply: SupplyItem in _cases:
		if claimed.has(supply):
			claimed.erase(supply)
		elif not free.has(supply):
			free.append(supply)
	return free


## Promises a case to a pawn on their way to take it. Undo with unclaim().
func claim(supply: SupplyItem) -> void:
	_claimed.append(supply)


func unclaim(supply: SupplyItem) -> void:
	_claimed.erase(supply)


## Takes a claimed case off (the top-most of its kind); it still counts until finish().
func take(supply: SupplyItem) -> void:
	_claimed.erase(supply)
	var index: int = _cases.rfind(supply)
	if index >= 0:
		_cases.remove_at(index)
	_out.append(supply)
	_redraw()


## A case taken off was put away.
func finish(supply: SupplyItem) -> void:
	_out.erase(supply)


## A case taken off couldn't be put away: it goes back on top.
func put_back(supply: SupplyItem) -> void:
	_out.erase(supply)
	_cases.append(supply)
	_redraw()


func _redraw() -> void:
	if not is_node_ready() or _bases.is_empty():
		return
	for child: Node in _piles.get_children():
		child.queue_free()
	var per_pile: int = dock.get_per_pile()
	# Piles are filled in order but drawn back to front, so nearer ones draw over farther ones.
	var order: Array[int] = []
	for pile: int in _bases.size():
		order.append(pile)
	order.sort_custom(func(a: int, b: int) -> bool: return _bases[a].y < _bases[b].y)
	for pile: int in order:
		for level: int in per_pile:
			var index: int = pile * per_pile + level
			if index >= _cases.size():
				break
			var sprite := Sprite2D.new()
			sprite.texture = _cases[index].case_texture
			sprite.centered = false
			sprite.offset = UNIT_OFFSET
			sprite.flip_h = _mirrored
			_piles.add_child(sprite)
			sprite.global_position = _bases[pile] - Vector2(0.0, level * dock.pile_step)
