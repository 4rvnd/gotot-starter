# Godot Game Development on Codex Cloud — Complete Plan

## Overview

This document covers everything needed to build, run, and visually verify Godot 4 games using OpenAI's Codex Cloud agent — starting from zero, with no existing game code. The agent writes `.tscn` scene files and `.gd` scripts directly as text, launches the game headlessly via a virtual framebuffer, captures screenshots, and iterates autonomously.

---

## Table of Contents

1. [How It Works (Architecture)](#1-how-it-works-architecture)
2. [Prerequisites](#2-prerequisites)
3. [Repository Setup (From Scratch)](#3-repository-setup-from-scratch)
4. [Setup Script — `.codex/setup.sh`](#4-setup-script--codexsetupsh)
5. [Agent Instructions — `AGENTS.md`](#5-agent-instructions--agentsmd)
6. [Starter Game — Minimal Platformer](#6-starter-game--minimal-platformer)
7. [Codex Cloud Configuration](#7-codex-cloud-configuration)
8. [Launching Your First Task](#8-launching-your-first-task)
9. [The Visual Verification Loop](#9-the-visual-verification-loop)
10. [Prompting Strategies That Work](#10-prompting-strategies-that-work)
11. [Gotchas and Troubleshooting](#11-gotchas-and-troubleshooting)
12. [Existing Open-Source Kits](#12-existing-open-source-kits)
13. [Going Further](#13-going-further)

---

## 1. How It Works (Architecture)

Codex Cloud runs your GitHub repo inside a sandboxed Linux container (Ubuntu-based, called `codex-universal`). The execution flow is:

```
┌─────────────────────────────────────────────────────┐
│                  CODEX CLOUD CONTAINER              │
│                                                     │
│  1. Clone repo + checkout branch                    │
│  2. Run .codex/setup.sh (with internet)             │
│     → installs Godot 4, Xvfb, mesa, imagemagick    │
│  3. Cache container state (reused for ~12 hours)    │
│  4. Agent phase begins (internet off by default)    │
│     → reads AGENTS.md for project conventions       │
│     → writes/edits .tscn, .gd, project.godot       │
│     → runs godot --headless --check-only (lint)     │
│     → launches game on Xvfb virtual display         │
│     → captures screenshot via imagemagick           │
│     → reads stderr/stdout for errors                │
│     → fixes issues and repeats                      │
│  5. Agent finishes → PR with all file changes       │
└─────────────────────────────────────────────────────┘
```

**Why Godot specifically works well here:**

- Scene files (`.tscn`) and resource files (`.tres`) are plain text — the agent reads and writes them directly, no binary editor state needed.
- GDScript files are simple Python-like text files.
- `project.godot` is an INI-style config file.
- Godot has native CLI flags: `--headless`, `--check-only`, `--export-release`, `--render-driver`.
- No IDE or GUI required at any point in the pipeline.

---

## 2. Prerequisites

| Item | Details |
|------|---------|
| **ChatGPT plan** | Plus, Pro, Business, Edu, or Enterprise (all include Codex) |
| **GitHub account** | Connected to Codex at `chatgpt.com/codex` |
| **Repository** | Public or private, Codex needs read/write access |
| **Local Godot install** | Optional but recommended — to open and play the PR result locally |
| **No game code needed** | The agent builds everything from the prompt + starter scaffold |

---

## 3. Repository Setup (From Scratch)

Create a new GitHub repo. The following is the **exact file tree** you need before your first Codex task:

```
my-godot-game/
├── .codex/
│   └── setup.sh              # Container setup script
├── AGENTS.md                  # Agent instructions
├── project.godot              # Minimal Godot project config
├── scenes/
│   └── .gitkeep               # Empty dir for scene files
├── scripts/
│   └── .gitkeep               # Empty dir for GDScript files
├── assets/
│   └── .gitkeep               # Empty dir for sprites/audio
└── README.md                  # Optional
```

### `project.godot` (Minimal Starter)

This is the bare minimum Godot 4 project file. The agent will modify it as needed.

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; but it is human-readable for a reason.

[application]

config/name="My Codex Game"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.4")

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[rendering]

renderer/rendering_method="gl_compatibility"
```

**Important:** `renderer/rendering_method` must be `"gl_compatibility"` — this uses OpenGL 3.3 which works on Mesa's software renderer (`llvmpipe`) inside the container. The Vulkan/Forward+ renderer will likely fail or produce blank frames in a headless environment.

---

## 4. Setup Script — `.codex/setup.sh`

This runs once when Codex spins up your container. It has internet access during this phase.

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing system dependencies ==="
sudo apt-get update -qq
sudo apt-get install -y -qq \
  xvfb \
  libgl1 \
  libgles2 \
  libegl1 \
  libvulkan1 \
  mesa-vulkan-drivers \
  mesa-utils \
  libx11-6 \
  libxi6 \
  libxcursor1 \
  libxrandr2 \
  libxinerama1 \
  libxkbcommon0 \
  libpulse0 \
  libasound2 \
  imagemagick \
  ffmpeg \
  xdotool \
  procps \
  wget \
  unzip

echo "=== Downloading Godot 4.4.1 Stable ==="
GODOT_VERSION="4.4.1"
GODOT_TAG="${GODOT_VERSION}-stable"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_linux.x86_64.zip"
wget -q "${GODOT_URL}" -O /tmp/godot.zip
unzip -o /tmp/godot.zip -d /tmp
sudo mv "/tmp/Godot_v${GODOT_TAG}_linux.x86_64" /usr/local/bin/godot
sudo chmod +x /usr/local/bin/godot
rm /tmp/godot.zip

echo "=== Verifying Godot install ==="
godot --version

echo "=== Installing GDToolkit (gdformat + gdlint) ==="
pip install gdtoolkit --break-system-packages 2>/dev/null || pip install gdtoolkit

echo "=== Starting Xvfb virtual display ==="
# Kill any existing Xvfb
pkill Xvfb 2>/dev/null || true
# Start fresh on display :99
Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset &
sleep 1

# Persist DISPLAY for the agent phase
echo 'export DISPLAY=:99' >> ~/.bashrc

echo "=== Verifying display ==="
DISPLAY=:99 xdpyinfo | head -5 || echo "Warning: xdpyinfo not available, but Xvfb should still work"

echo "=== Setup complete ==="
echo "Godot $(godot --version) installed"
echo "Xvfb running on DISPLAY=:99"
echo "ImageMagick $(convert --version | head -1) installed"
```

### Notes on the Setup Script

- `setup.sh` runs in a **separate bash session** from the agent. `export` commands inside the script do NOT carry over. That's why we append to `~/.bashrc`.
- Xvfb is started with `&` (background process). The `+extension GLX` flag enables OpenGL support on the virtual display.
- The `-ac` flag disables access control so any process can render to the display.
- Codex caches this container state for up to 12 hours, so subsequent tasks reuse the cached Godot install instantly.
- The `--break-system-packages` flag is needed for pip on Ubuntu 24+ (which Codex uses).

---

## 5. Agent Instructions — `AGENTS.md`

Place this at the repo root. Codex reads it automatically to learn your project conventions.

```markdown
# Godot 4 Game Project

## Project overview
This is a Godot 4.4 game using GDScript and the GL Compatibility renderer.
All scene files, scripts, and assets are plain text and should be edited directly.

## Tech stack
- Engine: Godot 4.4 (GDScript, NOT C#)
- Renderer: GL Compatibility (OpenGL 3.3) — do NOT use Forward+ or Vulkan
- Display: Xvfb virtual framebuffer on DISPLAY=:99

## Directory structure
- `scenes/` — all .tscn scene files
- `scripts/` — all .gd script files
- `assets/` — sprites, audio, fonts (placeholder colored rects are fine)
- `project.godot` — engine config (update run/main_scene when adding new scenes)

## Build & validate commands

### Check for parse/load errors (fast, always run first):
```

godot --path . --headless --check-only 2>&1

```

### Launch game on virtual display:
```

DISPLAY=:99 godot --path . --render-driver opengl3 2>&1 &
GAME_PID=$!

```

### Capture screenshot after launch:
```

sleep 4
DISPLAY=:99 import -window root /tmp/screenshot.png

```

### Send keyboard input:
```

DISPLAY=:99 xdotool key Right
DISPLAY=:99 xdotool key space
sleep 1
DISPLAY=:99 import -window root /tmp/screenshot_after_input.png

```

### Kill game before making edits:
```

kill $GAME_PID 2>/dev/null || true

```

## Validation workflow (ALWAYS follow this after changes)

1. Run `godot --path . --headless --check-only 2>&1` — fix any errors before proceeding
2. Launch the game: `DISPLAY=:99 godot --path . --render-driver opengl3 &`
3. Wait 4 seconds for the scene to fully load
4. Capture screenshot: `DISPLAY=:99 import -window root /tmp/screenshot.png`
5. Examine the screenshot — check if nodes are visible, positioned correctly, and no black/blank screen
6. Optionally send inputs (arrow keys, space, etc.) and capture again
7. Read any stderr output for warnings or runtime errors
8. Kill the game process before making further code edits
9. Repeat until the game works correctly

## Coding conventions
- Always use @onready for node references
- Use typed variables: `var speed: float = 200.0`
- Add a debug label node that prints FPS and player position — this helps verify the game is running
- Use placeholder ColorRect or Polygon2D nodes instead of image sprites (no assets needed)
- Prefer signals over polling for inter-node communication
- Each scene should have its own script in scripts/

## Lint & format
- Format: `gdformat scripts/*.gd`
- Lint: `gdlint scripts/*.gd`

## Common pitfalls to avoid
- NEVER use Forward+ or Vulkan renderer — only gl_compatibility works headlessly
- NEVER forget to set run/main_scene in project.godot
- ALWAYS use DISPLAY=:99 prefix when running GUI commands
- If the screenshot is pure black, the scene tree is probably empty or nodes are offscreen
- If Godot crashes silently, check stderr — usually a missing resource or malformed .tscn
- Kill the game process before editing files — Godot locks some resources
```

---

## 6. Starter Game — Minimal Platformer

If you want to seed the repo with a working game so Codex has something to build on, here are the files for a dead-simple 2D platformer.

### `scenes/main.tscn`

```
[gd_scene load_steps=4 format=3 uid="uid://main"]

[ext_resource type="Script" path="res://scripts/player.gd" id="1"]
[ext_resource type="Script" path="res://scripts/debug_overlay.gd" id="2"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(32, 48)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_ground"]
size = Vector2(1280, 32)

[node name="Main" type="Node2D"]

[node name="Player" type="CharacterBody2D" parent="."]
position = Vector2(200, 500)
script = ExtResource("1")

[node name="Sprite" type="ColorRect" parent="Player"]
offset_left = -16
offset_top = -24
offset_right = 16
offset_bottom = 24
color = Color(0.2, 0.6, 1, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Player"]
shape = SubResource("RectangleShape2D_player")

[node name="Ground" type="StaticBody2D" parent="."]
position = Vector2(640, 700)

[node name="GroundSprite" type="ColorRect" parent="Ground"]
offset_left = -640
offset_top = -16
offset_right = 640
offset_bottom = 16
color = Color(0.4, 0.3, 0.2, 1)

[node name="GroundCollision" type="CollisionShape2D" parent="Ground"]
shape = SubResource("RectangleShape2D_ground")

[node name="Platform1" type="StaticBody2D" parent="."]
position = Vector2(400, 550)

[node name="PlatSprite" type="ColorRect" parent="Platform1"]
offset_left = -80
offset_top = -8
offset_right = 80
offset_bottom = 8
color = Color(0.3, 0.7, 0.3, 1)

[node name="PlatCollision" type="CollisionShape2D" parent="Platform1"]
shape = SubResource("RectangleShape2D_plat1")

[sub_resource type="RectangleShape2D" id="RectangleShape2D_plat1"]
size = Vector2(160, 16)

[node name="Platform2" type="StaticBody2D" parent="."]
position = Vector2(700, 420)

[node name="PlatSprite" type="ColorRect" parent="Platform2"]
offset_left = -80
offset_top = -8
offset_right = 80
offset_bottom = 8
color = Color(0.3, 0.7, 0.3, 1)

[node name="PlatCollision" type="CollisionShape2D" parent="Platform2"]
shape = SubResource("RectangleShape2D_plat2")

[sub_resource type="RectangleShape2D" id="RectangleShape2D_plat2"]
size = Vector2(160, 16)

[node name="DebugOverlay" type="Label" parent="."]
offset_left = 10
offset_top = 10
offset_right = 400
offset_bottom = 60
script = ExtResource("2")
```

### `scripts/player.gd`

```gdscript
extends CharacterBody2D

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -500.0
const GRAVITY: float = 980.0

func _physics_process(delta: float) -> void:
    # Gravity
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    # Jump
    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    # Horizontal movement
    var direction: float = Input.get_axis("ui_left", "ui_right")
    if direction:
        velocity.x = direction * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)

    move_and_slide()

    # Print state for agent debugging
    if Engine.get_frames_drawn() % 60 == 0:
        print("Player pos: %s | on_floor: %s | vel: %s" % [
            global_position, is_on_floor(), velocity
        ])
```

### `scripts/debug_overlay.gd`

```gdscript
extends Label

func _process(_delta: float) -> void:
    text = "FPS: %d" % Engine.get_frames_per_second()
```

### Why This Starter Matters

The starter game gives Codex something **concrete to validate against**. On its first run, the agent can:

- Immediately run `--check-only` and confirm the project parses
- Launch, capture a screenshot, and confirm a blue rectangle (player) sitting on a brown rectangle (ground)
- Send arrow key inputs and confirm the player moves
- See the FPS counter in the top-left corner

Without a starter, the agent is writing blind and its first several iterations may just be getting the `.tscn` format right.

---

## 7. Codex Cloud Configuration

### Step-by-step in the Codex UI

1. Go to **[chatgpt.com/codex](https://chatgpt.com/codex)**
2. Connect your GitHub account (if not already done)
3. Select your repo from the list (or paste the URL)
4. Go to **Environment settings** (gear icon next to the repo)

#### Setup Script

- Set the path to `.codex/setup.sh`
- This runs once per container creation, with internet access

#### Environment Variables

Add these:

| Variable | Value | Purpose |
|----------|-------|---------|
| `DISPLAY` | `:99` | Points to the Xvfb virtual display |

#### Internet Access

- **Setup phase:** Always has internet (for downloading Godot)
- **Agent phase:** Set to **"Limited"** or **"Unrestricted"** if you want the agent to download assets, reference docs, or call a vision API for screenshot analysis. Set to **"Off"** if you want a fully sandboxed run (agent relies on stderr/stdout only for validation)

#### Package Versions (Optional)

- You can pin Python and Node.js versions if needed, but defaults work fine for Godot projects

### Verifying Container Cache

After your first task completes (even if the game isn't perfect), the container is cached for ~12 hours. Subsequent tasks skip the entire setup.sh and start instantly with Godot already installed.

---

## 8. Launching Your First Task

### Go to Codex → your repo → "New task"

#### Good first prompt (if you included the starter game)

```
Run the starter platformer game headlessly on the Xvfb display.
Capture a screenshot and verify the player (blue rect) and ground 
(brown rect) are visible. If anything is wrong, fix the scene file
and retry. Once it works, add the following features:

1. A coin collectible (yellow circle/rect) on the floating platform
2. A score counter in the top-right corner that increases when
   the player touches a coin
3. A simple particle effect when the coin is collected
4. At least 3 more platforms with coins

After each change, re-launch, screenshot, and verify.
```

#### Good first prompt (if you're starting completely empty)

```
Create a complete 2D platformer game in Godot 4.4 from scratch.

Requirements:
- A player character (blue ColorRect, 32x48px) with movement and jumping
- A ground platform spanning the full viewport width
- 5 floating platforms at different heights
- 3 coin collectibles (yellow ColorRects) on various platforms
- A score counter (Label node) in the top-right
- A debug FPS counter in the top-left
- Use GL Compatibility renderer only

After creating all files, run the validation workflow from AGENTS.md:
- check-only first
- launch on DISPLAY=:99
- capture screenshot
- verify everything renders
- fix any issues and repeat

Use placeholder ColorRects for all visuals — no image assets needed.
```

#### What happens next

1. Codex creates a cloud container, clones your repo
2. Runs `.codex/setup.sh` → Godot + Xvfb installed
3. Reads `AGENTS.md` → understands how to build/run/test
4. Starts writing files (`.tscn`, `.gd`, `project.godot`)
5. Runs validation loop (headless check → launch → screenshot → fix)
6. When satisfied, finishes and produces a PR diff
7. You review the PR, merge it, and open in Godot locally to play

---

## 9. The Visual Verification Loop

This is the core innovation that makes AI game development actually work.

### Without visual verification (bad)

```
Write code → hope it works → find out it doesn't when you open it locally
```

### With visual verification (good)

```
Write code → build → launch on Xvfb → screenshot → analyze → fix → repeat
```

### How the agent captures and analyzes screenshots

```bash
# Launch game in background
DISPLAY=:99 godot --path . --render-driver opengl3 2>/tmp/godot_stderr.log &
GAME_PID=$!

# Wait for scene to load
sleep 4

# Capture full window
DISPLAY=:99 import -window root /tmp/frame1.png

# Send inputs
DISPLAY=:99 xdotool key Right Right Right
sleep 0.5
DISPLAY=:99 import -window root /tmp/frame2_after_move.png

DISPLAY=:99 xdotool key space
sleep 0.5
DISPLAY=:99 import -window root /tmp/frame3_after_jump.png

# Read any errors
cat /tmp/godot_stderr.log

# Clean up
kill $GAME_PID 2>/dev/null
```

### What the agent checks in the screenshot

The agent can't "see" the screenshot directly in Codex Cloud (it doesn't have native vision). But it can:

1. **Check file size** — a 0KB or tiny PNG means nothing rendered (black screen)
2. **Use ImageMagick to analyze** — `identify /tmp/screenshot.png` gives dimensions and color depth; `convert /tmp/screenshot.png -format %c histogram:info:-` gives a color histogram to check if the screen is all one color (blank)
3. **Check stderr** — Godot prints warnings and errors about missing nodes, failed resource loads, type mismatches, etc.
4. **Check stdout** — the debug print statements in `player.gd` confirm the game loop is running and physics are working
5. **Check pixel regions** — `convert /tmp/screenshot.png -crop 100x100+0+0 -format %c histogram:info:-` to check if the top-left corner has the debug label rendered

### Upgrading to True Visual QA

If you enable internet access on the agent phase, the agent can call an external vision API (OpenAI's own `gpt-4o` or `gpt-5.4` with vision) to analyze the screenshot semantically:

```bash
# Example: agent encodes screenshot and sends to vision API
base64 /tmp/screenshot.png | curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": [
        {"type": "text", "text": "Analyze this game screenshot. Is a blue player rectangle visible? Is there a brown ground? Are platforms visible? Are there any visual glitches?"},
        {"type": "image_url", "image_url": {"url": "data:image/png;base64,'"$(cat /tmp/screenshot_b64.txt)"'"}}
      ]}
    ]
  }'
```

For this to work, add your `OPENAI_API_KEY` as a **Secret** (not an environment variable) in Codex environment settings. Secrets are encrypted and only available during the setup phase — so you'd need to save it to a file the agent can read, or restructure the flow.

Alternatively, the **godogen** project handles this by having an orchestrator script that receives the screenshot and sends it to a multimodal model outside the Codex sandbox.

---

## 10. Prompting Strategies That Work

### Be specific about geometry and positions

```
❌ "Add some platforms"
✅ "Add 3 platforms: one at position (300, 500), one at (600, 380), 
    one at (900, 260). Each should be 160px wide and 16px tall."
```

### Ask for incremental changes, not full rewrites

```
❌ "Build me a complete RPG with inventory, combat, and dialog"
✅ "Add a simple enemy (red rect) that patrols left-right on 
    Platform2. It should reverse direction at the platform edges."
```

### Always ask for validation

```
✅ "After making changes, run the full validation workflow and 
    confirm the game runs. If the screenshot shows a black screen, 
    debug the issue."
```

### Use the debug overlay

```
✅ "Make sure the debug overlay prints the player position, 
    current velocity, and number of coins collected."
```

### Reference AGENTS.md explicitly

```
✅ "Follow the validation workflow in AGENTS.md after every change."
```

---

## 11. Gotchas and Troubleshooting

### Black/blank screenshot

- **Cause:** Scene tree is empty, main_scene not set, or renderer mismatch
- **Fix:** Ensure `project.godot` has `run/main_scene` pointing to a valid `.tscn`. Ensure renderer is `gl_compatibility`. Ensure at least one visible node exists.

### Godot crashes silently

- **Cause:** Malformed `.tscn` file, missing `[ext_resource]`, or circular dependency
- **Fix:** Run `godot --headless --check-only` first — it catches most parse errors. Check stderr output carefully.

### `DISPLAY` not set

- **Cause:** The `export DISPLAY=:99` from setup.sh didn't persist to agent phase
- **Fix:** Add `DISPLAY` as an environment variable in Codex settings (not just in the script). Also ensure every GUI command uses the `DISPLAY=:99` prefix explicitly.

### Xvfb not running

- **Cause:** Xvfb process died between setup and agent phase, or container was cached without it
- **Fix:** Add a check in AGENTS.md telling the agent to run `pgrep Xvfb || Xvfb :99 -screen 0 1280x720x24 &` before launching the game.

### `import` command not found (ImageMagick)

- **Cause:** ImageMagick not installed or `import` shadowed by another binary
- **Fix:** Use full path `/usr/bin/import` or install with `sudo apt-get install imagemagick`

### Game runs but player falls through the floor

- **Cause:** CollisionShape2D missing or wrong shape size, or physics layer mismatch
- **Fix:** The debug print in `player.gd` shows `is_on_floor()` — if it's always `false`, the collision setup is broken. Agent should check that both the player and ground have `CollisionShape2D` nodes with valid shapes.

### `.tscn` format errors

- **Cause:** Godot's `.tscn` format is strict about `load_steps`, `uid`, `sub_resource` IDs, and node paths
- **Fix:** Tell the agent to start minimal and add nodes one at a time, validating after each addition. Avoid writing a 200-line `.tscn` from scratch in one shot.

### Container times out

- **Cause:** Task took too long (Codex has execution time limits)
- **Fix:** Break complex games into multiple tasks. First task: create the base game. Second task: add enemies. Third task: add UI. Each task builds on the previous PR.

---

## 12. Existing Open-Source Kits

### godogen — `github.com/htdt/godogen`

- Turns a single sentence into a playable Godot 4 game
- Works with both Claude Code and Codex
- Includes asset generation (uses Gemini, Grok, Tripo3D for sprites and 3D models)
- Visual QA via screenshot capture and multimodal model analysis
- Uses C# instead of GDScript
- Requires API keys for asset generation services

### CODEXVault_GODOT — `github.com/FromAriel/CODEXVault_GODOT`

- GitHub template repo — fork it and start immediately
- Comprehensive "maximal" setup with every tool pre-configured
- Includes AGENTS.md, setup.sh, validation scripts, GDToolkit, pre-commit hooks
- Supports both GDScript and C#/.NET
- Designed to be trimmed down — remove what you don't need
- 142+ commits of iteration — battle-tested

### Godot MCP Codex — `github.com/niejiaqiang/godot-mcp-codex`

- MCP server that lets Codex interact with a running Godot editor
- Can inspect scenes, edit nodes, read/write scripts
- Requires Godot editor running locally (not headless-only)
- More suited for local Codex CLI use than Codex Cloud

---

## 13. Going Further

### Multi-task iteration pattern

Break game development into sequential Codex tasks, each building on the last PR:

| Task # | Prompt | What it produces |
|--------|--------|-----------------|
| 1 | "Create base platformer with player, ground, 5 platforms" | Core gameplay |
| 2 | "Add 3 enemy types that patrol platforms" | Enemy AI |
| 3 | "Add coin collectibles with score UI and particle effects" | Collectibles |
| 4 | "Add a main menu scene and game over scene" | UI flow |
| 5 | "Add sound effects using AudioStreamPlayer nodes" | Audio |
| 6 | "Add a second level and scene transition" | Level progression |
| 7 | "Polish: screen shake on death, tween animations, juice" | Game feel |

### Automated nightly builds

Use GitHub Actions + the Codex CLI to run nightly "playtest" tasks:

```yaml
# .github/workflows/nightly-playtest.yml
name: Nightly Playtest
on:
  schedule:
    - cron: '0 2 * * *'
jobs:
  playtest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Codex playtest
        run: |
          npx @openai/codex exec "Run the game, capture 5 screenshots at 
          different points, verify everything renders correctly, file any 
          issues you find as GitHub issues"
```

### Exporting the final game

Once the game is polished, add an export task:

```
Export the game for Linux x86_64 using:
godot --path . --headless --export-release "Linux" build/game.x86_64

Verify the exported binary runs on Xvfb and produces the same 
screenshot as the editor run.
```

### Using Claude Code instead

Everything in this plan works identically with Claude Code (Anthropic's coding agent). The differences:

- Claude Code has native vision — it can directly "see" screenshots without calling an external API
- Use `CLAUDE.md` instead of `AGENTS.md` (same content, different filename)
- Claude Code runs locally or via `claude --headless` in CI
- The setup script and Xvfb workflow are identical

---

## Quick Start Checklist

- [ ] Create GitHub repo
- [ ] Add `.codex/setup.sh` (from Section 4)
- [ ] Add `AGENTS.md` (from Section 5)
- [ ] Add `project.godot` (from Section 3)
- [ ] Optionally add starter game files (from Section 6)
- [ ] Connect repo to Codex at `chatgpt.com/codex`
- [ ] Configure environment: setup script path, `DISPLAY=:99` env var, internet access
- [ ] Launch first task with a specific prompt (from Section 8)
- [ ] Review the PR, merge, open locally in Godot, and play
- [ ] Iterate with follow-up tasks
