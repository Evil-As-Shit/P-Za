# Za: Game Design Document

## Instructions for Claude Code

Read this whole file first to get up to speed on the game, then follow these rules.

- **Use Godot best practices.** Write idiomatic Godot 4 code and follow the official docs and the GDScript style guide.
  - Use statically typed GDScript.
  - Build the game from small, reusable scenes and compose them rather than building deep inheritance.
  - Follow "signals up, calls down" so child nodes don't reach into their parents.
  - Use custom `Resource` types for data (recipes, traits, equipment and so on) instead of hard-coding it.
  - Use autoloads sparingly.
  - Keep a clean, consistent project folder structure.
- **The project uses Godot 4.7.2 with the Forward+ renderer.** Use APIs that exist in that version and confirm against `project.godot`. Don't guess.
- **Code is GDScript only.** Don't use C#.
- **Use agents as needed.** Use subagents for research, codebase exploration and independent or parallel tasks, so the main conversation stays focused. Don't spawn agents for small, simple changes.
- **Don't invent design specifics.** This document is intentionally high-level. If numbers, formulas, systems, assets or schedules aren't covered here, ask the designer instead of making them up.
- **Use placeholder art and audio** unless the designer says otherwise.
- **Keep this file current.** When the designer makes a design decision, update the relevant section here, keeping it short and high-level.
- **Communicate briefly.** Give short, plain-language summaries. Don't add unrequested extras or expand the scope.

### Ask first

Check with the designer before:
- Making or changing any design decision.
- Adding a third-party plugin or addon. Stay with vanilla Godot unless the designer approves.
- Adding any other new dependency.
- Doing a large refactor or deleting files.

### Project layout

Use this default layout and keep it consistent:
- `scenes/` for scenes, `scripts/` for scripts, `resources/` for custom `Resource` data, and `assets/` for art, audio and fonts. Organize by feature inside them when it helps.
- Name files and folders in `snake_case`. Name classes and nodes in `PascalCase`, as the GDScript style guide says.

### Running and testing

- Godot (Steam install): `C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- Git isn't on PATH. Use SourceTree's bundled copy: `%LOCALAPPDATA%\Atlassian\SourceTree\git_local\cmd\git.exe`
- Headless checks are allowed. Run Godot headless to confirm the project loads and scripts parse, and verify your own work before reporting it done.

### Workflow

- Use git. Make small, focused commits with clear messages, and keep the `.godot/` folder out of version control.
- Commit locally only. The designer pushes using SourceTree.
- Plan before building any large feature.
- Build the smallest playable slice first (a pawn, a task and the ticket-to-pizza loop), then add systems on top of it one at a time.

## About this document

Short, high-level design doc. It covers the basics of the gameplay and mechanics only. Specific numbers, formulas, asset lists and schedules are deliberately left out; they get decided later, one at a time, by the designer.

- **Lead designer:** Vincent Messina
- **Status:** Concept / pre-production
- **Engine:** Godot 4.7.2 (Forward+ renderer), scripted in **GDScript**
- **Platform:** PC (keyboard and mouse)
- **Monetization:** none planned

## Pitch

A cozy, 2.5D isometric pizza parlor management sim in the style of RimWorld. You run the shop by managing a small staff of pawns who work on their own. You never control them directly. You set priorities, tune the menu and operations, and watch the staff, and the drama between them, play out.

- **Art style:** stylized, cozy 2.5D isometric
- **Audience:** tycoon, management and base-builder players
- **Controls:** mouse and keyboard, with hotkeys and a contextual cursor

## Design pillars

1. **Emergent pawn drama:** staff have personalities, moods and quirks that produce stories.
2. **Tactile kitchen craft:** making pizza should feel physical, readable and satisfying.
3. **Satisfying tycoon scaling:** the shop grows from a small parlor into a bigger operation.

## Art and grid

- **2D isometric** in a 2D scene (no 3D).
- The floor grid is a **32×16 diamond** (`TileMapLayer`, diamond-down layout). Tile art can be a little larger than the grid. The overhang is intentional.
- **Pawn sprite sheets** (15×44 frames). Row 1 is walk down-left, row 2 is walk up-left, and row 3 is idle (frames 1–2 down-left, frames 3–4 up-left). Right-facing poses are flipped in code.
- Pawns move along the grid axes only, so they always face one of the four iso diagonals.

## Core loop

1. **Prep and supply:** before opening, order ingredients, make or buy dough and sauce, and set up the menu (pizzas, sizes, prices).
2. **Service:** open the doors. Orders arrive as printed tickets. Pawns make, bake and serve the pizzas all day, with busier rushes around lunch and dinner.
3. **Close and clean:** clean up after the rush, then review the day.
4. **Reinvest:** use profits to improve the shop, equipment and staff, then repeat.

## Core mechanics

Each item below is a direction, not a final spec.

### Pawns and the priority system
- Pawns are autonomous. The player sets task priorities per pawn (a RimWorld-style work-priority grid) and never gives direct move or work commands.
- Tasks include dough prep, sauce, assembly, oven, slicing, boxing, box making, cashier, front-of-house service, driving and cleaning. Training is also a task.
- Pizza boxes arrive as unfolded sheets, so staff have to make (fold) them before they can be used for boxing.
- Driving is just another skill pawns can develop. Delivery drivers are regular in-house staff, not a separate hire.
- Pawns claim work from the station queues according to their priorities and skill.

### Orders and the ticket rack
- Orders print as physical tickets from the register.
- The player arranges tickets on a rack with two sections: **Wait** and **Make**. Pawns work the Make tickets in order, so reordering tickets steers the kitchen indirectly.
- **Taking or serving an order is automatic.** There is no manual "Take" step, and completed orders go out on their own.
- Order types are dine-in, to-go, pickup and delivery. Delivery uses a driver who leaves the shop and comes back later.
- Dine-in seating is self-serve: customers order, sit down, and a front-of-house employee brings the food to their table.

### ETA and reviews
- The player sets the promised wait time with an ETA slider on the HUD.
- Promising longer waits eases pressure but costs customer satisfaction and reviews. Missing or beating the promise also affects how customers feel.

### Customers and demand
- Customers and demand come from the shop's reviews. Good reviews bring more business and bad ones drive it away.
- Calendar events can raise or lower demand on certain days.

### Pizza crafting
- Dough and sauce can be bought premade or made from scratch in-house. Premade is convenient but limited in quality. Scratch work depends on ingredient quality and pawn skill.
- The player builds a custom menu: specialty pizzas, crust sizes, toppings and prices.
- A finished pizza's quality comes from its components and how well it was made/baked.

### Staff, mood and traits
- Pawns have moods driven by things like stress, fatigue, pay and how well they get along with other pawns, which affect speed and quality.
- Pawns have hidden personality traits that are revealed after they have worked some shifts. A better manager reveals them faster.
- Experienced pawns want better pay. Pawns can ask for raises, and unhappiness can build if they don't get one.
- Pawns can become friends if their personality types jive, or enemies if they don't.
- Pawns quit after being stressed at work for a long time.
- Hiring comes from a stack of resumes the player sorts through. Better applicants come with better reviews.
- **Trainees** can shadow a veteran to learn safely, at some cost to the veteran's output.
- A **manager** must be on shift during open hours. When the shop is quiet and the manager is out of sight, pawns slack off (for example, browsing their phones).

### Store operations
- The day runs in phases, and the player can pause or speed up time.
- Ingredients arrive in regular recurring deliveries, with an emergency option at a premium. Fresh ingredients spoil, so cold storage matters.
- Kitchens get dirty. Poor cleanliness leads to health inspector penalties.
- Equipment can be upgraded for capacity and reliability. The player lays out and arranges the kitchen, and pawn movement is affected by the layout.

### Progression and failure
- Progression comes from upgrades: expanding the floorplan, and buying newer, better (and more expensive) appliances.
- The player loses by running out of money to pay for employees and for bills and rent.

### Onboarding
- New players get an onboarding tutorial.
- UI tooltips help first-time players learn the interface.

## Out of scope for this document

Intentionally not defined here: numeric balance values, formulas, asset lists and production tracking, roadmap dates, and the economy. These get decided with the designer as they come up.

## Not yet decided

Nothing is listed as open right now. Anything not covered in this document is still undecided, so ask the designer instead of assuming.