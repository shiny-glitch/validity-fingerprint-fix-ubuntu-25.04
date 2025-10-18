#!/usr/bin/env bash
set -euo pipefail
echo "[uninstall] Removing Validity fingerprint auto-heal components…"

systemctl disable --now fix-fingerprint.service fix-fingerprint-postboot.timer || true

rm -f /etc/systemd/system/fix-fingerprint.service \
      /etc/systemd/system/fix-fingerprint-postboot.service \
      /etc/systemd/system/fix-fingerprint-postboot.timer \
      /etc/udev/rules.d/90-validity-fix.rules \
      /etc/udev/rules.d/90-validity-start-driver.rules \
      /etc/udev/rules.d/99-validity-no-autosuspend.rules \
      /usr/local/bin/fix-fingerprint.sh \
      /usr/local/bin/reset-validity-usb.sh

systemctl daemon-reload
udevadm control --reload && udevadm trigger

echo "[uninstall] Done."
echo "[uninstall] You can keep python3-validity/open-fprintd installed, or remove them manually if desired."
