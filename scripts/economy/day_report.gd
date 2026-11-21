class_name DayReport
extends RefCounted
## What happened in one shop day: orders served, how fast, and the money in and out.

var day: int = 0
var orders_served: int = 0
var pizzas_served: int = 0
## Shop minutes each served order took, from printing to going out.
var order_minutes: Array[int] = []
## Orders still on the rack at closing.
var orders_open: int = 0
var revenue: float = 0.0
var ingredients: float = 0.0
var wages: float = 0.0
var staff_count: int = 0
var staff_hours: float = 0.0
## Bill name -> amount charged at closing.
var bills: Dictionary[String, float] = {}
## Cash once everything is paid.
var cash_after: float = 0.0


func get_bills_total() -> float:
	var total: float = 0.0
	for amount: float in bills.values():
		total += amount
	return total


func get_profit() -> float:
	return revenue - ingredients - wages - get_bills_total()


func get_average_minutes() -> float:
	if order_minutes.is_empty():
		return 0.0
	var total: int = 0
	for minutes: int in order_minutes:
		total += minutes
	return float(total) / order_minutes.size()


func get_longest_minutes() -> int:
	return order_minutes.max() if not order_minutes.is_empty() else 0
