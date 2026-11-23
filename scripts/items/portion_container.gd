class_name PortionContainer
extends SideItem
## A container a task takes portions from in place (e.g. the sauce bucket on the prep
## table): it sits on a station's side area and shows how full it is. Its texture is the
## container, drawn over its contents. An empty one is swapped for a full one from storage
## and washed (see PortionBehavior).

## Contents at each level, fullest first, drawn under the container. The level shown drops
## evenly as portions are used; nothing is shown once it's empty.
@export var level_textures: Array[Texture2D] = []
## Portions in a full one (placeholder).
@export var portions: int = 20
## Storage kind for full ones (e.g. Sauce, the prep table's cooler).
@export var full_kind: StorageKind
## Storage kind for empty ones (e.g. Empty Dishes), the overflow while no dish sink has room.
@export var empty_kind: StorageKind
## An empty one as a dish: washed at a dish sink, then put away full again.
@export var dish: Dish


func set_up(item: Item) -> void:
	item.side_item = self
	item.fill_portions(self)


## Makes a new one, full or empty, where `work` keeps loose items.
func spawn(work: WorkManager, full: bool) -> Item:
	var item: Item = work.spawn_item(null)
	set_up(item)
	if not full:
		item.use_portions(portions)
	return item


## Contents art for `left` portions, or null when empty.
func get_level_texture(left: int) -> Texture2D:
	if left <= 0 or level_textures.is_empty():
		return null
	var levels: int = level_textures.size()
	var index: int = levels - ceili(float(left) * levels / portions)
	return level_textures[clampi(index, 0, levels - 1)]
