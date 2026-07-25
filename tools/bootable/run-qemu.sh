#!/usr/bin/env bash
# Boot an Inferno image under QEMU (BIOS / i386).
#
# Usage:
#   tools/bootable/run-qemu.sh [image.img]
#
# Auto-detects floppy (~1.44MB) vs hard-disk images.
#
# Expert knobs (env):
#   QEMU          qemu binary (default: qemu-system-i386)
#   QEMU_MEM      memory, default 256M
#   QEMU_EXTRA    extra qemu args
#   QEMU_GRAPHIC  set to 1 for VGA window (default: serial console)
#   QEMU_MEDIA    force floppy|hd
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMG="${1:-$ROOT/tools/bootable/dist/inferno-boot.img}"
QEMU="${QEMU:-qemu-system-i386}"
MEM="${QEMU_MEM:-256M}"

if [[ ! -f "$IMG" ]]; then
  echo "error: image not found: $IMG" >&2
  echo "Build one with: tools/bootable/build.sh" >&2
  echo "            or: tools/bootable/build.sh --hd" >&2
  exit 1
fi

if ! command -v "$QEMU" >/dev/null 2>&1; then
  echo "error: $QEMU not found. Install qemu-system-x86." >&2
  exit 1
fi

size=$(wc -c <"$IMG")
media="${QEMU_MEDIA:-}"
if [[ -z "$media" ]]; then
  if [[ "$size" -le 2000000 ]]; then
    media="floppy"
  else
    media="hd"
  fi
fi

args=(
  -m "$MEM"
  -device rtl8139,netdev=n0
  -netdev user,id=n0,hostfwd=tcp::8080-:8080,hostfwd=tcp::9090-:9090
)

if [[ "$media" == "floppy" ]]; then
  args+=(-boot a -fda "$IMG")
else
  args+=(-boot c -drive "file=$IMG,format=raw,if=ide")
fi

if [[ "${QEMU_GRAPHIC:-0}" == "1" ]]; then
  args+=(-serial stdio)
else
  args+=(-nographic)
fi

# shellcheck disable=SC2206
extra=( ${QEMU_EXTRA:-} )

echo "Starting Inferno in QEMU"
echo "  image:  $IMG"
echo "  media:  $media"
echo "  ports:  host 8080→guest loco, host 9090→guest grid"
echo "  tip:    ls /dev    ls /prog    (name space first)"
echo "  exit:   Ctrl-A X  (nographic) or close the window"
echo

exec "$QEMU" "${args[@]}" "${extra[@]}"
