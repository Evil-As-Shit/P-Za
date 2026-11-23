# Za: instructions for Claude Code

Za is a Godot 4.7.2 pizza shop management game. The design is in [`GDD.md`](GDD.md): read the sections that touch your task before gameplay work, and the whole thing when you're new to the project.

## Rules

- **Use Godot best practices.** Write idiomatic Godot 4 code that follows the official docs and the GDScript style guide.
  - Use statically typed GDScript only (no C#).
  - Build from small, reusable scenes and compose them rather than building deep inheritance.
  - Follow "signals up, calls down" so child nodes don't reach into their parents.
  - Use custom `Resource` types for data (recipes, stations, tasks and so on) instead of hard-coding it.
  - Use autoloads sparingly.
- **Target Godot 4.7.2 (Forward+).** Use APIs that exist in that version; check unfamiliar ones with the `godot-api` skill. Don't guess.
- **Don't invent design specifics.** The GDD is intentionally high-level. If numbers, formulas, systems, assets or schedules aren't covered there, ask the designer instead of making them up.
- **Make systems work; don't chase balance.** Check for real breakage (errors, stalls, deadlocks), but don't tune or measure balance unless asked.
- **Use placeholder art and audio** unless the designer says otherwise.
- **Keep `GDD.md` current.** When the designer makes a design decision, update the relevant section there, keeping it short and high-level. Keep the map below current when files move or systems are added.
- **Communicate briefly.** Give short, plain-language summaries. Don't add unrequested extras or expand the scope.
- **Use agents as needed** for research, exploration and independent tasks. Don't spawn agents for small changes.

## Ask first

Check with the designer before:
- Making or changing any design decision.
- Adding a third-party plugin, addon or any other dependency. Stay with vanilla Godot unless the designer approves.
- Doing a large refactor or deleting files.

## Tools

- Godot (Steam install): `C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`. Running it headless is allowed, to check the project loads and to verify your work before reporting it done. After adding a new `class_name`, run it once with `--headless --import`.
- Git isn't on PATH. Use SourceTree's bundled copy: `%LOCALAPPDATA%\Atlassian\SourceTree\git_local\cmd\git.exe`.
- **Tests:** `.\tests\run_tests.ps1 -Quiet [name]` runs `tests/test_*.gd` headless (the full suite takes about 20 s). Run it after gameplay changes, and add a test for each new system. See the `run-tests` skill. Task and wait times are in shop-clock minutes, so changing the day's length doesn't need retuning.
- Aseprite (Steam install): `C:\Program Files\Steam\steamapps\common\Aseprite\Aseprite.exe`, usable with `-b` for exports.

## Workflow

- Commit locally only, and only when the designer asks; the designer pushes with SourceTree. Make small, focused commits with clear messages. Keep `.godot/` out of version control.
- Plan before building any large feature. Build the smallest playable slice first, then add systems one at a time.

## Project layout

- `scenes/`, `scripts/`, `resources/` (custom `Resource` data), `Assets/` (art, audio, fonts), `tests/`, `docs/` (sprite list, draw order), `art_templates/` (drawing guides, ignored by Godot). Organize by feature inside them.
- Files and folders in `snake_case`; classes and nodes in `PascalCase`.

## Where things live in `scripts/`

`world/world.gd` (the `world.tscn` root) only sets up and connects the systems, and handles input. Everything else lives in its own folder:

- **`work/`**: `WorkManager` hands out jobs to idle pawns by priority (order jobs, shop jobs and chores like washing; restocking only as filler), walks them through each job (stops, then the work spot), and sends idle pawns wandering. It's the hub most gameplay goes through. `WorkSpot` is a station spot a job could use.
- **`tasks/`**: `Job` (one step of an order, worked by one pawn) and `JobStop` (a stop on the way: pick up, set out). `TaskType` is a kind of work (stretch, bake, cut) in a `WorkType` column of the priority grid.
  - `TaskBehavior` plans and carries out a task: what's fetched, where it's done, what happens to the items. A new kind of task gets a subclass in **`tasks/behaviors/`** set on its `TaskType` resource. Examples: `IngredientBehavior` (dough from a container), `AtContainerBehavior` and `IntoContainerBehavior` (work at or into a box), `StackBehavior`, `ThrowOutBehavior`, `RackWhenFullBehavior` (Load oven: park the pizza on a pizza rack while the ovens are full), and restocking (`FoldBehavior`, `PutAwayBehavior`, `PutAwayContainerBehavior`, `SetOutContainerBehavior`). Dishes: `WashBehavior` (a chore: one pawn takes a sink's dirty batch through its basins), `BringDishesBehavior` and `PutAwayDishBehavior` (to and from the sink).
- **`pawns/`**: `Pawn` walks the paths and works the jobs it's given, and animates. It doesn't decide anything; `WorkManager` does. It holds its priorities, skill levels and whether it's the manager; `SkillRules` sets how levels scale work time and grow with practice.
- **`stations/`**: `Station` is a placed piece of equipment (spots that hold items, plus supply stock for storage). Its type is a `StationData` resource (art, footprint, facings, `StationSpot`s, `StorageLayout`s). Surfaces are split into slots (`SlotGrid`, 4×4 per cell); each spot's item sits in its work area of slots, side items (e.g. the sauce bucket) sit in the station's side areas, and items draw back to front. `StationRole` is a role a general table or rack can take (Prep, Boxing, storage of a `StorageKind`). A `DishSink` on the data makes it a dish sink; its `DishBoards` node holds the dirty and clean drainboard piles.
- **`items/`**: `Item` is anything 1×1 that sits on a station, the floor, a pawn's hands or another item (pizza in a box). `IngredientContainer` is a multi-unit tub (dough); `Dish` is something washed at a sink (an empty tub, for now); `PortionContainer` is one a task takes portions from in place (the sauce bucket, used by `PortionBehavior`); `RotatedArt` pairs art with its quarter-turned version. `DonenessRules` sets how done a pizza comes out of the oven (set on the bake `TaskType`; `WorkManager` times the take-out by Oven skill).
- **`tickets/`**: `TicketRack` holds `Ticket`s in Wait and Make (pawns only work Make, top to bottom). A ticket's `OrderItem`s (one per pizza) are worked in parallel, one job at a time, then stacked and handed off.
- **`orders/`**: `OrderSource` places random orders, more in rushes (none without a manager). It stands in for customers. The manager quotes each order's wait: `WaitEstimate` is the queue-aware guess (with `WorkManager`'s recent average walk per job) and `QuoteRules` sets how far off the manager is by Managing skill (`WorkManager.quote_order()`).
- **`reviews/`**: `ShopReputation` keeps the shop's rating (newer reviews count more) and today's reviews for the day report. `ReviewRules` scores each customer's `Review` (stars, complaints, compliments) and sets how the rating scales `OrderSource`'s demand.
- **`menu/`**: `Recipe` is a menu item: its steps (task types) and price.
- **`economy/`**: `ShopFinances` (cash and today's tally), `Bill` (daily running costs), `DayReport` (the end-of-day summary).
- **`world/`**: `ShopFloor` (floor tiles and the pathfinding grid; furniture blocks cells), `BuildMode` (place, move and sell stations), `ShopClock` (day, time, game speed), `ShopCamera`, `ShopWalls` with `WallStyle` and `WallPiece`.
- **`ui/`**: `Hud` owns the panels and passes the player's requests up: `ClockPanel`, `TicketRackPanel` (`TicketColumn`, `TicketCard`), `PriorityPanel`, `StationPanel`, `PawnPanel`, `BuildPanel`, `DayReportPanel`.

**How an order flows:** `OrderSource` → the manager quotes it → register (`world.gd`) prints a `Ticket` on the `TicketRack` → `WorkManager` gives each `OrderItem`'s next `Job` to a pawn, planned by its `TaskBehavior` → the `Pawn` walks its stops and works at a `Station` spot, moving `Item`s → finished items are stacked and handed off → `ShopFinances` takes the payment and the customer leaves a review with `ShopReputation`. Late tickets are cancelled (a 1-star review) and their leftovers thrown out.

Data lives in `resources/` by type (`stations/`, `tasks/`, `recipes/`, `items/`, `work_types/`, `station_roles/`, `storage_kinds/`, `storage_layouts/`, `orders/`, `reviews/`, `bills/`, `pawns/`, `walls/`, `tilesets/`, `ui/`). Scenes mirror the scripts in `scenes/` (`world/`, `stations/`, `pawns/`, `items/`, `ui/`).
