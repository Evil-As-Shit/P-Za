class_name ReviewRules
extends Resource
## How customers review an order, how reviews move the shop's rating, and how the rating
## scales demand. A review starts at the top and loses stars for each problem; customers
## who leave without their food give the lowest. All numbers are placeholders.

@export var max_stars: int = 5
@export var min_stars: int = 1

@export_group("Quote")
## Late by up to this many shop minutes past the quote costs `late_penalty`; later costs
## `very_late_penalty`.
@export var late_minutes: int = 10
@export var late_penalty: int = 1
@export var very_late_penalty: int = 2
@export var late_text: String = "Took longer than quoted"
@export var on_time_text: String = "Ready when promised"

@export_group("Wait")
## Waiting longer than this share of their patience costs `long_wait_penalty`.
@export var long_wait_share: float = 0.5
@export var long_wait_penalty: int = 1
@export var long_wait_text: String = "Long wait"

@export_group("Doneness")
@export var under_penalty: int = 1
@export var over_penalty: int = 1
@export var under_text: String = "Undercooked"
@export var over_text: String = "Overcooked"
@export var perfect_text: String = "Perfectly baked"

@export_group("Food quality")
## Any Poor item costs `poor_penalty`; an order of all Great items wins back
## `great_bonus` (see QualityRules).
@export var poor_penalty: int = 1
@export var great_bonus: int = 1
@export var poor_text: String = "Poor food"
@export var great_text: String = "Great food"
## Stars each quality tier (Poor to Great) counts as when it moves the rating directly, and
## how far it moves it (less than a review).
@export var tier_stars: Array[int] = [2, 3, 4, 5]
@export_range(0.0, 1.0) var quality_weight: float = 0.02

@export_group("Left")
@export var never_taken_text: String = "Nobody took my order"
@export var not_ready_text: String = "Never got my food"

@export_group("Rating")
## The shop's rating before any reviews.
@export var starting_rating: float = 3.0
## How far each review moves the rating toward its stars (newer reviews count more).
@export_range(0.0, 1.0) var review_weight: float = 0.05
## Rating at which orders come at the normal rate; demand scales with rating / this.
@export var normal_rating: float = 3.0


## The review for an order that was ready `ticket.get_age(now_minutes)` after ordering (the
## customer's walk to the counter doesn't count).
func judge_order(ticket: Ticket, now_minutes: int) -> Review:
	var review := Review.new()
	var lost: int = 0
	if ticket.quoted_minutes >= 0:
		var miss: int = ticket.get_quote_miss(now_minutes)
		if miss > 0:
			lost += late_penalty if miss <= late_minutes else very_late_penalty
			review.complaints.append(late_text)
		else:
			review.compliments.append(on_time_text)
	if ticket.get_age(now_minutes) > ticket.patience * long_wait_share:
		lost += long_wait_penalty
		review.complaints.append(long_wait_text)

	var any_under: bool = false
	var any_over: bool = false
	var all_perfect: bool = not ticket.order_items.is_empty()
	for order_item: OrderItem in ticket.order_items:
		match order_item.doneness:
			DonenessRules.Doneness.UNDER:
				any_under = true
			DonenessRules.Doneness.OVER:
				any_over = true
		if order_item.doneness != DonenessRules.Doneness.PERFECT:
			all_perfect = false
	if any_under:
		lost += under_penalty
		review.complaints.append(under_text)
	if any_over:
		lost += over_penalty
		review.complaints.append(over_text)
	if all_perfect:
		review.compliments.append(perfect_text)

	match ticket.get_quality_tier():
		QualityRules.Tier.POOR:
			lost += poor_penalty
			review.complaints.append(poor_text)
		QualityRules.Tier.GREAT:
			lost -= great_bonus
			review.compliments.append(great_text)

	review.stars = clampi(max_stars - lost, min_stars, max_stars)
	return review


## The review from a customer who left: their order was never taken, or never ready.
func judge_left(never_taken: bool) -> Review:
	var review := Review.new()
	review.stars = min_stars
	review.complaints.append(never_taken_text if never_taken else not_ready_text)
	return review


## The rating after a review of `stars`.
func next_rating(rating: float, stars: int) -> float:
	return lerpf(rating, float(stars), review_weight)


## The rating after an order of quality `tier` (see QualityRules.Tier) went out, or as it
## was for an order with no quality.
func next_rating_for_quality(rating: float, tier: int) -> float:
	if tier < 0 or tier >= tier_stars.size():
		return rating
	return lerpf(rating, float(tier_stars[tier]), quality_weight)


## How many times the normal order rate a shop with `rating` gets.
func demand_multiplier(rating: float) -> float:
	return rating / normal_rating if normal_rating > 0.0 else 1.0
