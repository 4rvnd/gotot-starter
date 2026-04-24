# Skyline Coins

A small Godot 4.4 platformer scaffold built for text-first Codex iteration.

The game is intentionally asset-free: the player, platforms, coins, hazard, UI, and collection burst effects are all built from Godot nodes and GDScript.

## Play

- Move: left/right arrow keys
- Jump: space/enter
- Goal: collect every coin while avoiding the red patrol hazard

## Validate

```bash
tools/static_project_check.sh
tools/validate.sh
tools/visual_smoke.sh
```

`tools/validate.sh` and `tools/visual_smoke.sh` require Godot on `PATH`, or set `GODOT_BIN=/path/to/godot`. The visual smoke test also requires Xvfb and ImageMagick's `import`.

## Codex Cloud

Use `codex/setup.sh` as the setup script. It installs Godot 4.4.1, Xvfb, ImageMagick, xdotool, and gdtoolkit, then starts the `:99` virtual display.
