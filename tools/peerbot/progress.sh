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

# True when progress is pinned by env (must match peerbot_get_level).
# PEERBOT_EXPERT=0 means "not expert" and does *not* override the file.
peerbot_env_pins_level() {
  if [[ -n "${PEERBOT_EXPERT:-}" && "${PEERBOT_EXPERT}" != "0" ]]; then
    return 0
  fi
  if [[ -n "${PEERBOT_LEVEL:-}" ]]; then
    return 0
  fi
  return 1
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

# Persist learning progress.
# Returns: 0 ok (written or already at level), 2 skipped (env pins level).
peerbot_set_level() {
  local want="$1" cur f
  if peerbot_env_pins_level; then
    echo "peerbot: level is pinned by env (PEERBOT_LEVEL / PEERBOT_EXPERT); not writing file" >&2
    echo "peerbot: unset those to save tutorial progress" >&2
    return 2
  fi
  cur=$(peerbot_get_level)
  if [[ "$want" -le "$cur" ]]; then
    return 0
  fi
  f=$(peerbot_progress_file)
  mkdir -p "$(dirname "$f")"
  echo "$want" >"$f"
  echo "peerbot: progress → level $want  ($f)"
}

# After a lesson: persist want, re-read level, succeed only if level >= want.
# Prints unlock line on success. Exits the caller shell on failure when used
# as:  peerbot_unlock 1 "message" || exit $?
peerbot_unlock() {
  local want="$1" msg="$2" rc=0 cur
  peerbot_set_level "$want" || rc=$?
  if [[ $rc -eq 2 ]]; then
    echo "  Progress not saved — env override is active." >&2
    peerbot_level_help >&2
    return 2
  elif [[ $rc -ne 0 ]]; then
    return "$rc"
  fi
  cur=$(peerbot_get_level)
  if [[ "$cur" -lt "$want" ]]; then
    echo "  Progress check failed (level $cur < $want)." >&2
    return 1
  fi
  echo "  ✓ Level $want unlocked — $msg"
  return 0
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
