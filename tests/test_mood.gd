extends "res://tests/test_base.gd"
## Mood: stress builds on a job during a rush and lowers mood; Happy and Stressed change work
## speed and quality; very low mood brings a breakdown (no new jobs) that ends on its own;
## working a rush gives "Survived the rush" once it's over. The shop rushes on its own when
## unfinished tickets outnumber 2 per pawn, and pawns then work 25% faster.

const CUTTING := preload("res://resources/work_types/cutting.tres")

var _rush_ordered: bool = false


func _start() -> void:
	stop_random_orders()
	var rules: MoodRules = load("res://resources/pawns/mood_rules.tres")
	var mood := PawnMood.new(rules)
	if not is_equal_approx(mood.mood, rules.base_mood) or mood.get_band() != PawnMood.Band.CONTENT:
		fail("a new pawn starts at mood %.1f (%s), expected %.0f Content" % [mood.mood, mood.get_band_name(), rules.base_mood])
		return
	if not is_equal_approx(mood.get_speed_multiplier(), 1.0) or mood.get_quality_levels() != 0:
		fail("Content changes speed or quality")
		return

	# A rush: faster, and stress builds only while on a job.
	mood.set_rushing(true)
	if not is_equal_approx(mood.get_speed_multiplier(), rules.rush_speed):
		fail("rush speed is %.2f, expected %.2f" % [mood.get_speed_multiplier(), rules.rush_speed])
		return
	mood.tick(10.0, false)
	if mood.stress > 0.0:
		fail("stress built while idle in a rush")
		return
	mood.tick(10.0, true)
	if not is_equal_approx(mood.stress, rules.stress_rise_per_minute * 10.0):
		fail("10 minutes on a job in a rush gave stress %.1f" % mood.stress)
		return
	if mood.mood >= rules.base_mood:
		fail("stress didn't lower mood (%.1f)" % mood.mood)
		return

	# Rush over: "Survived the rush", and stress eases.
	var stress: float = mood.stress
	mood.set_rushing(false)
	if not mood.get_effects().has(rules.rush_survived):
		fail("working a rush didn't give \"Survived the rush\"")
		return
	mood.tick(5.0, true)
	if mood.stress >= stress:
		fail("stress didn't ease after the rush")
		return

	# Happy: faster and better.
	var lift := MoodEffect.new()
	lift.mood = 40.0
	lift.minutes = 500.0
	mood.add_effect(lift)
	mood.tick(100.0, false)
	if mood.get_band() != PawnMood.Band.HAPPY:
		fail("mood %.1f with a +40 effect isn't Happy" % mood.mood)
		return
	if not is_equal_approx(mood.get_speed_multiplier(), rules.happy_speed) or mood.get_quality_levels() != rules.happy_quality_levels:
		fail("Happy doesn't speed up or improve quality")
		return

	# Breaking: a breakdown that ends on its own, then a cooldown.
	var drop := MoodEffect.new()
	drop.mood = -100.0
	drop.minutes = 1000.0
	mood.get_effects().clear()
	mood.add_effect(drop)
	var started: Array[int] = [0]
	var ended: Array[int] = [0]
	mood.breakdown_started.connect(func() -> void: started[0] += 1)
	mood.breakdown_ended.connect(func() -> void: ended[0] += 1)
	mood.mood = 5.0
	# Long enough for the breakdown to end, but inside its cooldown.
	var minutes: int = int(rules.breakdown_minutes + rules.breakdown_cooldown_minutes / 2.0)
	for i: int in minutes:
		mood.tick(1.0, false)
	if started[0] != 1 or ended[0] != 1:
		fail("%d minutes at rock-bottom mood gave %d breakdowns (%d ended), expected 1" % [minutes, started[0], ended[0]])
		return
	if mood.get_quality_levels() != rules.stressed_quality_levels or mood.get_speed_multiplier() >= 1.0:
		fail("low mood doesn't slow down or lower quality")
		return

	# A real pawn: mood lowers the skill a step counts for, and a breakdown takes no jobs.
	var pawn: Pawn = work.get_pawns()[0]
	pawn.set_skill(CUTTING, 10)
	pawn.mood.mood = 20.0
	if pawn.get_quality_level(CUTTING) != 10 + rules.stressed_quality_levels:
		fail("a Stressed pawn's cutting counts as level %d" % pawn.get_quality_level(CUTTING))
		return
	pawn.mood.mood = rules.base_mood
	pawn.mood.start_breakdown()
	if work.try_assign(pawn):
		fail("a pawn on a breakdown took a job")
		return

	# The shop rushes on its own once tickets outnumber 2 per pawn.
	var count: int = int(work.rush_tickets_per_pawn * work.get_pawns().size()) + 1
	for i: int in count:
		order_pizzas(1)
	_rush_ordered = true


func _step() -> void:
	if not _rush_ordered or not work.is_rushing():
		return
	var pawn: Pawn = work.get_pawns()[1]
	pawn.mood.mood = pawn.mood.rules.base_mood
	var expected: float = pawn.work_speed * pawn.mood.rules.rush_speed
	if not is_equal_approx(pawn.get_work_rate(CUTTING), expected):
		fail("in a rush a base-level pawn works at %.2f, expected %.2f" % [pawn.get_work_rate(CUTTING), expected])
		return
	pass_test("stress, mood bands, breakdowns and the rush work")
