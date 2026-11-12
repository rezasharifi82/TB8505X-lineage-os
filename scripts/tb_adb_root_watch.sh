#!/usr/bin/env bash
# =============================================================================
# tb_adb_root_watch.sh — keep adbd on the tablet running as root.
#
# Intended for a systemd user service (see tb-adb-root.service) or:
#   nohup ./tb_adb_root_watch.sh >/dev/null 2>&1 &
#
# The check is cheap: it only talks to adb when the tablet is present.
# =============================================================================
set -u

ADB="${ADB:-$HOME/tools/platform-tools/adb}"
SLEEP="${SLEEP:-10}"

while true; do
  if timeout 5 "$ADB" get-state >/dev/null 2>&1; then
    id=$("$ADB" shell id 2>/dev/null || true)
    if ! printf '%s' "$id" | grep -q 'uid=0'; then
      "$ADB" shell "phh-su -c 'setprop service.adb.root 1; setprop ctl.restart adbd'" \
        >/dev/null 2>&1 || true
      sleep 3
      "$ADB" wait-for-device >/dev/null 2>&1 || true
    fi
  fi
  sleep "$SLEEP"
done
