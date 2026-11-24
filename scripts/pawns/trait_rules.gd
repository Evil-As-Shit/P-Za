class_name TraitRules
extends Resource
## The traits pawns can have and how many each rolls. All numbers are placeholders.

@export var traits: Array[PawnTrait] = []
## Each pawn rolls between these many traits (inclusive), never two from one group.
@export var min_traits: int = 2
@export var max_traits: int = 2


## A random set of traits: no two from the same group.
func roll(rng: RandomNumberGenerator) -> Array[PawnTrait]:
	var pool: Array[PawnTrait] = traits.duplicate()
	# Shuffle with the given rng, so rolls can be repeated.
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: PawnTrait = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var count: int = rng.randi_range(min_traits, max_traits)
	var picked: Array[PawnTrait] = []
	var groups: Array[StringName] = []
	for each: PawnTrait in pool:
		if picked.size() >= count:
			break
		if each.group != &"" and groups.has(each.group):
			continue
		picked.append(each)
		groups.append(each.group)
	return picked
