extends "res://tests/test_base.gd"
## Playtest: runs the real starting shop (random skills, traits, phone breaks) for several
## days at top speed and prints each day's numbers, plus stock every two hours. Not part of
## the test suite (run_tests.ps1 only runs test_*.gd). Run it with:
##   godot --headless --path . --fixed-fps 60 --script res://tests/playtest.gd -- days=5
## Options after "--": days=N, speed=N (shop speed, default 24).

var _days: int = 5
var _speed: int = 24
var _placed: int = 0
var _pizzas_placed: int = 0
var _turned_away: int = 0
var _cancelled: int = 0
var _taken: int = 0
var _report_frame: int = -1
var _last_logged_hour: int = -1
var _deliveries: Deliveries
var _lobby: Lobby
var _open_stock: Dictionary[String, int] = {}
var _totals := {"served": 0, "missed": 0, "profit": 0.0}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=")
		if parts.size() == 2 and parts[0] == "days":
			_days = int(parts[1])
		elif parts.size() == 2 and parts[0] == "speed":
			_speed = int(parts[1])
	world = (load(WORLD_SCENE) as PackedScene).instantiate()
	# Counted before the world handles it, so a full line can be told apart.
	(world.get_node("OrderSource") as OrderSource).order_placed.connect(_on_order_placed)
	root.add_child(world)


## Real starting staff: keep their rolled skills and traits.
func _even_out_skills() -> void:
	pass


func _start() -> void:
	timeout_frames = 60 * 60 * 60 * 4
	_deliveries = world.get_node("Deliveries")
	_lobby = world.get_node("Lobby")
	if not clock.speeds.has(_speed):
		clock.speeds.append(_speed)
	clock.set_speed(_speed)
	rack.ticket_cancelled.connect(func(_t: Ticket) -> void: _cancelled += 1)
	work.order_taken.connect(func(_j: Job) -> void: _taken += 1)
	clock.day_started.connect(func(_day: int) -> void: _report_frame = frame)
	for pawn: Pawn in work.get_pawns():
		var traits: Array[String] = []
		for t: PawnTrait in pawn.traits:
			traits.append(t.display_name)
		print("  %s%s traits %s" % [pawn.name, " (manager)" if pawn.is_manager else "", ", ".join(traits)])
	_snapshot_open()
	print("Day 1 (%s) opens: %s" % [ShopClock.get_weekday_name(1), _stock_text()])


func _on_order_placed(recipes: Array[Recipe]) -> void:
	_placed += 1
	_pizzas_placed += recipes.size()
	if not _lobby.has_room_in_line():
		_turned_away += 1


## Activity -> shop minutes the staff spent on it today.
var _activity: Dictionary[String, float] = {}
var _last_minutes: float = -1.0


func _tally_activity() -> void:
	var now: float = clock.get_open_minutes()
	var dt: float = now - _last_minutes if _last_minutes >= 0.0 else 0.0
	_last_minutes = now
	if dt <= 0.0 or dt > 5.0:
		return
	for pawn: Pawn in work.get_pawns():
		var key: String = "idle"
		if pawn.is_away():
			key = "off shift"
		elif not pawn.on_shift and pawn.is_walking():
			key = "going home"
		elif pawn.is_on_breakdown():
			key = "breakdown"
		elif pawn.is_resting():
			key = "break"
		elif pawn.has_job():
			var job: Job = pawn.get_job()
			key = String(job.task_type.id) if job.task_type != null else "job?"
			if pawn.is_working():
				key += ":work"
			elif pawn._state == Pawn.State.WAITING_AT_STOP:
				key += ":wait"
			else:
				key += ":walk"
		elif pawn._on_phone:
			key = "phone"
		elif pawn.is_walking():
			key = "wander"
		if key in ["idle", "wander", "phone"] and _open_tickets() > 0:
			key = "%s %s while tickets open" % [pawn.name, key]
			if OS.get_cmdline_user_args().has("why") and int(now) % 15 == 0 and int(now) != _idle_snapshots:
				_idle_snapshots = int(now)
				print("    %s %s idle (%s): %s | %s" % [
					ShopClock.format_time(clock.get_minute_of_day()), pawn.name, key, _steps_text(), _prep_text()
				])
		_activity[key] = _activity.get(key, 0.0) + dt


## What each open order's pizzas are on: "<step>" (claimed by a pawn) or "<step>?" (nobody).
func _steps_text() -> String:
	var tally: Dictionary[String, int] = {}
	for ticket: Ticket in rack.get_tickets(Ticket.Section.MAKE):
		if ticket.ready:
			continue
		for job: Job in ticket.get_active_jobs():
			var key: String = String(job.task_type.id) + ("" if job.claimed_by != null else "?")
			tally[key] = tally.get(key, 0) + 1
	return str(tally)


var _idle_snapshots: int = 0


## The prep table's spots, cheese left, and shop jobs under way.
func _prep_text() -> String:
	var parts: Array[String] = []
	var prep: Station = world.get_node("Entities/PrepTable")
	for spot: int in prep.get_spot_count():
		var item: Item = prep.get_item(spot)
		parts.append(item.name if item != null else "-")
	var pan: IngredientPan = load("res://resources/items/cheese_pan.tres")
	parts.append("cheese %d" % prep.get_pan_left(pan))
	for oven: String in ["PizzaOven", "PizzaOven2", "PizzaRack"]:
		var station: Station = world.get_node("Entities/" + oven)
		var used: int = 0
		for spot: int in station.get_spot_count():
			if station.get_item(spot) != null:
				used += 1
		parts.append("%s %d/%d" % [oven, used, station.get_spot_count()])
	var jobs: Array[String] = []
	for job: Job in work.get_shop_jobs():
		jobs.append(String(job.task_type.id) + ("" if job.claimed_by != null else "?"))
	parts.append("shop jobs %s" % [jobs])
	return " ".join(parts)


## Tickets on the rack that aren't ready yet.
func _open_tickets() -> int:
	var count: int = 0
	for section: Ticket.Section in [Ticket.Section.WAIT, Ticket.Section.MAKE]:
		for ticket: Ticket in rack.get_tickets(section):
			if not ticket.ready:
				count += 1
	return count


func _activity_text() -> String:
	var keys: Array = _activity.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _activity[a] > _activity[b])
	var parts: Array[String] = []
	for key: String in keys:
		parts.append("%s %d" % [key, int(_activity[key])])
	return ", ".join(parts)


## Bake -> [done_at, minute it was first claimed or -1].
var _watched_bakes: Dictionary = {}
## Shop minutes after done each pizza came out, and after done its take-out was claimed.
var _pulled_after: Array[float] = []
var _claimed_after: Array[float] = []


func _watch_bakes() -> void:
	var now: float = work._now
	var minute: float = ShopClock.minutes_to_seconds(1.0)
	var live: Dictionary = {}
	for bake: Variant in work._bakes:
		live[bake] = true
		if not _watched_bakes.has(bake):
			_watched_bakes[bake] = [bake.done_at, -1.0]
		var entry: Array = _watched_bakes[bake]
		if entry[1] < 0.0 and is_instance_valid(bake.item) and work._waiting_for.has(bake.item):
			entry[1] = now
	for bake: Variant in _watched_bakes.keys():
		if not live.has(bake):
			var entry: Array = _watched_bakes[bake]
			_pulled_after.append((now - entry[0]) / minute)
			if entry[1] >= 0.0:
				_claimed_after.append((entry[1] - entry[0]) / minute)
			_watched_bakes.erase(bake)


func _spread(values: Array[float]) -> String:
	if values.is_empty():
		return "-"
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return "median %.1f, p90 %.1f, max %.1f (n %d)" % [
		sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.9)], sorted[-1], sorted.size()
	]


func _step() -> void:
	_tally_activity()
	_watch_bakes()
	var hour: int = clock.get_minute_of_day() / 60
	if hour != _last_logged_hour and hour % 2 == 0 and _report_frame < 0:
		_last_logged_hour = hour
		print("  %02d:00 tickets %d, at register %d, line %s | %s" % [
			hour, rack.get_ticket_count(), work.get_waiting_orders().size(),
			"full" if not _lobby.has_room_in_line() else "ok", _stock_text(),
		])
	if _report_frame < 0 or frame != _report_frame + 2:
		return
	var panel: DayReportPanel = world.get_node("Hud/DayReportPanel")
	var report: DayReport = panel.report
	var gave_up_at_register: int = report.orders_missed - _cancelled - _turned_away
	print("Day %d (%s): placed %d (%d pizzas), served %d (%d pizzas), missed %d [line full %d, never taken %d, not ready %d], open %d" % [
		report.day, ShopClock.get_weekday_name(report.day), _placed, _pizzas_placed,
		report.orders_served, report.pizzas_served, report.orders_missed, _turned_away,
		gave_up_at_register, _cancelled, report.orders_open,
	])
	print("  avg ticket %.1f min, longest %d | stars %.2f, rating %.2f, popularity %.0f | sales %s supplies %s wages %s bills %s profit %s cash %s" % [
		report.get_average_minutes(), report.get_longest_minutes(), report.get_average_stars(),
		report.rating, report.popularity, ShopFinances.format_money(report.revenue),
		ShopFinances.format_money(report.supplies), ShopFinances.format_money(report.wages),
		ShopFinances.format_money(report.get_bills_total()),
		ShopFinances.format_money(report.get_profit()), ShopFinances.format_money(report.cash_after),
	])
	print("  complaints %s" % [report.complaints])
	print("  oven: out at done %s | pawn at oven at done %s" % [_spread(_pulled_after), _spread(_claimed_after)])
	_pulled_after.clear()
	_claimed_after.clear()
	print("  staff minutes: %s" % _activity_text())
	_activity.clear()
	_totals.served += report.orders_served
	_totals.missed += report.orders_missed
	_totals.profit += report.get_profit()
	_placed = 0
	_pizzas_placed = 0
	_turned_away = 0
	_cancelled = 0
	_report_frame = -1
	if report.day >= _days or report.is_out_of_money():
		if report.is_out_of_money():
			print("Out of money after day %d" % report.day)
		pass_test("%d days: served %d, missed %d, profit %s" % [
			_days, _totals.served, _totals.missed, ShopFinances.format_money(_totals.profit),
		])
		return
	(panel.get_node("%Continue") as Button).pressed.emit()
	print("Day %d (%s) opens: %s" % [report.day + 1, ShopClock.get_weekday_name(report.day + 1), _stock_text()])


func _snapshot_open() -> void:
	for supply: SupplyItem in _deliveries.catalog.items:
		_open_stock[supply.display_name] = _deliveries.get_stock(supply)


## Every supply's delivery stock, plus what's stored at each storage station.
func _stock_text() -> String:
	var parts: Array[String] = []
	for supply: SupplyItem in _deliveries.catalog.items:
		parts.append("%s %d" % [supply.display_name, _deliveries.get_stock(supply)])
	for station: Station in work.get_stations():
		if station.get_stored_kind() != null and station.get_capacity() > 0:
			parts.append("%s %d/%d" % [station.name, station.get_stock(), station.get_capacity()])
	return ", ".join(parts)
