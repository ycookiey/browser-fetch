---
name: browser-fetch
description: Delegate browser automation to a lightweight subagent (Haiku) to reduce context consumption. Also provides web clipping (HTML→Markdown) via clipper.
---

# browser-fetch

Delegate browser automation to a cost-effective subagent, preserving the main agent's context window.

## Why This Skill?

- **Problem**: `agent-browser snapshot` can consume 10,000+ tokens on complex pages
- **Solution**: Haiku subagent processes snapshots and returns only summaries (~100 tokens)
- **Result**: 90%+ context reduction while maintaining full browser capabilities

## Prerequisites

### Install agent-browser

```bash
npm install -g agent-browser
agent-browser install
```

### Install clipper

```bash
npm install -g @philschmid/clipper
```

Uses [Mozilla Readability](https://github.com/mozilla/readability) + [Turndown](https://github.com/mixmark-io/turndown) internally — same stack as Obsidian Web Clipper.

## Scripts

Helper scripts in `bin/` handle daemon startup, snapshots, and index.log automatically.

| Script | Usage | Description |
|--------|-------|-------------|
| `open.sh` | `open.sh <url> <outdir> [nnn]` | Open URL + snapshot → `NNN.txt` (SPA/listing pages) |
| `clip.sh` | `clip.sh <url> <outdir> [nnn]` | Clip URL → `NNN.md` (articles/docs) |
| `batch-clip.sh` | `batch-clip.sh <urls_file> <outdir>` | Clip all URLs in file → multiple `NNN.md` |
| `snap.sh` | `snap.sh <outdir> [nnn] [opts...]` | Snapshot only (after actions) → `NNN.txt` |
| `close.sh` | `close.sh` | Close browser session |

- `nnn` auto-increments if omitted (001, 002, ...)
- Scripts print the output file path on stdout

### Script Location

The scripts are in `~/.claude/skills/browser-fetch/bin/`. Use the full path or set `SKILL_DIR`:

```bash
SKILL_DIR="$HOME/.claude/skills/browser-fetch"
```

## Subagent Rules (Critical)

1. **ONLY execute scripts in `bin/`**. Do NOT run:
   - `clipper` directly (use `clip.sh` or `batch-clip.sh`)
   - `agent-browser` directly (use `open.sh`, `snap.sh`)
   - Python scripts (NEVER create or execute `.py` files)
   - Node.js scripts (NEVER create or execute `.js` files)
2. **File writing**: Use ONLY bash builtins:
   ```bash
   # Good: echo/printf
   echo "https://example.com" >> urls.txt
   printf "%s\n" "$url" >> urls.txt
   
   # Bad: Python/Node
   python3 -c "..."  # NEVER
   ```
3. **Max 1 retry**. If a command fails twice, report the error and stop.
4. **Never return raw data**. Read the file, build a summary, return the summary only.

## Snapshot Options

Pass extra options to `snap.sh` as trailing arguments:

```bash
snap.sh "$OUTDIR" 002 -d 2        # Depth limit
snap.sh "$OUTDIR" 002 -s "#content" # Scope to selector
```

If snapshot output exceeds token limits, retry with `-d 2`. If still too large, use `-s "main"`.

## Summary Format

Subagent must return **structured summaries**, not raw element lists.

### Good

```
Product listing page (127 items displayed)

Structure:
- Filters: category (@e12), price range (@e18), search (@e24)
- Sort: date (@e30), popularity (@e31)

Sample items:
- "Product A" $29.99 (@e45)
- "Product B" $49.99 (@e52)
- "Product C" $19.99 (@e58)

Ready for instructions.
(debug: 001.txt)
```

### Bad

```
- @e1 Logo
- @e2 Login button
- @e3 Menu
```

→ No context. Main agent cannot make decisions from this.

## Invocation Templates

### Opening a Page

```
Task(
  model: haiku,
  subagent_type: general-purpose,
  prompt: """
  Open a URL and return a structured summary.

  SKILL_DIR="$HOME/.claude/skills/browser-fetch"
  OUTDIR="{OUTDIR}"

  ## Step 1: Run script
  bash "$SKILL_DIR/bin/open.sh" "{URL}" "$OUTDIR"

  ## Step 2: Read the snapshot file (path printed by the script)
  ## Step 3: Return a structured summary (NOT raw data)

  ## Rules
  - If the script fails, retry ONCE. If it fails again, report the error and stop.
  - Do NOT run any other commands.

  ## Return format
  {Page type and overview}

  Structure:
  - {section}: {description} (@refs)

  Key elements:
  - {element} (@ref)

  Ready for instructions.
  (debug: {NNN}.txt)
  """
)
```

### Performing Actions

```
Task(
  model: haiku,
  subagent_type: general-purpose,
  prompt: """
  Perform actions and take a snapshot.

  SKILL_DIR="$HOME/.claude/skills/browser-fetch"
  OUTDIR="{OUTDIR}"

  ## Step 1: Run action commands
  agent-browser fill @e1 "value"   agent-browser click @e3 
  ## Step 2: Take snapshot
  bash "$SKILL_DIR/bin/snap.sh" "$OUTDIR"

  ## Step 3: Read the snapshot file and return a structured summary

  ## Rules
  - If a command fails, retry ONCE. If it fails again, report the error and stop.
  - Do NOT run any other commands.

  ## Return format
  Structured summary only. (debug: {NNN}.txt)
  """
)
```

### Ending Session

```
Task(
  model: haiku,
  subagent_type: general-purpose,
  prompt: """
  bash "$HOME/.claude/skills/browser-fetch/bin/close.sh"
  """
)
```

## Main Agent Rules

- **After reading this skill**, state your planned workflow to the user:
  - Which scripts you will use
  - How many Haiku tasks you expect
  - What output files will be generated
- Trust subagent summaries
- **Do NOT read generated files** (`*.txt`, `*.md`) unless:
  - The user explicitly asks to analyze content
  - Debugging a specific issue
  - Only read what is needed for the task (use `head`, `grep`, line ranges)
- Replace `{OUTDIR}`, `{URL}` in templates before sending to subagent
- `{OUTDIR}` = `scratchpad/browser-session` (project-relative or absolute)

## Token-Efficient Patterns

### Write-Only Mode (Recommended)

Subagent writes results to file, returns only confirmation. Main agent reads file later if needed.

```
Task(
  model: haiku,
  prompt: """
  Extract data and write to file. Do NOT return the data.

  SKILL_DIR="$HOME/.claude/skills/browser-fetch"
  OUTDIR="{OUTDIR}"
  SUMMARY_FILE="$OUTDIR/summary.md"

  ## Step 1: Actions
  agent-browser click @e12
  bash "$SKILL_DIR/bin/snap.sh" "$OUTDIR"

  ## Step 2: Read snapshot, extract info, write to summary file
  Write extracted data to $SUMMARY_FILE (append mode)

  ## Step 3: Return ONLY
  Done. Wrote to summary.md
  """
)
```

### Batch Processing

Process multiple items in one subagent call. Write each result to file.

```
Task(
  model: haiku,
  prompt: """
  Process multiple links and write results to file.

  OUTDIR="{OUTDIR}"
  RESULT_FILE="$OUTDIR/events.md"

  For each ref in [@e12, @e13, @e14]:
    1. agent-browser click {ref}
    2. agent-browser get url
    3. agent-browser snapshot -i -c
    4. Extract: title, date, deadline, URL
    5. Append to $RESULT_FILE

  Return ONLY: Done. Processed 3 items.
  """
)
```

### Why This Matters

| Pattern | Tokens Returned | Use Case |
|---------|-----------------|----------|
| Summary mode | ~100-500 | Need immediate decision |
| Write-only | ~10-20 | Data collection, batch processing |
| Return raw data | 1000-10000+ | Never do this |

## File Structure

```
~/.claude/skills/browser-fetch/
├── SKILL.md
├── README.md
└── bin/
    ├── open.sh     # Open URL + snapshot (SPA/listing)
    ├── clip.sh     # Clip URL to Markdown (articles/docs)
    ├── snap.sh     # Snapshot only (after actions)
    └── close.sh    # Close session

scratchpad/browser-session/   (per-project, created at runtime)
├── index.log
├── 001.txt         # snapshot from open.sh/snap.sh
├── 002.md          # clip from clip.sh
└── ...
```

---

## Web Clip (HTML → Markdown)

Convert article/content pages to clean Markdown.

- **Single URL**: Use `clip.sh`
- **Multiple URLs**: Use `batch-clip.sh`

> [!NOTE]
> Internally uses Mozilla Readability (same as Obsidian Web Clipper).
> Works best on article-like pages (blogs, docs, news).
> May not work well on listing pages, dashboards, or SPAs.

---

## When to Use What

| Page Type | Script | Reason |
|-----------|--------|--------|
| **Listing / index page** | `open.sh` / `snap.sh` | Structure exploration, link extraction |
| **Dashboard / SPA** | `open.sh` / `snap.sh` | Requires JS execution, interaction |
| **Single article / detail page** | `clip.sh` | Clean Markdown, no AI cost |
| **Multiple detail pages** | `batch-clip.sh` | Batch convert URLs to Markdown |

### Typical Workflow: List → Detail (Token-Efficient)

#### Haiku Task 1: Extract URLs from Listing Page

```
Task(
  model: haiku,
  prompt: """
  Extract detail page URLs from listing page.

  SKILL_DIR="$HOME/.claude/skills/browser-fetch"
  OUTDIR="{OUTDIR}"
  URLS_FILE="$OUTDIR/urls.txt"

  ## Step 1: Take snapshot
  bash "$SKILL_DIR/bin/snap.sh" "$OUTDIR"

  ## Step 2: Read snapshot, extract detail page URLs
  Write each URL (one per line) to $URLS_FILE

  ## Step 3: Return ONLY
  Done. Extracted {N} URLs to urls.txt
  (debug: {NNN}.txt)
  """
)
```

#### Haiku Task 2: Batch Clip All URLs

```
Task(
  model: haiku,
  prompt: """
  Batch clip all URLs to Markdown.

  SKILL_DIR="$HOME/.claude/skills/browser-fetch"
  OUTDIR="{OUTDIR}"

  ## Step 1: Run batch clip
  bash "$SKILL_DIR/bin/batch-clip.sh" "$OUTDIR/urls.txt" "$OUTDIR"

  ## Step 2: Return ONLY the script output
  """
)
```

#### Main Agent: Read Generated Markdown

After Task 2 completes, read the generated `.md` files to analyze/summarize.

```
Haiku Task 1              Haiku Task 2              Main Agent
    │                         │                         │
    │ snap.sh → extract URLs  │                         │
    │ → urls.txt              │                         │
    ├────────────────────────►│                         │
                              │ batch-clip.sh           │
                              │ → 001.md, 002.md, ...   │
                              ├────────────────────────►│
                                                        │ Read .md files
                                                        │ Analyze/summarize
```
