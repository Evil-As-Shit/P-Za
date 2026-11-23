---
name: godot-api
description: Exact Godot 4.7.2 API reference (every class's methods, properties, signals, enums, constants, annotations and GDScript built-ins) dumped from the Godot install this project uses. Use before writing or changing GDScript that calls an engine API you are not certain exists in 4.7.2 with that exact name, parameters or return type, when a script error mentions a nonexistent method or property, or when asked whether something is available in this Godot version.
---

# Godot 4.7.2 API reference

`reference/` holds the API of the exact Godot build the project runs (`reference/VERSION.txt`). It was dumped with `godot --doctool`, so it matches 4.7.2 exactly, unlike memory of older 4.x versions.

If `reference/` is missing (it is not committed to git) or `VERSION.txt` doesn't match `config/features` in `project.godot`, rebuild it first. It takes a few seconds:

```powershell
.\.claude\skills\godot-api\scripts\build_reference.ps1
```

## Layout

- `reference/<Class>.txt`: one file per class, e.g. `Node2D.txt`, `Vector2.txt`, `TileMapLayer.txt`.
- `reference/@GDScript.txt`: GDScript built-ins: annotations (`@export_range`, `@onready`, ...), functions (`preload`, `range`, ...) and constants (`PI`, `TAU`, `INF`).
- `reference/@GlobalScope.txt`: global functions (`clamp`, `lerp`, `randi_range`, ...), singletons and global enums (`Error`, `Key`, `MouseButton`, ...).
- `reference/_classes.txt`: every class with its parent (`Sprite2D extends Node2D`).

Each file has sections (`## Properties`, `## Methods`, `## Signals`, `## Enums`, `## Constants`, `## Constructors`, `## Operators`, `## Theme items`, `## Annotations`), one entry per line:

```
Vector2 position = Vector2(0, 0)  [set_position / get_position]
void move_local_x(delta: float, scaled: bool = false)
float get_angle_to(point: Vector2) const
signal child_entered_tree(node: Node)
enum InternalMode { INTERNAL_MODE_DISABLED = 0, INTERNAL_MODE_FRONT = 1, INTERNAL_MODE_BACK = 2 }
```

## How to look things up

Search with Grep in `.claude/skills/godot-api/reference`, not by reading whole files:

- Does a method or property exist on a class? Grep the name in `<Class>.txt`. **A class file lists only what that class adds.** If it isn't there, follow `extends` up the chain (the first line of each file, or `_classes.txt`), e.g. `Sprite2D` → `Node2D` → `CanvasItem` → `Node` → `Object`.
- Where does a name live? Grep the name across the whole folder (e.g. `\bget_global_mouse_position\(`).
- What are an enum's values? Grep `enum <Name>` (or `flags <Name>` for bitfields).
- Exact parameter types and defaults: copy them from the signature line.

## Limits

- **Signatures only.** Descriptions aren't included, so for what a method *does* or how to use it, rely on knowledge of Godot and confirm the signature here.
- **Deprecation isn't marked.** An entry existing doesn't mean it is recommended. For example, `TileMap` still exists but `TileMapLayer` replaces it. Prefer the current API when you know one.
- Lists engine classes only, not this project's own `class_name` scripts. Look those up in `scripts/`.

If a lookup shows that an API is missing or has a different signature from what you expected, fix the code to match the reference. Don't guess at an alternative; find it here.
