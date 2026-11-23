class_name WorkType
extends Resource
## A kind of work: one column of the priority grid (Dough stretching, Oven, Hauling...).
## Each task type belongs to one.

@export var id: StringName
@export var display_name: String
## If true, pawns have a skill level in this work that sets how fast they do it and grows
## with practice. Plain carrying (Hauling) has none.
@export var has_skill: bool = true
