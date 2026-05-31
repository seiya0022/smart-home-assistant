#!/usr/bin/env bash
# List ALSA capture and playback devices for wyoming-satellite configuration.
set -euo pipefail

echo "=== Capture devices (microphones) ==="
echo "Use a plughw: device name for MIC_DEVICE in .env"
echo
if command -v arecord >/dev/null 2>&1; then
  arecord -L | grep -E '^[a-z]|^  ' || arecord -L
else
  echo "arecord not found. Install alsa-utils: sudo apt install alsa-utils"
fi

echo
echo "=== Playback devices (speakers) ==="
echo "Use a plughw: device name for SND_DEVICE in .env"
echo
if command -v aplay >/dev/null 2>&1; then
  aplay -L | grep -E '^[a-z]|^  ' || aplay -L
else
  echo "aplay not found. Install alsa-utils: sudo apt install alsa-utils"
fi

echo
echo "Example .env entries:"
echo "  MIC_DEVICE=plughw:CARD=PCH,DEV=0"
echo "  SND_DEVICE=plughw:CARD=PCH,DEV=0"
