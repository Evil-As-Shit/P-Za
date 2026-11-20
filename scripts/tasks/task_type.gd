class_name TaskType
extends Resource
## A kind of work pawns can do (assembly, oven, boxing...).

@export var id: StringName
@export var display_name: String
## Seconds of work at normal speed. Skill and mood will scale this later.
@export var base_work_time: float = 5.0
## If true, the pawn only loads the item and the station works it for base_work_time on
## its own (e.g. baking). The ticket moves on right away, so its next steps can be done
## meanwhile, but the item can't be moved until it's done.
@export var unattended: bool = false

@export_group("Containers")
## If set, the pawn fetches one of this supply from storage (e.g. &"box") and sets it out
## on a free spot. It becomes the ticket's container.
@export var fetch_supply: StringName
## Look of the set-out container once this step is done (e.g. an open box), drawn under
## and over whatever goes in it.
@export var container_under_texture: Texture2D
@export var container_over_texture: Texture2D
## If true, this step is worked at the spot holding the ticket's container, and the item
## goes into it. When done, the container becomes the ticket's item.
@export var into_container: bool = false
