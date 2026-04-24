#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "${GODOT_BIN}" >/dev/null 2>&1 && [[ ! -x "${GODOT_BIN}" ]]; then
  echo "validate: Godot binary not found. Install Godot 4.4+ or set GODOT_BIN=/path/to/godot." >&2
  exit 127
fi

"${GODOT_BIN}" --path "${ROOT_DIR}" --headless --check-only 2>&1

if command -v gdformat >/dev/null 2>&1; then
  gdformat --check "${ROOT_DIR}/scripts"/*.gd
else
  echo "validate: gdformat not installed; skipping format check"
fi

if command -v gdlint >/dev/null 2>&1; then
  gdlint "${ROOT_DIR}/scripts"/*.gd
else
  echo "validate: gdlint not installed; skipping lint check"
fi
