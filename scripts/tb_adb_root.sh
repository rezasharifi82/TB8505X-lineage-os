#!/usr/bin/env bash
# =============================================================================
# tb_adb_root.sh — switch the TB-8505X adbd to root without `adb root`.
#
# LineageOS 18.1 on the Phh GSI blocks the host `adb root` command even when
# "Rooted debugging" is enabled. The GSI ships `phh-su`, so we set
# service.adb.root and restart adbd from inside the device instead.
#
# Usage:  ./tb_adb_root.sh
# =============================================================================
set -euo pipefail

ADB="${ADB:-$HOME/tools/platform-tools/adb}"

command -v "$ADB" >/dev/null 2>&1 || { echo "adb not found: $ADB" >&2; exit 1; }

if ! timeout 10 "$ADB" get-state >/dev/null 2>&1; then
  echo "no adb device (connect the tablet and enable USB debugging)" >&2
  exit 1
fi

if "$ADB" shell id 2>/dev/null | grep -q 'uid=0'; then
  echo "adbd is already root"
  exit 0
fi

echo "switching adbd to root via phh-su ..."
"$ADB" shell "phh-su -c 'setprop service.adb.root 1; setprop ctl.restart adbd'" \
  || { echo "phh-su failed; falling back to 'adb root'" >&2; "$ADB" root || true; }

sleep 3
timeout 20 "$ADB" wait-for-device || true
echo -n "adbd now: "
"$ADB" shell id
