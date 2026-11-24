class_name Social
extends Node
## How the pawns get along. Every pair has a hidden chemistry (rolled, plus their traits).
## Pawns near each other change their opinions of each other by it, and fill their social
## need (more with people they like); alone, social drains (see SocialRules).

@export var rules: SocialRules

var _floor: ShopFloor
var _pawns: Array[Pawn] = []
## "id_id" (lower instance id first) -> the pair's chemistry.
var _chemistry: Dictionary[String, float] = {}


## Call once the pawns are in play (and have their traits).
func setup(pawns: Array[Pawn], shop_floor: ShopFloor, rng: RandomNumberGenerator) -> void:
	_pawns = pawns
	_floor = shop_floor
	for i: int in _pawns.size():
		for j: int in range(i + 1, _pawns.size()):
			var rolled: float = rng.randf_range(-rules.chemistry_range, rules.chemistry_range)
			_chemistry[_key(_pawns[i], _pawns[j])] = rolled + get_trait_match(_pawns[i], _pawns[j])


func _process(delta: float) -> void:
	tick(delta / ShopClock.minutes_to_seconds(1.0))


## Moves social time on by `minutes` shop minutes.
func tick(minutes: float) -> void:
	if minutes <= 0.0 or rules == null:
		return
	for pawn: Pawn in _pawns:
		var mood: PawnMood = pawn.mood
		# Gone home: away from the shop's company (and loneliness).
		if mood == null or pawn.is_away():
			continue
		var company: Array[Pawn] = get_company(pawn)
		if company.is_empty():
			mood.change_social(-rules.alone_drain_per_minute * mood.social_need * minutes)
			continue
		var value: float = 0.0
		for other: Pawn in company:
			mood.change_opinion(other, get_chemistry(pawn, other) * rules.opinion_per_minute * minutes)
			# Neutral company is pleasant; a friend doubles it, a rival makes it a drain.
			value += 0.5 + mood.get_opinion(other) / 100.0
		value /= company.size()
		mood.change_social(value * rules.company_per_minute * mood.social_need * minutes)


## The other pawns near enough to `pawn` to count as company.
func get_company(pawn: Pawn) -> Array[Pawn]:
	var company: Array[Pawn] = []
	var here: Vector2i = _floor.global_to_cell(pawn.global_position)
	for other: Pawn in _pawns:
		if other == pawn or other.is_away():
			continue
		var there: Vector2i = _floor.global_to_cell(other.global_position)
		if maxi(absi(there.x - here.x), absi(there.y - here.y)) <= rules.near_cells:
			company.append(other)
	return company


func get_chemistry(a: Pawn, b: Pawn) -> float:
	return _chemistry.get(_key(a, b), 0.0)


func set_chemistry(a: Pawn, b: Pawn, chemistry: float) -> void:
	_chemistry[_key(a, b)] = chemistry


## Chemistry from traits: a bonus per shared trait, a penalty per pair of opposites.
func get_trait_match(a: Pawn, b: Pawn) -> float:
	var match_value: float = 0.0
	for mine: PawnTrait in a.traits:
		for theirs: PawnTrait in b.traits:
			if mine == theirs:
				match_value += rules.shared_trait_bonus
			elif mine.group != &"" and mine.group == theirs.group:
				match_value -= rules.opposite_trait_penalty
	return match_value


## "Friend", "Rival" or "" for an opinion.
func get_relation(opinion: float) -> String:
	if opinion >= rules.friend_at:
		return "Friend"
	if opinion <= rules.rival_at:
		return "Rival"
	return ""


static func _key(a: Pawn, b: Pawn) -> String:
	var first: int = mini(a.get_instance_id(), b.get_instance_id())
	var second: int = maxi(a.get_instance_id(), b.get_instance_id())
	return "%d_%d" % [first, second]
