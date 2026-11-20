# Sprite list

A suggested list of the sprites Za needs, most important first. The order follows the build order: finish the pizza loop, then service, then staff life. These are only suggestions. Anything marked **TBD** is a design call for the designer.

Guide sheets for drawing are in [`art_templates/`](../art_templates). See [How to use the templates](#how-to-use-the-templates).

## Already have

- Pawn walk (down-left, up-left), idle and phone: `pawn_sheet.png` (laid out on the 7-row guide; rows 4–7 still empty)
- Floor tiles ×3: `tile_placeholder.png`
- Small table (1×1), long table (2×1, two facings), rotation test cube, bin: `Object_Spritesheet.png`
- Walls (work in progress): `walls_temp_wip.png`
- Small oven (1×1, one facing): `Small_Oven.png`
- Pizza stages (dough ball, dough, sauce, cheese, baked) and 4 cut-line frames above them: `pizza_sheet.png`. Cut lines are drawn 16 px above where they land on the pizza.
- Pizza box (closed, open base and lid): `box_sheet.png`
- Box rack (2×1, one facing, split into top and bottom shelf): `box_rack_sheet.png`
- Pickup counter (1×1, one facing): `Object_Spritesheet.png` at (128, 0)

## Priority 1: the pizza loop (next slices)

| # | Sprite | Guide | Notes |
|---|--------|-------|-------|
| 1 | Pawn **work** animation (down-left, up-left) | pawn rows 4–5 | Pawns currently stand idle while working. |
| 2 | Pawn **carry** walk (down-left, up-left) | pawn rows 6–7 | For carrying pizzas and boxes between stations. |
| 3 | **Oven** | object 2×2 | Drawn in the middle of its 4 tiles, leaving room to spare around it. Open and closed or "baking" states are nice to have. |
| 4 | **Pizza box**: flat sheet | object 1×1 | Open and closed boxes are done. Boxes arrive flat and get folded (GDD). |
| 5 | **Box folding** station; other box rack facings | object 2×1 | The box rack stores folded boxes; boxing happens on a table. Where folding happens is **TBD**. |
| 6 | **Register** (prints tickets) | object 1×1 or 2×1 | Where orders come from. |
| 7 | **Walls and door**: left wall, right wall, corner, front door | (wall guide later) | Started in `walls_temp_wip.png`. Wall height **TBD**. |
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

### `object_1x1_guide.png`, `object_2x1_guide.png`, `object_2x2_guide.png`

One cell per facing, left to right: **facing 0, 1, 2, 3**. The blue diamonds are the object's floor footprint, and the darker diamond is its origin cell (the cell you set in the inspector). Draw the object so its base or legs sit on the footprint.

- The game lines each sprite up by its **left edge** and **bottom row**. Keep those the same as the guide. The height is free, so tall objects can use more rows, and you can crop empty rows off the top.
- Cell widths: 1×1 = 32 px, 2×1 = 48 px, 2×2 = 64 px.
- Symmetric objects (like the long table) can reuse facing 0's art for facing 2 and facing 1's for facing 3.
- Mirroring facing 0 horizontally gives a rough start for facing 1.
- **Carried items** (pizzas, boxes and so on) need only one view: draw them with their front facing **down-right**, with the back (like a box's fold or lid) up-left. The game flips them to match the pawn carrying them, and to face the pawn when set down.

### `table_height_guide.png`

Standard work-surface height, so tables and counters are consistent. Cells left to right: 1×1, 2×1 facing 0, 2×1 facing 1 (same layout as the object guides).

- Blue is the floor footprint. Orange is the tabletop, **16 px** above it, with dotted leg lines at the corners.
- The red dots are where items are anchored (pizzas, boxes): 20 px above the floor cell's center, 4 px above the middle of the tabletop. That's the item offset the tables and pickup counter use.
- A station drawn taller or shorter needs its item offset changed by the same amount.

### `item_16x16_guide.png`

An 8×4 grid of 16×16 cells, with a red center mark, for small icons (mood bubbles, menu icons). Pizzas and boxes use the 1×1 object guide instead.
