extends "res://tests/test_base.gd"
## Social: pawns near each other move their opinions of each other by their pair's
## chemistry and fill their social need (less, or a drain, with someone they dislike);
## alone, social drains, faster for Chatty pawns. Chemistry gets a bonus per shared trait
## and a penalty per pair of opposites. Social moves mood; strong opinions make friends and
## rivals, and a lonely pawn's card says so.

const CALM := preload("res://resources/pawns/traits/calm.tres")
const CHATTY := preload("res://resources/pawns/traits/chatty.tres")
const LONER := preload("res://resources/pawns/traits/loner.tres")


func _start() -> void:
	stop_random_orders()
	var social: Social = world.get_node("Social")
	social.process_mode = Node.PROCESS_MODE_DISABLED
	var rules: SocialRules = social.rules
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	# Frozen in place, two together and two apart; any others are sent home out of the way.
	var cells: Array[Vector2i] = [Vector2i(12, 7), Vector2i(13, 7), Vector2i(2, 8), Vector2i(17, 8)]
	var pawns: Array[Pawn] = keep_pawns(cells.size())
	for i: int in pawns.size():
		pawns[i].process_mode = Node.PROCESS_MODE_DISABLED
		pawns[i].global_position = shop_floor.cell_to_global(cells[i])
		pawns[i].mood.social = 50.0
		pawns[i].mood.opinions.clear()
	var a: Pawn = pawns[0]
	var b: Pawn = pawns[1]
	var alone: Pawn = pawns[2]
	var chatty: Pawn = pawns[3]
	if social.get_company(a) != [b] or not social.get_company(alone).is_empty():
		fail("company is wrong: %s has %d near, %s has %d" % [a.display_name, social.get_company(a).size(), alone.display_name, social.get_company(alone).size()])
		return

	# Good chemistry: opinions rise both ways, social fills.
	social.set_chemistry(a, b, 0.5)
	chatty.set_traits([CHATTY])
	social.tick(10.0)
	var expected: float = 0.5 * rules.opinion_per_minute * 10.0
	if not is_equal_approx(a.mood.get_opinion(b), expected) or not is_equal_approx(b.mood.get_opinion(a), expected):
		fail("10 minutes together gave opinions %.1f and %.1f, expected %.1f" % [a.mood.get_opinion(b), b.mood.get_opinion(a), expected])
		return
	if a.mood.social <= 50.0:
		fail("company didn't fill social (%.1f)" % a.mood.social)
		return
	# Alone: social drains, twice as fast for a Chatty pawn.
	var drained: float = 50.0 - alone.mood.social
	if not is_equal_approx(drained, rules.alone_drain_per_minute * 10.0) \
			or not is_equal_approx(50.0 - chatty.mood.social, drained * 2.0):
		fail("alone, social drained %.2f (Chatty %.2f)" % [drained, 50.0 - chatty.mood.social])
		return

	# A rival drains social even in company.
	a.mood.opinions[b] = -90.0
	social.set_chemistry(a, b, 0.0)
	var before: float = a.mood.social
	social.tick(10.0)
	if a.mood.social >= before:
		fail("company of a rival didn't drain social")
		return
	if social.get_relation(-90.0) != "Rival" or social.get_relation(60.0) != "Friend" or social.get_relation(0.0) != "":
		fail("relations by opinion are wrong")
		return

	# Traits: a shared trait helps chemistry, opposites hurt it.
	a.set_traits([CALM, CHATTY])
	b.set_traits([CALM, LONER])
	if not is_equal_approx(social.get_trait_match(a, b), rules.shared_trait_bonus - rules.opposite_trait_penalty):
		fail("trait match is %.2f" % social.get_trait_match(a, b))
		return

	# Social moves mood, and a lonely pawn's card says so.
	var mood_rules: MoodRules = a.mood.rules
	alone.mood.energy = 100.0
	alone.mood.stress = 0.0
	alone.mood.get_effects().clear()
	alone.mood.social = 100.0
	var high: float = alone.mood.get_target()
	alone.mood.social = 50.0
	if not is_equal_approx(high - alone.mood.get_target(), mood_rules.social_mood_cost):
		fail("full social lifts mood by %.1f" % (high - alone.mood.get_target()))
		return
	alone.mood.social = mood_rules.lonely_below - 1.0
	alone.mood.mood = mood_rules.base_mood
	if PawnCard.get_status(alone) != "Lonely":
		fail("a lonely pawn's card says \"%s\"" % PawnCard.get_status(alone))
		return
	pass_test("opinions and social follow company and chemistry; social moves mood")
