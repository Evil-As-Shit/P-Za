class_name Item
extends Node2D
## A 1×1 object that sits on a station, on the floor, in a pawn's hands, or inside
## another item (e.g. a pizza in a box). Its node position is the center of its floor
## cell, or the surface it rests on.

## Turned versions of item art (e.g. a box with its lid on the other edge).
@export var rotated_art: RotatedArt

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
## Set if tasks take portions from it in place (e.g. a sauce bucket), with how many are left.
var portions: PortionContainer = null
var portions_left: int = 0
## What it is, if it was set out as a station's side item (see SideItem).
var side_item: SideItem = null
## Name shown when it's selected (see get_display_name()), e.g. "Box". Empty to name it by
## what it holds or is.
var display_name: String = ""
## True for an ingredient (e.g. a dough ball or a bag of cheese), which has a quality.
var is_ingredient: bool = false

var _mirrored: bool = false
## True while shown with its turned art (see RotatedArt).
var _turned: bool = false
## Each sprite's art as drawn (before turning).
var _art: Dictionary[Sprite2D, Texture2D] = {}
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


## Its name: display_name if set, else its side item's or ingredient container's name.
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if side_item != null:
		return side_item.display_name
	if ingredient != null:
		return ingredient.display_name
	return "Item"


## Highlights it while it's selected.
func set_selected(selected: bool) -> void:
	modulate = Color(1.2, 1.2, 0.9) if selected else Color.WHITE


func set_texture(texture: Texture2D) -> void:
	_set_art(_sprite, texture)


## Drawn over everything, contents included. Pass null to take it off.
func set_lid(texture: Texture2D) -> void:
	_set_art(_lid, texture)


## Tints the item's own art (not its marks or contents), e.g. a pale or burnt pizza.
func set_tint(color: Color) -> void:
	_sprite.modulate = color


## Marks drawn over the item (e.g. cut lines). Pass null to clear.
func set_overlay(texture: Texture2D) -> void:
	_set_art(_overlay, texture)


## Art drawn under and over the item's contents (e.g. an open box), and where the
## contents sit relative to the item. Pass nulls to clear.
func set_wrap(
	under: Texture2D, over: Texture2D, contents_offset: Vector2 = Vector2.ZERO
) -> void:
	_set_art(_under, under)
	_set_art(_over, over)
	_contents.position = contents_offset


## Art drawn under the item only (e.g. the pizza screen it sits on in a rack). Pass null
## to take it off.
func set_under(texture: Texture2D) -> void:
	_set_art(_under, texture)


## Turns the item to face a pawn standing at `side` (a grid step from the item's cell), so
## its back (e.g. a box's lid) is away from them. Art is drawn facing a pawn down-right;
## for a pawn down-left it's mirrored. For a pawn behind it, its turned art is used (mirrored
## for up-right) if it has any; otherwise it's just mirrored as before.
func face_toward(side: Vector2i) -> void:
	var behind: bool = side.x < 0 or side.y < 0
	if behind and _has_turned_art():
		set_view(true, side.y != 0)
	else:
		set_view(false, side.y > 0 or side.x < 0)


## Mirrors the item, with its art as drawn (e.g. while carried).
func set_mirrored(mirrored: bool) -> void:
	set_view(false, mirrored)


## Shows the item with its turned art or not, mirrored or not. Its contents turn with it
## (e.g. boxes in a stack) and move to stay in the same place inside it.
func set_view(turned: bool, mirrored: bool) -> void:
	_turned = turned
	_mirrored = mirrored
	for sprite: Sprite2D in [_under, _sprite, _overlay, _over, _lid]:
		sprite.flip_h = mirrored
		_show_art(sprite)
	for item: Item in _content_offsets:
		item.set_view(turned, mirrored)
		_place_content(item)


func _set_art(sprite: Sprite2D, texture: Texture2D) -> void:
	_art[sprite] = texture
	_show_art(sprite)


func _show_art(sprite: Sprite2D) -> void:
	var texture: Texture2D = _art.get(sprite)
	if _turned and rotated_art != null:
		texture = rotated_art.get_turned(texture)
	sprite.texture = texture


func _has_turned_art() -> bool:
	if rotated_art == null:
		return false
	for texture: Texture2D in _art.values():
		if rotated_art.has_turned(texture):
			return true
	return false


## Puts `item` inside this one, between its under and over art, at `offset`. Items put in
## later draw in front.
func put_in(item: Item, offset: Vector2 = Vector2.ZERO) -> void:
	item.container = self
	item.reparent(_contents, false)
	_content_offsets[item] = offset
	item.set_view(_turned, _mirrored)
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


## Makes this a full container of `kind` (see PortionContainer).
func fill_portions(kind: PortionContainer) -> void:
	portions = kind
	portions_left = kind.portions
	set_texture(kind.texture)
	_show_portions()


## Takes `amount` portions out (no fewer than none left).
func use_portions(amount: int) -> void:
	portions_left = maxi(portions_left - amount, 0)
	_show_portions()


func _show_portions() -> void:
	set_under(portions.get_level_texture(portions_left))


## The outermost item this one is inside (or itself), which is what sits somewhere.
func get_outermost() -> Item:
	var item: Item = self
	while item.container != null:
		item = item.container
	return item
