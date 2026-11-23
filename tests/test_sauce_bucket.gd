extends "res://tests/test_base.gd"
## The prep table's sauce bucket: it's set out full in its side slot between the first two
## pizza spots (on whole pixels, and it comes along when the table turns). Each sauce step
## takes a portion and the sauce level shown drops; the one that empties it refills it
## (placeholder until it's washed).

const BUCKET := preload("res://resources/items/sauce_bucket.tres")

var _prep: Station
var _bucket: Item
var _phase: int = 0


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_prep = world.get_node("Entities/PrepTable")
	var buckets: Array[Item] = _prep.get_side_items()
	if buckets.size() != 1 or buckets[0].portions != BUCKET:
		fail("the prep table should start with one sauce bucket, has %d side items" % buckets.size())
		return
	_bucket = buckets[0]
	if _bucket.portions_left != BUCKET.portions or _bucket._under.texture != BUCKET.level_textures[0]:
		fail("the bucket doesn't start full")
		return
	if _prep._side_items[_bucket] != Rect2i(4, 6, 1, 1):
		fail("the bucket isn't in the slot between pizzas 1 and 2")
		return
	# Turned to each facing and back, it comes along and stays on whole pixels.
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	var start_facing: int = _prep.facing
	for facing: int in _prep.data.get_facings():
		_prep.facing = facing
		_prep.place(shop_floor)
		if _prep.get_side_items() != [_bucket] or _bucket.global_position != _bucket.global_position.round():
			fail("at facing %d the bucket wasn't carried along on whole pixels" % facing)
			return
	_prep.facing = start_facing
	_prep.place(shop_floor)
	order_pizzas(1)


func _step() -> void:
	match _phase:
		0:
			if _bucket.portions_left == BUCKET.portions - 1:
				# One portion from empty: the next sauce step empties it, and it refills.
				_bucket.use_portions(_bucket.portions_left - 1)
				if _bucket._under.texture != BUCKET.level_textures.back():
					fail("an almost empty bucket doesn't show the lowest level")
					return
				order_pizzas(1)
				_phase = 1
			elif _bucket.portions_left != BUCKET.portions:
				fail("a sauce step took %d portions, not 1" % (BUCKET.portions - _bucket.portions_left))
		1:
			if _bucket.portions_left == BUCKET.portions:
				if _bucket._under.texture != BUCKET.level_textures[0]:
					fail("the refilled bucket doesn't show full")
				else:
					pass_test("sauce taken a portion at a time; the emptied bucket refilled")
			elif _bucket.portions_left != 1:
				fail("bucket at %d portions after emptying" % _bucket.portions_left)
