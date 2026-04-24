#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "static_project_check: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "${ROOT_DIR}/${path}" ]] || fail "missing ${path}"
}

require_file "codex/setup.sh"
require_file "AGENTS.md"
require_file "project.godot"
require_file "scenes/main.tscn"
require_file "scripts/main.gd"
require_file "scripts/player.gd"
require_file "scripts/coin.gd"
require_file "scripts/patrol_enemy.gd"
require_file "scripts/debug_overlay.gd"
require_file "tools/visual_smoke.sh"

grep -q 'run/main_scene="res://scenes/main.tscn"' "${ROOT_DIR}/project.godot" \
  || fail "project.godot must point run/main_scene at scenes/main.tscn"

grep -q 'renderer/rendering_method="gl_compatibility"' "${ROOT_DIR}/project.godot" \
  || fail "project.godot must use the GL Compatibility renderer"

grep -q 'ExtResource("1_' "${ROOT_DIR}/scenes/main.tscn" \
  || fail "main scene must reference external script resources"

grep -q 'groups=\["coins"\]' "${ROOT_DIR}/scenes/main.tscn" \
  || fail "main scene must put collectible nodes in the coins group"

grep -q 'extends CharacterBody2D' "${ROOT_DIR}/scripts/player.gd" \
  || fail "player.gd must extend CharacterBody2D"

grep -q 'signal collected' "${ROOT_DIR}/scripts/coin.gd" \
  || fail "coin.gd must expose a collected signal"

grep -q 'func respawn' "${ROOT_DIR}/scripts/player.gd" \
  || fail "player.gd must expose respawn for hazards"

python3 - "${ROOT_DIR}" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
scene = (root / "scenes/main.tscn").read_text()

script_paths = re.findall(r'\[ext_resource type="Script" path="(res://[^"]+)" id="([^"]+)"\]', scene)
missing_scripts = [
    resource_path
    for resource_path, _resource_id in script_paths
    if not (root / resource_path.replace("res://", "")).exists()
]

sub_defs = set(re.findall(r'\[sub_resource type="[^"]+" id="([^"]+)"\]', scene))
sub_refs = set(re.findall(r'SubResource\("([^"]+)"\)', scene))
ext_defs = {resource_id for _resource_path, resource_id in script_paths}
ext_refs = set(re.findall(r'ExtResource\("([^"]+)"\)', scene))

node_paths = {"."}
parent_errors = []
node_re = re.compile(r'\[node name="([^"]+)" type="[^"]+"(?: parent="([^"]+)")?')

for match in node_re.finditer(scene):
    name, parent = match.groups()
    parent = parent or ""
    if parent and parent not in node_paths:
        parent_errors.append(f"{name} -> {parent}")
    node_path = name if not parent or parent == "." else f"{parent}/{name}"
    node_paths.add(node_path)

errors = []
if missing_scripts:
    errors.append(f"missing script resources: {missing_scripts}")
if sub_refs - sub_defs:
    errors.append(f"missing subresources: {sorted(sub_refs - sub_defs)}")
if ext_refs - ext_defs:
    errors.append(f"missing ext resources: {sorted(ext_refs - ext_defs)}")
if parent_errors:
    errors.append(f"missing parent paths: {parent_errors}")

if errors:
    raise SystemExit("scene resource check failed: " + "; ".join(errors))
PY

echo "static_project_check: ok"
