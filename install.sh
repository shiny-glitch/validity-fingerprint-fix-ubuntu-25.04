#!/usr/bin/env bash
set -euo pipefail

echo "[install] Validity Fingerprint Fix for Ubuntu 25.04 (Plucky)"

# --- sanity: root ---
if [[ $EUID -ne 0 ]]; then
  echo "[install] Please run with sudo."
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export DEBIAN_FRONTEND=noninteractive
apt update

need_open_fprintd=0
if ! apt-cache policy open-fprintd | grep -q 'Candidate:'; then
  need_open_fprintd=1
fi

# If open-fprintd isn't available, add PPA (and pin to noble if on plucky)
if [[ $need_open_fprintd -eq 1 ]]; then
  . /etc/os-release
  echo "[install] Adding PPA: ubuntuhandbook1/open-fprintd"
  apt -y install software-properties-common || true
  add-apt-repository -y ppa:ubuntuhandbook1/open-fprintd

  if [[ "${VERSION_CODENAME:-}" == "plucky" ]]; then
    sed -i 's/plucky/noble/g' /etc/apt/sources.list.d/*open-fprintd*.list || true
  fi
  apt update
fi

# Install stack (daemon + driver + CLI)
apt install -y python3-validity open-fprintd fprintd-clients || {
  echo "[install] ERROR: Could not install required packages."
  exit 1
}

# Prevent stock fprintd (daemon) from replacing open-fprintd
apt purge -y fprintd || true
apt-mark hold fprintd || true

# --- install scripts ---
install -m 0755 "${REPO_DIR}/scripts/fix-fingerprint.sh" /usr/local/bin/fix-fingerprint.sh
install -m 0755 "${REPO_DIR}/scripts/reset-validity-usb.sh" /usr/local/bin/reset-validity-usb.sh

# --- install systemd units ---
install -m 0644 "${REPO_DIR}/systemd/fix-fingerprint.service" /etc/systemd/system/fix-fingerprint.service
install -m 0644 "${REPO_DIR}/systemd/fix-fingerprint-postboot.service" /etc/systemd/system/fix-fingerprint-postboot.service
install -m 0644 "${REPO_DIR}/systemd/fix-fingerprint-postboot.timer" /etc/systemd/system/fix-fingerprint-postboot.timer

# --- udev rules ---
install -m 0644 "${REPO_DIR}/systemd/90-validity-fix.rules" /etc/udev/rules.d/90-validity-fix.rules
install -m 0644 "${REPO_DIR}/systemd/90-validity-start-driver.rules" /etc/udev/rules.d/90-validity-start-driver.rules
install -m 0644 "${REPO_DIR}/systemd/99-validity-no-autosuspend.rules" /etc/udev/rules.d/99-validity-no-autosuspend.rules

# --- reload/enable ---
systemctl daemon-reload
udevadm control --reload
udevadm trigger

systemctl enable --now fix-fingerprint.service
systemctl enable --now fix-fingerprint-postboot.timer

# Run once now
/usr/local/bin/fix-fingerprint.sh || true

echo "[install] Done."
echo "[install] Check: journalctl -t fingerprint-fix -b --no-pager"
