#!/usr/bin/env bash
# Shared progress helpers for peerbot learn + gates.
# Levels:
#   0 — closed only (default)
#   1 — may --allow loco
#   2 — may --allow grid (and loco)
#   3 — may --public (bind 0.0.0.0)
#   4 — may --allow all / classic cluster ports (expert)

peerbot_progress_file() {
  if [[ -n "${PEERBOT_PROGRESS:-}" ]]; then
    echo "$PEERBOT_PROGRESS"
    return
  fi
  local base="${XDG_CONFIG_HOME:-$HOME/.config}/inferno-os"
  mkdir -p "$base" 2>/dev/null || true
  echo "$base/peerbot.level"
}

peerbot_get_level() {
  if [[ -n "${PEERBOT_EXPERT:-}" && "${PEERBOT_EXPERT}" != "0" ]]; then
    echo 4
    return
  fi
  if [[ -n "${PEERBOT_LEVEL:-}" ]]; then
    echo "${PEERBOT_LEVEL}"
    return
  fi
  local f
  f=$(peerbot_progress_file)
  if [[ -f "$f" ]]; then
    local v
    v=$(tr -dc '0-9' <"$f" | head -c 1)
    echo "${v:-0}"
  else
    echo 0
  fi
}

peerbot_set_level() {
  local want="$1" cur f
  cur=$(peerbot_get_level)
  # never lower an expert env override via file write confusion
  if [[ -n "${PEERBOT_LEVEL:-}" || -n "${PEERBOT_EXPERT:-}" ]]; then
    echo "peerbot: level is overridden by env (PEERBOT_LEVEL/PEERBOT_EXPERT); not writing file" >&2
    return 0
  fi
  if [[ "$want" -le "$cur" ]]; then
    return 0
  fi
  f=$(peerbot_progress_file)
  mkdir -p "$(dirname "$f")"
  echo "$want" >"$f"
  echo "peerbot: progress → level $want  ($f)"
}

# Return 0 if allow-list + public flag are permitted at current level.
# Args: allow_csv  public_flag(0|1)
peerbot_check_gate() {
  local allow="${1:-}" public="${2:-0}"
  local level name
  level=$(peerbot_get_level)
  allow="${allow// /}"

  if [[ "$public" == "1" && "$level" -lt 3 ]]; then
    cat >&2 <<EOF
peerbot: --public (0.0.0.0 / accept all guests) needs level 3.
  You are at level $level.
  Learn first:  tools/peerbot/learn.sh
  (Or expert escape: PEERBOT_EXPERT=1 — you own the blast radius.)
EOF
    return 1
  fi

  [[ -z "$allow" || "$allow" == "none" ]] && return 0

  if [[ "$allow" == "all" && "$level" -lt 4 ]]; then
    cat >&2 <<EOF
peerbot: --allow all needs level 4 (expert).
  You are at level $level.
  Learn first:  tools/peerbot/learn.sh
EOF
    return 1
  fi

  IFS=',' read -ra names <<<"$allow"
  for name in "${names[@]}"; do
    [[ -n "$name" ]] || continue
    case "$name" in
      loco)
        if [[ "$level" -lt 1 ]]; then
          cat >&2 <<EOF
peerbot: opening 'loco' (8080) needs level 1 — know what loco does first.
  You are at level $level.
  Run:  tools/peerbot/learn.sh
EOF
          return 1
        fi
        ;;
      grid)
        if [[ "$level" -lt 2 ]]; then
          cat >&2 <<EOF
peerbot: opening 'grid' (9090) needs level 2 — know what grid does first.
  You are at level $level.
  Run:  tools/peerbot/learn.sh
EOF
          return 1
        fi
        ;;
      registry|cpupool|emulator|metrics)
        if [[ "$level" -lt 4 ]]; then
          cat >&2 <<EOF
peerbot: '$name' is an expert/cluster port — needs level 4.
  Prefer loco (8080) / grid (9090) until then.
  Run:  tools/peerbot/learn.sh
EOF
          return 1
        fi
        ;;
      none|off|deny) ;;
      *)
        # unknown names still fail later in lookup; treat as expert
        if [[ "$level" -lt 4 ]]; then
          cat >&2 <<EOF
peerbot: unknown/general assignment '$name' needs level 4.
  Stick to loco / grid until the tutorial says otherwise.
  Run:  tools/peerbot/learn.sh
EOF
          return 1
        fi
        ;;
    esac
  done
  return 0
}

peerbot_level_help() {
  local level
  level=$(peerbot_get_level)
  cat <<EOF
peerbot learning level: $level

  0  closed only — explore the name space (ls /dev)
  1  may --allow loco     (8080 local services)
  2  may --allow grid     (9090 shared fabric)
  3  may --public         (0.0.0.0 — global host)
  4  may --allow all / classic cluster ports

Advance:  tools/peerbot/learn.sh
EOF
}
