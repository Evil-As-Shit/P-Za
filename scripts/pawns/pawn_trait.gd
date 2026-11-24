class_name PawnTrait
extends Resource
## A personality trait (e.g. Calm, Lazy): multipliers on how the pawn works and feels.
## Traits in the same group are opposites; a pawn never has two from one group.

@export var display_name: String = "Trait"
@export_multiline var description: String = ""
## Traits sharing a group exclude each other (e.g. &"stress" for Calm and Nervous).
@export var group: StringName
## Multiplies how fast stress builds.
@export var stress_gain: float = 1.0
## Multiplies work speed.
@export var work_speed: float = 1.0
## Multiplies how often they check their phone while idle.
@export var slack: float = 1.0
