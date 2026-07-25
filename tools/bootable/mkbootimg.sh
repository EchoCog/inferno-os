#!/usr/bin/env bash
# Assemble a bootable Inferno floppy image from built native artifacts.
#
# Prerequisites (built tree):
#   Inferno/386/9load
#   Inferno/386/pbs
#   Inferno/386/bin/ieasy   (from: cd os/pc && mk CONF=easy install)
#
# Usage:
#   tools/bootable/mkbootimg.sh [output.img]
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/tools/bootable/dist/inferno-boot.img}"
ARCH="${INFERNO_ARCH:-386}"

LOAD="$ROOT/Inferno/$ARCH/9load"
PBS="$ROOT/Inferno/$ARCH/pbs"
KERNEL="${INFERNO_KERNEL:-$ROOT/Inferno/$ARCH/bin/ieasy}"
INI="${INFERNO_INI:-$ROOT/tools/bootable/plan9.ini}"
MKFAT="$ROOT/tools/bootable/mkfatfloppy.py"

die() { echo "error: $*" >&2; exit 1; }

[[ -f "$LOAD" ]]   || die "missing $LOAD — build with: (cd os/boot/pc && mk install)"
[[ -f "$PBS" ]]    || die "missing $PBS — build with: (cd os/boot/pc && mk install)"
[[ -f "$KERNEL" ]] || die "missing $KERNEL — build with: (cd os/pc && mk CONF=easy install)"
[[ -f "$INI" ]]    || die "missing $INI"
[[ -x "$MKFAT" || -f "$MKFAT" ]] || die "missing $MKFAT"

mkdir -p "$(dirname "$OUT")"

# 9load looks for 8.3 names on FAT; keep them short and obvious.
python3 "$MKFAT" \
  -o "$OUT" \
  -b "$PBS" \
  -l INFERNO \
  "$LOAD=9LOAD" \
  "$INI=PLAN9.INI" \
  "$KERNEL=IEASY"

echo
echo "Bootable image ready: $OUT"
echo "Run it with:  tools/bootable/run-qemu.sh $OUT"
