# browser-fetch

A Claude Code skill that delegates browser automation to a lightweight subagent, reducing context consumption by 90%+.

## Problem

[agent-browser](https://github.com/vercel-labs/agent-browser) snapshots can consume 10,000+ tokens on complex pages, quickly exhausting your context window.

## Solution

This skill delegates browser operations to a Haiku subagent:

1. **Main agent** (Opus/Sonnet) sends high-level instructions
2. **Haiku subagent** executes agent-browser commands, saves raw data to files
3. **Haiku returns** only a structured summary (~100 tokens)
4. **Main agent** makes decisions based on summaries, not raw data

## Architecture

```mermaid
flowchart TB
    subgraph Files["scratchpad/browser-session/"]
        index["index.log"]
        f001["001.txt"]
        f002["002.txt"]
        more["..."]
    end

    subgraph Haiku["Haiku Subagent"]
        h1["agent-browser operations"]
        h2["snapshot → file"]
        h3["build summary"]
    end

    subgraph Main["Main Agent (Opus/Sonnet)"]
        m1["Define tasks"]
        m2["Review summaries"]
        m3["Issue next instructions"]
        m4["Read raw data (debug only)"]
    end

    Haiku -->|"save"| f001
    Haiku -->|"save"| f002
    Haiku -->|"append"| index
    Haiku -->|"summary only"| Main
    Main -->|"task instructions"| Haiku
    Main -.->|"debug only"| Files
```

## Sequence

```mermaid
sequenceDiagram
    participant Main as Main Agent
    participant Haiku as Haiku Subagent
    participant Files as Files

    Main->>Haiku: Task: Open URL
    Haiku->>Haiku: agent-browser open
    Haiku->>Haiku: agent-browser snapshot -i -c
    Haiku->>Files: Save 001.txt
    Haiku->>Files: Append index.log
    Haiku-->>Main: Summary: "Login page<br/>@e1 email, @e2 pass, @e3 submit<br/>(debug: 001.txt)"

    Main->>Haiku: Task: Fill @e1, @e2 and click @e3
    Haiku->>Haiku: agent-browser fill @e1
    Haiku->>Haiku: agent-browser fill @e2
    Haiku->>Haiku: agent-browser click @e3
    Haiku->>Haiku: agent-browser snapshot -i -c
    Haiku->>Files: Save 002.txt
    Haiku->>Files: Append index.log
    Haiku-->>Main: Summary: "Dashboard<br/>@e5 menuA, @e6 menuB<br/>(debug: 002.txt)"

    Note over Main,Files: On failure only
    Main->>Files: Read 002.txt
    Files-->>Main: Raw snapshot data
```

## Prerequisites

```bash
npm install -g agent-browser
agent-browser install
```

## Installation

```bash
# Clone to your Claude Code skills directory
cd ~/.claude/skills
git clone https://github.com/ycookiey/browser-fetch.git
```

## Usage

Once installed, invoke with `/browser-fetch` or let Claude Code auto-detect when browser automation is needed.

See [SKILL.md](./SKILL.md) for detailed usage patterns.

## Key Features

- **90%+ context reduction**: Raw snapshots stay in files, only summaries reach main agent
- **Structured summaries**: Subagent returns page overview + key refs, not raw element lists
- **Debug-friendly**: Raw data saved to `scratchpad/browser-session/` for troubleshooting
- **Session persistence**: Browser state maintained across multiple operations

## License

MIT
