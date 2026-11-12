#!/usr/bin/env bash
# =============================================================================
# flash_verified.sh — precheck, then flash LineageOS 18.1 GSI + stock vendor.
#
#   ./flash_verified.sh --yes
#
# Every step is checked. Any failure aborts before the next write.
# This wipes userdata/cache. Logs to logs/flash_<timestamp>.log
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${TB8505X_ROOT:-$(cd "$HERE/.." && pwd)}"
FB="${FASTBOOT:-$HOME/tools/platform-tools/fastboot}"
ADB="${ADB:-$HOME/tools/platform-tools/adb}"
FB_TIMEOUT="${FB_TIMEOUT:-900}"

VENDOR="$ROOT/backups/brom_full_20261110_210125/vendor.bin"
BOOT="$ROOT/images/boot/boot_patched.img"
DTBO="$ROOT/backups/brom_pre_unlock/dtbo.bin"
VBMETA="$ROOT/images/boot/vbmeta_disabled.img"
GSI="$ROOT/images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img"

BOLD=$'\033[1m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; CYAN=$'\033[0;36m'; RESET=$'\033[0m'
log()  { echo "${CYAN}[*]${RESET} $*"; }
ok()   { echo "${GREEN}[ OK ]${RESET} $*"; }
warn() { echo "${YELLOW}[WARN]${RESET} $*"; }
die()  { echo "${RED}[FAIL]${RESET} $*" >&2; exit 1; }

[ "${1:-}" = "--yes" ] || die "refusing to flash without --yes (this wipes userdata/cache)"

mkdir -p "$ROOT/logs"
STAMP=$(date +%Y%m%d_%H%M%S)
LOG="$ROOT/logs/flash_$STAMP.log"
# everything below is also written to the log
exec > >(tee -a "$LOG") 2>&1

echo "${BOLD}=== TB-8505X verified flash — $STAMP ===${RESET}"
echo

# ------------------------------------------------------------------ precheck
"$HERE/precheck_flash.sh" || die "preflight failed — nothing was flashed"
echo

# ------------------------------------------------------------------ device
devs=$("$FB" devices 2>/dev/null | awk 'NF{print $1}')
[ -n "$devs" ] || die "no fastboot device after preflight"
[ "$(echo "$devs" | wc -l)" -eq 1 ] || die "multiple fastboot devices: $devs"
FB_SERIAL="$devs"
fb() { timeout "$FB_TIMEOUT" "$FB" -s "$FB_SERIAL" "$@"; }
ok "using fastboot serial $FB_SERIAL"

getvar() { timeout 20 "$FB" -s "$FB_SERIAL" getvar "$1" 2>&1 | sed -n "s/.*$1: //p" | head -1; }
product=$(getvar product)
[ "$product" = "akita_row_call" ] || die "wrong product: $product"
ok "product=$product"

# ------------------------------------------------------------------ helpers
step() {
  local name=$1; shift
  log "$name"
  local out rc
  set +e
  out=$("$@" 2>&1); rc=$?
  set -e
  echo "$out"
  if [ $rc -ne 0 ] || echo "$out" | grep -qiE "^FAILED|error:"; then
    die "$name failed (rc=$rc). Stopping; nothing further was written."
  fi
  echo "$out" | grep -q "OKAY" || warn "$name returned rc=0 but no OKAY line"
  ok "$name"
}

# ------------------------------------------------------------------ flash
step "1/6 vbmeta (AVB verification off)" \
  fb flash vbmeta "$VBMETA"
step "2/6 stock vendor (Android 10, 838 MB)" \
  fb flash vendor "$VENDOR"
step "3/6 boot (stock kernel + patched fstab)" \
  fb flash boot "$BOOT"
step "4/6 dtbo (stock)" \
  fb flash dtbo "$DTBO"
step "5/6 system (LineageOS 18.1 arm64_bvS, 1.85 GB)" \
  fb flash system "$GSI"

log "6/6 wiping userdata/cache/metadata"
fb -w || die "fastboot -w failed"
ok "wipe complete"

log "rebooting"
fb reboot || die "fastboot reboot failed"
ok "reboot sent"

# ------------------------------------------------------------------ monitor
echo
log "waiting up to 5 min for Android/USB (first boot takes ~100 s)"
start=$(date +%s)
while :; do
  now=$(date +%s); el=$((now-start))
  [ $el -gt 300 ] && break
  adbstate=$("$ADB" devices 2>/dev/null | awk 'NR>1 && NF{print $2; exit}' || true)
  if [ "$adbstate" = "device" ]; then
    echo
    ok "ADB online after ${el}s"
    "$ADB" shell getprop ro.build.version.release 2>/dev/null || true
    "$ADB" shell getprop ro.lineage.version 2>/dev/null || true
    exit 0
  fi
  if [ "$adbstate" = "unauthorized" ]; then
    echo
    warn "Android booted, adb unauthorized after ${el}s — tap Allow on the tablet"
    exit 0
  fi
  usb=$(lsusb 2>/dev/null | grep -iE "0e8d:201c|18d1|17ef|2717" | sed 's/.*ID //' | tr '\n' ' ' || true)
  printf "[%3ss] usb=[%s] adb=[%s]\r" "$el" "${usb:-none}" "${adbstate:-none}"
  sleep 5
done
echo
die "no adb after 5 min. If the screen is 'Lenovo logo then fastboot', the bootloader rejected the image — do not reflash blindly; report the screen text."
