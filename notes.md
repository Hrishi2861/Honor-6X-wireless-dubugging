# ADB Auto-Enable (No-Touch) — v1.0

First release of the Honor 6X wireless-debugging Magisk module.

## What's included

- **`adb_autoenable.zip`** — flashable Magisk module (Magisk v20.4+).

## Features

- Disables the ADB authorization prompt (`ro.adb.secure=0`) — connect with no on-device confirmation.
- Starts `adbd` on **TCP port 5555** at boot (classic ADB-over-network, works on Android 8 / EMUI 8).
- Forces `adb_enabled=1` with root and re-asserts it for ~5 minutes to survive EMUI silently reverting the toggle.

## Install

1. Copy `adb_autoenable.zip` to the phone (microSD card or browser download — the USB port is busy with the OTG mouse).
2. Magisk → **Modules → Install from storage** → select the zip.
3. **Reboot.**

## Connect

```bash
adb connect <phone-ip>:5555
adb devices
scrcpy
```

Find `<phone-ip>` with `nmap -p 5555 --open 192.168.43.0/24`, or from the hotspot host's connected-devices list. See the [README](https://github.com/Hrishi2861/Honor-6X-wireless-dubugging#usage-connecting-from-the-laptop) for full details.

## ⚠️ Security

While active, any device on the same network can connect via ADB with no prompt. Use only on a private, trusted hotspot; remove the module in Magisk to revert.

## Changelog

- Initial release: `ro.adb.secure=0`, ADB-over-TCP 5555, root-enforced `adb_enabled` with EMUI re-assert loop.
