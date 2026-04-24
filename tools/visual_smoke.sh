#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
SCREENSHOT_PATH="${SCREENSHOT_PATH:-/tmp/skyline-coins-smoke.png}"
DISPLAY_VALUE="${DISPLAY:-:99}"
if [[ "${DISPLAY_VALUE}" != :* ]]; then
  DISPLAY_VALUE=":${DISPLAY_VALUE}"
fi

if ! command -v "${GODOT_BIN}" >/dev/null 2>&1 && [[ ! -x "${GODOT_BIN}" ]]; then
  echo "visual_smoke: Godot binary not found. Install Godot 4.4+ or set GODOT_BIN=/path/to/godot." >&2
  exit 127
fi

if ! command -v import >/dev/null 2>&1; then
  echo "visual_smoke: ImageMagick 'import' command not found." >&2
  exit 127
fi

if ! pgrep Xvfb >/dev/null 2>&1; then
  if ! command -v Xvfb >/dev/null 2>&1; then
    echo "visual_smoke: Xvfb is not running and is not installed." >&2
    exit 127
  fi
  Xvfb "${DISPLAY_VALUE}" -screen 0 1280x720x24 -ac +extension GLX +render -noreset &
  sleep 1
fi

DISPLAY="${DISPLAY_VALUE}" "${GODOT_BIN}" --path "${ROOT_DIR}" --render-driver opengl3 2>/tmp/skyline-coins-godot.log &
GAME_PID=$!

cleanup() {
  kill "${GAME_PID}" 2>/dev/null || true
}
trap cleanup EXIT

sleep 4
DISPLAY="${DISPLAY_VALUE}" import -window root "${SCREENSHOT_PATH}"

if [[ ! -s "${SCREENSHOT_PATH}" ]]; then
  echo "visual_smoke: screenshot was not created at ${SCREENSHOT_PATH}" >&2
  exit 1
fi

echo "visual_smoke: screenshot captured at ${SCREENSHOT_PATH}"
