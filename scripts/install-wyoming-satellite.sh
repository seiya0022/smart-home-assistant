#!/usr/bin/env bash
# Install wyoming-satellite on the ThinkPad host and register a user systemd service.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WYOMING_DIR="${WYOMING_DIR:-$HOME/wyoming-satellite}"
WYOMING_REPO="https://github.com/rhasspy/wyoming-satellite.git"
SERVICE_NAME="wyoming-satellite.service"
SERVICE_DIR="$HOME/.config/systemd/user"
TEMPLATE="$ROOT/scripts/wyoming-satellite.service.template"

missing_packages=()
for pkg in python3-venv python3-pip alsa-utils; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    missing_packages+=("$pkg")
  fi
done

if ((${#missing_packages[@]} > 0)); then
  echo "Missing required packages: ${missing_packages[*]}"
  echo "Install them with:"
  echo "  sudo apt update"
  echo "  sudo apt install -y ${missing_packages[*]}"
  exit 1
fi

if ! arecord -L 2>/dev/null | grep -q '^pulse$'; then
  echo "Warning: ALSA 'pulse' device not found."
  echo "Install PipeWire/PulseAudio ALSA plugin if needed:"
  echo "  sudo apt install -y pipewire pipewire-pulse libasound2-plugins"
  echo "Falling back to 'default' is possible via MIC_DEVICE/SND_DEVICE in .env."
fi

if [[ ! -f "$ROOT/.env" ]]; then
  echo "Creating .env from .env.example..."
  cp "$ROOT/.env.example" "$ROOT/.env"
fi

# shellcheck disable=SC1091
set -a
source "$ROOT/.env"
set +a

MIC_DEVICE="${MIC_DEVICE:-pulse}"
SND_DEVICE="${SND_DEVICE:-pulse}"

if [[ ! -d "$WYOMING_DIR/.git" ]]; then
  echo "Cloning wyoming-satellite into $WYOMING_DIR..."
  git clone "$WYOMING_REPO" "$WYOMING_DIR"
else
  echo "Updating wyoming-satellite in $WYOMING_DIR..."
  git -C "$WYOMING_DIR" pull --ff-only
fi

echo "Setting up Python virtual environment..."
"$WYOMING_DIR/script/setup"

echo "Installing VAD dependency..."
"$WYOMING_DIR/.venv/bin/pip3" install 'pysilero-vad==1.0.0'

if ! groups "$USER" | grep -q '\baudio\b'; then
  echo "Warning: user '$USER' is not in the 'audio' group."
  echo "Add yourself with: sudo usermod -aG audio $USER"
  echo "Then log out and back in before using the microphone."
fi

if ! loginctl show-user "$USER" -p Linger --value 2>/dev/null | grep -q yes; then
  echo "Enabling systemd user lingering so the service survives logout..."
  sudo loginctl enable-linger "$USER"
fi

USER_ID="$(id -u)"
mkdir -p "$SERVICE_DIR"

sed \
  -e "s|@@REPO_ROOT@@|$ROOT|g" \
  -e "s|@@WYOMING_DIR@@|$WYOMING_DIR|g" \
  -e "s|@@USER_ID@@|$USER_ID|g" \
  -e "s|@@MIC_DEVICE@@|$MIC_DEVICE|g" \
  -e "s|@@SND_DEVICE@@|$SND_DEVICE|g" \
  "$TEMPLATE" > "$SERVICE_DIR/$SERVICE_NAME"

systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME"

echo
echo "wyoming-satellite installed and started."
echo "  Install dir: $WYOMING_DIR"
echo "  Service:     systemctl --user status $SERVICE_NAME"
echo "  Logs:        ./scripts/wyoming-satellite-logs.sh"
echo "  Restart:     ./scripts/restart-wyoming-satellite.sh"
echo
echo "Ensure Docker services are running: docker compose up -d"
echo "Then verify port 10700: ss -tlnp | grep 10700"
