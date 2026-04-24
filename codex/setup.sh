#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Godot runtime dependencies ==="
sudo apt-get update -qq

ALSA_PACKAGE="libasound2"
if apt-cache show libasound2t64 >/dev/null 2>&1; then
  ALSA_PACKAGE="libasound2t64"
fi

sudo apt-get install -y -qq \
  xvfb \
  x11-utils \
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
  "${ALSA_PACKAGE}" \
  imagemagick \
  ffmpeg \
  xdotool \
  procps \
  wget \
  unzip \
  python3-pip

echo "=== Downloading Godot 4.4.1 Stable ==="
GODOT_VERSION="4.4.1"
GODOT_TAG="${GODOT_VERSION}-stable"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_linux.x86_64.zip"

wget -q "${GODOT_URL}" -O /tmp/godot.zip
unzip -o /tmp/godot.zip -d /tmp
sudo mv "/tmp/Godot_v${GODOT_TAG}_linux.x86_64" /usr/local/bin/godot
sudo chmod +x /usr/local/bin/godot
rm /tmp/godot.zip

echo "=== Installing GDScript formatting tools ==="
pip install gdtoolkit --break-system-packages 2>/dev/null || pip install gdtoolkit

echo "=== Starting Xvfb virtual display ==="
pkill Xvfb 2>/dev/null || true
Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset &
sleep 1

echo 'export DISPLAY=:99' >> ~/.bashrc

echo "=== Verifying setup ==="
godot --version
DISPLAY=:99 xdpyinfo | head -5 || true
convert --version | head -1 || true
echo "=== Setup complete ==="
