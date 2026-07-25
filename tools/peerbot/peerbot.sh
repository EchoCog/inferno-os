#!/usr/bin/env bash
# peerbot — default-deny host port manager for Inferno try/boot paths
#
# Block all host publishes unless there is a good reason for the
# thing you are currently testing. Nicknames, not raw port soup.
#
#   tools/peerbot/peerbot.sh list
#   tools/peerbot/peerbot.sh why loco
#   tools/peerbot/peerbot.sh status --allow none
#   tools/peerbot/peerbot.sh docker-args --allow loco
#   tools/peerbot/peerbot.sh qemu-fwds --allow loco,grid
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="${PEERBOT_CATALOG:-$ROOT/tools/peerbot/ports.catalog}"

die() { echo "peerbot: $*" >&2; exit 2; }

usage() {
  cat <<'EOF'
peerbot — default DENY host ports; open only what this test needs

  peerbot list
  peerbot why <name>
  peerbot status [--allow none|loco|loco,grid|all]
  peerbot docker-args [--allow ...]   # prints docker -p argv lines
  peerbot qemu-fwds [--allow ...]     # prints hostfwd=... CSV (or empty)

Env:
  PEERBOT_PUBLIC=1   bind 0.0.0.0 instead of 127.0.0.1 (loud choice)
  PEERBOT_ALLOW=...  default for --allow when omitted
EOF
}

catalog_lines() {
  grep -v '^\s*#' "$CATALOG" | grep -v '^\s*$'
}

lookup() {
  local want="$1"
  while IFS= read -r line; do
    local name port role reason
    name=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$1); print $1}')
    port=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
    role=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')
    reason=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')
    if [[ "$name" == "$want" ]]; then
      printf '%s|%s|%s|%s\n' "$name" "$port" "$role" "$reason"
      return 0
    fi
  done < <(catalog_lines)
  return 1
}

normalize_allow() {
  local raw="${1:-}"
  raw="${raw// /}"
  if [[ -z "$raw" ]]; then
    raw="${PEERBOT_ALLOW:-none}"
  fi
  raw="${raw// /}"
  case "$raw" in
    ""|none|off|deny) echo ""; return ;;
    all)
      catalog_lines | awk -F'|' '{gsub(/^ +| +$/,"",$1); print $1}' | paste -sd, -
      return
      ;;
  esac
  echo "$raw"
}

parse_allow_flag() {
  ALLOW_OUT="${PEERBOT_ALLOW:-none}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --allow)
        ALLOW_OUT="${2:-none}"
        shift 2
        ;;
      --allow=*)
        ALLOW_OUT="${1#*=}"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  normalize_allow "$ALLOW_OUT"
}

cmd_list() {
  printf '%-10s %6s  %s\n' "NAME" "PORT" "WHEN TO OPEN"
  printf '%-10s %6s  %s\n' "----" "----" "------------"
  while IFS= read -r line; do
    local name port reason
    name=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$1); print $1}')
    port=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
    reason=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')
    printf '%-10s %6s  %s\n' "$name" "$port" "$reason"
  done < <(catalog_lines)
  echo
  echo "Default: DENY. Example:  ./try.sh --allow loco"
}

cmd_why() {
  local name="${1:-}"
  [[ -n "$name" ]] || die "usage: peerbot why <name>"
  local row
  row=$(lookup "$name") || die "unknown nickname '$name' (peerbot list)"
  IFS='|' read -r n port role reason <<<"$row"
  cat <<EOF
peerbot: $n
  port:    $port
  role:    $role
  open if: $reason
  else:    keep CLOSED (default deny)
EOF
}

cmd_status() {
  local allow
  allow=$(parse_allow_flag "$@")
  echo "peerbot policy: DEFAULT DENY"
  if [[ -z "$allow" ]]; then
    echo "  published on host: (none)"
    echo "  self boundary only — good for learning the name space"
    echo "  open something:  --allow loco   or   --allow loco,grid"
    return
  fi
  if [[ "${PEERBOT_PUBLIC:-0}" == "1" ]]; then
    echo "  bind: 0.0.0.0  (PUBLIC — accepts guests on all interfaces)"
  else
    echo "  bind: 127.0.0.1  (self — host loopback only)"
  fi
  echo "  published on host:"
  IFS=',' read -ra names <<<"$allow"
  for name in "${names[@]}"; do
    [[ -n "$name" ]] || continue
    local row
    row=$(lookup "$name") || die "unknown nickname '$name'"
    IFS='|' read -r n port role reason <<<"$row"
    echo "    $n  :$port"
    echo "      why: $reason"
  done
}

cmd_docker_args() {
  local allow
  allow=$(parse_allow_flag "$@")
  [[ -n "$allow" ]] || return 0
  IFS=',' read -ra names <<<"$allow"
  for name in "${names[@]}"; do
    [[ -n "$name" ]] || continue
    local row
    row=$(lookup "$name") || die "unknown nickname '$name'"
    IFS='|' read -r n port role reason <<<"$row"
    echo "-p"
    if [[ "${PEERBOT_PUBLIC:-0}" == "1" ]]; then
      echo "${port}:${port}"
    else
      echo "127.0.0.1:${port}:${port}"
    fi
  done
}

cmd_qemu_fwds() {
  local allow
  allow=$(parse_allow_flag "$@")
  local fwds=()
  if [[ -n "$allow" ]]; then
    IFS=',' read -ra names <<<"$allow"
    for name in "${names[@]}"; do
      [[ -n "$name" ]] || continue
      local row
      row=$(lookup "$name") || die "unknown nickname '$name'"
      IFS='|' read -r n port role reason <<<"$row"
      if [[ "${PEERBOT_PUBLIC:-0}" == "1" ]]; then
        fwds+=("hostfwd=tcp::${port}-:${port}")
      else
        fwds+=("hostfwd=tcp:127.0.0.1:${port}-:${port}")
      fi
    done
  fi
  if [[ ${#fwds[@]} -eq 0 ]]; then
    echo ""
  else
    local IFS=','
    echo "${fwds[*]}"
  fi
}

[[ -f "$CATALOG" ]] || die "missing catalog $CATALOG"
CMD="${1:-}"
shift || true
case "$CMD" in
  ""|-h|--help) usage ;;
  list) cmd_list ;;
  why) cmd_why "${1:-}" ;;
  status) cmd_status "$@" ;;
  docker-args) cmd_docker_args "$@" ;;
  qemu-fwds) cmd_qemu_fwds "$@" ;;
  *) die "unknown command '$CMD' (try --help)" ;;
esac
