class_name Item
extends Node2D
## A 1×1 object that sits on a station, on the floor, or in a pawn's hands (e.g. a pizza).
## Its node position is the center of its floor cell, or the surface it rests on.

## Station it's sitting on, or null when carried or on the floor.
var station: Station = null

@onready var _under: Sprite2D = $Under
@onready var _sprite: Sprite2D = $Sprite
@onready var _over: Sprite2D = $Over


func set_texture(texture: Texture2D) -> void:
	_sprite.texture = texture


## Art drawn under and over the item (e.g. an open box). Pass nulls to clear.
func set_wrap(under: Texture2D, over: Texture2D) -> void:
	_under.texture = under
	_over.texture = over
