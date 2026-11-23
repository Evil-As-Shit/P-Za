extends SceneTree
## Shared setup for headless tests. Loads the shop, then calls _start() once it's ready and
## _step() every frame after. A test ends with pass_test() or fail(); run them all with
## tests/run_tests.ps1. The runner also fails a test that prints any engine error.

const WORLD_SCENE := "res://scenes/world/world.tscn"

## Frames before a test gives up (at the runner's 60 fps).
var timeout_frames: int = 60 * 600

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


## Starting skills are random; tests start every pawn at the base level (base work times)
## so their timing doesn't vary from run to run.
func _even_out_skills() -> void:
	for pawn: Pawn in work.get_pawns():
		for work_type: WorkType in work.work_types:
			if work_type.has_skill:
				pawn.set_skill(work_type, pawn.skill_rules.base_level)


## Stops random orders, so the test controls what's ordered.
func stop_random_orders() -> void:
	(world.get_node("OrderSource") as Node).process_mode = Node.PROCESS_MODE_DISABLED


## The dough storage pawns take from and put back to first: the walk-in's first Dough shelf.
func dough_storage() -> Station:
	var dough: StorageKind = load("res://resources/storage_kinds/dough.tres")
	for station: Station in work.get_stations():
		if station.get_stored_kind() == dough:
			return station
	return null


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
