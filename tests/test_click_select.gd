extends "res://tests/test_base.gd"
## Clicking selects by pixel: an opaque pixel of a pawn, item or station selects it, and a
## see-through pixel inside its art's rect doesn't. Clicking an item shows its name and
## quality: a pizza being made its tier so far, then its final tier; a dough container the
## ingredients' quality and what's left. Set up off the floor, away from everything else.

const STATION_SCENE := preload("res://scenes/stations/station.tscn")
const TABLE := preload("res://resources/stations/long_table.tres")
const DOUGH := preload("res://resources/items/dough_container.tres")

var _hud: Hud
var _panel: ItemPanel


func _start() -> void:
	stop_random_orders()
	_hud = world.get_node("Hud")
	_panel = _hud.get_node("ItemPanel")
	var entities: Node2D = world.get_node("Entities")
	var shop_floor: ShopFloor = world.get_node("ShopFloor")

	# A pawn: an opaque pixel selects them, a clear one in their frame doesn't.
	var pawn: Pawn = work.get_pawns()[0]
	pawn.process_mode = Node.PROCESS_MODE_DISABLED
	pawn.global_position = Vector2(-4000.0, -4000.0)
	var pawn_sprite: AnimatedSprite2D = pawn.get_node("Body/Sprite")
	if not _select_opaque(pawn_sprite, [], pawn) or not _click_clear(pawn_sprite, []):
		return
	if _hud.get_shown_pawn() != null:
		fail("clicking a clear pixel in the pawn's frame kept them selected")
		return

	# A table off the floor, with a pizza on it for a ticket waiting on the rack.
	var table := STATION_SCENE.instantiate() as Station
	table.data = TABLE
	table.cell = Vector2i(-60, -60)
	entities.add_child(table)
	table.place(shop_floor)
	var ticket: Ticket = rack.print_ticket([world.debug_recipe])
	var order_item: OrderItem = ticket.order_items[0]
	var pizza: Item = work.spawn_item(world.debug_recipe.get_stage_texture(1))
	order_item.item = pizza
	table.put_item(0, pizza)
	var pizza_sprite: Sprite2D = pizza.get_node("Sprite")
	if not _select_opaque(pizza_sprite, [table.get_node("Canvas/Layers/Cover")], pizza):
		return
	if _hud.get_shown_item() != pizza or _hud.get_shown_station() != null:
		fail("clicking the pizza didn't show it (and only it) in the item panel")
		return
	_panel._show_details()
	if not _panel._details.text.contains("Quality so far:"):
		fail("a pizza being made shows '%s', expected its quality so far" % _panel._details.text)
		return
	order_item.quality_tier = QualityRules.Tier.GREAT
	_panel._show_details()
	if not _panel._details.text.contains("Quality: Great"):
		fail("a finished Great pizza shows '%s'" % _panel._details.text)
		return

	# The table's own art (not under the pizza) selects the table; clear pixels don't.
	var table_sprite: Sprite2D = table.get_node("Canvas/Layers/Sprite")
	var table_cover: Sprite2D = table.get_node("Canvas/Layers/Cover")
	if not _select_opaque(table_sprite, [pizza_sprite], table):
		return
	if _hud.get_shown_station() != table or _hud.get_shown_item() != null:
		fail("clicking the table's art didn't select the table (and only it)")
		return
	if not _click_clear(table_sprite, [pizza_sprite, table_cover]):
		return
	if _hud.get_shown_station() != null:
		fail("clicking a clear pixel in the table's art rect kept it selected")
		return

	# A dough container on the floor: its quality is the ingredients', and what's left.
	var tub: Item = IngredientBehavior.spawn_container(DOUGH, work)
	tub.global_position = Vector2(-3000.0, -3000.0)
	if not _select_opaque(tub.get_node("Lid"), [], tub):
		return
	_panel._show_details()
	if _hud.get_shown_item() != tub or not _panel._details.text.contains("Quality:") \
			or not _panel._details.text.contains("left"):
		fail("the dough container shows '%s'" % _panel._details.text)
		return
	pass_test("clicks select by pixel; items show their quality")


## Clicks an opaque pixel of `sprite` (clear on every cover). Fails unless `expected` is
## then selected.
func _select_opaque(sprite: CanvasItem, covers: Array, expected: Node) -> bool:
	var point: Variant = _find_pixel(sprite, covers, true)
	if point == null:
		fail("found no opaque pixel on %s" % sprite.name)
		return false
	world._select_at(point)
	if world._selected_item != expected and world._selected_station != expected \
			and _hud.get_shown_pawn() != expected:
		fail("clicking an opaque pixel of %s didn't select %s" % [sprite.name, expected.name])
		return false
	return true


## Clicks a see-through pixel inside `sprite`'s rect (clear on every cover too).
func _click_clear(sprite: CanvasItem, covers: Array) -> bool:
	var point: Variant = _find_pixel(sprite, covers, false)
	if point == null:
		fail("found no clear pixel in %s's rect" % sprite.name)
		return false
	world._select_at(point)
	return true


## A global point on a pixel of `sprite` that's opaque (or clear), and clear on every cover.
func _find_pixel(sprite: CanvasItem, covers: Array, opaque: bool) -> Variant:
	var rect: Rect2
	if sprite is Sprite2D:
		rect = (sprite as Sprite2D).get_rect()
	else:
		var animated := sprite as AnimatedSprite2D
		var size: Vector2 = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame).get_size()
		rect = Rect2(animated.offset - (size / 2.0).floor(), size)
	var to_global: Transform2D = (sprite as Node2D).global_transform
	for y: int in int(rect.size.y):
		for x: int in int(rect.size.x):
			var point: Vector2 = to_global * (rect.position + Vector2(x, y) + Vector2(0.5, 0.5))
			if PixelPick.is_opaque_at(sprite, point) != opaque:
				continue
			if covers.any(func(cover: CanvasItem) -> bool: return PixelPick.is_opaque_at(cover, point)):
				continue
			return point
	return null
