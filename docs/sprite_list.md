# Sprite list

A suggested list of the sprites Za needs, most important first. The order follows the build order: finish the pizza loop, then service, then staff life. These are only suggestions. Anything marked **TBD** is a design call for the designer.

Guide sheets for drawing are in [`art_templates/`](../art_templates). See [How to use the templates](#how-to-use-the-templates).

## Already have

- Pawn walk (down-left, up-left), idle and phone: `pawn_sheet.png` (laid out on the 7-row guide; rows 4–7 still empty)
- Floor tiles ×3: `tile_placeholder.png`
- Small table (1×1), long table (2×1, two facings), rotation test cube, bin: `Object_Spritesheet.png`
- Walls: `walls_sheet.png`. Back-left, back-right, back corner, front-left, front-right, front corner, and capped left/right side corners, each full height and short. `walls_with_reference.png` shows each on its floor tile.
- Small oven (1×1, one facing): `Small_Oven.png`
- Pizza stages (dough ball, dough, sauce, cheese, baked) and 4 cut-line frames above them: `pizza_sheet.png`. Cut lines are drawn 16 px above where they land on the pizza.
- Pizza box: `box_sheet.png`, on a 32×16 grid. Left column: closed box (row 1), open box back with lid on the back-left edge (rows 2–3), its front edge (row 4). Right column, turned a quarter: closed box (row 1), front edge with the lid standing on the front-right edge (rows 2–3, drawn over the pizza), open box back (row 4). Items worked from in front use the left column (mirrored for a pawn down-left); from behind, the right column (mirrored for a pawn up-right), so the lid always faces away from the pawn. The pieces are `resources/items/box/*.tres`, paired in `resources/items/rotated_art.tres`.
- Work-spot marker (pink iso circle): `work_spot_sheet.png`, drawn on the 3×3 guide with the station in the middle cell and the circle on the pawn's side (frames: down-left, up-left, up-right, down-right). Shown on the floor where pawns stand at a selected station.
- Sauce bucket: `sauce_bucket_small.png`, 32×16 cells like the pizza stages. Sauce levels full to nearly empty in row 1 (4 frames) and row 2 frame 1, drawn under the see-through bucket in row 4 frame 1. Takes 1 surface slot. `resources/items/sauce_bucket.tres`.
- Pizza cutter (placeholder): `pizza_cutter.png`, two 32×64 item frames: handle toward a pawn down-right (lying up-left to down-right), then turned for a pawn behind (handle up-left), paired in `rotated_art.tres`. Takes 1×2 surface slots between a Boxing table's pizzas. `resources/items/pizza_cutter.tres`.
- Dough container (lid, inside/back, front edge; 32×16 cells stacked in that order, same anchor): `dough_container.png`. Holds 6 dough balls.
- Box rack, original one-facing art: `box_rack_sheet.png` (no longer used; replaced by the placeholder below)
- Pickup counter (1×1, one facing): `Object_Spritesheet.png` at (128, 0). In game the counter currently uses the numbered rotation-test cubes on row 2 (four facings, "1|2" to "4|1") to check rotation.
- Facings: a station's facings 0 (working side down-left) and 3 (down-right) are mirror images, as are 1 and 2 (the back views). Drawing one front view gives both front facings by flipping; draw a back view to allow the back facings.

## Generated art (in use)

- `stations/three_sink_sheet.png`: three-compartment dish sink, 5×1 (5 cells along the working side), 96×96 per facing (0–3 left to right, all four drawn, not mirrored, so the sides stay correct). From the worker's left: dirty-dish drainboard, wash (soapy), rinse, sanitize basins, clean-dish drainboard. Drainboards are at table height (16 px). Used by the Dish Sink station. Dirty dishes on it are the clean art tinted (placeholder until dirty art).

## Placeholders (generated, to be redrawn)

Script-drawn stand-ins in `Assets/Sprites/placeholder/`, using the same palette and grid as the art above. The oven, register, flat boxes, pallet, prep table, pizza rack and box rack are used in game; the rest aren't wired up yet.

- `oven_2x2_sheet.png`: 2×2 oven, 64×80 per facing (0–3 left to right). Row 1 closed, row 2 baking (glowing window). Used by the Pizza Oven station.
- `register_sheet.png`: register and ticket printer on the pickup-counter base, 32×48 per facing. Used by the Register station.
- `chair_sheet.png`: wooden chair, 32×48 per facing. Facing is the way the sitter faces.
- `fridge_sheet.png`: reach-in fridge, 32×64 per facing (on the 1×1 guide).
- `dough_mixer_sheet.png`: floor mixer, 32×48 per facing.
- `box_flat_sheet.png`: 32×16 cells like `box_sheet.png`. A single flat box (used: stacked on the pallet, carried while folding), then a strapped bundle of flats (unused).
- `pallet_sheet.png`: wooden pallet, 1×1, 32×48 per facing. Used by the Box Pallet station, which holds flat boxes next to the boxing tables.
- `prep_table_sheet.png`: pizza prep table (refrigerated make table), 3×2 (3 cells along the working side, 2 deep), 80×96 per facing on `object_3x2_guide.png`. Front row: white cutting board at table height, where pizzas are assembled. Back row: raised rail with 8 ingredient pans (sauce, cheese ×2, pepperoni, mushroom, pepper, olives, onion). Cooler doors and compressor below. Row 1 lids open (shown while it's in use), row 2 lids closed. Used by the Prep Table station.
- `pizza_rack_sheet.png`: sheet-pan style pizza rack on casters, 1×1, 32×80 per facing (0–3 left to right). Row 1 is the base (back frame, drawn under stored pizzas), row 2 the cover (front post and front rail ends, drawn over them). Open on the working side and the back, so facings 0 and 2 share art, as do 1 and 3. 17 slots, 3 px apart (first at 9 px, last at 57 px above the floor), one pizza per slot. Used by the Pizza Rack station.
- `box_rack_sheet.png`: chrome wire shelving, 2×1, 48×64 frames drawn at facing 3. Frame 1 is the base (back and side posts, bottom shelf 3 px up), frame 2 the cover (top shelf 25 px up, front post). Open on both long sides, so facing 1 reuses facing 3's art and 0 and 2 are its mirror image. Used by the Rack station at all four facings.
- `pizza_screen.png`: 32×16, laid out like the pizza stages. A pizza screen drawn under each pizza on the rack, so stacked layers read apart.
- `ingredient_icons.png`: on the 16×16 item guide. Dough, sauce, cheese, pepperoni, mushroom, olives.

## Priority 1: the pizza loop (next slices)

| # | Sprite | Guide | Notes |
|---|--------|-------|-------|
| 1 | Pawn **work** animation (down-left, up-left) | pawn rows 4–5 | Pawns currently stand idle while working. |
| 2 | Pawn **carry** walk (down-left, up-left) | pawn rows 6–7 | For carrying pizzas and boxes between stations. |
| 3 | **Oven** | object 2×2 | Drawn in the middle of its 4 tiles, leaving room to spare around it. Open and closed or "baking" states are nice to have. |
| 4 | **Pizza box**: flat sheet | object 1×1 | Placeholder in use (`box_flat_sheet.png`). Pawns fold flats at the box pallet; a folding animation would help. |
| 5 | **Box pallet** and **box rack** (real art) | object 1×1, 2×1 | Folding happens standing at the box pallet, next to the boxing tables; the pallet uses a placeholder. |
| 6 | **Register** (prints tickets) | object 1×1 or 2×1 | Where orders come from. |
| 7 | **Doorway pieces** (door frames or wall end caps), full and short; optional cutaway side corners (full back wall joined to a short front wall) | `walls_with_reference.png` | Doors are gaps for now. |
| 8 | Kitchen floor vs. dining floor tiles | your tile layout | Your current tiles already work on the grid. |

## Priority 2: service and customers

| # | Sprite | Guide | Notes |
|---|--------|-------|-------|
| 12 | **Customer** pawns | pawn sheet | Same layout as staff, so the code works unchanged. |
| 13 | Pawn **sit** and **eat** (down-left, up-left) | pawn sheet, extra rows | For dine-in. |
| 14 | **Chair** (4 facings) | object 1×1 | Dining tables already exist. |
| 15 | **Dough station** (mixer) and **sauce station** | object 1×1 or 2×1 | Scratch prep. |
| 16 | **Fridge / walk-in cooler**, dry shelf, ingredient crates | object 1×1 to 2×2 | Cold storage matters for spoilage. |
| 17 | Ingredient items: dough, sauce, cheese, toppings | item 16×16 | Also usable as menu icons. |
| 18 | **Delivery** vehicle, or a driver exiting through the door | **TBD** | Depends on how delivery is shown. |

## Priority 3: staff life and management

| # | Sprite | Guide | Notes |
|---|--------|-------|-------|
| 19 | Pawn variety: hair and shirt variants, manager and trainee looks | pawn sheet | Palette swaps of one base are the cheapest route. |
| 20 | ~~Pawn **slacking on phone** idle~~ | done | In the idle row, frames 5–8. |
| 21 | Mood / thought bubbles: happy, stressed, tired, angry, friend, enemy | item 16×16 | Drawn above pawns. |
| 22 | Mess: floor dirt decals, spills, trash can, sink, mop | 1×1 decals, item 16×16 | Cleanliness and inspections. |
| 23 | **Health inspector** | pawn sheet | |
| 24 | Upgraded equipment tiers (better ovens and so on) | object guides | |
| 25 | Decor | object guides | |

## UI (no pixel templates; sizes depend on the HUD layout)

- Ticket card, rack panel frame
- HUD: money, clock / day phase, speed controls (pause, 1×, 2×, 3×), ETA slider
- Work-priority grid cells, resume card, end-of-day summary
- Cursors: default, pointer, drag, plus contextual cursors (GDD)
- Tooltip frame

## How to use the templates

The guides are colored backgrounds to draw over. In Aseprite, open the guide, add a new layer above it, draw on that layer, and **hide or delete the guide layer before exporting**. You can also bring a guide into an existing file with *Layer → New Reference Layer from File*. The `art_templates/` folder has a `.gdignore`, so Godot won't import the guides.

**Pixel-perfect rule:** floor tiles are drawn centered on their cell, so keep each tile's frame an **even width and height** (the floor tile is 34×22; its bottom row is empty padding). An odd size puts the whole floor half a pixel off from everything else. Other art lines up from its corners, so any size works there.

### `pawn_sheet_guide.png` (120×308)

8 columns × 7 rows of **15×44** frames, with alternating cell colors so frame edges are visible. The pink line is the ground, and the red pixel marks where the feet touch it (the pawn's position on the floor).

| Row | Contents | Status |
|-----|----------|--------|
| 1 | Walk, down-left (8 frames) | used now |
| 2 | Walk, up-left (8 frames) | used now |
| 3 | Idle: frames 1–2 down-left, frames 3–4 up-left. Phone: frames 5–6 down-left, frames 7–8 up-left | used now (phone not shown in game yet) |
| 4 | Work, down-left | proposed |
| 5 | Work, up-left | proposed |
| 6 | Carry walk, down-left | proposed |
| 7 | Carry walk, up-left | proposed |

Right-facing poses are flipped in code, so only draw left-facing poses. Rows 4–7 get wired up once you've drawn them. Frame counts per row are up to you.

### `object_1x1_guide.png`, `object_2x1_guide.png`, `object_2x2_guide.png`, `object_3x2_guide.png`, `object_3x3_guide.png`

One cell per facing, left to right: **facing 0, 1, 2, 3**. The blue diamonds are the object's floor footprint, and the darker diamond is its origin cell (the cell you set in the inspector). Draw the object so its base or legs sit on the footprint.

- The game lines each sprite up by its **left edge** and **bottom row**. Keep those the same as the guide. The height is free, so tall objects can use more rows, and you can crop empty rows off the top.
- Cell widths: 1×1 = 32 px, 2×1 = 48 px, 2×2 = 64 px, 3×2 = 80 px, 3×3 = 96 px (the 3×2 sheet is 320×96 with 56 px above the footprint; the 3×3 sheet is 384×96, with 48 px above).
- Symmetric objects (like the long table) can reuse facing 0's art for facing 2 and facing 1's for facing 3.
- Objects bigger than one cell are drawn in 16 px wide strips, each sorted at the floor cell under it, so pawns walking around them go in front of or behind the right part. Nothing to do when drawing: stay inside the guide's width, and keep things stacked on top within 48 px above the art. `tests/test_visual_draw_order.gd` checks this with plain test boxes on each guide (`tests/draw_order/`).
- Mirroring facing 0 horizontally gives a rough start for facing 1.
- **Carried items** (pizzas, boxes and so on) need only one view: draw them with their front facing **down-right**, with the back (like a box's fold or lid) up-left. The game flips them to match the pawn carrying them, and to face the pawn when set down.

### `table_height_guide.png`

Standard work-surface height, so tables and counters are consistent. Cells left to right: 1×1, 2×1 facing 0, 2×1 facing 1 (same layout as the object guides).

- Blue is the floor footprint. Orange is the tabletop, **16 px** above it, with dotted leg lines at the corners.
- The red dots are where items are anchored (pizzas, boxes): the middle of the tabletop, 16 px above the floor cell's center. That's the item offset the tables, pickup counter and oven use.
- A station drawn taller or shorter needs its item offset changed by the same amount.

### `surface_slots_guide.png`

Same layout as the 1×1 guide (one 32×64 cell per facing). The tabletop, 16 px up, is split into the 4×4 grid of surface slots (8×4 px diamonds) that items take on stations. Orange is a spot's usual work area (3×3, against the pawn's edge, leaving a strip on the worker's left and at the back), and the red pixel is where its item is anchored. Pizzas, boxes and dough containers are 3×3; draw small things (a cutter, a sauce bucket) to fit the slots they'll take.

### `item_16x16_guide.png`

An 8×4 grid of 16×16 cells, with a red center mark, for small icons (mood bubbles, menu icons). Pizzas and boxes use the 1×1 object guide instead.
