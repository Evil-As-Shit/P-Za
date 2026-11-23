class_name QualityRules
extends Resource
## How good a finished pizza is: a hidden score (0-100) from its ingredients, the skill of
## the pawns who made it and how done it came out, shown as a tier. All numbers are
## placeholders.

enum Tier { POOR, OKAY, GOOD, GREAT }

const TIER_NAMES: Array[String] = ["Poor", "Okay", "Good", "Great"]

## Score of the ingredients (premade for now).
@export var ingredient_score: float = 50.0
## Skill level that neither adds nor takes away, and points per level above or below it
## (averaged over the hands-on steps, see TaskType.affects_quality).
@export var skill_center: int = 10
@export var points_per_level: float = 2.0
@export_group("Doneness")
@export var perfect_bonus: float = 10.0
@export var under_penalty: float = 15.0
@export var over_penalty: float = 15.0
@export_group("Tiers")
## Lowest score of Okay, Good and Great (anything lower is Poor).
@export var okay_at: float = 40.0
@export var good_at: float = 60.0
@export var great_at: float = 80.0


## The score of a finished order item.
func get_score(order_item: OrderItem) -> float:
	var score: float = ingredient_score
	if not order_item.skill_levels.is_empty():
		var total: int = 0
		for level: int in order_item.skill_levels:
			total += level
		var average: float = float(total) / order_item.skill_levels.size()
		score += (average - skill_center) * points_per_level
	match order_item.doneness:
		DonenessRules.Doneness.PERFECT:
			score += perfect_bonus
		DonenessRules.Doneness.UNDER:
			score -= under_penalty
		DonenessRules.Doneness.OVER:
			score -= over_penalty
	score -= order_item.freshness_loss
	return clampf(score, 0.0, 100.0)


func get_tier(score: float) -> Tier:
	if score >= great_at:
		return Tier.GREAT
	if score >= good_at:
		return Tier.GOOD
	if score >= okay_at:
		return Tier.OKAY
	return Tier.POOR


static func get_tier_name(tier: Tier) -> String:
	return TIER_NAMES[tier]
