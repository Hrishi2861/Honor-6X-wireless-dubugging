# Honor 6X — Wireless Debugging (No-Touch) Magisk Module

A Magisk module that enables **ADB over WiFi with zero touchscreen interaction**, built for an Honor 6X (EMUI 8 / Android 8.0) with a **dead touchscreen** that is operated by an **OTG mouse**.

## The problem this solves

- The touchscreen is dead; the phone is controlled with a USB OTG mouse.
- There is only **one micro-USB port**, so the mouse and a PC cable can't be plugged in at the same time.
- USB debugging can't be used the normal way: attaching the PC means unplugging the only input device, and the **"Allow USB debugging?" RSA prompt** can't be accepted once the mouse is gone.
- On EMUI, the USB-debugging toggle also tends to silently revert after you leave Developer Options.

This module fixes all of that at boot, with root, so the phone can be reached **over WiFi/hotspot** — no cable, no prompt, no touch.

## What it does

On every boot the module:

- Disables the ADB authorization prompt (`ro.adb.secure=0`) — any host connects without confirmation.
- Starts `adbd` on **TCP port 5555** (classic ADB-over-network — works on Android 8, unlike the Android 11 "Wireless debugging" UI).
- Forces `adb_enabled=1` with root and **re-asserts it for ~5 minutes** so EMUI can't quietly turn it back off.

The result: from a laptop on the same network you run `adb connect <phone-ip>:5555` and get an authorized connection instantly — then drive the phone with [`scrcpy`](https://github.com/Genymobile/scrcpy).

## Requirements

- Device rooted with **Magisk v20.4+**.
- Magisk app navigable with the OTG mouse (to flash from storage).
- Tested target: Honor 6X, EMUI 8, Android 8.0 (the mechanism is generic and works on most rooted Android devices).

## Installation

1. Download `adb_autoenable.zip` from the [Releases](https://github.com/Hrishi2861/Honor-6X-wireless-dubugging/releases) page.
2. Get it onto the phone. Since the USB port is occupied by the mouse, the easiest routes are:
   - **microSD card** (Honor 6X has a slot) via a PC card reader, or
   - **download it in a browser** over the hotspot.
3. Open **Magisk → Modules → Install from storage**, pick the zip (navigate with the mouse).
4. **Reboot.**

## Usage (connecting from the laptop)

Both the phone and the laptop must be on the **same network** — a shared phone hotspot works fine.

**1. Find the phone's IP** (Linux example; `192.168.43.0/24` is the usual hotspot range):

```bash
# Best: scan for the open ADB port — that host IS the phone
sudo apt install nmap -y
nmap -p 5555 --open 192.168.43.0/24

# No nmap? ping-sweep then read the neighbour table
for i in $(seq 1 254); do ping -c1 -W1 192.168.43.$i >/dev/null & done; wait
ip neigh
```

Or simply read the **Connected devices** list on the phone hosting the hotspot.

**2. Connect and control:**

```bash
adb connect <phone-ip>:5555
adb devices           # should show the device as "device" (authorized)
scrcpy                # mirror + control with the laptop mouse/keyboard
```

## Building from source

```bash
git clone https://github.com/Hrishi2861/Honor-6X-wireless-dubugging.git
cd Honor-6X-wireless-dubugging/module
zip -r ../adb_autoenable.zip . -x '.*'
```

The zip must have `module.prop` at its root — that's why we zip the *contents* of `module/`.

## How it works

| File | Role |
|------|------|
| `module/module.prop` | Module metadata shown in the Magisk app. |
| `module/system.prop` | Applied early by Magisk: `ro.adb.secure=0`, `service.adb.tcp.port=5555`. |
| `module/service.sh` | Late-start boot script: enables `adb_enabled`, restarts `adbd` on TCP 5555, and re-asserts for ~5 min to survive EMUI's auto-revert. |
| `module/customize.sh` | Install-time messages + permission fix. |
| `module/META-INF/.../update-binary` | Official Magisk module installer (makes the zip flashable). |

## Troubleshooting

- **`adb connect` returns `unauthorized`:** `ro.adb.secure=0` hasn't taken yet. Do a **second reboot** (guarantees `system.prop` is applied by init before `adbd`) and retry.
- **The USB-debugging toggle in Developer Options looks off:** ignore it — the module drives `adbd` directly, so the WiFi path works regardless of the toggle's displayed state.
- **Can't find the IP:** the phone list on the hotspot host is the fastest source; otherwise re-run the nmap scan.

## ⚠️ Security note

While active, `ro.adb.secure=0` plus an open TCP 5555 means **any device on the same network can connect via ADB with no prompt.** This is a deliberate trade-off for a no-touch recovery scenario — keep it to a **private, trusted hotspot**. To lock it back down, disable or remove the module in the Magisk app.

## Author

**Hrishikesh Thombare**
- GitHub: [@Hrishi2861](https://github.com/Hrishi2861)
- Telegram: [@rtx5069](https://t.me/rtx5069)

## License

[MIT License](./LICENSE) — Copyright (c) 2026 Hrishikesh Thombare.
