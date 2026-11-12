#!/usr/bin/env bash
# =============================================================================
# tb_shade.sh — open or close the Android notification shade over ADB.
#
# Useful when the physical top edge of the digitizer is hard to hit, or for
# scripted screenshots. On the tablet itself you can also just tap the clock /
# status bar once, which opens the shade on LineageOS 18.1.
#
# Usage:  ./tb_shade.sh [open|close]
# =============================================================================
set -euo pipefail

ADB="${ADB:-$HOME/tools/platform-tools/adb}"
ACTION="${1:-open}"

case "$ACTION" in
  open)  "$ADB" shell cmd statusbar expand-notifications ;;
  close) "$ADB" shell cmd statusbar collapse ;;
  *) echo "usage: $0 [open|close]" >&2; exit 2 ;;
esac
