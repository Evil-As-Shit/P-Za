extends "res://tests/test_base.gd"
## The prep table's sauce bucket: it's set out full in its side slot between the first two
## pizza spots (on whole pixels, and it comes along when the table turns), with one spare in
## the table's hidden cooler. Each sauce step takes a portion and the sauce level shown drops.
## 1. An empty bucket is swapped before saucing: the empty goes to the dish sink, the spare
##    comes out of the cooler into the side slot, and the washed one goes back to the cooler.
## 2. With the sink's dirty board full, the empty goes to Empty Dishes storage instead, and
##    is brought to the sink once there's room, washed and put back in the cooler.

const BUCKET := preload("res://resources/items/sauce_bucket.tres")
const SLOT := Rect2i(7, 11, 2, 2)

var _prep: Station
var _boards: DishBoards
var _empties: Station
var _bucket: Item
var _phase: int = 0
var _tickets_done: int = 0


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	rack.ticket_completed.connect(func(_t: Ticket) -> void: _tickets_done += 1)
	_prep = world.get_node("Entities/PrepTable")
	_boards = world.get_node("Entities/DishSink").get_dish_boards()
	_empties = world.get_node("Entities/EmptyDishesTable")
	var buckets: Array[Item] = _prep.get_side_items()
	if buckets.size() != 1 or buckets[0].portions != BUCKET:
		fail("the prep table should start with one sauce bucket, has %d side items" % buckets.size())
		return
	_bucket = buckets[0]
	if _bucket.portions_left != BUCKET.portions or _bucket._under.texture != BUCKET.level_textures[0]:
		fail("the bucket doesn't start full")
		return
	if _prep._side_items[_bucket] != SLOT:
		fail("the bucket isn't in the slot between pizzas 1 and 2")
		return
	if not _prep.holds(BUCKET.full_kind) or _prep.get_stock() != 1:
		fail("the cooler should hold 1 spare bucket, holds %d" % _prep.get_stock())
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
	# Used up: the next pizza swaps it.
	_bucket.use_portions(BUCKET.portions)
	if _bucket._under.texture != null:
		fail("an empty bucket still shows sauce")
		return
	order_pizzas(1)


func _step() -> void:
	match _phase:
		0:
			if _tickets_done < 1:
				return
			var current: Item = _current_bucket()
			if current == null or current == _bucket:
				fail("the empty bucket wasn't swapped")
			elif current.portions_left != BUCKET.portions - 1:
				fail("the swapped-in bucket has %d portions, not %d" % [current.portions_left, BUCKET.portions - 1])
			elif _prep._side_items[current] != SLOT:
				fail("the swapped-in bucket isn't in the side slot")
			elif is_instance_valid(_bucket):
				fail("the empty bucket is still around")
			else:
				_phase = 1
		1:
			if _all_back():
				# Fill the sink's dirty board, then empty the bucket again.
				_boards._dirty_room_claimed += BUCKET.portions
				_bucket = _current_bucket()
				_bucket.use_portions(BUCKET.portions)
				order_pizzas(1)
				_phase = 2
		2:
			if _empties.get_stock() == 1 and _empties.get_top_dish(BUCKET.empty_kind) == BUCKET.dish:
				_boards._dirty_room_claimed -= BUCKET.portions
				work.assign_all()
				_phase = 3
			elif _tickets_done >= 2:
				fail("the empty didn't go to Empty Dishes storage while the sink was full")
		3:
			if _tickets_done >= 2 and _all_back() and _empties.get_stock() == 0:
				pass_test("empty bucket swapped from the cooler, washed and put back, also via Empty Dishes")


func _current_bucket() -> Item:
	for item: Item in _prep.get_side_items():
		if item.portions == BUCKET:
			return item
	return null


## The spare is back in the cooler and nothing's waiting at the sink.
func _all_back() -> bool:
	return (
		_prep.get_stock() == 1 and _boards.get_dirty_count() == 0
		and _boards.get_clean_count() == 0
	)
