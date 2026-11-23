---
name: run-tests
description: Run Za's Godot tests (tests/test_*.gd) and report only what failed. Use after changing GDScript, scenes or resources to check nothing broke, when the user asks to run or check tests, or when debugging a failing test.
---

# Running Za's tests

Always use the project's runner; don't call Godot on tests by hand unless debugging below. Run from the project folder:

```powershell
.\tests\run_tests.ps1 -Quiet                 # all tests, prints only failures + a summary line
.\tests\run_tests.ps1 -Quiet prep_table      # only tests whose name contains "prep_table"
.\tests\run_tests.ps1 -Detail single_order   # failures show the last 40 lines of Godot output
```

- **Always pass `-Quiet`** unless the user wants to see every passing test. Passing lines are noise.
- **Pick the smallest set that covers the change.** Filter by name (it matches part of the file name, e.g. `oven` → `test_pizza_oven.gd`). Test names follow the system they cover: `register`, `manager`, `reviews`, `prep_table`, `pizza_oven`, `doneness`, `box_folding`, `dough_put_away`, `empty_bucket`, `patience`, `skills`, `pawn_panel`, `priority_skill_refresh`, `pawn_avoidance`, `build_mode`, `move_busy`, `role_change`, `station_in_the_way`, `camera`, `multi_order`, `single_order`, `full_day`, `visual_draw_order`.
- **Run the full suite** before saying a feature is done, or when a change touches shared code (work manager, pawns, tickets, world). It takes about 20 seconds (most of it `test_visual_draw_order`), so run it in the foreground. Use `run_in_background` only if it starts taking minutes.
- `test_full_day` is the smoke test: a whole simulated shop day. It catches stalls and deadlocks. Treat its served/missed numbers as information, not a target (the user isn't tuning balance yet).
- `test_visual_*` tests open a window to check rendered pixels; the runner handles that. They can fail if the machine has no display.

## What counts as a failure

The runner marks a test FAIL if it prints `FAIL`, exits non-zero, times out (default 600 s of game time, `timeout_frames` in `test_base.gd`), or prints any engine error: `SCRIPT ERROR`, `ERROR:`, or leaked objects at exit. A test can print `PASS` and still fail because of an error or leak; read the error lines under it.

## Reporting

Tell the user the summary line (`All N tests passed.` or `X of N tests failed.`) and, for each failure, the test name and the one or two lines that explain it. Don't paste full output.

If a failure looks unrelated to the change, rerun that test a few times. If it passes on reruns, tell the user it's flaky (with its failure message) instead of quietly calling the run green. Pawns idle for random times, so a test that depends on where pawns happen to be can fail only sometimes. That's usually a real bug showing up rarely, worth finding: loop the test 30 or more times with debug prints until it fails.

## Debugging a failure

1. Rerun just that test with `-Detail` to see the end of its output (stack trace, last prints).
2. If that's not enough, run it directly and read the whole output:
   ```powershell
   & "C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --fixed-fps 60 --script res://tests/test_<name>.gd
   ```
   (Drop `--headless` for `test_visual_*`. `$env:GODOT` overrides the path in the runner.)
3. If the error names an engine method or property that doesn't exist, check it with the `godot-api` skill.

## Writing a new test

Extend `res://tests/test_base.gd`. Override `_start()` (the shop is loaded; `world`, `clock`, `rack`, `finances` and `work` are set) and `_step()` (called every frame), and end with `pass_test("what was checked")` or `fail("why")`. Helpers: `stop_random_orders()`, `order_pizzas(count)`. Name it `tests/test_<system>.gd` so the runner finds it.
