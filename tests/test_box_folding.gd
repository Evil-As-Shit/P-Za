extends "res://tests/test_base.gd"
## Boxes arrive flat on the pallet. Idle Box folding pawns fold them standing at the pallet and
## carry each one to box storage (which starts empty) as part of the same Fold box job, one
## pawn at a time; Boxing tables stay free. With no folded boxes to be had, a pawn setting
## out a box folds a flat one on the spot, which takes longer.

var _rack: Station
var _pallet: Station
var _boxing_role: StationRole = preload("res://resources/station_roles/boxing.tres")
var _saw_fold_at_pallet: bool = false
var _saw_put_away: bool = false
## Each fold job seen, and the pawn who folded for it.
var _folders: Dictionary[Job, Pawn] = {}
var _phase: int = 0
var _ticket: Ticket
var _saw_fold_on_demand: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_rack = world.get_node("Entities/BoxRack")
	_pallet = world.get_node("Entities/BoxPallet")
	if _rack.get_stock() != 0:
		fail("box storage should start empty, has %d" % _rack.get_stock())
		return
	if _pallet.get_stock() == 0:
		fail("the pallet should start with flat boxes")
		return


func _step() -> void:
	var folding: int = 0
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null:
			continue
		if job.task_type.id == &"fold_box":
			folding += 1
			if job.part == FoldBehavior.Part.FOLD:
				if job.station == _pallet:
					_saw_fold_at_pallet = true
				_folders[job] = pawn
			elif job.part == FoldBehavior.Part.PUT_AWAY:
				_saw_put_away = true
				if job.station != _rack:
					fail("a folded box was carried somewhere other than the box rack")
					return
				if _folders.get(job) != pawn:
					fail("%s put away a box someone else folded" % pawn.display_name)
					return
		if job.task_type.id == &"set_out_box" and job.extra_minutes > 0.0:
			_saw_fold_on_demand = true
	if folding > 1:
		fail("%d pawns were folding boxes at once" % folding)
		return
	if _phase == 0:
		# No folded box is set down, and none becomes a separate put-away job.
		for child: Node in world.get_node("Entities").get_children():
			if child is Item:
				fail("a folded box was set down instead of taken to the rack")
				return
		for job: Job in work.get_shop_jobs():
			if job.task_type.id == &"put_away_box":
				fail("putting a folded box away became a separate job")
				return
		for station: Station in work.get_stations():
			if station.role == _boxing_role:
				for spot: int in station.get_spot_count():
					if station.get_item(spot) != null or station.is_reserved(spot):
						fail("folding ahead used a Boxing table spot")
						return
	match _phase:
		0:
			# Folding ahead: box storage fills up from the pallet.
			if _rack.get_stock() < 16:
				return
			if not _saw_fold_at_pallet or not _saw_put_away:
				fail("boxes were stored without being folded at the pallet and carried over")
				return
			_phase = 1
		1:
			# Take box storage away: no folded boxes anywhere.
			if not _rack.is_idle():
				return
			world._on_role_change_requested(_rack, null)
			_ticket = order_pizzas(1)
			rack.ticket_completed.connect(_on_completed)
			_phase = 2


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if not _saw_fold_on_demand:
		fail("the pizza was boxed without folding a flat box on demand")
		return
	pass_test("%d boxes folded and carried to the rack one at a time; folded on demand with none stored" % _folders.size())
