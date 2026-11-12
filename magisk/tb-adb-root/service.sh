#!/system/bin/sh
# Wait until Android has fully booted, then switch adbd to root.
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done
setprop service.adb.root 1
setprop ctl.restart adbd
