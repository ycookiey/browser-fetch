#!/usr/bin/env bash
# snap.sh — Take a snapshot of the current page (after actions)
# Usage: snap.sh <outdir> [nnn] [snapshot-opts...]
#
# Examples:
#   snap.sh ./scratchpad/browser-session
#   snap.sh ./scratchpad/browser-session 002
#   snap.sh ./scratchpad/browser-session 002 -d 2
#   snap.sh ./scratchpad/browser-session 002 -s "#content"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

OUTDIR="${1:?Usage: snap.sh <outdir> [nnn] [snapshot-opts...]}"

mkdir -p "$OUTDIR"

# Auto-determine NNN if not provided
if [[ -n "${2:-}" ]]; then
  NNN="$2"
else
  LAST=$(ls "$OUTDIR"/*.txt "$OUTDIR"/*.md 2>/dev/null | sed 's/.*\///' | sed 's/\.\(txt\|md\)//' | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
  if [[ -n "$LAST" ]]; then
    NNN=$(printf "%03d" $(( 10#$LAST + 1 )))
  else
    NNN="001"
  fi
fi

OUTFILE="$OUTDIR/$NNN.txt"
INDEXLOG="$OUTDIR/index.log"

# Extra snapshot options (from 3rd argument onward)
SNAP_OPTS=("${@:3}")

ensure_daemon

# Take snapshot
echo "[snap] Taking snapshot -> $OUTFILE ..." >&2
run_with_retry agent-browser snapshot -i -c "${SNAP_OPTS[@]}" > "$OUTFILE"

# Update index.log
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$NNN | $TIMESTAMP | snapshot | after action" >> "$INDEXLOG"

echo "[snap] Done. Snapshot saved to $OUTFILE"
echo "$OUTFILE"
