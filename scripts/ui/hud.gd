class_name Hud
extends CanvasLayer
## The on-screen panels: clock and cash, ticket rack, priorities, the selected station and
## the day report. Keeps them showing the shop's state, applies speed picks and ticket moves
## directly, and passes the player's other requests up.

signal priority_change_requested(pawn: Pawn, work_type: WorkType, priority: int)
signal role_change_requested(station: Station, role: StationRole)
signal station_close_requested
signal report_closed
signal build_choice_requested(data: StationData)
signal build_close_requested
signal sell_requested

var _rack: TicketRack
var _pawns: Array[Pawn] = []
var _work_types: Array[WorkType] = []

@onready var _rack_panel: TicketRackPanel = $TicketRackPanel
@onready var _priority_panel: PriorityPanel = $PriorityPanel
@onready var _station_panel: StationPanel = $StationPanel
@onready var _clock_panel: ClockPanel = $ClockPanel
@onready var _day_report_panel: DayReportPanel = $DayReportPanel
@onready var _build_panel: BuildPanel = $BuildPanel


func setup(
	clock: ShopClock, rack: TicketRack, finances: ShopFinances, pawns: Array[Pawn],
	work_types: Array[WorkType]
) -> void:
	_rack = rack
	_pawns = pawns
	_work_types = work_types

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
	refresh_priorities()
	_station_panel.role_change_requested.connect(role_change_requested.emit)
	_station_panel.close_requested.connect(station_close_requested.emit)
	_day_report_panel.continue_requested.connect(report_closed.emit)


func refresh_rack() -> void:
	_rack_panel.show_rack(
		_rack.get_tickets(Ticket.Section.WAIT), _rack.get_tickets(Ticket.Section.MAKE),
		_rack.now_minutes
	)


## Updates how long each ticket has waited (and its lateness color).
func update_ticket_times() -> void:
	_rack_panel.update_times(_rack.now_minutes)


func refresh_priorities() -> void:
	_priority_panel.show_priorities(_pawns, _work_types)


func toggle_priorities() -> void:
	_priority_panel.visible = not _priority_panel.visible


## Shows the station in the station panel, or hides the panel for null.
func show_station(station: Station) -> void:
	if station == null:
		_station_panel.hide()
	else:
		_station_panel.show_station(station)


## The station shown in the station panel, or null.
func get_shown_station() -> Station:
	return _station_panel.station if _station_panel.visible else null


func show_report(report: DayReport) -> void:
	_day_report_panel.show_report(report)


func hide_report() -> void:
	_day_report_panel.hide()


## Fills the build menu with the stations the player can build.
func setup_build(catalog: Array[StationData]) -> void:
	_build_panel.show_catalog(catalog)
	_build_panel.station_chosen.connect(build_choice_requested.emit)
	_build_panel.close_requested.connect(build_close_requested.emit)
	_build_panel.sell_requested.connect(sell_requested.emit)


func show_build(shown: bool) -> void:
	_build_panel.visible = shown


func set_can_sell(can_sell: bool) -> void:
	_build_panel.set_can_sell(can_sell)
