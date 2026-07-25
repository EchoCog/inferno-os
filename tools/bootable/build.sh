#!/usr/bin/env bash
# Build native PC bootloader + easy kernel, then assemble a boot image.
#
# Modes:
#   1) Local tree already has a hosted toolchain (mk, 8c, limbo, ...)
#   2) Docker: tools/bootable/build.sh --docker
#
# Usage:
#   tools/bootable/build.sh [--docker] [--hd] [--skip-image]
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
USE_DOCKER=0
SKIP_IMAGE=0
IMG_MODE="floppy"

for arg in "$@"; do
  case "$arg" in
    --docker) USE_DOCKER=1 ;;
    --hd|--disk) IMG_MODE="hd" ;;
    --floppy) IMG_MODE="floppy" ;;
    --skip-image) SKIP_IMAGE=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$USE_DOCKER" == "1" ]]; then
  echo "==> Building bootable image via Docker ($IMG_MODE)"
  docker build -f "$ROOT/Dockerfile.bootable" -t inferno-os:bootable "$ROOT"
  mkdir -p "$ROOT/tools/bootable/dist"
  cid=$(docker create inferno-os:bootable)
  cleanup() { docker rm -f "$cid" >/dev/null 2>&1 || true; }
  trap cleanup EXIT

  # Image builds both artifacts; export the one matching --floppy/--hd,
  # and always leave the other available when present.
  if [[ "$IMG_MODE" == "hd" ]]; then
    docker cp "$cid:/out/inferno-hd.img" "$ROOT/tools/bootable/dist/inferno-hd.img"
    docker cp "$cid:/out/inferno-boot.img" "$ROOT/tools/bootable/dist/inferno-boot.img" 2>/dev/null || true
    cleanup
    trap - EXIT
    echo
    echo "Done (docker / hd)."
    echo "  Image: tools/bootable/dist/inferno-hd.img"
    echo "  Boot:  tools/bootable/run-qemu.sh tools/bootable/dist/inferno-hd.img"
  else
    docker cp "$cid:/out/inferno-boot.img" "$ROOT/tools/bootable/dist/inferno-boot.img"
    docker cp "$cid:/out/inferno-hd.img" "$ROOT/tools/bootable/dist/inferno-hd.img" 2>/dev/null || true
    cleanup
    trap - EXIT
    echo
    echo "Done (docker / floppy)."
    echo "  Image: tools/bootable/dist/inferno-boot.img"
    echo "  Boot:  tools/bootable/run-qemu.sh tools/bootable/dist/inferno-boot.img"
    echo "  HD:    tools/bootable/build.sh --docker --hd"
  fi
  echo "  Docs:  docs/GETTING_STARTED.md  docs/BOOTABLE.md"
  exit 0
fi

export ROOT
# shellcheck disable=SC1091
if [[ -f "$ROOT/mkconfig" ]]; then
  # Inferno mkconfig is not shell, but we need PATH to hosted bins.
  :
fi

HOST_BIN="$ROOT/Linux/386/bin"
if [[ ! -x "$HOST_BIN/mk" ]]; then
  cat >&2 <<EOF
error: hosted toolchain not found at $HOST_BIN/mk

Two easy options:
  A) Express path (no local toolchain):
       ./try.sh
  B) Bootable path via Docker:
       tools/bootable/build.sh --docker
  C) Build hosted Inferno first (INSTALL), then re-run this script.
EOF
  exit 1
fi

export PATH="$HOST_BIN:$PATH"

echo "==> Bootloader (9load, mbr, pbs)"
(cd "$ROOT/os/boot/pc" && mk install)

echo "==> Easy kernel (standalone first-boot)"
(cd "$ROOT/os/pc" && mk CONF=easy install)

if [[ "$SKIP_IMAGE" == "1" ]]; then
  echo "Skipping image assembly (--skip-image)"
  exit 0
fi

echo "==> Disk image ($IMG_MODE)"
if [[ "$IMG_MODE" == "hd" ]]; then
  "$ROOT/tools/bootable/mkbootimg.sh" --hd "$ROOT/tools/bootable/dist/inferno-hd.img"
  echo
  echo "Done."
  echo "  Boot:  tools/bootable/run-qemu.sh tools/bootable/dist/inferno-hd.img"
else
  "$ROOT/tools/bootable/mkbootimg.sh" --floppy "$ROOT/tools/bootable/dist/inferno-boot.img"
  echo
  echo "Done."
  echo "  Boot:  tools/bootable/run-qemu.sh"
fi
echo "  Docs:  docs/GETTING_STARTED.md  docs/NAMESPACE.md"
