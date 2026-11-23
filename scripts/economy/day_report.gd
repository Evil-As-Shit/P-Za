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
## Orders whose customers gave up waiting, and what they would have paid.
var orders_missed: int = 0
var sales_missed: float = 0.0
var revenue: float = 0.0
var ingredients: float = 0.0
var wages: float = 0.0
var staff_count: int = 0
var staff_hours: float = 0.0
## Bill name -> amount charged at closing.
var bills: Dictionary[String, float] = {}
## Cash once everything is paid.
var cash_after: float = 0.0
## Stars of each review left today.
var review_stars: Array[int] = []
## Complaint or compliment text -> how many reviews mentioned it today.
var complaints: Dictionary[String, int] = {}
var compliments: Dictionary[String, int] = {}
## The shop's rating at closing.
var rating: float = 0.0


func get_average_stars() -> float:
	if review_stars.is_empty():
		return 0.0
	var total: int = 0
	for stars: int in review_stars:
		total += stars
	return float(total) / review_stars.size()


## The `count` most mentioned entries of `tally` (e.g. complaints), most first.
static func get_top(tally: Dictionary[String, int], count: int) -> Array[String]:
	var texts: Array[String] = []
	texts.assign(tally.keys())
	texts.sort_custom(func(a: String, b: String) -> bool: return tally[a] > tally[b])
	return texts.slice(0, count)


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
