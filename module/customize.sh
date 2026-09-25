ui_print "- ADB auth will be disabled and ADB-over-TCP enabled on port 5555"
ui_print "- Reboot after install, then from the PC: adb connect <phone-ip>:5555"
set_perm_recursive "$MODPATH" 0 0 0755 0644
