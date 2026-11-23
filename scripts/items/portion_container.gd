class_name PortionContainer
extends Resource
## A container a task takes portions from in place (e.g. the sauce bucket on the prep
## table): it sits on a station's side area and shows how full it is.

@export var display_name: String
## Container art, drawn over its contents, in the item frame layout.
@export var container_texture: Texture2D
## Contents at each level, fullest first, drawn under the container. The level shown drops
## evenly as portions are used; nothing is shown once it's empty.
@export var level_textures: Array[Texture2D] = []
## Portions in a full one (placeholder).
@export var portions: int = 20
## Surface slots it takes (see SlotGrid).
@export var slot_size: Vector2i = Vector2i.ONE


## Contents art for `left` portions, or null when empty.
func get_level_texture(left: int) -> Texture2D:
	if left <= 0 or level_textures.is_empty():
		return null
	var levels: int = level_textures.size()
	var index: int = levels - ceili(float(left) * levels / portions)
	return level_textures[clampi(index, 0, levels - 1)]
