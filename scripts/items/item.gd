class_name Item
extends Node2D
## A 1×1 object that sits on a station, on the floor, in a pawn's hands, or inside
## another item (e.g. a pizza in a box). Its node position is the center of its floor
## cell, or the surface it rests on.

## Station it's sitting on, or null.
var station: Station = null
## Which of the station's spots, or -1.
var spot: int = -1
## Item it's inside, or null.
var container: Item = null
## True while a station works it on its own (e.g. baking). It can't be moved meanwhile.
var busy: bool = false
## Set if this is an ingredient container (e.g. a dough tub); its contents are the units.
var ingredient: IngredientContainer = null

var _mirrored: bool = false
## Where each item inside sits, as if not mirrored.
var _content_offsets: Dictionary[Item, Vector2] = {}
## Units promised to pawns on their way to take one.
var _units_claimed: int = 0

@onready var _under: Sprite2D = $Under
@onready var _sprite: Sprite2D = $Sprite
## Marks drawn on top of the item, like cut lines.
@onready var _overlay: Sprite2D = $Overlay
@onready var _contents: Node2D = $Contents
@onready var _over: Sprite2D = $Over
@onready var _lid: Sprite2D = $Lid


func set_texture(texture: Texture2D) -> void:
	_sprite.texture = texture


## Drawn over everything, contents included. Pass null to take it off.
func set_lid(texture: Texture2D) -> void:
	_lid.texture = texture


## Marks drawn over the item (e.g. cut lines). Pass null to clear.
func set_overlay(texture: Texture2D) -> void:
	_overlay.texture = texture


## Art drawn under and over the item's contents (e.g. an open box), and where the
## contents sit relative to the item. Pass nulls to clear.
func set_wrap(
	under: Texture2D, over: Texture2D, contents_offset: Vector2 = Vector2.ZERO
) -> void:
	_under.texture = under
	_over.texture = over
	_contents.position = contents_offset


## Item art is drawn with its front facing down-right (a box's fold and lid are at the
## back, up-left). Mirrored, it faces down-left. Only flips the item's own art, not its
## contents' own art, though they move to stay in the same place inside it.
func set_mirrored(mirrored: bool) -> void:
	_mirrored = mirrored
	for sprite: Sprite2D in [_under, _sprite, _overlay, _over, _lid]:
		sprite.flip_h = mirrored
	for item: Item in _content_offsets:
		_place_content(item)


## Puts `item` inside this one, between its under and over art, at `offset`. Items put in
## later draw in front.
func put_in(item: Item, offset: Vector2 = Vector2.ZERO) -> void:
	item.container = self
	item.reparent(_contents, false)
	_content_offsets[item] = offset
	_place_content(item)


## Takes `item` out. The caller moves it somewhere.
func take_out(item: Item) -> void:
	_content_offsets.erase(item)
	item.container = null


func _place_content(item: Item) -> void:
	var offset: Vector2 = _content_offsets[item]
	item.position = Vector2(-offset.x, offset.y) if _mirrored else offset


## Items inside, back to front (for an ingredient container, its units).
func get_units() -> Array[Item]:
	var units: Array[Item] = []
	units.assign(_content_offsets.keys())
	return units


## Units left that no pawn has claimed.
func get_free_units() -> int:
	return _content_offsets.size() - _units_claimed


## Promises a unit to a pawn on its way. Undo with unclaim_unit() if they never arrive.
func claim_unit() -> void:
	_units_claimed += 1


func unclaim_unit() -> void:
	_units_claimed -= 1


## Takes a claimed unit out (the front-most) and returns it. The caller moves it.
func take_unit() -> Item:
	_units_claimed -= 1
	var unit: Item = get_units().back()
	take_out(unit)
	return unit


## The outermost item this one is inside (or itself), which is what sits somewhere.
func get_outermost() -> Item:
	var item: Item = self
	while item.container != null:
		item = item.container
	return item
