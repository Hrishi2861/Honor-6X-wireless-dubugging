#!/system/bin/sh
# ADB Auto-Enable (No-Touch) — runs at every boot in late_start service mode.
MODDIR=${0%/*}

# Wait for a complete boot before touching the Settings provider.
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done
sleep 10

# Unlock developer settings + turn on USB debugging (same as the Settings toggle,
# but applied with root so it is not subject to the flaky EMUI UI).
settings put global development_settings_enabled 1
settings put global adb_enabled 1

# Belt-and-suspenders in case the system.prop timing missed adbd startup.
resetprop ro.adb.secure 0
resetprop service.adb.tcp.port 5555

# Initial restart so adbd binds TCP 5555 (auth OFF).
setprop ctl.restart adbd

# EMUI is known to silently revert the USB-debugging setting shortly after boot.
# Re-assert for the first ~5 minutes. We use ctl.start (a no-op when adbd is already
# running) so an active connection is never dropped.
i=0
while [ $i -lt 20 ]; do
  sleep 15
  settings put global adb_enabled 1
  resetprop service.adb.tcp.port 5555
  setprop ctl.start adbd
  i=$((i + 1))
done

# Record current IP addresses to the module dir (readable once ADB is up).
ip addr show 2>/dev/null | grep 'inet ' > "$MODDIR/last_ip.txt"
