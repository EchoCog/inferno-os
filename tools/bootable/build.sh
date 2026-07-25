#!/usr/bin/env bash
# Build native PC bootloader + easy kernel, then assemble a boot image.
#
# Modes:
#   1) Local tree already has a hosted toolchain (mk, 8c, limbo, ...)
#   2) Docker: tools/bootable/build.sh --docker
#
# Usage:
#   tools/bootable/build.sh [--docker] [--skip-image]
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
USE_DOCKER=0
SKIP_IMAGE=0

for arg in "$@"; do
  case "$arg" in
    --docker) USE_DOCKER=1 ;;
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
  echo "==> Building bootable image via Docker"
  docker build -f "$ROOT/Dockerfile.bootable" -t inferno-os:bootable "$ROOT"
  mkdir -p "$ROOT/tools/bootable/dist"
  docker create --name inferno-boot-copy inferno-os:bootable
  docker cp inferno-boot-copy:/out/inferno-boot.img "$ROOT/tools/bootable/dist/inferno-boot.img"
  docker rm inferno-boot-copy
  echo "Image: tools/bootable/dist/inferno-boot.img"
  echo "Run:   tools/bootable/run-qemu.sh"
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

echo "==> Disk image"
"$ROOT/tools/bootable/mkbootimg.sh" "$ROOT/tools/bootable/dist/inferno-boot.img"

echo
echo "Done."
echo "  Boot:  tools/bootable/run-qemu.sh"
echo "  Docs:  docs/GETTING_STARTED.md"
