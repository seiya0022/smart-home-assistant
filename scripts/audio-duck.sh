#!/usr/bin/env bash
# Duck non-assistant audio streams while wyoming-satellite is listening/responding.
# Jarvis TTS (aplay) is excluded so only other apps are lowered.
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/wyoming-audio-duck.state"
WATCHDOG_PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/wyoming-audio-duck.watchdog.pid"

DUCK_LEVEL="${DUCK_LEVEL:-20%}"
DUCK_TIMEOUT="${DUCK_TIMEOUT:-40}"
AUDIO_DUCK_ENABLED="${AUDIO_DUCK_ENABLED:-1}"

usage() {
  echo "Usage: $0 {start|stop}" >&2
  exit 1
}

require_pactl() {
  if ! command -v pactl >/dev/null 2>&1; then
    echo "audio-duck: pactl not found; install pulseaudio-utils" >&2
    return 1
  fi
}

is_jarvis_stream() {
  local app_name="$1"
  [[ "$app_name" == *aplay* ]]
}

list_sink_inputs() {
  pactl list sink-inputs 2>/dev/null | awk '
    /^(Sink Input|シンク入力) / {
      if (idx != "") {
        print idx "\t" app "\t" vol
      }
      if (match($0, /#[0-9]+/)) {
        idx = substr($0, RSTART + 1, RLENGTH - 1)
      }
      app = ""
      vol = ""
    }
    /(Volume|ボリューム):/ {
      line = $0
      if (match(line, /[0-9]+%/)) {
        vol = substr(line, RSTART, RLENGTH)
      }
    }
    /application\.name = "/ {
      line = $0
      sub(/.*application\.name = "/, "", line)
      sub(/".*/, "", line)
      app = line
    }
    /^$/ {
      if (idx != "") {
        print idx "\t" app "\t" vol
        idx = ""
      }
    }
    END {
      if (idx != "") print idx "\t" app "\t" vol
    }
  '
}

get_sink_input_volume() {
  local index="$1"
  pactl list sink-inputs 2>/dev/null | awk -v idx="$index" '
    /^(Sink Input|シンク入力) / {
      if (match($0, /#[0-9]+/)) {
        current = substr($0, RSTART + 1, RLENGTH - 1)
      } else {
        current = ""
      }
      vol = ""
    }
    current == idx && /(Volume|ボリューム):/ {
      line = $0
      if (match(line, /[0-9]+%/)) {
        vol = substr(line, RSTART, RLENGTH)
      }
    }
    END {
      print vol
    }
  '
}

stop_watchdog() {
  if [[ -f "$WATCHDOG_PID_FILE" ]]; then
    local pid
    pid="$(cat "$WATCHDOG_PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$WATCHDOG_PID_FILE"
  fi
}

start_watchdog() {
  stop_watchdog
  (
    sleep "$DUCK_TIMEOUT"
    if [[ -f "$STATE_FILE" ]]; then
      echo "audio-duck: watchdog timeout (${DUCK_TIMEOUT}s); restoring volumes" >&2
      "$0" stop
    fi
  ) &
  echo $! >"$WATCHDOG_PID_FILE"
}

duck_start() {
  if [[ "$AUDIO_DUCK_ENABLED" != "1" ]]; then
    exit 0
  fi

  require_pactl || exit 0

  if [[ -f "$STATE_FILE" ]]; then
    exit 0
  fi

  : >"$STATE_FILE"
  local ducked=0

  while IFS=$'\t' read -r index app_name volume; do
    [[ -z "$index" ]] && continue
    if is_jarvis_stream "$app_name"; then
      continue
    fi

    if [[ -z "$volume" ]]; then
      volume="$(get_sink_input_volume "$index")"
    fi
    [[ -z "$volume" ]] && continue

    echo "${index} ${volume}" >>"$STATE_FILE"
    pactl set-sink-input-volume "$index" "$DUCK_LEVEL" >/dev/null 2>&1 || continue
    ducked=$((ducked + 1))
    echo "audio-duck: lowered sink-input #${index} (${app_name:-unknown}) to ${DUCK_LEVEL}" >&2
  done < <(list_sink_inputs)

  if [[ ! -s "$STATE_FILE" ]]; then
    rm -f "$STATE_FILE"
    echo "audio-duck: no duckable sink-inputs found" >&2
    exit 0
  fi

  echo "audio-duck: ducked ${ducked} stream(s)" >&2
  start_watchdog
}

duck_stop() {
  stop_watchdog

  if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
  fi

  if ! require_pactl; then
    rm -f "$STATE_FILE"
    exit 0
  fi

  local restored=0
  while read -r index volume; do
    [[ -z "$index" || -z "$volume" ]] && continue
    pactl set-sink-input-volume "$index" "$volume" >/dev/null 2>&1 || true
    restored=$((restored + 1))
  done <"$STATE_FILE"

  rm -f "$STATE_FILE"
  echo "audio-duck: restored ${restored} stream(s)" >&2
}

case "${1:-}" in
  start) duck_start ;;
  stop) duck_stop ;;
  *) usage ;;
esac
