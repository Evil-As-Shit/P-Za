# Za: Game Design Document

## Instructions for Claude Code

Read this whole file first to get up to speed on the game, then follow these rules.

### Rules

- **Use Godot best practices.** Write idiomatic Godot 4 code that follows the official docs and the GDScript style guide.
  - Use statically typed GDScript only (no C#).
  - Build from small, reusable scenes and compose them rather than building deep inheritance.
  - Follow "signals up, calls down" so child nodes don't reach into their parents.
  - Use custom `Resource` types for data (recipes, stations, tasks and so on) instead of hard-coding it.
  - Use autoloads sparingly.
- **Target Godot 4.7.2 (Forward+).** Use APIs that exist in that version and confirm against `project.godot`. Don't guess.
- **Don't invent design specifics.** This document is intentionally high-level. If numbers, formulas, systems, assets or schedules aren't covered here, ask the designer instead of making them up.
- **Use placeholder art and audio** unless the designer says otherwise.
- **Keep this file current.** When the designer makes a design decision, update the relevant section here, keeping it short and high-level.
- **Communicate briefly.** Give short, plain-language summaries. Don't add unrequested extras or expand the scope.
- **Use agents as needed** for research, exploration and independent tasks. Don't spawn agents for small changes.

### Ask first

Check with the designer before:
- Making or changing any design decision.
- Adding a third-party plugin, addon or any other dependency. Stay with vanilla Godot unless the designer approves.
- Doing a large refactor or deleting files.

### Tools

- Godot (Steam install): `C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`. Running it headless is allowed, to check the project loads and to verify your work before reporting it done. After adding a new `class_name`, run it once with `--headless --import`.
- Git isn't on PATH. Use SourceTree's bundled copy: `%LOCALAPPDATA%\Atlassian\SourceTree\git_local\cmd\git.exe`.
- **Tests:** `tests/run_tests.ps1` runs every `tests/test_*.gd` headless (a full day takes seconds). Run it after gameplay changes, and add a test for each new system. Task and wait times are in shop-clock minutes, so changing the day's length doesn't need retuning.

### Workflow

- Commit locally only, and only when the designer asks; the designer pushes with SourceTree. Make small, focused commits with clear messages. Keep `.godot/` out of version control.
- Plan before building any large feature. Build the smallest playable slice first, then add systems one at a time.

### Project layout

- `scenes/`, `scripts/`, `resources/` (custom `Resource` data), `Assets/` (art, audio, fonts), `tests/`, `docs/` (sprite list), `art_templates/` (drawing guides, ignored by Godot). Organize by feature inside them.
- Files and folders in `snake_case`; classes and nodes in `PascalCase`.

### Where things live

- `world.gd` only connects the systems. Jobs are assigned and run by `WorkManager` (`scripts/work/`); HUD panels are `Hud` (`scripts/ui/`); building is `BuildMode` (`scripts/world/`).
- A new kind of task gets a `TaskBehavior` subclass in `scripts/tasks/behaviors/` (what it fetches, where it's done, what happens to the items), set on its `TaskType` resource.
- A station type is a `StationData` resource (footprint, facings, spots, storage layouts); placed stations are `Station` nodes. Items (pizzas, boxes, containers) are `Item` nodes that can hold other items.
- Money is `ShopFinances` with `Bill` resources; orders are `Ticket`s on the `TicketRack`.

## About this document

Short, high-level design doc covering the basics of the gameplay and mechanics. Numbers, formulas, asset lists and schedules are left out unless the designer has set them; numbers marked as placeholders are there to make the game playable and will be tuned later. Art needs are tracked in [`docs/sprite_list.md`](docs/sprite_list.md).

- **Lead designer:** Vincent Messina
- **Status:** pre-production (playable kitchen prototype)
- **Engine:** Godot 4.7.2 (Forward+), GDScript
- **Platform:** PC (keyboard and mouse)
- **Monetization:** none planned

## Pitch

A cozy, 2.5D isometric pizza parlor management sim in the style of RimWorld. You run the shop by managing a small staff of pawns who work on their own. You never control them directly. You set priorities, tune the menu and operations, and watch the staff, and the drama between them, play out.

- **Art style:** stylized, cozy 2.5D isometric pixel art
- **Audience:** tycoon, management and base-builder players
- **Controls:** mouse and keyboard, with hotkeys and a contextual cursor

## Design pillars

1. **Emergent pawn drama:** staff have personalities, moods and quirks that produce stories.
2. **Tactile kitchen craft:** making pizza should feel physical, readable and satisfying.
3. **Satisfying tycoon scaling:** the shop grows from a small parlor into a bigger operation.

## Core loop

1. **Prep and supply:** before opening, order ingredients, make or buy dough and sauce, and set up the menu (pizzas, sizes, prices).
2. **Service:** open the doors. Orders arrive as printed tickets. Pawns make, bake and serve the pizzas all day, with busier rushes around lunch and dinner.
3. **Close and clean:** clean up after the rush, then review the day.
4. **Reinvest:** use profits to improve the shop, equipment and staff, then repeat.

## Art and grid

- **2D isometric** in a 2D scene (no 3D). The floor grid is a **32×16 diamond** (`TileMapLayer`, diamond-down). Tile art can overhang the grid a little.
- **Pixel perfect:** placed objects, tiles and walls sit on whole art pixels; the camera moves in whole pixels and zooms in whole steps; the game renders at the window's own size (a bigger window shows more of the shop). Only moving things (walking pawns) may sit between pixels.
- **Pawns** use 15×44 frames: walk down-left, walk up-left, and idle and phone poses. Right-facing poses are flipped in code. Pawns move along the grid axes only, so they always face one of the four iso diagonals, and they turn toward the station they're working at.
- **Stations** (tables, counters, racks, ovens) face 4 ways, and their footprint and work spots rotate with them. A facing without its own art uses its mirror image flipped (working side down-left ↔ down-right, up-left ↔ up-right), so one front view gives two facings; back views need their own art.
- **Items** (pizzas, boxes, dough containers) are 1×1. Closed boxes and dough containers stack. Box art has a turned version, so a box's lid always faces away from the pawn working it.
- **Walls** are thin panels on the edges between floor cells. A hotkey cycles full, cutaway (front walls short, the default) and walls down. A doorway is a gap in a wall. For now walls trace the floor's outline; rooms, interior walls and building them come later.

## Core mechanics

Each item below is a direction, not a final spec. "For now" marks placeholder behavior.

### Pawns and work priorities

- Pawns are autonomous. The player sets work priorities per pawn and never gives direct move or work commands.
- **Priority grid:** pawns are rows, broad work types are columns, and each cell is 1–4 (1 first) or blank (never). Columns, left to right:
  - **Kitchen:** stretch, sauce, cheese, load oven, throw out leftovers (later dough and sauce prep).
  - **Oven:** take pizzas out.
  - **Boxing:** set out a box, cut, stack boxes (later folding).
  - **Front:** take orders at the register, carry finished orders to pickup (later service).
  - Driving and Cleaning get columns when they exist.
- An idle pawn takes work by its grid: priority 1 before 2, and the leftmost column wins a tie. Within a work type, it takes the first open job in Make-rack order. Pawns finish their current job before choosing again.
- New hires start with everything blank until the player assigns work. Training is a separate checkbox (see Staff).
- When no manager has line of sight, pawns skip their low-priority work (and slack off).
- Each task type has a fixed base work time for now. Skill and mood will scale it later.
- Pawns with no work wander and sometimes check their phone (placeholder).

### Stations, spots and roles

- Each station has one or more **spots**. A spot is where a pawn stands plus where its item sits, and one pawn uses it at a time. Clicking a station shows its work spots on the floor.
- **Roles (zones, part 1):** tables, counters and racks are general-purpose. The player clicks one to give it a role, either work or storage:
  - Work: Prep (making pizzas), Boxing (boxes, unloading, cutting), Pickup (hand-off).
  - Storage: Boxes, Dough (full dough containers), Empty Dough (empty containers).
  - Or unused. A station either works or stores. Ovens and the garbage can keep a fixed purpose.
- Each station type sets how each stored kind stacks on it (racks have shelf positions; tables stack on each spot).
- For now, Boxes and Dough storage start full and refill the moment they run out (until deliveries exist), and Empty Dough storage clears the moment it fills (until there's a cleaning station).
- Later zone work: storage priority (like RimWorld stockpiles), then painted front/back-of-house areas.

### Orders and the ticket rack

- Orders print as physical tickets from the register. A customer's order waits at the register until a Front pawn takes it (a short "Take order" task), then its ticket prints. With no register, or nobody on Front, customers pile up at the register; the ticket rack shows how many are waiting. Order types are dine-in, to-go, pickup and delivery (only plain pickup-style orders exist for now).
- The **ticket rack** is a HUD panel with **Wait** and **Make** columns. Pawns work the Make tickets in order, so dragging and reordering tickets steers the kitchen indirectly.
- New tickets land in Wait and the player moves them to Make. For now, new tickets go straight to the bottom of Make; the player can still drag them back to Wait.
- Pulling an in-progress ticket back to Wait stops its pawns. Work done so far is kept and resumes when the ticket returns to Make. A pizza being carried at that moment is set down on the floor.
- Each ticket shows its order number, items (e.g. "3 Pizza"), status, how many pizzas are boxed, and the shop minutes since it printed (closed hours don't count). Order type and the ETA come later.
- **Patience:** customers wait 45 shop minutes from when they order, including any time waiting at the register (a ticket's age counts from then). The ticket turns yellow at half that and red in the last fifth. A customer whose order was never taken leaves and the sale is lost. If the order isn't at the pickup counter by then, the customer leaves: the ticket is cancelled, the sale is lost, and anything made for it (pizzas, boxes, a dropped dough container) is thrown out by a Kitchen pawn at the garbage can.
- The player never takes or serves orders by hand: pawns take them at the register, and completed orders go out on their own.
- **Demand (for now):** until customers exist, orders arrive at random while the shop is open: about one every 12 shop minutes, twice as often during the lunch (12:00–13:30) and dinner (18:00–19:30) rushes, and none in the last hour (from 21:00). About 60% are one pizza, 30% two or three, and 10% four to eight (party orders), so roughly 70 orders and 150 pizzas a day. The starting staff keep up between rushes and fall behind during them.

### Making a pizza

- **Recipes:** a menu item is an ordered list of task steps; each step is one job, done by one pawn at one station, so a ticket can be paused between steps. A plain pizza is stretch, sauce, cheese, load oven, set out box, take out of oven, then cut. An order's pizzas are each worked in parallel by whichever pawns are free.
- **Timing target:** like a real shop, one pizza alone takes about 10 shop minutes from ticket to customer. Baking is about 5 of that; prep steps take well under a minute each.
- The pizza is a real item. It sits on a station and pawns carry it between stations. A spot holding another ticket's pizza can't be used.
- **Dough:** dough balls come in lidded containers of 6, stacked in Dough storage. To stretch, a pawn takes a ball from the open container on a Prep spot. If none is open, they first fetch a full one and set it out on a Prep spot (lid off), where it takes up that spot until it's empty. Only one container is set out at a time. The pawn who takes the last ball carries the empty to Empty Dough storage (later, to a cleaning station).
- **Oven:** baking runs on its own; a Kitchen pawn loads the pizza and is free while it cooks. Once it's done, an Oven pawn takes it out and drops it into its open box. Later, when it's taken out will set its doneness (under, perfect, over), modified by Oven skill.
- **Boxes:** pizza boxes arrive as flat sheets that staff fold before use (later). The box rack stores folded boxes. Once the pizza is in the oven, a pawn takes a box from the rack and opens it on an empty Boxing spot. Once the pizza is in the box, a pawn cuts it there (cut lines appear as the work goes) and the box closes.
- A pizza never waits in the oven for a box: if its box isn't open yet, it's set on a free Boxing spot and moved into the box when it's cut. That only happens while a spot would still be free for its box (and the boxes of any other waiting pizzas); otherwise it stays in the oven, so unboxed pizzas can't fill every spot.
- **Stacking and hand-off:** finished boxes stack on the boxing table (up to 8). The order's first closed box stays where it was cut as the stack's base, and a Boxing pawn moves each later box onto it. When the last box joins, a Front pawn carries the whole stack to the pickup counter (later: right away for to-go, or when the customer arrives for pickup). The ticket shows Ready, and after a short wait (placeholder) the order goes out and leaves the rack.

### Pizza crafting and the menu

- Dough and sauce can be bought premade or made from scratch in-house. Premade is convenient but limited in quality. Scratch work depends on ingredient quality and pawn skill.
- The player builds a custom menu: specialty pizzas, crust sizes, toppings and prices.
- A finished pizza's quality comes from its components and how well it was made and baked.

### ETA, reviews and customers

- The player sets the promised wait time with an ETA slider on the HUD. Longer promises ease pressure but cost satisfaction and reviews; missing or beating the promise also affects how customers feel. This builds on patience.
- Demand comes from the shop's reviews: good reviews bring more business, bad ones drive it away. Calendar events raise or lower demand on certain days.
- Delivery uses a driver who leaves the shop and comes back later. Driving is a skill like any other; drivers are regular staff, not a separate hire.
- Dine-in seating is self-serve: customers order, sit down, and a front-of-house pawn brings the food to their table.

### Staff, mood and traits

- Pawns have moods driven by things like stress, fatigue, pay and how they get along with other pawns, which affect speed and quality.
- Pawns have hidden personality traits that are revealed after some shifts. A better manager reveals them faster.
- Pawns can become friends if their personalities jive, or enemies if they don't.
- Experienced pawns want better pay and can ask for raises; unhappiness builds if they don't get one. Pawns quit after being stressed at work for a long time.
- Hiring comes from a stack of resumes the player sorts through. Better reviews bring better applicants.
- **Trainees** shadow a veteran to learn safely, at some cost to the veteran's output. Training is a checkbox on the pawn, not a grid column. A trainee shadows anyone doing work the trainee is also assigned, if that pawn's skill is higher.
- A **manager** must be on shift during open hours. When the shop is quiet and the manager is out of sight, pawns slack off (for example, browsing their phones).

### Time and the day

- A day covers shop hours (10:00 to 22:00) and lasts 30 real minutes at 1x (one shop minute is 2.5 real seconds).
- Speeds are pause, 1x, 3x and 6x (Space and 1/2/3, or the HUD buttons), so a day takes 30, 10 or 5 real minutes. While paused the player can still pan, use the rack and set priorities.
- For now, when a day ends the next starts and work in progress carries on. Prep, close and review phases come later.

### Money and the day report

- Cash shows on the HUD next to the clock. It starts at zero and can go negative for now.
- Each order is paid when it goes out (a plain pizza is $15). Ingredients are paid as they're used (dough ball, sauce, cheese, box). At closing, wages (each pawn's hourly wage for the whole day) and daily bills (rent, electricity, gas, water) are paid. All numbers are placeholders.
- **Day report:** at closing the game pauses on a report: orders served (and pizzas), orders missed (and sales lost), orders still open (they carry over), average and longest ticket time, then sales, each cost, profit and cash. "Start next day" resumes.

### Building the shop

- **Build mode (B):** pick a station type (table, small table, counter, oven, rack, garbage can) and place it. A ghost shows green where it fits and red where it doesn't, along with its work spots. R turns it to each facing it has art for.
- Clicking a station that nothing is using picks it up to move it (stored stock comes along). Delete or the Sell button sells it (anything stored on it goes too).
- A placement doesn't fit if it's off the floor or on another station, its work spots are blocked, it covers another station's work spot, a pawn is standing there, or it would cut anything off.
- For now, building is free, works any time, and selling pays nothing back. Walls and floor building come later.
- Pawn movement depends on the layout, so arranging the kitchen well is part of the game.

### Supply, cleanliness and equipment

- Ingredients arrive in regular recurring deliveries, with an emergency option at a premium. Fresh ingredients spoil, so cold storage matters.
- Kitchens get dirty. Poor cleanliness leads to health inspector penalties.
- Equipment can be upgraded for capacity and reliability.

### Progression and failure

- Progression comes from upgrades: expanding the floorplan and buying newer, better (and more expensive) appliances.
- The player loses by running out of money for wages, bills and rent.

### Onboarding

- New players get an onboarding tutorial, and UI tooltips help first-time players learn the interface.

## Not yet decided

Anything not covered here is undecided, so ask the designer instead of assuming. Known open questions:
- Where and how boxes are folded (a folding station, or at the rack).
- What the cleaning station looks like and who uses it.
- How customers appear in the shop (the register and order taking are in; customers are still invisible).
- Balance: prices, costs, wages, bills and demand are placeholders.
