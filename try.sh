#!/usr/bin/env bash
# Express path: run Inferno with almost no prior knowledge.
#
#   ./try.sh
#
# Builds the hosted Docker image if needed, then starts Inferno.
# Forwards loco (8080) and grid (9090) — see docs/NETWORK_PORTS.md.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
IMAGE="${TRY_IMAGE:-inferno-os:dev}"
DOCKERFILE="${TRY_DOCKERFILE:-$ROOT/Dockerfile}"

if ! command -v docker >/dev/null 2>&1; then
  cat >&2 <<EOF
error: docker is required for the Express path.

Alternatives:
  - Bootable QEMU image:  tools/bootable/build.sh --docker
  - Hosted from source:   see INSTALL
  - Plain-language guide: docs/GETTING_STARTED.md
EOF
  exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> Building $IMAGE (first run only; grabs coffee)"
  docker build -f "$DOCKERFILE" -t "$IMAGE" "$ROOT"
fi

port_args=()
for spec in ${TRY_PORTS:-8080:8080 9090:9090}; do
  port_args+=(-p "$spec")
done

echo "Starting Inferno (Express path)"
echo "  image: $IMAGE"
echo "  loco:  http://127.0.0.1:8080  (local services)"
echo "  grid:  http://127.0.0.1:9090  (distributed services)"
echo "  docs:  docs/GETTING_STARTED.md"
echo
echo "Tip: want a real bootloader + kernel image?  tools/bootable/build.sh --docker"
echo

# Default CMD in Dockerfile is: emu -c1 wm/wm
# shellcheck disable=SC2086
exec docker run --rm -it "${port_args[@]}" ${TRY_DOCKER_ARGS:-} "$IMAGE" "$@"
