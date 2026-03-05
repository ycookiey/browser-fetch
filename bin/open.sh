#!/usr/bin/env bash
# open.sh — Open URL and take snapshot
# Usage: open.sh <url> <outdir> [nnn]
#
# Examples:
#   open.sh "https://example.com" ./scratchpad/browser-session
#   open.sh "https://example.com" ./scratchpad/browser-session 001

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

URL="${1:?Usage: open.sh <url> <outdir> [nnn]}"
OUTDIR="${2:?Usage: open.sh <url> <outdir> [nnn]}"

mkdir -p "$OUTDIR"

# Auto-determine NNN if not provided
if [[ -n "${3:-}" ]]; then
  NNN="$3"
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

ensure_daemon

# Open URL
echo "[open] Opening $URL ..." >&2
run_with_retry agent-browser open "$URL"

# Take snapshot
echo "[open] Taking snapshot -> $OUTFILE ..." >&2
run_with_retry agent-browser snapshot -i -c > "$OUTFILE"

# Update index.log
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$NNN | $TIMESTAMP | $URL | opened" >> "$INDEXLOG"

echo "[open] Done. Snapshot saved to $OUTFILE"
echo "$OUTFILE"
