class_name PortionBehavior
extends TaskBehavior
## Works the item at its spot like the default behavior, and takes portions from a container
## of `supply` sitting in the station's side areas (e.g. sauce from the sauce bucket on the
## prep table) when the work is done. A station without one works as before.
## Placeholder until dish washing covers it: an emptied container refills on the spot.

@export var supply: PortionContainer
## Portions one job uses.
@export var amount: int = 1


func on_finished(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	if job.station == null:
		return
	for item: Item in job.station.get_side_items():
		if item.portions == supply and item.portions_left > 0:
			item.use_portions(amount)
			if item.portions_left == 0:
				item.fill_portions(supply)
			return
