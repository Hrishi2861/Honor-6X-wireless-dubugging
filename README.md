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

**1. Find the phone's current IP.**

> ⚠️ **Never hardcode the subnet.** If the hotspot is hosted by an **Android 9 (Pie) or newer**
> phone, that phone invents a **brand-new random `/24` every time the hotspot is toggled** — the
> gateway moves too, and it usually is *not* `.1`. `192.168.43.0/24` is a pre-Pie assumption and
> will simply be the wrong network. Always **derive the subnet from your own machine**, then scan
> it for the open ADB port. That host *is* the phone.

The fastest human-readable answer is still the **Connected devices** list on the phone hosting
the hotspot. Everything below automates it.

### Linux

```bash
# 1. Work out the subnet you're actually on (never assume a fixed range)
DEV=$(ip -4 route show default | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
NET=$(ip -4 route show dev "$DEV" scope link | awk '/proto kernel/{print $1; exit}')
echo "scanning $NET (via $DEV)"

# 2a. With nmap
sudo apt install nmap -y
nmap -p 5555 --open "$NET"

# 2b. No nmap, no sudo — pure bash, ~3s for a /24
BASE=${NET%.*/*}
for i in $(seq 1 254); do
  (timeout 1 bash -c "echo >/dev/tcp/$BASE.$i/5555" 2>/dev/null && echo "$BASE.$i:5555 OPEN") &
done; wait
```

### Windows

`ipconfig` works in both `cmd` and PowerShell:

```bat
ipconfig | findstr IPv4
```

PowerShell — derive the subnet and scan it in one go:

```powershell
# 1. The interface that holds the default route, plus your address
$me = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1
$a  = $me.IPv4Address.Address.IPAddressToString
$base = $a -replace '\.\d+$',''
"$base.0/24  (iface $($me.InterfaceAlias), gw $($me.IPv4DefaultGateway.NextHop))"

# 2. Scan for the open ADB port
1..254 | ForEach-Object -ThrottleLimit 64 {
    $t = "$base.$_"
    $c = New-Object Net.Sockets.TcpClient
    try {
        $r = $c.BeginConnect($t, 5555, $null, $null)
        if ($r.AsyncWaitHandle.WaitOne(700) -and $c.Connected) { "$t`:5555 OPEN" }
    } catch { } finally { $c.Close() }
}
```

Avoid `Test-NetConnection` for this — it retries and takes several seconds per closed port,
so a `/24` crawl takes minutes.

### macOS

**No, Linux commands don't transfer as-is.** macOS has no `ip` command at all (it's iproute2, a
Linux-only kernel interface — `brew install iproute2mac` is a partial, non-compatible shim), and
it also lacks `timeout` and `seq`. Use the BSD tools:

```bash
# 1. Your address, and the /24 you sit on
IFACE=$(route -n get default | awk '/interface:/{print $2}')
MYIP=$(ipconfig getifaddr "$IFACE")          # the macOS 'ipconfig' is NOT Windows ipconfig
BASE=${MYIP%.*}                             # 10.73.234.22 -> 10.73.234
echo "scanning $BASE.0/24 (via $IFACE, $MYIP)"

# 2. Scan for the open ADB port ({1..254} instead of seq; -G caps connect time, no timeout needed)
for i in {1..254}; do
  (nc -z -G 1 -w 1 "$BASE.$i" 5555 2>/dev/null && echo "$BASE.$i:5555 OPEN") &
done; wait
```

Two macOS-specific traps here: `ifconfig` prints `netmask 0xffffff00` rather than `/24`, so you
cannot reuse the Linux CIDR-parsing one-liner — hence deriving `BASE` from the address instead.
A hotspot is always a `/24`, so that assumption is safe here; for a genuinely non-`/24` network
read the real prefix from `netstat -rn` (note macOS prints `10.73.234/24`, i.e. three octets).

Portability cheat-sheet:

| Task | Linux | macOS | Windows |
|------|-------|-------|---------|
| Your interface | `ip -4 route show default` | `route -n get default` | `Get-NetIPConfiguration` |
| Your IPv4 | `ip -4 addr show scope global` | `ipconfig getifaddr en0` | `ipconfig` |
| Route to internet | `ip route get 1.1.1.1` | `netstat -rn` | `route print` |
| ARP table | `ip neigh` | `arp -a` | `arp -a` |
| `/dev/tcp` scan | ✅ works | ✅ only under `bash`, **not** zsh | ❌ use PowerShell |
| `ping -W` unit | seconds | **milliseconds** | ms (`-w`) |

**2. Confirm it's really the phone**, then connect:

```bash
adb connect <phone-ip>:5555
adb devices -l        # expect: product:BLN-L22 model:BLN_L22 device:HWBLN-H
scrcpy                # mirror + control with the laptop mouse/keyboard
```

### Why a ping sweep won't work here

The Honor 6X does **not** answer ICMP, so it never appears in `ip neigh` / `arp -a` and a
ping-sweep-and-read-the-ARP-table approach finds nothing at all. Only a **TCP connect scan for
port 5555** sees it. Treat `ping` as unavailable for discovery.

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
- **The IP changed and my old address is dead:** expected. The hotspot host re-randomized its subnet (see below). Re-run the scan; don't retype a remembered address.
- **Can't find the IP:** scan for TCP 5555 as shown above — *not* `ping`, which this phone ignores. The hotspot host's connected-devices list is the quickest manual option.

## Why the hotspot subnet keeps changing

Since **Android 9 (Pie)**, AOSP replaced the hardcoded hotspot range `192.168.43.1/24` with a
**randomly generated `/24`, re-drawn every time the hotspot is enabled** — in
`packages/modules/Connectivity/.../Tethering/src/android/net/ip/IpServer.java`. The point is to
avoid colliding with a LAN the hotspot's own upstream connection may already be on.

So with a Pie+ hotspot host you will see a new subnet on every toggle and every reboot:

```
10.175.16.231:5555     earlier session
10.124.129.231:5555    after a restart
10.73.234.231:5555     after another restart
```

Two things worth noticing:

- **Only the first three octets change.** The last octet stays put, because the DHCP server keys
  leases on the client's identity (MAC / DHCP client-id), which doesn't change. Don't rely on
  this though — it is not guaranteed, and the `192.168.43.x` shape is pure coincidence.
- **The gateway moves with it, and is usually not `.1`** (e.g. `10.73.234.7`, not `10.73.234.1`).
  A non-`.1` gateway is a reliable tell that the randomized path is in use.

Confirming which behaviour you have, from the hotspot host over USB:

```bash
adb -s <host-serial> shell dumpsys wifi | grep -E 'CMD_SET_AP|CMD_AP_STOPPED'
```

A `CMD_SET_AP 1 0` line is the hotspot coming up — each one means a fresh subnet roll.

If you want a **fixed** address instead, the honest options are to pin a static IP on the
Honor 6X's WiFi connection (only viable if the host stops randomising), or to sidestep the
hotspot and use a normal router on a fixed subnet. Android's stock tethering UI exposes no
subnet setting, so there is no built-in way to pin it.

> ⚠️ Some hotspot hosts do **not** expose their DHCP leases to `adb` — MIUI/Android 16 here
> reports `mDhcpResultsParcelable baseConfiguration null` — so querying the host for the client's
> IP is not a reliable option. The port scan is.

## ⚠️ Security note

While active, `ro.adb.secure=0` plus an open TCP 5555 means **any device on the same network can connect via ADB with no prompt.** This is a deliberate trade-off for a no-touch recovery scenario — keep it to a **private, trusted hotspot**. To lock it back down, disable or remove the module in the Magisk app.

## Author

**Hrishikesh Thombare**
- GitHub: [@Hrishi2861](https://github.com/Hrishi2861)
- Telegram: [@rtx5069](https://t.me/rtx5069)

## License

[MIT License](./LICENSE) — Copyright (c) 2026 Hrishikesh Thombare.
