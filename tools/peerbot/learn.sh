#!/usr/bin/env bash
# peerbot learn — short tutorial before general port assignments
#
# Progressive levels. You cannot open wider publishes until you show
# you know what the nicknames mean.
#
#   tools/peerbot/learn.sh           # interactive
#   tools/peerbot/learn.sh status
#   tools/peerbot/learn.sh reset
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tools/peerbot/progress.sh"

# Sets REPLY (avoid command-substitution so ASK_N increments stick).
ask() {
  local prompt="$1"
  if [[ -n "${PEERBOT_LEARN_ANSWERS:-}" ]]; then
    ASK_N=$((ASK_N + 1))
    REPLY=$(printf '%s\n' "$PEERBOT_LEARN_ANSWERS" | sed -n "${ASK_N}p")
    echo "$prompt" >&2
    echo "  → $REPLY" >&2
    return
  fi
  read -r -p "$prompt" REPLY
}

norm() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'
}

lesson_header() {
  local n="$1" title="$2"
  echo
  echo "============================================================"
  echo "  Lesson $n — $title"
  echo "============================================================"
  echo
}

cmd_status() {
  peerbot_level_help
}

cmd_reset() {
  local f
  f=$(peerbot_progress_file)
  rm -f "$f"
  echo "peerbot: progress reset ($f)"
  peerbot_level_help
}

run_tutorial() {
  ASK_N=0
  local level ans
  level=$(peerbot_get_level)
  echo "peerbot learn — ports before power tools"
  echo "Current level: $level"
  echo
  echo "Rule: closed until you understand what you are opening."
  echo "Docs: docs/PEERBOT.md  docs/NETWORK_PORTS.md  docs/NAMESPACE.md"
  echo

  # --- Level 1: loco ---
  if [[ "$level" -lt 1 ]]; then
    lesson_header 1 "loco (8080) — local services"
    cat <<'EOF'
  Inferno (and peerbot) nickname **8080** as **loco**:
  services that live on *this* machine — your local workshop.

  Before loco is open on the host, you can still learn inside the
  container/VM:  ls /dev   ls /prog   (the name space).

  Opening loco publishes host port 8080 so tools on your laptop
  can reach those local services.
EOF
    ask "  Q: What nickname means local services on this machine? "
    ans=$(norm "$REPLY")
    if [[ "$ans" != "loco" && "$ans" != "8080" && "$ans" != "loco(8080)" && "$ans" != "loco/8080" ]]; then
      echo "  Not yet. Hint: loco = local. Re-run learn.sh when ready."
      exit 1
    fi
    ask "  Q: Which port number is loco? "
    ans=$(norm "$REPLY")
    if [[ "$ans" != "8080" ]]; then
      echo "  Not yet. loco is 8080. Re-run learn.sh when ready."
      exit 1
    fi
    peerbot_set_level 1
    echo "  ✓ Level 1 unlocked — you may:  ./try.sh --allow loco"
    level=1
  fi

  # --- Level 2: grid ---
  if [[ "$level" -lt 2 ]]; then
    lesson_header 2 "grid (9090) — shared fabric"
    cat <<'EOF'
  **9090** is **grid**: shared / distributed services — discovery,
  pools, things that span more than one seat.

  Learn loco first. Open grid only when you are testing the fabric,
  not because "ports are fun."
EOF
    ask "  Q: What nickname means shared/distributed services? "
    ans=$(norm "$REPLY")
    if [[ "$ans" != "grid" && "$ans" != "9090" ]]; then
      echo "  Not yet. Hint: grid goes wide. Re-run learn.sh when ready."
      exit 1
    fi
    ask "  Q: Which port number is grid? "
    ans=$(norm "$REPLY")
    if [[ "$ans" != "9090" ]]; then
      echo "  Not yet. grid is 9090. Re-run learn.sh when ready."
      exit 1
    fi
    peerbot_set_level 2
    echo "  ✓ Level 2 unlocked — you may:  ./try.sh --allow loco,grid"
    level=2
  fi

  # --- Level 3: self / host / guest ---
  if [[ "$level" -lt 3 ]]; then
    lesson_header 3 "self vs host vs guest (how loud)"
    cat <<'EOF'
  Binding address matters as much as the port number:

    127.0.0.1 / 127.0.0.0/8   self   — only this host's loopback
    0.0.0.0                   host   — accept payloads from all guests
    255.255.255.255           guest  — broadcast toward all hosts

  peerbot defaults to self (127.0.0.1).
  --public means global host (0.0.0.0). That is how "minikube went
  public with my entire fs" moments start. Unlock it only when you
  mean it.
EOF
    ask "  Q: Which bind means 'only loopback / self'? (127.0.0.1 or 0.0.0.0) "
    ans=$(norm "$REPLY")
    if [[ "$ans" != "127.0.0.1" && "$ans" != "127.0.0.0/8" && "$ans" != "127/8" && "$ans" != "self" ]]; then
      echo "  Not yet. Self = 127.0.0.1. Re-run learn.sh when ready."
      exit 1
    fi
    ask "  Q: Which bind accepts guests on all interfaces? (0.0.0.0 or 127.0.0.1) "
    ans=$(norm "$REPLY")
    if [[ "$ans" != "0.0.0.0" && "$ans" != "host" && "$ans" != "globalhost" ]]; then
      echo "  Not yet. Global host = 0.0.0.0. Re-run learn.sh when ready."
      exit 1
    fi
    ask "  Q: peerbot flag for 0.0.0.0 publish? (--public or --allow all) "
    ans=$(norm "$REPLY")
    if [[ "$ans" != "--public" && "$ans" != "public" ]]; then
      echo "  Not yet. Use --public for 0.0.0.0. Re-run learn.sh when ready."
      exit 1
    fi
    peerbot_set_level 3
    echo "  ✓ Level 3 unlocked — you may:  ./try.sh --allow loco --public"
    level=3
  fi

  # --- Level 4: expert / general ---
  if [[ "$level" -lt 4 ]]; then
    lesson_header 4 "expert ports (only when needed)"
    cat <<'EOF'
  Classic cluster ports (6675 registry, 6676 cpupool, 6677 emu) and
  --allow all are power tools. Prefer loco/grid aliases until you are
  debugging the cluster itself.

  General port assignments without a nickname are how accidental
  exposure happens. Level 4 means you accept that.
EOF
    ask "  Q: Prefer which nicknames over 6675/6677? (loco,grid or all) "
    ans=$(norm "$REPLY")
    if [[ "$ans" != "loco,grid" && "$ans" != "locogrid" && "$ans" != "loco/grid" ]]; then
      echo "  Not yet. Prefer loco,grid. Re-run learn.sh when ready."
      exit 1
    fi
    ask "  Q: Type 'i understand' to unlock expert assignments: "
    ans=$(norm "$REPLY")
    if [[ "$ans" != "iunderstand" ]]; then
      echo "  OK — staying at level 3. Expert can wait."
      peerbot_level_help
      exit 0
    fi
    peerbot_set_level 4
    echo "  ✓ Level 4 unlocked — expert publishes allowed. Be kind to your future self."
    level=4
  fi

  echo
  echo "Tutorial complete for your current path."
  peerbot_level_help
  echo
  echo "Next:  ./try.sh --allow loco"
  echo "       docs/NAMESPACE.md  (tree before more ports)"
}

case "${1:-}" in
  status|-s|--status) cmd_status ;;
  reset) cmd_reset ;;
  -h|--help)
    cat <<EOF
Usage: tools/peerbot/learn.sh [status|reset]

Interactive lessons unlock peerbot --allow / --public gradually.
EOF
    ;;
  *) run_tutorial ;;
esac
