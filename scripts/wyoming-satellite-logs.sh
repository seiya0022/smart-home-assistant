#!/usr/bin/env bash
# Follow wyoming-satellite logs from the user systemd service.
set -euo pipefail

journalctl --user -u wyoming-satellite -f "$@"
