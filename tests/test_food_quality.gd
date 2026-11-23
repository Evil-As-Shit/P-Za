extends "res://tests/test_base.gd"
## Food quality: the score comes from the ingredients, the makers' skill and doneness, and
## sets the tier; a Poor order loses a review star, an all-Great one wins one back, and the
## tier also nudges the rating. Then a real pizza made by top-skill pawns comes out with
## every hands-on step's skill counted and its quality set by the time it's ready.

const RULES := preload("res://resources/recipes/quality_rules.tres")
const REVIEWS := preload("res://resources/reviews/review_rules.tres")

var _ticket: Ticket


func _start() -> void:
	var problem: String = _check_scores()
	if problem == "":
		problem = _check_reviews()
	if problem != "":
		fail(problem)
		return
	# A real order, made by pawns at the top skill level.
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	for pawn: Pawn in work.get_pawns():
		for work_type: WorkType in work.work_types:
			if work_type.has_skill:
				pawn.set_skill(work_type, 20)
	_ticket = order_pizzas(1)
	work.order_ready.connect(_on_ready)


func _on_ready(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	var order_item: OrderItem = ticket.order_items[0]
	if order_item.skill_levels != [20, 20, 20, 20]:
		fail("counted skill levels %s, not four steps at 20" % [order_item.skill_levels])
	elif ticket.get_quality_tier() < 0:
		fail("the ready order has no quality")
	elif ticket.get_quality_tier() != RULES.get_tier(RULES.get_score(order_item)):
		fail("the order's tier doesn't match its score")
	else:
		pass_test("scores, tiers, review stars and rating nudge work; a real pizza was judged %s" %
			QualityRules.get_tier_name(ticket.get_quality_tier()))


func _check_scores() -> String:
	var cases: Array = [
		[[20, 20, 20, 20], DonenessRules.Doneness.PERFECT, 80.0, QualityRules.Tier.GREAT],
		[[10, 10, 10, 10], DonenessRules.Doneness.PERFECT, 60.0, QualityRules.Tier.GOOD],
		[[10, 10, 10, 10], DonenessRules.Doneness.NONE, 50.0, QualityRules.Tier.OKAY],
		[[0, 0, 0, 0], DonenessRules.Doneness.UNDER, 15.0, QualityRules.Tier.POOR],
	]
	for case: Array in cases:
		var order_item := OrderItem.new(null, world.debug_recipe)
		order_item.skill_levels.assign(case[0])
		order_item.doneness = case[1]
		var score: float = RULES.get_score(order_item)
		if not is_equal_approx(score, case[2]) or RULES.get_tier(score) != case[3]:
			return "skills %s, doneness %d: score %.1f, tier %d (expected %.1f, %d)" % [
				case[0], case[1], score, RULES.get_tier(score), case[2], case[3]]
		order_item.clear_jobs()
	return ""


func _check_reviews() -> String:
	var poor: Ticket = _ticket_of_tier(QualityRules.Tier.POOR)
	var review: Review = REVIEWS.judge_order(poor, 0)
	if review.stars != 4 or not review.complaints.has(REVIEWS.poor_text):
		return "a Poor order got %d stars, complaints %s" % [review.stars, review.complaints]
	var great: Ticket = _ticket_of_tier(QualityRules.Tier.GREAT)
	great.order_items[0].doneness = DonenessRules.Doneness.UNDER
	review = REVIEWS.judge_order(great, 0)
	if review.stars != 5 or not review.compliments.has(REVIEWS.great_text):
		return "an undercooked but Great order got %d stars (expected one won back to 5)" % review.stars
	var nudged: float = REVIEWS.next_rating_for_quality(3.0, QualityRules.Tier.GREAT)
	if not is_equal_approx(nudged, lerpf(3.0, 5.0, REVIEWS.quality_weight)):
		return "a Great order moved the rating to %.3f" % nudged
	for ticket: Ticket in [poor, great]:
		ticket.release()
	return ""


func _ticket_of_tier(tier: QualityRules.Tier) -> Ticket:
	var recipes: Array[Recipe] = [world.debug_recipe]
	var ticket := Ticket.new(0, recipes, null, null)
	ticket.order_items[0].quality_tier = tier
	return ticket
