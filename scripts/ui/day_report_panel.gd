class_name DayReportPanel
extends PanelContainer
## End-of-day summary: orders, ticket times, reviews and the money in and out. Shown at
## closing while the game is paused; Continue starts the next day.

signal continue_requested

const DIM := Color(1.0, 1.0, 1.0, 0.6)
const GOOD := Color(0.55, 0.9, 0.5)
const BAD := Color(1.0, 0.45, 0.4)
## Complaints and compliments listed (the most mentioned).
const TOP_COUNT: int = 3

## The report on show, or null.
var report: DayReport = null

@onready var _title: Label = %Title
@onready var _lines: GridContainer = %Lines
@onready var _continue: Button = %Continue


func _ready() -> void:
	_continue.pressed.connect(continue_requested.emit)


func show_report(p_report: DayReport) -> void:
	report = p_report
	_title.text = "Day %d closed" % report.day
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()

	_add_line("Orders served", "%d (%d pizzas)" % [report.orders_served, report.pizzas_served])
	_add_line(
		"Orders missed", "%d" % report.orders_missed, "",
		BAD if report.orders_missed > 0 else Color.WHITE
	)
	if report.orders_open > 0:
		_add_line("Still open", "%d (carried over)" % report.orders_open)
	_add_line("Average ticket", "%d min" % roundi(report.get_average_minutes()))
	_add_line("Longest ticket", "%d min" % report.get_longest_minutes())
	_add_gap()
	_add_reviews()
	_add_gap()
	_add_line("Sales", ShopFinances.format_money(report.revenue))
	if report.orders_missed > 0:
		_add_line("Sales lost", ShopFinances.format_money(report.sales_missed), "", DIM)
	_add_line("Ingredients", _cost(report.ingredients))
	_add_line(
		"Wages", _cost(report.wages),
		"%d staff × %d h" % [report.staff_count, roundi(report.staff_hours)]
	)
	for bill_name: String in report.bills:
		_add_line(bill_name, _cost(report.bills[bill_name]))
	_add_gap()
	var profit: float = report.get_profit()
	_add_line("Profit", ShopFinances.format_money(profit), "", GOOD if profit >= 0.0 else BAD)
	_add_line(
		"Cash", ShopFinances.format_money(report.cash_after), "",
		BAD if report.cash_after < 0.0 else Color.WHITE
	)
	show()


## Today's reviews, the rating, and the top complaints and compliments.
func _add_reviews() -> void:
	if report.review_stars.is_empty():
		_add_line("Reviews", "none")
	else:
		_add_line(
			"Reviews", "%d (average %.1f/5)" % [report.review_stars.size(), report.get_average_stars()]
		)
	_add_line("Shop rating", "%.1f/5" % report.rating)
	for text: String in DayReport.get_top(report.complaints, TOP_COUNT):
		_add_line("  " + text, "×%d" % report.complaints[text], "", BAD)
	for text: String in DayReport.get_top(report.compliments, TOP_COUNT):
		_add_line("  " + text, "×%d" % report.compliments[text], "", GOOD)


func _cost(amount: float) -> String:
	return ShopFinances.format_money(-amount)


func _add_line(
	label: String, value: String, note: String = "", color: Color = Color.WHITE
) -> void:
	var name_label := Label.new()
	name_label.text = label if note.is_empty() else "%s  (%s)" % [label, note]
	_lines.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.modulate = color
	_lines.add_child(value_label)


func _add_gap() -> void:
	for i: int in 2:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6)
		_lines.add_child(gap)
