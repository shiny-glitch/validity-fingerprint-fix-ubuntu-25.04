# Validity Fingerprint Fix for Ubuntu 25.04 (Plucky)

**Fixes flaky / “No devices found”** Validity (Vendor **138a**) fingerprint sensors on Ubuntu **25.04** by:
- using **python3-validity** (userspace driver) + **open-fprintd** (daemon),
- disabling USB autosuspend,
- USB power-cycling the sensor at boot,
- fixing startup timing (udev settle + delayed start),
- auto-healing on boot, after boot (timer), and on device add (udev→systemd trigger).

> Tested: ThinkPad P51 (VSI 55E FM209-001). Community testing welcome!

## Quick Install
```bash
git clone https://github.com/<you>/validity-fingerprint-fix-ubuntu-25.04.git
cd validity-fingerprint-fix-ubuntu-25.04
sudo ./install.sh
