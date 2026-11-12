#!/usr/bin/env bash
# =============================================================================
# precheck_flash.sh — verify EVERYTHING before writing anything to the tablet.
#
#   ./precheck_flash.sh
#
# Exit 0 = safe to flash. Exit 1 = do not flash.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${TB8505X_ROOT:-$(cd "$HERE/.." && pwd)}"
FB="${FASTBOOT:-$HOME/tools/platform-tools/fastboot}"
FB_TIMEOUT="${FB_TIMEOUT:-120}"

VENDOR="$ROOT/backups/brom_full_20261110_210125/vendor.bin"
BOOT="$ROOT/images/boot/boot_patched.img"
DTBO="$ROOT/backups/brom_pre_unlock/dtbo.bin"
VBMETA="$ROOT/images/boot/vbmeta_disabled.img"
GSI="$ROOT/images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img"

BOLD=$'\033[1m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
log()  { echo "${BOLD}[*]${RESET} $*"; }
ok()   { echo "${GREEN}[ OK ]${RESET} $*"; }
warn() { echo "${YELLOW}[WARN]${RESET} $*"; }
bad()  { echo "${RED}[FAIL]${RESET} $*"; FAILED=1; }
FAILED=0

fb() { timeout "$FB_TIMEOUT" "$FB" ${FB_SERIAL:+-s "$FB_SERIAL"} "$@"; }

# ---------------------------------------------------------------- host tools
log "host tools"
for t in "$FB" python3 e2fsck debugfs cpio gzip xz sha1sum sha256sum od; do
  command -v "$t" >/dev/null 2>&1 || bad "missing host tool: $t"
done
[ -x "$FB" ] && ok "fastboot: $FB"

# ---------------------------------------------------------------- files exist
log "flash candidate files"
for f in "$VENDOR" "$BOOT" "$DTBO" "$VBMETA" "$GSI"; do
  if [ -f "$f" ]; then ok "$(basename "$f")  $(stat -c%s "$f") bytes"
  else bad "missing $f"; fi
done

# ---------------------------------------------------------------- device state
log "fastboot device"
devs=$("$FB" devices 2>/dev/null | awk 'NF{print $1}')
if [ -z "$devs" ]; then
  bad "no fastboot device. Power-cycle: hold Power 15-20 s, then hold Volume Down while plugging USB in."
  echo
  echo "${RED}Preflight stopped: no device.${RESET}"
  exit 1
fi
if [ "$(echo "$devs" | wc -l)" -ne 1 ]; then
  bad "multiple fastboot devices: $devs — disconnect everything else"
  exit 1
fi
FB_SERIAL="$devs"
ok "device $FB_SERIAL"

GV="$ROOT/logs/precheck_getvar.txt"
mkdir -p "$ROOT/logs"
timeout 30 "$FB" -s "$FB_SERIAL" getvar all >"$GV" 2>&1 || true
gv() { sed -n "s/^(bootloader) $1: //p" "$GV" | head -1; }

product=$(gv product)
unlocked=$(gv unlocked)
userspace=$(gv is-userspace)
slots=$(gv slot-count)
bat=$(gv battery-voltage)
[ "$product" = "akita_row_call" ] && ok "product=$product" || bad "product='$product' (expected akita_row_call)"
[ "$unlocked" = "yes" ] && ok "bootloader unlocked" || bad "bootloader not unlocked ('$unlocked')"
[ "$userspace" = "no" ] && ok "bootloader fastboot (not fastbootd)" || warn "is-userspace=$userspace"
[ "$slots" = "0" ] && ok "no A/B slots (discrete partitions)" || warn "slot-count=$slots"
if [ -n "$bat" ]; then
  mv=${bat%mV}
  if [ "${mv:-0}" -ge 3400 ]; then ok "battery ${bat}"; else bad "battery too low: $bat"; fi
fi

declare -A WANT=( [system]=f3800000 [vendor]=32000000 [boot]=2000000 [dtbo]=800000 [vbmeta]=800000 )
for p in system vendor boot dtbo vbmeta; do
  got=$(gv "partition-size:$p")
  got=${got#0x}
  if [ -z "$got" ]; then bad "could not read partition-size:$p"; continue; fi
  if [ "${got,,}" = "${WANT[$p]}" ]; then ok "partition $p = 0x${got,,}"
  else bad "partition $p = 0x${got,,}, expected 0x${WANT[$p]}"; fi
done

# ---------------------------------------------------------------- size checks
log "image sizes vs partitions"
chk_size() {
  local label=$1 file=$2 part=$3
  local sz; sz=$(stat -c%s "$file")
  if [ "$sz" -le "$part" ]; then ok "$label: $sz <= $part"
  else bad "$label: $sz > partition $part"; fi
}
chk_size "vendor" "$VENDOR" $((0x32000000))
chk_size "boot"   "$BOOT"   $((0x2000000))
chk_size "dtbo"   "$DTBO"   $((0x800000))
chk_size "vbmeta" "$VBMETA" $((0x800000))
# GSI is sparse; python precheck validates expansion size

# ---------------------------------------------------------------- deep checks
echo
"$HERE/precheck_images.py"
pyrc=$?
[ "$pyrc" -eq 0 ] || bad "image preflight failed"

# ---------------------------------------------------------------- simulation
echo
log "flash simulation"
gsi_out=$(python3 - "$GSI" <<'PY'
import struct,sys
d=open(sys.argv[1],'rb').read(28)
_,_,_,_,_,blk,tblk,_,_=struct.unpack('<I4H4I',d)
print(tblk*blk)
PY
)
total=$(( $(stat -c%s "$VENDOR") + $(stat -c%s "$BOOT") + $(stat -c%s "$DTBO") + $(stat -c%s "$VBMETA") + gsi_out ))
ok "system expands to $gsi_out bytes; total flash payload = $total bytes ($((total/1024/1024)) MiB)"
ok "estimated transfer time at ~30 MB/s: ~$((total/30/1024/1024)) s"
ok "flash order: vendor -> vbmeta -> boot -> dtbo -> system -> fastboot -w -> reboot"

echo
if [ "$FAILED" -eq 0 ]; then
  echo "${GREEN}${BOLD}PREFLIGHT PASSED — safe to flash.${RESET}"
  exit 0
fi
echo "${RED}${BOLD}PREFLIGHT FAILED — do NOT flash. Fix the FAIL lines above.${RESET}"
exit 1
