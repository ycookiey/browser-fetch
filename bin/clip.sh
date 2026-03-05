#!/usr/bin/env bash
# clip.sh — Clip a URL to Markdown using clipper (Readability + Turndown)
# Usage: clip.sh <url> <outdir> [nnn]
#
# Examples:
#   clip.sh "https://example.com/article" ./scratchpad/browser-session
#   clip.sh "https://example.com/article" ./scratchpad/browser-session 001
#
# Note: clipper only works on article-like pages (blog, docs, news).
#       For SPAs, dashboards, or listing pages, use open.sh instead.

set -euo pipefail

URL="${1:?Usage: clip.sh <url> <outdir> [nnn]}"
OUTDIR="${2:?Usage: clip.sh <url> <outdir> [nnn]}"

mkdir -p "$OUTDIR"

# Auto-determine NNN if not provided
if [[ -n "${3:-}" ]]; then
  NNN="$3"
else
  # Check both .md and .txt files for consistent numbering
  LAST=$(ls "$OUTDIR"/*.md "$OUTDIR"/*.txt 2>/dev/null | sed 's/.*\///' | sed 's/\.\(md\|txt\)//' | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
  if [[ -n "$LAST" ]]; then
    NNN=$(printf "%03d" $(( 10#$LAST + 1 )))
  else
    NNN="001"
  fi
fi

OUTFILE="$OUTDIR/$NNN.md"
INDEXLOG="$OUTDIR/index.log"

echo "[clip] Clipping $URL -> $OUTFILE ..." >&2
clipper clip -u "$URL" -o "$OUTFILE"

# Update index.log
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$NNN | $TIMESTAMP | $URL | clipped" >> "$INDEXLOG"

echo "[clip] Done. Clipped to $OUTFILE"
echo "$OUTFILE"
