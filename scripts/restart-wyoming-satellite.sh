#!/usr/bin/env bash
# Restart the host wyoming-satellite user systemd service.
set -euo pipefail

systemctl --user restart wyoming-satellite
echo "wyoming-satellite restarted."
systemctl --user --no-pager status wyoming-satellite
