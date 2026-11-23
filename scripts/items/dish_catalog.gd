class_name DishCatalog
extends Resource
## The things that get washed as dishes (see Dish), so the jobs that carry dishes to and
## from a sink can make the item a pawn carries for any of them.

@export var ingredient_containers: Array[IngredientContainer] = []
@export var portion_containers: Array[PortionContainer] = []


## An item for `dish` where `work` keeps loose items: a dirty one empty (lid off), a clean
## one as it's put away (lid on, or full). Null if the dish isn't in the catalog.
func spawn(dish: Dish, work: WorkManager, clean: bool) -> Item:
	for kind: IngredientContainer in ingredient_containers:
		if kind.dish == dish:
			var container: Item = IngredientBehavior.spawn_container(kind, work, 0)
			if not clean:
				container.set_lid(null)
			return container
	for kind: PortionContainer in portion_containers:
		if kind.dish == dish:
			return kind.spawn(work, clean)
	return null
