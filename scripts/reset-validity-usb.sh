#!/usr/bin/env bash
set -euo pipefail
VID_HEX="138a"  # Validity vendor ID

for dev in /sys/bus/usb/devices/*; do
  [[ -f "$dev/idVendor" ]] || continue
  if [[ "$(cat "$dev/idVendor")" == "$VID_HEX" ]]; then
    parent="$dev"
    [[ -f "$parent/authorized" ]] || parent="$(dirname "$dev")"
    if [[ -w "$parent/authorized" ]]; then
      echo 0 > "$parent/authorized" || true
      sleep 0.6
      echo 1 > "$parent/authorized" || true
    fi
  fi
done
