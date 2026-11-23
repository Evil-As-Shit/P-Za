class_name QuoteRules
extends Resource
## How the manager quotes an order's wait: the shop's best estimate (see WaitEstimate),
## off by a random share of it that shrinks with Managing skill. Each quote is practice.
## All numbers are placeholders.

## Most a quote can be off, as a share of the estimate, at skill level 0, the base level and
## the top level (straight lines between).
@export var error_at_zero: float = 0.5
@export var error_at_base: float = 0.15
@export var error_at_max: float = 0.0
## Shop minutes of Managing practice each quote gives.
@export var practice_per_quote: float = 1.0


## Most a manager at `level` can be off, as a share of the estimate.
func max_error(level: int, skill_rules: SkillRules) -> float:
	if skill_rules == null:
		return error_at_base
	return skill_rules.by_level(level, error_at_zero, error_at_base, error_at_max)


## The wait a manager at `level` quotes for an order estimated at `estimate` shop minutes.
func roll_quote(estimate: float, level: int, skill_rules: SkillRules) -> int:
	var error: float = max_error(level, skill_rules)
	return maxi(roundi(estimate * (1.0 + randf_range(-error, error))), 1)
