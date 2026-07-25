#!/usr/bin/env bash
# peerbot — default-deny host port manager for Inferno try/boot paths
#
# Block all host publishes unless there is a good reason for the
# thing you are currently testing. Nicknames, not raw port soup.
# Broader assignments unlock via tools/peerbot/learn.sh
#
#   tools/peerbot/peerbot.sh list
#   tools/peerbot/peerbot.sh why loco
#   tools/peerbot/peerbot.sh level
#   tools/peerbot/peerbot.sh status [--allow none|loco|loco,grid|all]
#   tools/peerbot/peerbot.sh docker-args --allow loco
#   tools/peerbot/peerbot.sh qemu-fwds --allow loco,grid
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="${PEERBOT_CATALOG:-$ROOT/tools/peerbot/ports.catalog}"
# shellcheck disable=SC1091
source "$ROOT/tools/peerbot/progress.sh"

die() { echo "peerbot: $*" >&2; exit 2; }

usage() {
  cat <<'EOF'
peerbot — default DENY host ports; open only what this test needs

  peerbot list
  peerbot why <name>
  peerbot level
  peerbot status [--allow none|loco|loco,grid|all]
  peerbot docker-args [--allow ...]   # prints docker -p argv lines
  peerbot qemu-fwds [--allow ...]     # prints hostfwd=... CSV (or empty)

Learning gate:
  tools/peerbot/learn.sh     # unlock loco → grid → --public → expert

Env:
  PEERBOT_PUBLIC=1   bind 0.0.0.0 instead of 127.0.0.1 (needs level 3)
  PEERBOT_ALLOW=...  default for --allow when omitted
  PEERBOT_EXPERT=1   skip gates (you own the blast radius)
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

# Sets ALLOW_RAW (as requested) and ALLOW_NORM (expanded)
parse_allow_flag() {
  ALLOW_RAW="${PEERBOT_ALLOW:-none}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --allow)
        ALLOW_RAW="${2:-none}"
        shift 2
        ;;
      --allow=*)
        ALLOW_RAW="${1#*=}"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  ALLOW_NORM=$(normalize_allow "$ALLOW_RAW")
  echo "$ALLOW_NORM"
}

gate_or_die() {
  local allow_raw="$1"
  local public="${PEERBOT_PUBLIC:-0}"
  # Gate on the user-facing request (so "all" is visible), not expansion
  local gate_list="$allow_raw"
  gate_list="${gate_list:-none}"
  if [[ "$gate_list" == "none" || "$gate_list" == "off" || "$gate_list" == "deny" ]]; then
    gate_list=""
  fi
  peerbot_check_gate "$gate_list" "$public" || exit 1
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
  echo "Default: DENY. Unlock publishes with:  tools/peerbot/learn.sh"
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
  peerbot_level_help
  echo
  echo "peerbot policy: DEFAULT DENY"
  if [[ -z "$allow" ]]; then
    echo "  published on host: (none)"
    echo "  self boundary only — good for learning the name space"
    echo "  unlock + open:  tools/peerbot/learn.sh   then   --allow loco"
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
  parse_allow_flag "$@" >/dev/null
  gate_or_die "$ALLOW_RAW"
  local allow="$ALLOW_NORM"
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
  parse_allow_flag "$@" >/dev/null
  gate_or_die "$ALLOW_RAW"
  local allow="$ALLOW_NORM"
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
  level) peerbot_level_help ;;
  status) cmd_status "$@" ;;
  docker-args) cmd_docker_args "$@" ;;
  qemu-fwds) cmd_qemu_fwds "$@" ;;
  *) die "unknown command '$CMD' (try --help)" ;;
esac
