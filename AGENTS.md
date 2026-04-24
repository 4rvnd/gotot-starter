# Godot 4 Game Project

## Project Overview

This is a Godot 4.4 GDScript project using the GL Compatibility renderer. Edit `.tscn`, `.gd`, and `project.godot` directly as text.

## Directory Structure

- `scenes/` stores Godot scene files.
- `scripts/` stores GDScript files.
- `assets/` stores optional sprites, audio, and fonts. The current game intentionally uses placeholder colored nodes.
- `tools/` stores local validation helpers.
- `codex/setup.sh` is the Codex Cloud setup script. This workspace blocked creating `.codex/setup.sh`, so configure this path directly in Codex Cloud.

## Required Commands

Run static checks first:

```bash
tools/static_project_check.sh
```

Run Godot parse/load checks:

```bash
tools/validate.sh
```

Launch on the virtual display:

```bash
tools/visual_smoke.sh
```

## Coding Conventions

- Use GDScript, not C#.
- Keep `renderer/rendering_method="gl_compatibility"` in `project.godot`.
- Use `CharacterBody2D` for the player and `Area2D` for pickups/hazards.
- Prefer signals for gameplay events such as coin collection.
- Use visible placeholder nodes (`ColorRect`, `Polygon2D`, `Label`) unless a real asset is intentionally added.
- Keep the debug overlay visible in the top-left so headless runs expose FPS and player position.

## Common Pitfalls

- Do not switch to Forward+ or Vulkan in this repo.
- Do not forget `run/main_scene="res://scenes/main.tscn"`.
- Prefix GUI commands with `DISPLAY=:99` in the Codex Cloud container.
- Kill the Godot process before editing if a GUI run is active.
