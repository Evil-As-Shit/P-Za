extends "res://tests/test_base.gd"
## Reviews: every customer reviews their order (1-5 stars, minus a star or two for each
## problem), customers who leave give 1 star, the rating leans toward recent reviews and
## scales demand, and the day report lists today's reviews.

var _reputation: ShopReputation
var _rules: ReviewRules
var _reviewed: bool = false
## The rating after the real order's review, until the day is closed (-1 before and after).
var _rating_after: float = -1.0


func _start() -> void:
	stop_random_orders()
	_reputation = world.get_node("ShopReputation")
	_rules = _reputation.rules
	if not is_equal_approx(_reputation.rating, 3.0):
		fail("the rating starts at %.2f, expected 3.0" % _reputation.rating)
		return

	# Quoted 10 min, perfect pizzas: 5 stars at 8 min, 4 at 15 (late), 2 at 25 (very late
	# and past half of 45 min patience).
	var perfect: Ticket = _make_ticket([DonenessRules.Doneness.PERFECT, DonenessRules.Doneness.PERFECT])
	for check: Array in [[8, 5], [15, 4], [25, 2]]:
		var review: Review = _rules.judge_order(perfect, check[0])
		if review.stars != check[1]:
			fail("perfect order at %d min (quoted 10) got %d stars, expected %d" % [check[0], review.stars, check[1]])
			return
	var early: Review = _rules.judge_order(perfect, 8)
	if not (early.compliments.has(_rules.on_time_text) and early.compliments.has(_rules.perfect_text)):
		fail("an early perfect order's compliments are %s" % [early.compliments])
		return
	if not _rules.judge_order(perfect, 15).complaints.has(_rules.late_text):
		fail("a late order has no late complaint")
		return
	perfect.release()

	# Under and over each cost a star; a terrible order still gets 1 star.
	var mixed: Ticket = _make_ticket([DonenessRules.Doneness.UNDER, DonenessRules.Doneness.OVER])
	var mixed_review: Review = _rules.judge_order(mixed, 8)
	if mixed_review.stars != 3 or mixed_review.compliments.has(_rules.perfect_text):
		fail("an on-time under+over order got %d stars (%s), expected 3" % [mixed_review.stars, mixed_review.compliments])
		return
	if _rules.judge_order(mixed, 40).stars != 1:
		fail("a very late, long, under+over order didn't get 1 star")
		return
	mixed.release()
	for never_taken: bool in [true, false]:
		var left: Review = _rules.judge_left(never_taken)
		if left.stars != 1 or left.complaints.size() != 1:
			fail("a customer who left gave %d stars" % left.stars)
			return

	# Rating moves 5% toward each review; demand scales with rating / 3.
	if not is_equal_approx(_rules.next_rating(3.0, 5), 3.1):
		fail("a 5-star review moved 3.0 to %.3f, expected 3.1" % _rules.next_rating(3.0, 5))
		return
	if not is_equal_approx(_rules.demand_multiplier(4.5), 1.5):
		fail("rating 4.5 gives %.2fx demand, expected 1.5x" % _rules.demand_multiplier(4.5))
		return

	# A real order: going out leaves a review, which moves the rating and demand.
	var manager: Pawn = work.get_manager()
	manager.set_skill(work.managing, 20)
	clock.set_speed(6)
	_reputation.rating_changed.connect(_on_rating_changed)
	var recipes: Array[Recipe] = [world.debug_recipe]
	world._on_order_placed(recipes)


func _on_rating_changed(rating: float) -> void:
	if _reviewed:
		return
	_reviewed = true
	var orders: OrderSource = world.get_node("OrderSource")
	if is_equal_approx(rating, 3.0) or not is_equal_approx(orders.demand_multiplier, rating / 3.0):
		fail("after a review the rating is %.2f and demand %.2fx" % [rating, orders.demand_multiplier])
		return
	var label: Label = world.get_node("Hud/ClockPanel").get_node("%Rating")
	if label.text != "%.1f/5" % rating:
		fail("the HUD shows rating '%s', expected %.1f/5" % [label.text, rating])
		return
	_rating_after = rating


## Once reviewed, closes the day: the day report gets today's review.
func _step() -> void:
	if _rating_after < 0.0:
		return
	var rating: float = _rating_after
	_rating_after = -1.0
	world._on_day_started(2)
	var panel: DayReportPanel = world.get_node("Hud/DayReportPanel")
	var report: DayReport = panel.report
	if report == null or report.review_stars.size() != 1 or not is_equal_approx(report.rating, rating):
		fail("the day report doesn't show today's one review")
		return
	pass_test("synthetic reviews scored as expected; a real order got %d stars (rating %.2f, demand %.2fx)" % [report.review_stars[0], rating, rating / 3.0])


func _make_ticket(doneness: Array[DonenessRules.Doneness]) -> Ticket:
	var recipes: Array[Recipe] = []
	for each: DonenessRules.Doneness in doneness:
		recipes.append(world.debug_recipe)
	var ticket := Ticket.new(999, recipes, rack.stack_task, rack.hand_off_task)
	ticket.printed_at = 0
	ticket.patience = 45
	ticket.quoted_minutes = 10
	for index: int in doneness.size():
		ticket.order_items[index].doneness = doneness[index]
	return ticket
