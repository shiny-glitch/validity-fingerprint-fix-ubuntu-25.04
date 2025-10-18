#!/usr/bin/env bash
set -euo pipefail

log() { logger -t fingerprint-fix "$*"; echo "[fingerprint-fix] $*"; }

# Resolve a non-root user for fprintd CLI checks (first real user)
USER_NAME="${SUDO_USER:-${USER:-}}"
if [[ -z "${USER_NAME}" || "${USER_NAME}" == "root" ]]; then
  USER_NAME="$(getent passwd 1000 | cut -d: -f1 || true)"
fi

log "Starting fingerprint self-check… (user=${USER_NAME:-unknown})"

# Ensure correct daemon and tools (avoid confusing fprintd-clients with fprintd daemon)
if dpkg-query -W -f='${Package}\n' fprintd 2>/dev/null | grep -qx fprintd; then
  log "Replacing stock fprintd with open-fprintd…"
  apt-get purge -y fprintd || true
fi
if ! dpkg -s open-fprintd >/dev/null 2>&1; then
  log "Installing open-fprintd…"
  apt-get update -y || true
  apt-get install -y open-fprintd fprintd-clients || true
fi
apt-mark hold fprintd >/dev/null 2>&1 || true

# Wait up to 30s for Validity device (VID 138a)
wait_secs=30
while (( wait_secs-- )); do
  if lsusb | grep -qi '138a:'; then
    log "Validity device detected via lsusb."
    break
  fi
  sleep 1
done

# USB reset (helps sleepy buses)
if command -v /usr/local/bin/reset-validity-usb.sh >/dev/null 2>&1; then
  /usr/local/bin/reset-validity-usb.sh || true
fi
sleep 1

# Make sure services are running
systemctl enable --now open-fprintd >/dev/null 2>&1 || true
systemctl enable --now python3-validity >/dev/null 2>&1 || true

# Nudge udev and restart
udevadm control --reload || true
udevadm trigger || true
systemctl restart open-fprintd || true
systemctl restart python3-validity || true

# Wait for DBus name (open-fprintd)
for i in {1..10}; do
  busctl --system --no-pager --no-legend 2>/dev/null | grep -q 'net.reactivated.Fprint' && break || true
  sleep 1
done

# Health check with retries; treat both messages as failure
tries=30
ok=0
if command -v fprintd-list >/dev/null 2>&1; then
  while (( tries-- )); do
    if ! fprintd-list "${USER_NAME:-root}" 2>&1 | egrep -qi "(No devices available|No devices found)"; then
      log "Fingerprint device is available; CLI check passed."
      ok=1
      break
    fi
    # Wake the daemon/interface by attempting a verify (non-intrusive)
    fprintd-verify >/dev/null 2>&1 || true
    sleep 1
  done
else
  log "fprintd-clients not found; install with: apt install -y fprintd-clients"
fi

if (( ok == 0 )); then
  log "WARNING: Fingerprint device still not exposed after retries."
  journalctl -u python3-validity -b --no-pager -n 60 2>&1 | sed 's/^/[python3-validity] /' | logger -t fingerprint-fix
else
  log "Fingerprint self-check completed."
fi

exit 0
