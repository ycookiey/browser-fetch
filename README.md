# browser-fetch

A [Claude Code skill](https://code.claude.com/docs/en/skills) that hands browser work to a Haiku subagent. The subagent drives [agent-browser](https://github.com/vercel-labs/agent-browser), saves each page snapshot to a file, and returns a short summary, so full snapshots stay out of the main agent's context.

## Features

- Opens pages and takes snapshots that list the page's interactive elements (buttons, links, inputs) with refs (`@e1`, `@e2`, ...) for later clicks and form input
- Saves every snapshot as a numbered file (`001.txt`, `002.txt`, ...) and logs it in `index.log`, so the main agent can read the raw data when something goes wrong
- Converts article-like pages to Markdown with [clipper](https://github.com/philschmid/clipper), for one URL or a list of URLs
- Keeps the browser open between subagent calls, so a login or an opened page carries over to the next call

## Requirements

- Claude Code
- Bash. On Windows, Git Bash
- Node.js and npm
- agent-browser and clipper:

```bash
npm install -g agent-browser
agent-browser install
npm install -g @philschmid/clipper
```

## Installation

Clone the repository into your personal skills folder. The prompts in `SKILL.md` run the scripts from `~/.claude/skills/browser-fetch/bin/`, so keep this exact path.

```bash
git clone https://github.com/ycookiey/browser-fetch.git ~/.claude/skills/browser-fetch
```

## Usage

Type `/browser-fetch` followed by your task, or ask Claude Code to do something in a browser and let it load the skill. [SKILL.md](SKILL.md) holds the instructions Claude follows: which script to use for each kind of page, the prompts for the subagent, and the summary format.

The subagent runs these scripts in `bin/`:

| Script | What it does |
|--------|--------------|
| `open.sh` | Opens a URL and saves a snapshot as `NNN.txt` |
| `snap.sh` | Saves a snapshot of the current page as `NNN.txt`, after clicks or form input |
| `clip.sh` | Saves a URL as Markdown in `NNN.md` |
| `batch-clip.sh` | Saves each URL in a file (one per line) as Markdown |
| `close.sh` | Closes the browser |

The files go to the folder Claude passes to the scripts. `SKILL.md` suggests `scratchpad/browser-session` in the current project.

## Limitations

- The scripts are written for Windows with Git Bash. They use GNU sed and need Bash 4.4 or later. With the bash and sed that come with macOS, the automatic file numbering and `snap.sh` don't work. Linux is untested.
- The check in `bin/common.sh` that starts the agent-browser daemon was written for agent-browser 0.8 on Windows. It hasn't been checked against newer agent-browser releases.
- `clip.sh` and `batch-clip.sh` download the page directly, not through the browser. They don't run JavaScript or send the browser's cookies, so pages that need a login or render with JavaScript come out empty or incomplete. Use `open.sh` for those.
- `batch-clip.sh` currently stops after the first URL in the list, because its success counter returns a non-zero status under `set -e`. Until this is fixed, run `clip.sh` once per URL.
- Snapshots and clips hold whatever the page shows, including pages you are logged in to. If the output folder is inside a git repository, add it to `.gitignore`.

## Uninstall

```bash
rm -rf ~/.claude/skills/browser-fetch
```

If nothing else uses agent-browser and clipper, remove them too:

```bash
npm uninstall -g agent-browser @philschmid/clipper
```

Then delete the output folders (`scratchpad/browser-session` by default) from your projects.

## License

[MIT](LICENSE)
