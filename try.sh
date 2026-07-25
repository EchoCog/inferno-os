#!/usr/bin/env bash
# Express path: run Inferno with almost no prior knowledge.
#
#   ./try.sh                  # default DENY — no host ports published
#   ./try.sh --allow loco     # open 8080 on 127.0.0.1 (local services test)
#   ./try.sh --allow loco,grid
#
# peerbot manages publishes: block everything unless this test needs it.
# See docs/PEERBOT.md and docs/NAMESPACE.md
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
IMAGE="${TRY_IMAGE:-inferno-os:dev}"
DOCKERFILE="${TRY_DOCKERFILE:-$ROOT/Dockerfile}"
PEERBOT="$ROOT/tools/peerbot/peerbot.sh"
ALLOW="${PEERBOT_ALLOW:-none}"
PASS=()

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
Usage: ./try.sh [--allow none|loco|loco,grid|...] [--public] [emu args...]

  Default: peerbot DENY (no -p publishes). Learn /dev /prog first.
  --allow loco       publish 8080 on 127.0.0.1 (needs learn level 1)
  --allow loco,grid  publish 8080 and 9090     (needs level 2)
  --public           bind 0.0.0.0              (needs level 3)

  Unlock levels:  tools/peerbot/learn.sh

EOF
      "$PEERBOT" list
      exit 0
      ;;
    --)
      shift
      PASS+=("$@")
      break
      ;;
    *)
      PASS+=("$1")
      shift
      ;;
  esac
done

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

# Compat: TRY_PORTS still works for experts, but peerbot is preferred.
port_args=()
TRY_PORTS_OVERRIDE=0
if [[ -n "${TRY_PORTS:-}" ]]; then
  TRY_PORTS_OVERRIDE=1
  for spec in $TRY_PORTS; do
    port_args+=(-p "$spec")
  done
else
  if ! port_out=$("$PEERBOT" docker-args --allow "$ALLOW"); then
    echo "hint: tools/peerbot/learn.sh" >&2
    exit 1
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    port_args+=("$line")
  done <<<"$port_out"
fi

echo "Starting Inferno (Express path)"
echo "  image: $IMAGE"
if [[ "$TRY_PORTS_OVERRIDE" == "1" ]]; then
  echo "peerbot policy: TRY_PORTS override (expert — tutorial bypass)"
  echo "  published on host (raw docker -p):"
  if [[ ${#port_args[@]} -eq 0 ]]; then
    echo "    (none)"
  else
    i=0
    while [[ $i -lt ${#port_args[@]} ]]; do
      if [[ "${port_args[$i]}" == "-p" ]]; then
        i=$((i + 1))
        echo "    -p ${port_args[$i]}"
      else
        echo "    ${port_args[$i]}"
      fi
      i=$((i + 1))
    done
  fi
  echo "  note: nickname status skipped; these mappings are what Docker will publish"
else
  "$PEERBOT" status --allow "$ALLOW"
fi
echo "  docs:  docs/GETTING_STARTED.md  docs/PEERBOT.md  docs/NAMESPACE.md"
echo
echo "Tip: name space first →  ls /dev   then later  ./try.sh --allow loco"
echo

# shellcheck disable=SC2086
exec docker run --rm -it "${port_args[@]}" ${TRY_DOCKER_ARGS:-} "$IMAGE" "${PASS[@]}"
