class_name TaskType
extends Resource
## A kind of work pawns can do (stretching, baking, cutting...). What's specific to a kind
## of task (what it fetches, where it's done, what happens to the items) is its behavior.

## Used when a task has no behavior set: carry the item to a free spot and work it there.
static var _default_behavior := TaskBehavior.new()

@export var id: StringName
@export var display_name: String
## Priority grid column this task falls under. Pawns never do tasks without one.
@export var work_type: WorkType
## Shop-clock minutes of work at normal speed (so they don't change with the day's real
## length). Skill and mood will scale this later.
@export var work_minutes: float = 1.0
## If true, the pawn only loads the item and the station works it for work_minutes on
## its own (e.g. baking). The ticket moves on right away, so its next steps can be done
## meanwhile, but the item can't be moved until it's done.
@export var unattended: bool = false
## For unattended tasks: how done the item comes out, set when the next step's pawn takes
## it out (e.g. a pizza from the oven). Empty means it's just ready once done.
@export var doneness_rules: DonenessRules
## If true, this step opens once the steps before it are done and is worked alongside the
## steps after it (e.g. setting out a box while the pizza bakes). Later steps that need it
## wait until it's done.
@export var prep: bool = false
## Drawn over the item while it's worked, one after another as the work fills (e.g. cut
## lines), after a first stretch with none. The last one stays when done.
@export var work_frames: Array[Texture2D] = []
## If true, the station shows its in-use art while this task is worked there, and stays that
## way while the item's next step opens it too (e.g. the prep table's lids stay open from
## sauce through cheese).
@export var opens_station: bool = false
## If true, the skill of the pawn who does this step counts toward the item's quality (see
## QualityRules), e.g. stretching or cutting.
@export var affects_quality: bool = false
## If true, it's a break, not work: it lasts work_minutes whatever the pawn's speed, gives no
## practice, and refills energy (see PawnMood).
@export var rest: bool = false
## If true, work done at a station dirties it (see WorkManager.station_dirt_per_task). Off
## for wiping it down. Breaks never do.
@export var dirties_station: bool = true
## Chance (0 to 1) that finishing this step at a station leaves a spill on the floor where
## the pawn stood (see FloorDirt), e.g. sauce. Placeholder.
@export_range(0.0, 1.0) var spill_chance: float = 0.0
## How the task is planned and carried out. Empty means the default (see TaskBehavior).
@export var behavior: TaskBehavior


func get_behavior() -> TaskBehavior:
	return behavior if behavior != null else _default_behavior


## Game seconds of work at normal speed (see work_minutes).
func get_work_seconds() -> float:
	return ShopClock.minutes_to_seconds(work_minutes)
