class_name Item
extends Node2D
## A 1×1 object that sits on a station, on the floor, or in a pawn's hands (e.g. a pizza).
## Its node position is the center of its floor cell, or the surface it rests on.

## Station it's sitting on, or null when carried or on the floor.
var station: Station = null

@onready var _sprite: Sprite2D = $Sprite


func set_texture(texture: Texture2D) -> void:
	_sprite.texture = texture
