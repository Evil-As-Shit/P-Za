class_name PixelPick
extends RefCounted
## Finds what's drawn at a point, pixel by pixel: the front-most sprite with an opaque pixel
## there, so a click lands on what the player sees and never on the empty space around art.
## Follows Godot's draw order: a y-sorted node draws its children (and, through y-sorted
## children, theirs) by y, then tree order; other nodes draw in tree order, children over
## their parent. Only z_index 0 is searched (overlays like work spot markers are skipped).

## Set on a sprite that shows another node's drawing (a station's strip of its canvas) to
## that node: it's searched instead, within the sprite's rect.
const SOURCE_META: StringName = &"pick_source"
## Pixels at least this opaque count as hits.
const MIN_ALPHA: float = 0.1

## Images of textures checked so far (for animated sprites), by texture.
static var _images: Dictionary[Texture2D, Image] = {}


## The front-most opaque sprite drawn at `point` (global) under `root`, or null.
static func find(root: Node, point: Vector2) -> CanvasItem:
	for entry: Array in _front_to_back(root):
		var hit: CanvasItem = _hit(entry[0], point, entry[1])
		if hit != null:
			return hit
	return null


## True if the sprite (Sprite2D or AnimatedSprite2D) has an opaque pixel at `point` (global).
static func is_opaque_at(item: CanvasItem, point: Vector2) -> bool:
	if item is Sprite2D:
		var sprite := item as Sprite2D
		return sprite.texture != null and sprite.is_pixel_opaque(sprite.to_local(point))
	if item is AnimatedSprite2D:
		return _animated_opaque_at(item as AnimatedSprite2D, point)
	return false


## The front-most hit in `item` (itself, or its children unless `self_only`), or null.
static func _hit(item: CanvasItem, point: Vector2, self_only: bool) -> CanvasItem:
	if item.has_meta(SOURCE_META):
		var shown := item as Sprite2D
		if shown != null and shown.get_rect().has_point(shown.to_local(point)):
			return find(item.get_meta(SOURCE_META) as Node, point)
		return null
	if not self_only:
		var hit: CanvasItem = find(item, point)
		if hit != null:
			return hit
	return item if is_opaque_at(item, point) else null


## The node's drawn children, front first, each as [item, self_only]. Under a y-sorted node,
## y-sorted children's children are sorted in with them (and they're checked self only).
static func _front_to_back(node: Node) -> Array[Array]:
	var entries: Array[Array] = []
	var y_sorted: bool = node is CanvasItem and (node as CanvasItem).y_sort_enabled
	if not y_sorted:
		for index: int in range(node.get_child_count() - 1, -1, -1):
			var child := node.get_child(index) as CanvasItem
			if _is_drawn(child):
				entries.append([child, false])
		return entries
	var sorted: Array[Array] = []
	_gather_sorted(node, sorted)
	# Front first: lower on screen, then later in the tree.
	sorted.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1])
	)
	for each: Array in sorted:
		entries.append([each[2], each[3]])
	return entries


## Appends [y, order, item, self_only] for each child of a y-sorted node, recursing into
## y-sorted children.
static func _gather_sorted(node: Node, out: Array[Array]) -> void:
	for child_node: Node in node.get_children():
		var child := child_node as CanvasItem
		if not _is_drawn(child):
			continue
		var y: float = (child as Node2D).global_position.y if child is Node2D else 0.0
		out.append([y, out.size(), child, child.y_sort_enabled])
		if child.y_sort_enabled:
			_gather_sorted(child, out)


static func _is_drawn(item: CanvasItem) -> bool:
	return item != null and item.visible and item.z_index == 0 and not item.show_behind_parent


static func _animated_opaque_at(sprite: AnimatedSprite2D, point: Vector2) -> bool:
	if sprite.sprite_frames == null:
		return false
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return false
	var size: Vector2 = texture.get_size()
	var local: Vector2 = sprite.to_local(point) - sprite.offset
	if sprite.centered:
		local += (size / 2.0).floor()
	if not Rect2(Vector2.ZERO, size).has_point(local):
		return false
	var pixel := Vector2i(local.floor())
	if sprite.flip_h:
		pixel.x = int(size.x) - 1 - pixel.x
	if sprite.flip_v:
		pixel.y = int(size.y) - 1 - pixel.y
	var image: Image = _get_image(texture)
	return image != null and image.get_pixelv(pixel).a >= MIN_ALPHA


static func _get_image(texture: Texture2D) -> Image:
	if not _images.has(texture):
		var image: Image = texture.get_image()
		if image != null and image.is_compressed():
			image = image.duplicate() as Image
			image.decompress()
		_images[texture] = image
	return _images[texture]
