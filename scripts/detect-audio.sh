#!/usr/bin/env bash
# List ALSA capture and playback devices for wyoming-satellite configuration.
set -euo pipefail

echo "=== Recommended (host satellite) ==="
echo "Use pulse in .env to follow the OS default input/output."
echo "Switch defaults in GNOME Settings -> Sound when plugging USB audio."
echo
echo "Example .env entries:"
echo "  MIC_DEVICE=pulse"
echo "  SND_DEVICE=pulse"
echo

echo "=== OS default devices ==="
if command -v pactl >/dev/null 2>&1; then
  echo "Default source (microphone):"
  pactl get-default-source 2>/dev/null || echo "  (not available)"
  echo "Default sink (speaker):"
  pactl get-default-sink 2>/dev/null || echo "  (not available)"
elif command -v wpctl >/dev/null 2>&1; then
  wpctl status 2>/dev/null | grep -E 'Default|Audio' || wpctl status
else
  echo "pactl/wpctl not found. Install pipewire-pulse or pulseaudio."
fi

echo
echo "=== Capture devices (microphones) ==="
echo "Use a plughw: device name only if you need fixed ALSA hardware access."
echo
if command -v arecord >/dev/null 2>&1; then
  arecord -L | grep -E '^[a-z]|^  ' || arecord -L
else
  echo "arecord not found. Install alsa-utils: sudo apt install alsa-utils"
fi

echo
echo "=== Playback devices (speakers) ==="
echo "Use a plughw: device name only if you need fixed ALSA hardware access."
echo
if command -v aplay >/dev/null 2>&1; then
  aplay -L | grep -E '^[a-z]|^  ' || aplay -L
else
  echo "aplay not found. Install alsa-utils: sudo apt install alsa-utils"
fi

echo
echo "=== Test capture with pulse ==="
echo "  arecord -D pulse -d 2 -f S16_LE -r 16000 test.wav"
echo "  aplay test.wav"
