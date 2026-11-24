# Za: Game Design Document

Instructions for Claude Code (rules, tools, workflow and a map of the code) are in [`CLAUDE.md`](CLAUDE.md).

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
- **Priority grid:** pawns are rows, work types are columns, and each cell is 1–4 (1 first) or blank (never). Each column except Hauling is also a skill (see Staff). Columns, left to right:
  - **Dough stretching:** stretch the dough.
  - **Pizza making:** sauce (and swap an empty sauce bucket), cheese (later toppings), load the oven.
  - **Oven:** take pizzas out.
  - **Cutting:** cut the pizza in its box.
  - **Box folding:** fold boxes.
  - **Cashier:** take orders at the register.
  - **Cleaning:** wash dishes at the dish sink.
  - **Hauling** (no skill): set out a box, stack boxes, carry finished orders to pickup, throw out leftovers, put dough containers away, take dishes to the sink and put clean ones away.
  - Later: Dough making, Sauce making, Driving, Service (dine-in), Managing.
- An idle pawn takes work by its grid: priority 1 before 2, and the leftmost column wins a tie. Within a work type, it takes the first open job in Make-rack order. Pawns finish their current job before choosing again.
- New hires start with everything blank until the player assigns work. Training is a separate checkbox (see Staff).
- When no manager has line of sight, pawns skip their low-priority work (and slack off).
- Each task type has a base work time, scaled by the pawn's skill in its column and by their mood and the rush (see Staff).
- **Skills:** every column except Hauling is a skill, leveled 0–20. Level 10 works at the base time, level 0 takes twice as long and level 20 half as long (straight lines between). Pawns learn by doing: each shop minute worked is practice, and level L to L+1 takes (L+1)×10 minutes. Starting pawns roll 4–10 in each skill. The priority grid shows each pawn's level in the corner of each cell. All numbers are placeholders.
- **Pawn panel:** clicking a pawn shows them in the inspect panel (see Staff): traits, needs, mood effects, opinions, and their skills (each level and a bar of practice toward the next). Pay comes later.
- **Selecting:** a click selects whatever is drawn in front at that pixel (a pawn, an item or any station); see-through parts of the art aren't clickable. Clicking an item (on a station, the floor or in someone's hands) shows its name and quality: a pizza shows its tier so far while it's being made, then its final tier; an ingredient shows the ingredients' quality, and a container what's left in it. Freshness will show here once it's tracked.
- Pawns with no work wander and sometimes check their phone (placeholder).

### Stations, spots and roles

- Each station has one or more **spots**. A spot is where a pawn stands plus where its item sits, and one pawn uses it at a time. Clicking a station shows its work spots on the floor.
- **Roles (zones, part 1):** tables, counters and racks are general-purpose. The player clicks one to give it a role, either work or storage:
  - Work: Prep (making pizzas), Boxing (boxes, unloading, cutting), Pickup (hand-off).
  - Storage: Boxes (folded), Flat Boxes, Dough (full dough containers), Empty Dishes (empty dough containers and sauce buckets, the overflow while the dish sink is full). A box pallet holds Flat Boxes from the start: 240 (20 bundles, about two days' worth; placeholder).
  - Or unused. A station either works or stores. Ovens, the dish sink and the garbage can keep a fixed purpose.
  - Changing a station's role stops the pawns using it (like picking it up); their jobs keep their progress and go elsewhere.
- Each station type sets how each stored kind stacks on it (racks have shelf positions; tables stack on each spot).
- **Surfaces (built in slices; so far each spot's main item sits in its work area, side items like the sauce bucket sit in side areas, a role can bring its own side items (a table set to Boxing gets a pizza cutter between its pizzas, just for show for now, gone when the role changes; a one-spot table has no room for one), and items draw back to front):** tabletops are split into an 8×8 grid of slots per cell (4×2 px each), and items take a footprint of slots (a pizza, box or dough container 6×6, a cutter or ladle 2×4, a sauce bucket or flat pan 2×2), so different things share a table without overlapping. Nothing shares a slot; items draw back to front, so one in front may hide part of one behind. Placement is automatic: each spot has a work area for its main item, centered on its cell with a little room all round, and each station type defines side areas in the leftover gaps (e.g. the sauce bucket and the Boxing cutter between two pizzas). Only items of the same kind stack. Storage becomes placed items too, so one tile can hold several kinds, and storage roles become filters. Dishes can stand on their side (fewer slots, no stacking) only in a dish rack.
- For now, Flat Boxes and Dough storage start full and refill the moment they run out (until deliveries exist); Boxes storage starts empty and is filled only by folding, and Empty Dishes storage only empties as Hauling pawns take its dishes to the dish sink.
- Later zone work: storage priority (like RimWorld stockpiles), then painted front/back-of-house areas.

### Orders and the ticket rack

- Orders print as physical tickets from the register. A customer's order waits at the register until a Cashier pawn takes it (a short "Take order" task), then its ticket prints. With no register, or nobody on Cashier, customers pile up at the register; the ticket rack shows how many are waiting. Order types are dine-in, to-go, pickup and delivery (only plain pickup-style orders exist for now).
- The **ticket rack** is a HUD panel with **Wait** and **Make** columns. Pawns work the Make tickets in order, so dragging and reordering tickets steers the kitchen indirectly.
- New tickets land in Wait and the player moves them to Make. For now, new tickets go straight to the bottom of Make; the player can still drag them back to Wait.
- Pulling an in-progress ticket back to Wait stops its pawns. Work done so far is kept and resumes when the ticket returns to Make. A pizza being carried at that moment is set down on the floor.
- Each ticket shows its order number, items (e.g. "3 Pizza"), status, how many pizzas are boxed, and the shop minutes since it printed (closed hours don't count), plus the manager's quoted wait (see ETA). Order type comes later.
- **Patience:** customers wait until 20 shop minutes past the manager's quoted wait (placeholder; 45 minutes for an unquoted order), counted from when they order, including any time waiting at the register (a ticket's age counts from then). The ticket turns yellow at half that and red in the last fifth. A customer whose order was never taken leaves and the sale is lost. If the order isn't at the pickup counter by then, the customer leaves: the ticket is cancelled, the sale is lost, and anything made for it (pizzas, boxes, a dropped dough container) is thrown out by a Hauling pawn at the garbage can.
- The player never takes or serves orders by hand: pawns take them at the register, and completed orders go out on their own.
- **Demand (for now):** customers arrive at random while the shop is open: at a 3.0 rating, about one every 15 shop minutes, twice as often during the lunch (12:00–13:30) and dinner (18:00–19:30) rushes, and none in the last hour (from 21:00). About 60% are one pizza, 30% two or three, and 10% four to eight (party orders), so roughly 55 orders and 110 pizzas a day. The starting staff keep up between rushes and fall behind during them.

### Making a pizza

- **Recipes:** a menu item is an ordered list of task steps; each step is one job, done by one pawn at one station, so a ticket can be paused between steps. A plain pizza is stretch, sauce, cheese, load oven, set out box, take out of oven, then cut. An order's pizzas are each worked in parallel by whichever pawns are free.
- **Timing target:** like a real shop, one pizza alone takes about 10 shop minutes from ticket to customer. Baking is about 5 of that; prep steps take well under a minute each.
- The pizza is a real item. It sits on a station and pawns carry it between stations. A spot holding another ticket's pizza can't be used.
- **Dough:** dough balls come in lidded containers of 6, stacked in Dough storage. To stretch, a pawn takes a ball from the open container on a Prep spot. If none is open, they first fetch one and set it out on a Prep spot (lid off), where it takes up that spot. Only one container is set out at a time. The pawn who takes the last ball carries the empty to the dish sink's dirty drainboard (or Empty Dishes storage if it's full). Once no pizza is waiting to be stretched, a Hauling pawn with nothing else to do puts the lid back on and takes the container back to Dough storage with what's left in it; the next one taken out is that partly used one.
- **Sauce:** the prep table has a sauce bucket in the slot between its first two pizza spots. Each sauce step takes a portion (a full bucket does 20 pizzas, placeholder; bigger pizzas will take more later), and its sauce level drops through 5 steps. A table set to Prep has no bucket and sauces as before.
- **Sauce bucket swap:** the prep table's cooler (hidden storage built into the table) holds 1 spare bucket, so each prep table has 2 that cycle. When the bucket is empty, the next Pizza making pawn to sauce there swaps it first: they take the empty to the dish sink's dirty drainboard (or Empty Dishes storage if it's full), take the spare from a cooler, set it out and sauce. With no spare (it's still being washed), saucing there waits. A washed bucket goes back to a cooler and counts as full (no auto-refill). Later, buckets are refilled from a larger bucket of scratch-made sauce kept in the walk-in cooler.
- **Oven:** baking runs on its own; a Pizza making pawn loads the pizza and is free while it cooks. Taking it out is offered to Oven pawns 1 shop minute before it's done (so nobody stands at the oven for the whole bake); once it's done, an Oven pawn takes it out and drops it into its open box.
- **Pizza rack:** while every oven spot is taken, the Pizza making pawn parks the made pizza on a free rack slot (one pizza per slot, tightly packed), freeing the prep table. It's loaded from the rack, in ticket order, once an oven spot frees up.
- **Doneness:** a pizza is perfect for 2 shop minutes after it's done, and over after that. The Oven pawn takes it out when they think it's ready: they aim for the middle of that window but are off by a random amount, up to ±1.5 minutes at skill level 0, ±0.5 at level 10 and none at 20. Too early is under (taken out mid-bake), too late is over, and a pizza left in with nobody free to take it out burns. For now doneness only shows as a pizza tint (pale or dark) and is tracked per pizza; later it will affect reviews. All numbers are placeholders.
- **Boxes:** pizza boxes arrive flat, stacked on a pallet next to the boxing tables. When a Box folding pawn has nothing else to do at any priority, they stand at the pallet, fold a box in hand and carry it to Boxes storage (the box rack), all as one Fold box job, until the rack is full. Only one pawn folds at a time. Folding never uses a Boxing spot, so it can't hold up orders. Once the pizza is in the oven, a pawn takes a folded box from the rack and opens it on an empty Boxing spot. If there are no folded boxes, they take a flat one from the pallet and fold it there on the spot, which takes longer. Once the pizza is in the box, a pawn cuts it there (cut lines appear as the work goes) and the box closes.
- A pizza never waits in the oven for a box: if its box isn't open yet, it's set on a free Boxing spot and moved into the box when it's cut. That only happens while a spot would still be free for its box (and the boxes of any other waiting pizzas); otherwise it stays in the oven, so unboxed pizzas can't fill every spot.
- **Stacking and hand-off:** finished boxes stack on the boxing table (up to 8). The order's first closed box stays where it was cut as the stack's base, and a Hauling pawn moves each later box onto it. When the last box joins, a Hauling pawn carries the whole stack to the pickup counter (later: right away for to-go, or when the customer arrives for pickup). The ticket shows Ready, and once its customer picks it up the order goes out and leaves the rack.

### Pizza crafting and the menu

- Dough and sauce can be bought premade or made from scratch in-house. Premade is convenient but limited in quality. Scratch work depends on ingredient quality and pawn skill.
- The player builds a custom menu: specialty pizzas, crust sizes, toppings and prices.
- A finished pizza's quality comes from its components and how well it was made and baked.
- **Food quality:** each pizza gets a hidden score (0–100), shown as a tier: Poor (under 40), Okay (40–59), Good (60–79) or Great (80+). The score starts from the ingredients' quality (premade for now, 50) and is adjusted by:
  - **Skill:** the average skill of the pawns who did its hands-on steps (stretch, sauce, cheese, cut) adds (level − 10) × 2, so −20 at level 0 and +20 at level 20.
  - **Doneness:** perfect +10, under or over −15.
  - **Freshness:** ingredients lose freshness while they're out of cold storage (the walk-in or a cooler). For now that's the dough: its container loses 1 point per 5 shop minutes out, up to −20, and a ball takes the container's freshness when it's taken out.
  - The ticket shows the order's quality (its worst pizza's tier) once it's ready. All numbers are placeholders.

### ETA, reviews and customers

- **ETA:** there's no ETA slider. The manager quotes each order's wait when it's placed, and the quote shows on the ticket. The quote starts from a queue-aware estimate (the recipe's time, plus the work already on the Make rack spread across the pawns who can do it, adjusted for their skills, plus the recent average walk per job, so a spread-out layout quotes longer), and the manager's error shrinks as their Managing skill grows: up to ±50% of the estimate at level 0, ±15% at level 10 and none at 20 (placeholders). Missing or beating the quote affects satisfaction and reviews, and customers give up 20 minutes past it (see Patience).
- **Reviews:** every customer reviews their order, 1–5 stars. A review starts at 5 and loses 1 star if the order was later than quoted (2 if more than 10 minutes late), 1 if the wait was over half their patience, 1 if any pizza was under and 1 if any was over, and 1 if any pizza was Poor; an order of all Great pizzas wins one lost star back (never below 1 or above 5). Customers who leave (order never taken, or not ready in time) give 1 star. Reviews also note complaints (late, long wait, undercooked, overcooked, poor food, left) and compliments (ready when promised, every pizza perfect, great food).
- **Rating:** the shop's rating starts at 3.0 and each review moves it 5% of the way toward its stars, so recent reviews count most. Each order's food quality also moves it 2% of the way toward 2 (Poor), 3 (Okay), 4 (Good) or 5 (Great) stars. It shows on the HUD next to cash. The day report lists today's reviews, their average, the rating, and the top 3 complaints and compliments.
- **Demand:** the order rate scales with rating ÷ 3 (1 star brings a third as many orders, 5 stars 1.67×). Later, calendar events raise or lower demand on certain days. All review numbers are placeholders.
- Delivery uses a driver who leaves the shop and comes back later. Driving is a skill like any other; drivers are regular staff, not a separate hire.
- **Customers (to-go, first slice):** each order is a visible customer (pawn art with a random shirt color, placeholder). They come in the front door and join a line at the register. If 10 are already in line (placeholder), they turn around and leave: the sale is lost, with no review. After ordering they stand somewhere in the lobby. Once their order is on the pickup counter they walk up, take it, pay and walk out the front door. A customer who gives up (in line or waiting) walks out the front door. No mood icons yet.
- Dine-in seating is self-serve: customers order, sit down, and a front-of-house pawn brings the food to their table.

### Staff, mood and traits

- Pawns have moods driven by things like stress, fatigue, pay and how they get along with other pawns, which affect speed and quality (inspired by RimWorld's needs and mood effects).
- **Mood (first slice):** each pawn's mood (0–100) drifts toward a target: 50, minus up to 40 for stress, plus any timed mood effects (e.g. "Survived the rush", +8 for 2 hours). Happy (70+) works 10% faster and cooks as if 2 skill levels higher; Stressed (under 30) works 10% slower and 2 levels lower. Under 15 a pawn has a breakdown: they finish their job, then stand on their phone for 20 minutes (at most once an hour).
- **Rush:** the shop rushes on its own when unfinished tickets outnumber 2 per pawn or any ticket is past its quote, and stops after 5 calm minutes. While rushing, pawns work 25% faster, but stress (0–100) builds 1.5 a minute for pawns on a job; it eases 1 a minute once the rush is over (and during a breakdown). A RUSH tag shows on the HUD, and pawns who worked it get "Survived the rush" when it ends.
- **Energy and breaks:** energy (0–100) drains 0.25 a minute on a job (twice that in a rush) and is full again each morning. Under 40 it lowers mood (up to −20 at 0), and under 15 the pawn works 15% slower. A pawn under 30 energy takes a 15-minute break once the shop isn't rushing (under 10, even in a rush). A table set to the **Break** role is a break table: one pawn per spot, +5 energy a minute. With no free break spot they rest standing on their phone (+2 a minute). Either way they take no work meanwhile, stress eases, and they get "Took a break" (+5 mood for an hour). All numbers are placeholders.
- **Pawn bar:** a row of pawn cards along the top of the screen (RimWorld-style): each has the pawn's portrait, name, a mood bar colored by mood band, and their most pressing status (Breakdown, On break, Exhausted, Tired, Stressed), with details on hover. Clicking a card selects the pawn, and double-clicking also centers the camera on them. The clock bar sits in the top-left corner.
- **Traits (first slice):** each pawn rolls 2 traits, never two opposites: **Calm** (stress builds at half the rate) or **Nervous** (1.5×), and **Hard worker** (10% faster, checks their phone half as often) or **Lazy** (10% slower, twice as often). For now they're shown openly in the pawn panel and on hover in the pawn bar; hiding them until revealed comes later. All numbers are placeholders.
- **Social (first slice):** each pawn has a social need (0–100, starting at 50) and an opinion (−100 to +100, starting at 0) of each other pawn. Every pair has a hidden chemistry (rolled −0.5 to +0.5, +0.25 for each trait they share, −0.25 for each pair of opposite traits). While two pawns are within 2 cells of each other, their opinions of each other move by chemistry per minute, and company fills social (more with someone they like; someone they dislike drains it). Alone, social slowly drains. Social above or below 50 moves mood by up to ±10. Opinions of +50 or more make friends, −50 or less rivals. A third trait pair, **Chatty** (needs company twice as much) or **Loner** (half as much), joins the others; pawns roll 2–3 traits. The pawn panel shows social and opinions, and a lonely pawn's card says "Lonely". All numbers are placeholders.
- **Bottom bar and inspect panel (RimWorld-style):** a bar along the bottom has Priorities (P), Build (B), Supplies and Report buttons. Each opens its window just above the bar, one at a time (opening one closes the other); Report reopens the last day's report. Whatever is selected (a pawn, station or item) shows in one inspect panel in the bottom-left corner. A pawn's has their name and traits over tabs: Needs (mood, stress, energy, social, and any break or breakdown), Mood (mood effects), Social (opinions) and Skills.
- Later mood factors: a messy kitchen, the break area, pay.
- Pawns have hidden personality traits that are revealed after some shifts. A better manager reveals them faster.
- Pawns can become friends if their personalities jive, or enemies if they don't.
- Experienced pawns want better pay and can ask for raises; unhappiness builds if they don't get one. Pawns quit after being stressed at work for a long time.
- Hiring comes from a stack of resumes the player sorts through. Better reviews bring better applicants.
- **Trainees** shadow a veteran to learn safely, at some cost to the veteran's output. Training is a checkbox on the pawn, not a grid column. A trainee shadows anyone doing work the trainee is also assigned, if that pawn's skill is higher.
- A **manager** must be on shift during open hours (a requirement, not optional). The manager is also a regular worker, and needs higher pay to stay satisfied. They quote order wait times (see ETA). The player picks the manager with a checkbox next to each pawn in the priority grid (one at a time). Managing is a skill (0–20) that grows with each order quoted (1 shop minute of practice per quote, placeholder). One starting pawn is the manager. With no manager, the shop doesn't open: no orders come in. When the shop is quiet and the manager is out of sight, pawns slack off (for example, browsing their phones).

### Time and the day

- Day 1 is a Monday, and the clock shows the weekday (e.g. "Mon, Day 1").
- A day covers shop hours (10:00 to 22:00) and lasts 30 real minutes at 1x (one shop minute is 2.5 real seconds).
- Speeds are pause, 1x, 3x and 6x (Space and 1/2/3, or the HUD buttons), so a day takes 30, 10 or 5 real minutes. A debug 12x (key 4) is there for testing. While paused the player can still pan, use the rack and set priorities.
- For now, when a day ends the next starts and work in progress carries on. Prep, close and review phases come later.

### Money and the day report

- Cash shows on the HUD next to the clock. It starts at zero and can go negative for now.
- Each order is paid when it goes out (a plain pizza is $18). Supplies are paid when delivered (see Deliveries): dough ball $0.80, sauce $0.40, cheese $1.50, box $0.60 per portion. Daily bills: rent $120, electricity $60, gas $40, water $15; wages $15 an hour. At closing, wages (each pawn's hourly wage for the whole day) and daily bills (rent, electricity, gas, water) are paid. All numbers are placeholders.
- **Day report:** at closing the game pauses on a report: orders served (and pizzas), orders missed (and sales lost), orders still open (they carry over), average and longest ticket time, reviews (see Reviews), then sales, each cost, profit and cash. "Start next day" resumes.

### Building the shop

- **Build mode (B):** pick a station type (prep table, table, small table, counter, register, small oven, pizza oven, pizza rack, rack, box pallet, garbage can, dish sink, walk-in in three sizes, bulk sauce bucket, bulk dough tub, delivery pallet) and place it.
- The **prep table** (3×2) is where pizzas are made: three spots along its cutting board, set to Prep. Its ingredient lids open when a pizza there gets its first ingredient (sauce) and stay open until its last (cheese) is done. Its cooler and ingredient pans are art only until ingredients exist. A ghost shows green where it fits and red where it doesn't, along with its work spots. R turns it to each facing it has art for.
- Clicking a station picks it up to move it, even while it's in use: what's on it (pizzas, boxes, stacks, a pizza baking) and its stored stock come along. While it's picked up nobody uses it: pawns working at it or on their way to it stop, setting down anything they carry, and pick their jobs back up (progress kept) once it's put down. Delete or the Sell button sells it (anything stored on it goes too), but only once nothing sits on its spots.
- A placement doesn't fit if it's off the floor or on another station, its work spots are blocked, it covers another station's work spot, a pawn is standing there, or it would cut anything off.
- For now, building is free, works any time, and selling pays nothing back. Walls and floor building come later.
- Pawn movement depends on the layout, so arranging the kitchen well is part of the game.
- **Starting shop** (placeholder layout): an 18×10 kitchen with an 18×4 lobby along its front, split by a wall. The register and pickup counter sit in that wall, worked from the kitchen side; a staff door at one end joins the two, and the front door opens into the lobby. Customers line up and wait in the lobby, and idle pawns don't wander into it. The kitchen runs back to front: the walk-in in the back corner, then along the back wall the prep table, a pizza rack and two pizza ovens. In front of them is the boxing line (garbage can, two Boxing tables, box pallet, box rack), with a third Boxing table in front of the walk-in, then the counter. The dish sink stands along the side wall, with Empty Dishes storage at its end and Clean Dishes storage in front of the walk-in. The back corner across from the walk-in holds four delivery pallets, by a back door, and a table set to Break stands in the front corner on that side.

### Supply, cleanliness and equipment

- Ingredients arrive in regular recurring deliveries, with an emergency option at a premium (later). Fresh ingredients spoil, so cold storage matters (spoilage comes with deliveries, not before).
- **Deliveries (first slice):** cheese bags, flat boxes, bulk sauce and bulk dough come only from deliveries; nothing refills itself. A delivery comes Monday, Wednesday and Friday at opening and auto tops up: it brings enough of each item to reach the player's target. A **supply panel** (the Supplies button on the bottom bar) lists each item's stock in the shop, its target (starting at what its storage holds; + and − change it by one case) and the next delivery day. Cases land on a **delivery pallet** (a placeable station; the starting shop has four in the back corner by a back door), and Hauling pawns put them away. The order is paid when it arrives, at each unit's portions times its per-use price (placeholders). A case is one storage unit: 3 cheese bags, a bundle of 12 flat boxes, 60 sauce portions or 24 dough balls; sauce and dough cases are poured straight into their bulk tub. There's no driver yet: at opening the cases appear on the pallet. The starting shop opens with its storage and bulk tubs full; storage built later starts empty. The pallet holds 12 cases; cases wait there until their storage has room, and a top-up never orders more than fits. Emergency orders come later.
- **Bulk dough:** a bulk dough tub in the walk-in, like the bulk sauce bucket. A Hauling pawn fills a clean dough container there (0.5 shop minutes, placeholder) and takes it to Dough storage; deliveries refill the tub. The bulk sauce bucket holds 300 portions (15 fills) and the bulk dough tub 240 dough balls (40 fills), about two days' worth (placeholders), and an empty one can't fill anything.
- **Walk-in cooler:** a placed station that pawns walk into through its door. It comes in three sizes: 3×3, 4×4 and 5×4 (door included). It holds the bulk cold items: dough containers, the bulk sauce bucket and bags of cheese. Its walls stand on the edges of its footprint, so its whole inside is floor. The player builds regular racks inside it in any layout, and a rack can be set to Dough storage only while it stands in a walk-in (moved out, it loses the role). Moving a walk-in carries everything inside it, stock included; it can only be sold empty. Nothing can stand across its wall. Idle pawns don't wander in. Dough is stored only in the walk-in: the open container still sits on the prep table while it's in use and goes back once no orders need it (this will tie into freshness later). Its walls follow the shop's wall view toggle. The starting kitchen has a 4×4 walk-in with one Dough rack inside, in place of the old dough rack.
- **Clean dishes:** every washed dish goes from the sink's clean drainboard to Clean Dishes storage (a rack role, anywhere), and is filled or put away from there.
- **Bulk sauce:** the bulk sauce bucket is a small station placed on the floor (anywhere for now). A Hauling pawn takes a clean sauce bucket from Clean Dishes storage, fills it at the bulk bucket (0.5 shop minutes, placeholder) and puts it in a prep table's cooler. With no bulk bucket, clean sauce buckets wait in Clean Dishes storage. Deliveries refill the bulk bucket until scratch sauce exists. The starting kitchen has one in the walk-in and a Clean Dishes rack by the sink.
- **Cheese:** the prep table's cheese pan (part of its art) does 30 pizzas (one bag). Once 3 or fewer are left, a Hauling pawn takes a bag from a Cheese rack (a rack role offered only inside a walk-in), refills the pan in place (0.25 shop minutes) and throws the empty bag in the garbage. With the pan empty, the cheese step waits. Clicking the prep table shows how much is left. All numbers are placeholders; the starting walk-in has a Cheese rack. Toppings come later with the custom menu.
- Kitchens get dirty. Poor cleanliness leads to health inspector penalties.
- **Dish sink** (5×1, three compartments): from the worker's left, a dirty drainboard, wash, rinse and sanitize basins, and a clean drainboard (6 dishes each, placeholder). For now the dishes are empty dough containers and sauce buckets. A Cleaning pawn washes in batches: they take every dish on the dirty board (as many as fit on the clean one), which disappear while worked, wash them all, rinse them all, sanitize them all (0.5, 0.25 and 0.25 shop minutes per dish, placeholders), then set them on the clean board. Hauling pawns take empties from Empty Dishes storage to the dirty board, and clean ones to Clean Dishes storage, then back to their storage, filled on the way (dough containers at the bulk dough tub, then to Dough storage; sauce buckets at the bulk bucket, then to a prep table's cooler). The starting kitchen has one.
- **Planned dishes** (later slices, each designed before it's built): pizza screens (dirtied when a pizza is loaded into the oven from the rack), sauce ladles and pizza cutters (dirtied after a number of uses), and sauce/topping pans (swapped out when empty, once ingredients exist). Clean ones go to a storage role per kind.
- Equipment can be upgraded for capacity and reliability.

### Progression and failure

- Progression comes from upgrades: expanding the floorplan and buying newer, better (and more expensive) appliances.
- The player loses by running out of money for wages, bills and rent.

### Onboarding

- New players get an onboarding tutorial, and UI tooltips help first-time players learn the interface.

## Not yet decided

Anything not covered here is undecided, so ask the designer instead of assuming. Known open questions:
- Call-ahead pickup, dine-in and delivery customers.
- Balance: prices, costs, wages, bills and demand are placeholders.
