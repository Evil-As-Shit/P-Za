extends "res://tests/test_base.gd"
## The camera pans in whole pixels and settles once panning stops, even when it stops on a
## half-pixel leftover (e.g. a one-pixel mouse drag at 2x zoom). It used to shake between
## two pixels every frame.

const SETTLE_FRAMES: int = 10

var _camera: ShopCamera
var _settled_at: Vector2
var _start_frame: int


func _start() -> void:
	_camera = world.get_node("ShopCamera")
	_camera.position = _camera.position.round()
	var start: Vector2 = _camera.position
	# Half-pixel moves, as a one-pixel drag at 2x zoom makes, in both directions.
	for amount: Vector2 in [Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(0.5, -0.5), Vector2(-0.5, -0.5)]:
		_camera._pan(amount)
	for i: int in 7:
		_camera._pan(Vector2(0.5, -0.5))
	_settled_at = _camera.position
	if _settled_at != _settled_at.round():
		fail("the camera moved off whole pixels to %s" % _settled_at)
		return
	if _settled_at.distance_to(start + Vector2(3.5, -3.5)) > 1.0:
		fail("panned to %s, expected about %s" % [_settled_at, start + Vector2(3.5, -3.5)])
		return
	_start_frame = frame


func _step() -> void:
	# No input now: each frame pans by nothing, and the camera must stay put.
	if _camera.position != _settled_at:
		fail("the camera moved from %s to %s with no input" % [_settled_at, _camera.position])
		return
	if frame - _start_frame >= SETTLE_FRAMES:
		pass_test("the camera stays still after half-pixel pans")
