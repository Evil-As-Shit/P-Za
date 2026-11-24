class_name ShopFinances
extends Node
## The shop's cash, and the running tally for today. Sales and supply deliveries change cash
## as they happen; wages and bills are paid at closing, when the day's report is made.

signal cash_changed(cash: float)

## Paid every day at closing.
@export var bills: Array[Bill] = []
@export var starting_cash: float = 0.0

var cash: float = 0.0
var _today := DayReport.new()


func _ready() -> void:
	cash = starting_cash


## Today's tally so far (wages and bills are added at closing).
func get_today() -> DayReport:
	return _today


## An order went out: `revenue` for `pizzas` items, `minutes` after it printed.
func record_sale(revenue: float, pizzas: int, minutes: int) -> void:
	_today.orders_served += 1
	_today.pizzas_served += pizzas
	_today.order_minutes.append(minutes)
	_today.revenue += revenue
	_change_cash(revenue)


## A customer gave up on an order worth `sales`. No money changes hands.
func record_missed(sales: float) -> void:
	_today.orders_missed += 1
	_today.sales_missed += sales


## A supply delivery arrived and was paid for.
func record_supplies(cost: float) -> void:
	if cost == 0.0:
		return
	_today.supplies += cost
	_change_cash(-cost)


## Pays wages and bills, and returns the finished report for `day`. Starts a new tally.
func close_day(
	day: int, wages: float, staff_count: int, staff_hours: float, orders_open: int
) -> DayReport:
	var report: DayReport = _today
	report.day = day
	report.wages = wages
	report.staff_count = staff_count
	report.staff_hours = staff_hours
	report.orders_open = orders_open
	for bill: Bill in bills:
		report.bills[bill.display_name] = bill.per_day
	_change_cash(-wages - report.get_bills_total())
	report.cash_after = cash
	_today = DayReport.new()
	return report


static func format_money(amount: float) -> String:
	var text: String = "$%.2f" % absf(amount)
	return "-" + text if amount < -0.005 else text


func _change_cash(amount: float) -> void:
	cash += amount
	cash_changed.emit(cash)
