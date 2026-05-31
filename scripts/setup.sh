#!/usr/bin/env bash
# First-time setup: create directories, copy config templates, start containers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Creating model directories..."
mkdir -p whisper piper

if [[ ! -f .env ]]; then
  echo "Creating .env from .env.example..."
  cp .env.example .env
  echo "Edit .env to set MAC_MINI_IP and audio devices (run scripts/detect-audio.sh)."
else
  echo ".env already exists, skipping."
fi

SECRETS="$ROOT/homeassistant/config/secrets.yaml"
SECRETS_EXAMPLE="$ROOT/homeassistant/config/secrets.yaml.example"
if [[ ! -f "$SECRETS" ]]; then
  echo "Creating secrets.yaml from secrets.yaml.example..."
  cp "$SECRETS_EXAMPLE" "$SECRETS"
else
  echo "secrets.yaml already exists, skipping."
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed."
  exit 1
fi

echo "Starting containers..."
docker compose up -d

echo
echo "Setup complete. Next steps:"
echo "  1. Open Home Assistant at http://<this-machine-ip>:8123"
echo "  2. Follow README.md to configure Wyoming integrations and Ollama"
echo "  3. Run scripts/detect-audio.sh if wake word / mic does not work"
