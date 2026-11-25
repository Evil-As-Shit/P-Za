class_name Hud
extends CanvasLayer
## The on-screen panels: clock and cash, the pawn bar, ticket rack, the bottom bar and its
## windows (priorities, build, supplies), the inspect panel for the selected station, pawn
## or item, and the day report. Keeps them showing the shop's state, applies speed picks and
## ticket moves directly, and passes the player's other requests up.

signal priority_change_requested(pawn: Pawn, work_type: WorkType, priority: int)
## The player ticked (on) or unticked a pawn's Manager box.
signal manager_change_requested(pawn: Pawn, on: bool)
## The player set a pawn's hourly wage in the pawn panel's Pay tab.
signal wage_change_requested(pawn: Pawn, wage: float)
## The player gave (`give`) or turned down the raise a pawn asked for.
signal raise_answered(pawn: Pawn, give: bool)
## The player confirmed firing a pawn in the pawn panel.
signal fire_requested(pawn: Pawn)
signal hire_requested(applicant: Applicant)
signal pass_requested(applicant: Applicant)
signal role_change_requested(station: Station, role: StationRole)
signal station_close_requested
signal item_close_requested
signal report_closed
signal build_choice_requested(data: StationData)
signal build_close_requested
signal sell_requested
signal supply_target_change_requested(supply: SupplyItem, target: int)
## The player painted a half hour of a pawn's schedule Work (`on`) or Off.
signal schedule_change_requested(pawn: Pawn, slot: int, on: bool)
## The player dragged one of the shop's hours (prep, open, last orders, close) to `minute`.
signal hours_change_requested(mark: ShopHours.Mark, minute: int)
## A pawn card was clicked: select the pawn (and with `focus`, center the camera on them).
signal pawn_select_requested(pawn: Pawn, focus: bool)
## The bottom bar's Build button (or opening another window) turns build mode on or off.
signal build_mode_requested(on: bool)

var _rack: TicketRack
var _pawns: Array[Pawn] = []
var _work_types: Array[WorkType] = []
var _managing: WorkType
var _clock: ShopClock
## The last day report, for the bottom bar's Report button (null before the first).
var _last_report: DayReport = null
## The report showing was reopened from the bottom bar (closing it doesn't resume the day).
var _report_reopened: bool = false
var _hiring: Hiring = null

@onready var _rack_panel: TicketRackPanel = $TicketRackPanel
@onready var _priority_panel: PriorityPanel = $PriorityPanel
@onready var _schedule_panel: SchedulePanel = $SchedulePanel
@onready var _station_panel: StationPanel = $StationPanel
@onready var _pawn_panel: PawnPanel = $PawnPanel
@onready var _item_panel: ItemPanel = $ItemPanel
@onready var _clock_panel: ClockPanel = $ClockPanel
@onready var _pawn_bar: PawnBar = $PawnBar
@onready var _bottom_bar: BottomBar = $BottomBar
@onready var _day_report_panel: DayReportPanel = $DayReportPanel
@onready var _build_panel: BuildPanel = $BuildPanel
@onready var _supply_panel: SupplyPanel = $SupplyPanel
@onready var _hiring_panel: HiringPanel = $HiringPanel


func setup(
	clock: ShopClock, rack: TicketRack, finances: ShopFinances, pawns: Array[Pawn],
	work_types: Array[WorkType], managing: WorkType
) -> void:
	_rack = rack
	_clock = clock
	_pawns = pawns
	_work_types = work_types
	_managing = managing

	_clock_panel.setup(clock.speeds)
	_clock_panel.speed_requested.connect(clock.set_speed)
	clock.time_changed.connect(_clock_panel.show_time)
	clock.speed_changed.connect(_clock_panel.show_speed)
	_clock_panel.show_time(clock.day, clock.get_minute_of_day())
	_clock_panel.show_speed(clock.speed)
	finances.cash_changed.connect(_clock_panel.show_cash)
	_clock_panel.show_cash(finances.cash)

	rack.changed.connect(refresh_rack)
	_rack_panel.move_requested.connect(rack.move_ticket)
	refresh_rack()

	_priority_panel.priority_change_requested.connect(priority_change_requested.emit)
	_priority_panel.manager_change_requested.connect(manager_change_requested.emit)
	refresh_priorities()
	_schedule_panel.slot_change_requested.connect(schedule_change_requested.emit)
	_schedule_panel.mark_change_requested.connect(hours_change_requested.emit)
	clock.time_changed.connect(refresh_schedules.unbind(2))
	_station_panel.role_change_requested.connect(role_change_requested.emit)
	_station_panel.close_requested.connect(station_close_requested.emit)
	_pawn_panel.close_requested.connect(show_pawn.bind(null))
	_pawn_panel.wage_change_requested.connect(wage_change_requested.emit)
	_pawn_panel.raise_answered.connect(raise_answered.emit)
	_pawn_panel.fire_requested.connect(fire_requested.emit)
	_hiring_panel.hire_requested.connect(hire_requested.emit)
	_hiring_panel.pass_requested.connect(pass_requested.emit)
	_pawn_bar.show_pawns(pawns)
	_pawn_bar.pawn_pressed.connect(pawn_select_requested.emit)
	_item_panel.close_requested.connect(item_close_requested.emit)
	_day_report_panel.continue_requested.connect(_on_report_continue)
	_bottom_bar.tab_toggled.connect(
		func(tab: StringName, on: bool) -> void: open_window(tab if on else &"")
	)
	_bottom_bar.report_requested.connect(_reopen_report)
	_bottom_bar.show_open(_get_open_window())


func refresh_rack() -> void:
	_rack_panel.show_rack(
		_rack.get_tickets(Ticket.Section.WAIT), _rack.get_tickets(Ticket.Section.MAKE),
		_rack.now_minutes
	)


func show_waiting_orders(count: int) -> void:
	_rack_panel.show_waiting_orders(count)


## Warns that no orders come in until there's a manager.
func show_no_manager(shown: bool) -> void:
	_rack_panel.show_no_manager(shown)


## Updates how long each ticket has waited (and its lateness color).
func update_ticket_times() -> void:
	_rack_panel.update_times(_rack.now_minutes)


func refresh_priorities() -> void:
	_priority_panel.show_priorities(_pawns, _work_types, _managing)


func toggle_priorities() -> void:
	open_window(&"" if _priority_panel.visible else BottomBar.PRIORITIES)


## Brings the schedule window up to date (while it's shown).
func refresh_schedules() -> void:
	if _schedule_panel.visible:
		_schedule_panel.show_schedules(_pawns, _clock.hours, _clock.get_minute_of_day())


## Staff were hired or let go: the pawn bar, priorities and schedules list them anew, and a
## pawn who's gone leaves the pawn panel.
func refresh_staff() -> void:
	var shown: Pawn = get_shown_pawn()
	_pawn_bar.show_pawns(_pawns)
	if shown != null and not _pawns.has(shown):
		show_pawn(null)
	else:
		_pawn_bar.show_selected(shown)
	refresh_priorities()
	refresh_schedules()


## Shows the resume stack in the hiring window and its count on the bottom bar (refreshed
## when it changes).
func setup_hiring(hiring: Hiring) -> void:
	_hiring = hiring
	hiring.resumes_changed.connect(refresh_hiring)
	refresh_hiring()


func refresh_hiring() -> void:
	if _hiring == null:
		return
	_bottom_bar.show_resume_count(_hiring.get_resumes().size())
	if _hiring_panel.visible:
		_hiring_panel.show_resumes(_hiring, _clock.day)


## Opens one of the bottom bar's windows (BottomBar.PRIORITIES, SCHEDULE, BUILD, SUPPLIES or
## HIRING) and closes the others; &"" closes them all. Build mode is the world's: it's asked
## for.
func open_window(tab: StringName) -> void:
	if _build_panel.visible and tab != BottomBar.BUILD:
		build_mode_requested.emit(false)
	_priority_panel.visible = tab == BottomBar.PRIORITIES
	_schedule_panel.visible = tab == BottomBar.SCHEDULE
	_supply_panel.visible = tab == BottomBar.SUPPLIES
	_hiring_panel.visible = tab == BottomBar.HIRING
	refresh_schedules()
	refresh_supplies()
	refresh_hiring()
	if tab == BottomBar.BUILD and not _build_panel.visible:
		build_mode_requested.emit(true)
	_bottom_bar.show_open(_get_open_window())


func _get_open_window() -> StringName:
	if _build_panel.visible:
		return BottomBar.BUILD
	if _priority_panel.visible:
		return BottomBar.PRIORITIES
	if _schedule_panel.visible:
		return BottomBar.SCHEDULE
	if _supply_panel.visible:
		return BottomBar.SUPPLIES
	if _hiring_panel.visible:
		return BottomBar.HIRING
	return &""


## Shows the station in the station panel, or hides the panel for null.
func show_station(station: Station) -> void:
	if station == null:
		_station_panel.hide()
	else:
		_station_panel.show_station(station)


## Lets the pawn panel name friends and rivals.
func setup_social(social: Social) -> void:
	_pawn_panel.social = social


## Shows the pawn in the pawn panel, or hides the panel for null.
func show_pawn(pawn: Pawn) -> void:
	_pawn_bar.show_selected(pawn)
	if pawn == null:
		_pawn_panel.hide()
	else:
		# The grid's work types, plus Managing (the panel lists those with a skill).
		var work_types: Array[WorkType] = _work_types.duplicate()
		if _managing != null:
			work_types.append(_managing)
		_pawn_panel.show_pawn(pawn, work_types)


## What the item panel needs to show food quality: finds the order item an item is being
## made as (see TicketRack.find_order_item()), and the quality rules.
func setup_items(find_order_item: Callable, rules: QualityRules) -> void:
	_item_panel.setup(find_order_item, rules)


## Shows the item in the item panel, or hides the panel for null.
func show_item(item: Item) -> void:
	if item == null:
		_item_panel.hide()
	else:
		_item_panel.show_item(item)


## The item shown in the item panel, or null.
func get_shown_item() -> Item:
	return _item_panel.item if _item_panel.visible else null


## The pawn shown in the pawn panel, or null.
func get_shown_pawn() -> Pawn:
	return _pawn_panel.pawn if _pawn_panel.visible else null


## The station shown in the station panel, or null.
func get_shown_station() -> Station:
	return _station_panel.station if _station_panel.visible else null


func show_rating(rating: float) -> void:
	_clock_panel.show_rating(rating)


func show_popularity(popularity: float, max_popularity: float) -> void:
	_clock_panel.show_popularity(popularity, max_popularity)


func show_rush(rushing: bool) -> void:
	_clock_panel.show_rush(rushing)


## The end-of-day report: closing it resumes the day (see report_closed).
func show_report(report: DayReport) -> void:
	_last_report = report
	_report_reopened = false
	_bottom_bar.set_report_available(true)
	_day_report_panel.show_report(report)


func hide_report() -> void:
	_day_report_panel.hide()


func _reopen_report() -> void:
	if _last_report == null or _day_report_panel.visible:
		return
	_report_reopened = true
	_day_report_panel.show_report(_last_report)


func _on_report_continue() -> void:
	if _report_reopened:
		_report_reopened = false
		hide_report()
	else:
		report_closed.emit()


## Fills the build menu with the stations the player can build.
func setup_build(catalog: Array[StationData]) -> void:
	_build_panel.show_catalog(catalog)
	_build_panel.station_chosen.connect(build_choice_requested.emit)
	_build_panel.close_requested.connect(build_close_requested.emit)
	_build_panel.sell_requested.connect(sell_requested.emit)


## Fills the supply panel from the shop's deliveries. It refreshes each shop minute while
## shown, and when a target changes.
func setup_supplies(deliveries: Deliveries) -> void:
	_supply_panel.setup(deliveries)
	_supply_panel.target_change_requested.connect(supply_target_change_requested.emit)
	deliveries.targets_changed.connect(refresh_supplies)
	deliveries.delivered.connect(refresh_supplies.unbind(1))
	_clock.time_changed.connect(refresh_supplies.unbind(2))


func show_supplies(shown: bool) -> void:
	open_window(BottomBar.SUPPLIES if shown else &"")


func refresh_supplies() -> void:
	if _supply_panel.visible:
		_supply_panel.refresh(_clock.day)


## Build mode turned on or off: the build window opens (closing the others) or closes.
func show_build(shown: bool) -> void:
	_build_panel.visible = shown
	if shown:
		_priority_panel.hide()
		_schedule_panel.hide()
		_supply_panel.hide()
		_hiring_panel.hide()
	_bottom_bar.show_open(_get_open_window())


func set_can_sell(can_sell: bool) -> void:
	_build_panel.set_can_sell(can_sell)
