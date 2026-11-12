#!/usr/bin/env bash
# =============================================================================
# download_gsi.sh — fetch and verify the LineageOS 18.1 arm64_bvS GSI.
#
#   ./download_gsi.sh
#
# The GSI is published by AndyYan on SourceForge. The SourceForge download page
# is not used; the direct mirror hosts are tried in order.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-$HERE/../images/gsi}"
NAME="lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img"
XZ="$DEST/$NAME.xz"
IMG="$DEST/$NAME"
SHA1_XZ="f7ad2f8938818f4866dfbd2f9b718a99a55266a7"
SHA1_IMG="5807df9ebacb69f034d24c6b3082ecd5d4d327f0"

mkdir -p "$DEST"

verify_xz() { [ -f "$XZ" ] && [ "$(sha1sum "$XZ" | awk '{print $1}')" = "$SHA1_XZ" ]; }
verify_img() { [ -f "$IMG" ] && [ "$(sha1sum "$IMG" | awk '{print $1}')" = "$SHA1_IMG" ]; }

if verify_img; then
  echo "already present: $IMG"
  exit 0
fi

if ! verify_xz; then
  P="project/andyyan-gsi/lineage-18.x/$NAME.xz"
  URLS=(
    "https://master.dl.sourceforge.net/$P?viasf=1"
    "https://downloads.sourceforge.net/$P"
    "https://netix.dl.sourceforge.net/$P?viasf=1"
    "https://altushost-swe.dl.sourceforge.net/$P?viasf=1"
    "https://deac-fra.dl.sourceforge.net/$P?viasf=1"
    "https://zenlayer.dl.sourceforge.net/$P?viasf=1"
  )
  rm -f "$XZ"
  for u in "${URLS[@]}"; do
    echo "trying $u"
    if command -v aria2c >/dev/null 2>&1; then
      aria2c -U "Wget/1.21.4" -c -x4 -s16 -k1M --max-tries=2 -o "$XZ" "$u" && break
    else
      curl -L --fail -C - --retry 3 -A "Wget/1.21.4" -o "$XZ" "$u" && break
    fi
  done
  verify_xz || { echo "download failed checksum; delete $XZ and retry (or use a VPN)" >&2; exit 1; }
fi

echo "verifying archive"
sha1sum "$XZ"
if [ ! -f "$IMG" ]; then
  xz -dk "$XZ"
fi
verify_img || { echo "uncompressed image failed SHA1: $IMG" >&2; exit 1; }
echo "ready: $IMG"
