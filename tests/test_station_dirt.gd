extends "res://tests/test_base.gd"
## Station dirt:
## 1. Making a pizza dirties the prep table it was made at, and tints its art.
## 2. A station dirty enough is wiped down clean by a Cleaning pawn at one of its spots, with
##    work time set by how dirty it was; one below the threshold is left alone.

var _prep: Station
var _filthy: Station
var _light: Station
var _wipe_job: Job = null
var _worked_at_spot: bool = false
var _ticket_done: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_prep = world.get_node("Entities/PrepTable")
	_filthy = world.get_node("Entities/BoxingTable3")
	_light = world.get_node("Entities/PizzaRack")
	_filthy.add_dirt(1.0)
	_light.add_dirt(0.3)
	if _filthy._sprite.self_modulate == Color.WHITE:
		fail("a filthy station isn't tinted")
		return
	rack.ticket_completed.connect(func(_t: Ticket) -> void: _ticket_done = true)
	order_pizzas(1)


func _step() -> void:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null or job.task_type.id != &"wipe_station":
			continue
		if job.destination == _light:
			fail("wiped a station below the threshold")
			return
		if job.destination == _filthy:
			_wipe_job = job
			if pawn.is_working() and job.station == _filthy and job.spot >= 0:
				_worked_at_spot = true
	if not _ticket_done or _wipe_job == null or _filthy.get_dirt() > 0.0:
		return
	if not _worked_at_spot:
		fail("the station was cleaned without a pawn working at it")
	elif not is_equal_approx(_wipe_job.extra_minutes, 0.5):
		fail("wiping a filthy station took %.2f minutes, not 0.5" % _wipe_job.extra_minutes)
	elif _filthy._sprite.self_modulate != Color.WHITE:
		fail("a wiped station is still tinted")
	elif _prep.get_dirt() <= 0.0:
		fail("making a pizza didn't dirty the prep table")
	else:
		pass_test("a pizza dirtied the prep table; a filthy station was wiped, a light one left")
