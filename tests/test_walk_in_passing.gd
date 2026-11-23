extends "res://tests/test_base.gd"
## Two pawns passing each other right along the walk-in's back wall step aside away from
## the wall, never into it, and each is drawn (and sorted) where it's stepped to.

const PAWN_SCENE := preload("res://scenes/pawns/pawn.tscn")
## The row just behind the starting walk-in's back-right wall.
const ROW: int = 7
const FROM_X: int = 6
const TO_X: int = 11

var _floor: ShopFloor
var _a: Pawn
var _b: Pawn
var _arrived: int = 0
var _stepped_aside: bool = false


func _start() -> void:
	stop_random_orders()
	_floor = world.get_node("ShopFloor")
	var entities: Node2D = world.get_node("Entities")
	# The shop's own pawns out of the way.
	for pawn: Pawn in work.get_pawns():
		pawn.process_mode = Node.PROCESS_MODE_DISABLED
		pawn.global_position = _floor.cell_to_global(Vector2i(0, 0))
	_a = PAWN_SCENE.instantiate()
	_b = PAWN_SCENE.instantiate()
	for pawn: Pawn in [_a, _b]:
		entities.add_child(pawn)
		pawn.shop_floor = _floor
		pawn.path_finished.connect(func() -> void: _arrived += 1)
	var path_ab: PackedVector2Array = _floor.get_path_points(Vector2i(FROM_X, ROW), Vector2i(TO_X, ROW))
	var path_ba: PackedVector2Array = _floor.get_path_points(Vector2i(TO_X, ROW), Vector2i(FROM_X, ROW))
	_a.global_position = path_ab[0]
	_b.global_position = path_ba[0]
	_a.follow_path(path_ab)
	_b.follow_path(path_ba)


func _step() -> void:
	if _a == null:
		return
	for pawn: Pawn in [_a, _b]:
		var offset: Vector2 = pawn.get_sidestep_offset()
		if offset == Vector2.ZERO:
			continue
		_stepped_aside = true
		var here: Vector2i = _floor.global_to_cell(pawn.global_position)
		var toward: Vector2i = _floor.global_to_cell(pawn.global_position + offset * Pawn.SIDESTEP_REACH)
		if toward != here and (_floor.is_edge_blocked(here, toward) or not _floor.is_walkable(toward)):
			fail("a pawn at %s stepped aside into the wall toward %s" % [here, toward])
			return
		var body: Node2D = pawn.get_node("Body")
		if not body.global_position.is_equal_approx(pawn.global_position + offset):
			fail("a pawn's drawing isn't where it stepped aside to")
			return
	if _arrived < 2:
		return
	if not _stepped_aside:
		fail("the pawns never stepped aside")
		return
	pass_test("passed along the walk-in's wall, stepping away from it")
