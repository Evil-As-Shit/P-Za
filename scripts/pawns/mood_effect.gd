class_name MoodEffect
extends Resource
## A timed lift or drop in a pawn's mood (e.g. "Survived the rush"). Getting it again
## restarts its time instead of stacking.

@export var display_name: String = "Mood effect"
## Added to the pawn's mood target while it lasts (negative lowers it).
@export var mood: float = 0.0
## Shop minutes it lasts.
@export var minutes: float = 60.0
