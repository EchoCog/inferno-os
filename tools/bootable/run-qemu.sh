#!/usr/bin/env bash
# Boot an Inferno image under QEMU (BIOS / i386).
#
#   tools/bootable/run-qemu.sh [image.img]
#   tools/bootable/run-qemu.sh --allow loco [image.img]
#
# peerbot default DENY: no hostfwd unless you ask.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PEERBOT="$ROOT/tools/peerbot/peerbot.sh"
IMG=""
ALLOW="${PEERBOT_ALLOW:-none}"
QEMU="${QEMU:-qemu-system-i386}"
MEM="${QEMU_MEM:-256M}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow)
      if [[ $# -ge 2 ]]; then
        ALLOW="$2"
        shift 2
      else
        ALLOW="none"
        shift
      fi
      ;;
    --allow=*)
      ALLOW="${1#*=}"
      shift
      ;;
    --public)
      export PEERBOT_PUBLIC=1
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: tools/bootable/run-qemu.sh [--allow none|loco|...] [--public] [image.img]

  Default: no host port forwards (peerbot DENY).
  --allow loco       forward 8080 (needs learn level 1)
  --allow loco,grid  forward 8080+9090 (needs level 2)
  Unlock: tools/peerbot/learn.sh

EOF
      "$PEERBOT" list
      exit 0
      ;;
    *)
      IMG="$1"
      shift
      ;;
  esac
done

IMG="${IMG:-$ROOT/tools/bootable/dist/inferno-boot.img}"

if [[ ! -f "$IMG" ]]; then
  echo "error: image not found: $IMG" >&2
  echo "Build one with: tools/bootable/build.sh" >&2
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

if ! fwds=$("$PEERBOT" qemu-fwds --allow "$ALLOW"); then
  echo "hint: tools/peerbot/learn.sh" >&2
  exit 1
fi
netdev="user,id=n0"
if [[ -n "$fwds" ]]; then
  netdev="$netdev,$fwds"
fi

args=(
  -m "$MEM"
  -device rtl8139,netdev=n0
  -netdev "$netdev"
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
"$PEERBOT" status --allow "$ALLOW"
echo "  tip:    ls /dev    ls /prog    (name space first)"
echo "  exit:   Ctrl-A X  (nographic) or close the window"
echo

exec "$QEMU" "${args[@]}" "${extra[@]}"
