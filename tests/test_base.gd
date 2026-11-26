extends SceneTree
## Shared setup for headless tests. Loads the shop, then calls _start() once it's ready and
## _step() every frame after. A test ends with pass_test() or fail(); run them all with
## tests/run_tests.ps1. The runner also fails a test that prints any engine error.

const WORLD_SCENE := "res://scenes/world/world.tscn"

## Frames before a test gives up (at the runner's 60 fps).
var timeout_frames: int = 60 * 600
## Off by default: every pawn is on shift all day, so tests about other things have the
## whole staff. Set it in _init() to keep the starting shop's shifts.
var keep_schedules: bool = false

var world: Node
var clock: ShopClock
var rack: TicketRack
var finances: ShopFinances
var work: WorkManager
var frame: int = 0

var _done: bool = false


func _initialize() -> void:
	world = (load(WORLD_SCENE) as PackedScene).instantiate()
	(world.get_node("Work") as WorkManager).phone_chance = 0.0
	if not keep_schedules:
		for node: Node in world.get_node("Entities").get_children():
			if node is Pawn:
				(node as Pawn).schedule = null
	root.add_child(world)


func _process(_delta: float) -> bool:
	if _done:
		return false
	frame += 1
	if frame == 2:
		clock = world.get_node("ShopClock")
		rack = world.get_node("TicketRack")
		finances = world.get_node("ShopFinances")
		work = world.get_node("Work")
		_even_out_skills()
		_start()
	elif frame > 2:
		_step()
	if not _done and frame > timeout_frames:
		fail("timed out after %d frames" % frame)
	return false


## Override: set the test up (the shop is ready).
func _start() -> void:
	pass


## Override: check progress each frame.
func _step() -> void:
	pass


## Starting skills and traits are random; tests start every pawn at the base level with no
## traits (base work times) so their timing doesn't vary from run to run.
func _even_out_skills() -> void:
	for pawn: Pawn in work.get_pawns():
		pawn.set_traits([])
		for work_type: WorkType in work.work_types:
			if work_type.has_skill:
				pawn.set_skill(work_type, pawn.skill_rules.base_level)


## Stops random orders, so the test controls what's ordered.
func stop_random_orders() -> void:
	(world.get_node("OrderSource") as Node).process_mode = Node.PROCESS_MODE_DISABLED


## Sends every pawn after the first `count` home for good (off all day, with no work), for
## tests whose setup needs room on the floor or a fixed number of pawns. Returns the pawns kept.
func keep_pawns(count: int) -> Array[Pawn]:
	var pawns: Array[Pawn] = work.get_pawns()
	for extra: Pawn in pawns.slice(count):
		extra.schedule = WorkSchedule.new()
		extra.priorities.clear()
		extra.set_away(true)
	return pawns.slice(0, count)


## Refills the box pallet's flat boxes whenever it runs out, standing in for deliveries in
## tests that make more pizzas than the starting shop has boxes for. Call from _step().
func keep_flat_boxes_stocked() -> void:
	var pallet: Station = world.get_node("Entities/BoxPallet")
	if pallet.get_stock() == 0:
		pallet.stock_up()


## The dough storage pawns take from and put back to first: the walk-in's first Dough shelf.
func dough_storage() -> Station:
	var dough: StorageKind = load("res://resources/storage_kinds/dough.tres")
	for station: Station in work.get_stations():
		if station.holds(dough):
			return station
	return null


## Takes `count` units of `kind` out of `station`'s storage, as if pawns had.
func take_units(station: Station, kind: StorageKind, count: int) -> void:
	for i: int in count:
		station.claim_supply(kind)
		station.take_supply(kind)


## Fills `station`'s storage with `kind` as far as it has room.
func fill_with(station: Station, kind: StorageKind) -> void:
	while station.has_room(kind):
		station.claim_room(kind)
		station.add_stock(kind)


## Makes the next unit of `kind` taken from `station` a partly used one with `left` in it.
func set_next_partial(station: Station, kind: StorageKind, left: int) -> void:
	var stack: StoredStack = station._find_taken_stack(kind, null)
	stack.lefts[-1] = left


## Units of every kind promised to pawns coming to take one from `station`.
func stock_claimed(station: Station) -> int:
	var total: int = 0
	for count: int in station._stock_claimed.values():
		total += count
	return total


## Places in `station`'s storage promised to pawns bringing a unit.
func room_claimed(station: Station) -> int:
	var total: int = 0
	for stack: StoredStack in station._stacks:
		total += stack.room_claimed
	return total


## Prints an order of `count` pizzas (straight into Make) and returns its ticket.
func order_pizzas(count: int) -> Ticket:
	var recipes: Array[Recipe] = []
	for i: int in count:
		recipes.append(world.debug_recipe)
	world._print_ticket(recipes)
	var make: Array[Ticket] = rack.get_tickets(Ticket.Section.MAKE)
	return make[make.size() - 1]


func pass_test(message: String = "") -> void:
	if _done:
		return
	_done = true
	print("PASS %s" % message)
	quit(0)


func fail(message: String) -> void:
	if _done:
		return
	_done = true
	print("FAIL %s" % message)
	quit(1)
