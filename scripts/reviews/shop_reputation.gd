class_name ShopReputation
extends Node
## The shop's rating, built from customer reviews (newer ones count more), and today's
## reviews for the day report.

signal rating_changed(rating: float)

@export var rules: ReviewRules

var rating: float = 3.0

var _today_stars: Array[int] = []
var _today_complaints: Dictionary[String, int] = {}
var _today_compliments: Dictionary[String, int] = {}


func _ready() -> void:
	if rules != null:
		rating = rules.starting_rating


## A customer got their order and reviews it.
func review_order(ticket: Ticket, now_minutes: int) -> Review:
	var review: Review = rules.judge_order(ticket, now_minutes)
	record(review)
	return review


## A customer left without their food: `never_taken` if nobody took their order.
func review_left(never_taken: bool) -> Review:
	var review: Review = rules.judge_left(never_taken)
	record(review)
	return review


func record(review: Review) -> void:
	_today_stars.append(review.stars)
	for text: String in review.complaints:
		_today_complaints[text] = _today_complaints.get(text, 0) + 1
	for text: String in review.compliments:
		_today_compliments[text] = _today_compliments.get(text, 0) + 1
	rating = rules.next_rating(rating, review.stars)
	rating_changed.emit(rating)


## How many times the normal order rate the shop gets at its rating.
func get_demand_multiplier() -> float:
	return rules.demand_multiplier(rating)


## Adds today's reviews to `report` and starts a new tally.
func close_day(report: DayReport) -> void:
	report.review_stars = _today_stars
	report.complaints = _today_complaints
	report.compliments = _today_compliments
	report.rating = rating
	_today_stars = []
	_today_complaints = {}
	_today_compliments = {}
