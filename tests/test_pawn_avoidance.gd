extends "res://tests/test_base.gd"
## Two pawns walking head-on along the same row step aside and pass each other instead of
## overlapping, slow down while passing, and settle back to their paths once clear.

const PAWN_SCENE := preload("res://scenes/pawns/pawn.tscn")
const ROW: int = 4

var _a: Pawn
var _b: Pawn
var _arrived: int = 0
var _walk_frames: int = 0
var _expected_frames: float = 0.0
var _closest_drawn: float = INF
var _finished_frame: int = -1


func _start() -> void:
	stop_random_orders()
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	var entities: Node2D = world.get_node("Entities")
	var path_ab: PackedVector2Array = shop_floor.get_path_points(Vector2i(1, ROW), Vector2i(10, ROW))
	var path_ba: PackedVector2Array = shop_floor.get_path_points(Vector2i(10, ROW), Vector2i(1, ROW))
	if path_ab.size() < 2 or path_ba.size() < 2:
		fail("no path along row %d" % ROW)
		return
	_a = PAWN_SCENE.instantiate()
	_b = PAWN_SCENE.instantiate()
	for pawn: Pawn in [_a, _b]:
		entities.add_child(pawn)
		pawn.path_finished.connect(func() -> void: _arrived += 1)
	_a.global_position = path_ab[0]
	_b.global_position = path_ba[0]
	_a.follow_path(path_ab)
	_b.follow_path(path_ba)
	var length: float = 0.0
	for i: int in path_ab.size() - 1:
		length += path_ab[i].distance_to(path_ab[i + 1])
	_expected_frames = length / _a.move_speed * 60.0


func _step() -> void:
	if _a == null:
		return
	if _arrived < 2:
		_walk_frames += 1
		# Where they're drawn while they're really (nearly) in the same place.
		if Pawn._to_floor(_a.global_position - _b.global_position).length() < 8.0:
			var drawn_a: Vector2 = _a.global_position + _a.get_sidestep_offset()
			var drawn_b: Vector2 = _b.global_position + _b.get_sidestep_offset()
			_closest_drawn = minf(_closest_drawn, drawn_a.distance_to(drawn_b))
		return
	if _finished_frame < 0:
		_finished_frame = frame
		if _closest_drawn == INF:
			fail("the pawns never met")
			return
		if _closest_drawn < 6.0:
			fail("the pawns were drawn only %.1f px apart while passing" % _closest_drawn)
			return
		if _walk_frames < _expected_frames * 1.05:
			fail("passing didn't slow them down (%d frames, %d alone)" % [_walk_frames, _expected_frames])
			return
	# Once clear, they ease back onto their paths.
	if _a.get_sidestep_offset() == Vector2.ZERO and _b.get_sidestep_offset() == Vector2.ZERO:
		pass_test("passed %.1f px apart, %d frames instead of %d" % [_closest_drawn, _walk_frames, _expected_frames])
	elif frame - _finished_frame > 60:
		fail("the pawns stayed stepped aside after passing")
