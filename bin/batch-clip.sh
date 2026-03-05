#!/usr/bin/env bash
# batch-clip.sh — Clip multiple URLs from a file
# Usage: batch-clip.sh <urls_file> <outdir>
#
# Examples:
#   batch-clip.sh urls.txt ./scratchpad/browser-session
#
# Input file format: one URL per line
# Output: NNN.md files for each URL

set -euo pipefail

URLS_FILE="${1:?Usage: batch-clip.sh <urls_file> <outdir>}"
OUTDIR="${2:?Usage: batch-clip.sh <urls_file> <outdir>}"

if [[ ! -f "$URLS_FILE" ]]; then
  echo "[batch-clip] Error: URLs file not found: $URLS_FILE" >&2
  exit 1
fi

mkdir -p "$OUTDIR"

INDEXLOG="$OUTDIR/index.log"
SUCCESS_COUNT=0
FAIL_COUNT=0

while IFS= read -r URL || [[ -n "$URL" ]]; do
  # Skip empty lines and comments
  [[ -z "$URL" || "$URL" =~ ^# ]] && continue

  # Auto-determine NNN
  LAST=$(ls "$OUTDIR"/*.md "$OUTDIR"/*.txt 2>/dev/null | sed 's/.*\///' | sed 's/\.\(md\|txt\)//' | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
  if [[ -n "$LAST" ]]; then
    NNN=$(printf "%03d" $(( 10#$LAST + 1 )))
  else
    NNN="001"
  fi

  OUTFILE="$OUTDIR/$NNN.md"

  echo "[batch-clip] Clipping $URL -> $OUTFILE ..." >&2
  
  if clipper clip -u "$URL" -o "$OUTFILE" 2>/dev/null; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$NNN | $TIMESTAMP | $URL | clipped" >> "$INDEXLOG"
    ((SUCCESS_COUNT++))
    echo "[batch-clip] OK: $OUTFILE" >&2
  else
    echo "[batch-clip] FAIL: $URL" >&2
    ((FAIL_COUNT++))
  fi

done < "$URLS_FILE"

echo "[batch-clip] Done. Success: $SUCCESS_COUNT, Failed: $FAIL_COUNT"
