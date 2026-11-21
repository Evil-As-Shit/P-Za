class_name RotatedArt
extends Resource
## Pairs item art with the same thing turned a quarter (e.g. a box with its lid on the
## other edge). Items worked from behind use the turned art, so it still faces away from
## the pawn; art with no pair is just mirrored.

## Art as drawn -> the same piece turned.
@export var pairs: Dictionary[Texture2D, Texture2D] = {}


func has_turned(texture: Texture2D) -> bool:
	return texture != null and pairs.has(texture)


## The turned version of `texture`, or `texture` itself if it has none.
func get_turned(texture: Texture2D) -> Texture2D:
	return pairs.get(texture, texture)
