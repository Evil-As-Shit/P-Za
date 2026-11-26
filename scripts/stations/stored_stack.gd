class_name StoredStack
extends RefCounted
## A stack of stored things of one kind (and one dish, for kinds that hold dishes) standing on
## a station's storage surface (see StorageSurface), in an area of its slots. See Station's
## storage.

var kind: StorageKind
## The dish every item in it is, for kinds whose layout holds dishes; else null.
var dish: Dish = null
## Index of the surface in the station's storage surfaces.
var surface: int = 0
## Its slots at facing 0.
var area: Rect2i
## Each item, bottom first: -1 for a full one; else for a kind of one unit per item, the count
## put back with a partly used one (e.g. a dough container with 4 of its 6 balls), or for a
## kind of several units per item (see StorageKind.units_per_item), the units left in it.
var lefts: Array[int] = []
## Units promised to pawns bringing one.
var room_claimed: int = 0
## Items it holds when full.
var max_items: int = 1
## Its drawn node.
var node: Node2D = null


func _init(p_kind: StorageKind, p_dish: Dish, p_surface: int, p_area: Rect2i, p_max: int) -> void:
	kind = p_kind
	dish = p_dish
	surface = p_surface
	area = p_area
	max_items = p_max


## Units in it.
func get_units() -> int:
	var total: int = 0
	for left: int in lefts:
		total += _units_in(left)
	return total


## Units it holds when full.
func get_max_units() -> int:
	return max_items * kind.units_per_item


## Unpromised units of room left.
func get_room() -> int:
	return get_max_units() - get_units() - room_claimed


## Adds one unit: a full item, or one that's `left` partly used. For a kind of several units
## per item, it tops up the top item first.
func add(left: int) -> void:
	var per_item: int = kind.units_per_item
	if per_item > 1:
		if not lefts.is_empty() and lefts.back() >= 0:
			lefts[-1] += 1
			if lefts[-1] >= per_item:
				lefts[-1] = -1
		else:
			lefts.append(1)
		return
	lefts.append(left)


## Takes one unit out and returns how much was left in it (see lefts): a partly used item
## first, else the top one. For a kind of several units per item, -1.
func take() -> int:
	var index: int = lefts.size() - 1
	for i: int in range(lefts.size() - 1, -1, -1):
		if lefts[i] >= 0:
			index = i
			break
	if kind.units_per_item > 1:
		var units: int = _units_in(lefts[index]) - 1
		if units <= 0:
			lefts.remove_at(index)
		else:
			lefts[index] = units
		return -1
	var left: int = lefts[index]
	lefts.remove_at(index)
	return left


## True if it's empty with nothing promised, so its slots are free again.
func is_unused() -> bool:
	return lefts.is_empty() and room_claimed == 0


## Units in one item, given its entry in lefts.
func _units_in(left: int) -> int:
	if kind.units_per_item > 1:
		return kind.units_per_item if left < 0 else left
	return 1
