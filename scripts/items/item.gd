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

@onready var _under: Sprite2D = $Under
@onready var _sprite: Sprite2D = $Sprite
@onready var _contents: Node2D = $Contents
@onready var _over: Sprite2D = $Over


func set_texture(texture: Texture2D) -> void:
	_sprite.texture = texture


## Art drawn under and over the item's contents (e.g. an open box). Pass nulls to clear.
func set_wrap(under: Texture2D, over: Texture2D) -> void:
	_under.texture = under
	_over.texture = over


## Item art is drawn with its front facing down-right (a box's fold and lid are at the
## back, up-left). Mirrored, it faces down-left. Only flips the item's own art, not its
## contents.
func set_mirrored(mirrored: bool) -> void:
	for sprite: Sprite2D in [_under, _sprite, _over]:
		sprite.flip_h = mirrored


## Puts `item` inside this one, between its under and over art.
func put_in(item: Item) -> void:
	item.container = self
	item.reparent(_contents, false)
	item.position = Vector2.ZERO


## The outermost item this one is inside (or itself), which is what sits somewhere.
func get_outermost() -> Item:
	var item: Item = self
	while item.container != null:
		item = item.container
	return item
