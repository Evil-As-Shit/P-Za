class_name TaskType
extends Resource
## A kind of work pawns can do (assembly, oven, boxing...).

@export var id: StringName
@export var display_name: String
## Priority grid column this task falls under. Pawns never do tasks without one.
@export var work_type: WorkType
## Seconds of work at normal speed. Skill and mood will scale this later.
@export var base_work_time: float = 5.0
## Cost of what this step uses up (e.g. the cheese, a box), paid when it's done.
@export var ingredient_cost: float = 0.0
## If true, the pawn only loads the item and the station works it for base_work_time on
## its own (e.g. baking). The ticket moves on right away, so its next steps can be done
## meanwhile, but the item can't be moved until it's done.
@export var unattended: bool = false
## If true, this step opens once the steps before it are done and is worked alongside the
## steps after it (e.g. setting out a box while the pizza bakes). Later steps that need it
## wait until it's done.
@export var prep: bool = false
## Drawn over the item while it's worked, one after another as the work fills (e.g. cut
## lines), after a first stretch with none. The last one stays when done.
@export var work_frames: Array[Texture2D] = []

## If true, the pawn moves a finished item onto its order's stack, worked where the stack
## stands, each item `stack_step` pixels above the one below.
@export var onto_stack: bool = false
@export var stack_step: float = 2.0
## If set, the pawn takes a unit from an open container of this ingredient on a station
## that does this task (setting a full one out from storage first if none is open), and the
## unit becomes the ticket's item.
@export var ingredient: IngredientContainer

@export_group("Containers")
## If set, the pawn fetches one of this supply from storage (e.g. &"box") and sets it out
## on a free spot. It becomes the ticket's container.
@export var fetch_supply: StringName
## Look of the set-out container once this step is done (e.g. an open box), drawn under
## and over whatever goes in it.
@export var container_under_texture: Texture2D
@export var container_over_texture: Texture2D
## Where things put in the container sit, relative to it (e.g. raised onto a box's floor).
@export var container_contents_offset: Vector2 = Vector2.ZERO
## If true, this step is worked at the spot holding the ticket's container.
@export var at_container: bool = false
## If true, the item goes into the container at the start of this step. Implies
## at_container.
@export var into_container: bool = false
## If true, the container closes when this step is done and becomes the ticket's item.
## Implies at_container.
@export var closes_container: bool = false


func is_at_container() -> bool:
	return at_container or into_container or closes_container
