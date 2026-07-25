#!/usr/bin/env bash
# Assemble a bootable Inferno image from built native artifacts.
#
# Usage:
#   tools/bootable/mkbootimg.sh [--floppy|--hd] [output.img]
#
# Prerequisites:
#   Inferno/386/{9load,pbs,mbr,pbslba}
#   Inferno/386/bin/ieasy
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARCH="${INFERNO_ARCH:-386}"
MODE="floppy"
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --floppy) MODE="floppy"; shift ;;
    --hd|--disk) MODE="hd"; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      OUT="$1"
      shift
      ;;
  esac
done

if [[ -z "$OUT" ]]; then
  if [[ "$MODE" == "hd" ]]; then
    OUT="$ROOT/tools/bootable/dist/inferno-hd.img"
  else
    OUT="$ROOT/tools/bootable/dist/inferno-boot.img"
  fi
fi

LOAD="$ROOT/Inferno/$ARCH/9load"
PBS="$ROOT/Inferno/$ARCH/pbs"
PBSLBA="$ROOT/Inferno/$ARCH/pbslba"
MBR="$ROOT/Inferno/$ARCH/mbr"
KERNEL="${INFERNO_KERNEL:-$ROOT/Inferno/$ARCH/bin/ieasy}"
INI_FD="${INFERNO_INI:-$ROOT/tools/bootable/plan9.ini}"
INI_HD="${INFERNO_INI_HD:-$ROOT/tools/bootable/plan9-hd.ini}"

die() { echo "error: $*" >&2; exit 1; }

[[ -f "$LOAD" ]]   || die "missing $LOAD — build with: (cd os/boot/pc && mk install)"
[[ -f "$KERNEL" ]] || die "missing $KERNEL — build with: (cd os/pc && mk CONF=easy install)"

mkdir -p "$(dirname "$OUT")"

if [[ "$MODE" == "floppy" ]]; then
  [[ -f "$PBS" ]] || die "missing $PBS"
  [[ -f "$INI_FD" ]] || die "missing $INI_FD"
  python3 "$ROOT/tools/bootable/mkfatfloppy.py" \
    -o "$OUT" \
    -b "$PBS" \
    -l INFERNO \
    "$LOAD=9LOAD" \
    "$INI_FD=PLAN9.INI" \
    "$KERNEL=IEASY"
else
  BOOTSEC="$PBSLBA"
  [[ -f "$BOOTSEC" ]] || BOOTSEC="$PBS"
  [[ -f "$BOOTSEC" ]] || die "missing pbslba/pbs"
  [[ -f "$INI_HD" ]] || die "missing $INI_HD"
  mbr_args=()
  if [[ -f "$MBR" ]]; then
    mbr_args=(-m "$MBR")
  else
    echo "warning: $MBR missing — using minimal MBR stub" >&2
  fi
  python3 "$ROOT/tools/bootable/mkfathd.py" \
    -o "$OUT" \
    "${mbr_args[@]}" \
    -b "$BOOTSEC" \
    -l INFERNO \
    --size-mb "${INFERNO_HD_MB:-64}" \
    "$LOAD=9LOAD" \
    "$INI_HD=PLAN9.INI" \
    "$KERNEL=IEASY"
fi

echo
echo "Bootable image ready: $OUT  ($MODE)"
echo "Run it with:  tools/bootable/run-qemu.sh $OUT"
