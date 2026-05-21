# Architecture

## Overview

Grounded Coding is a layered code intelligence environment:

```
┌─────────────────────────────────────────────┐
│              Claude Code Plugin             │
│  ┌─────────┐ ┌───────┐ ┌────────────────┐  │
│  │ Skills  │ │ Hooks │ │    Scripts     │  │
│  │  (12)   │ │  (3)  │ │     (17)      │  │
│  └────┬────┘ └───┬───┘ └───────┬────────┘  │
│       │          │              │           │
└───────┼──────────┼──────────────┼───────────┘
        │          │              │
┌───────┼──────────┼──────────────┼───────────┐
│       ▼          ▼              ▼           │
│            CLI Tool Layer                   │
│  ┌───────────┐ ┌────────┐ ┌──────┐ ┌─────┐ │
│  │ magellan  │ │ llmgrep│ │mirage│ │splice│ │
│  └─────┬─────┘ └───┬────┘ └──┬───┘ └──┬──┘ │
│        │            │         │        │    │
│        ▼            ▼         ▼        ▼    │
│         SQLite Graph Database              │
│         (.magellan/<project>.db)            │
└─────────────────────────────────────────────┘
        │
        │ (optional)
        ▼
┌─────────────────────┐
│  Envoy / Atheneum   │
│  Knowledge Graph +  │
│  Agent Coordination │
└─────────────────────┘
```

## Data Flow

1. **magellan** indexes source code into a SQLite-based symbol graph
2. **llmgrep** queries the graph for semantic/structural patterns
3. **mirage** builds CFGs from the graph for path and complexity analysis
4. **splice** uses the graph for span-safe refactoring across files
5. Skills orchestrate these tools through Claude Code's skill system
6. Hooks enforce discipline automatically (verification, protection, bootstrap)

## Skill Hierarchy

```
core (entry point)
├── setup (first-run configuration)
├── doctor (health diagnostics)
├── planning (graph-analyze → brainstorm → plan)
│   └── tools (CLI reference)
├── tdd (test-first workflow)
├── debugging (root-cause analysis)
├── verification (full local gate)
├── subagents (handoff protocol)
├── workspace (project CLAUDE.md)
├── atheneum (optional — envoy endpoints)
└── perf (optional — benchmarking)
```

## Database

Each project has its own SQLite database at `.magellan/<project>.db`. The database contains:

- Symbols (functions, structs, enums, traits, modules)
- References (calls, imports, type usage)
- Source documents (indexed file contents)
- Source inventory (external documents)
- Candidate facts (extracted knowledge)

## Hooks

| Event | Hook | Purpose |
|-------|------|---------|
| SessionStart | session-bootstrap.fish | Detect project state, health-check or bootstrap |
| PreToolUse (Write\|Edit) | protect-sensitive-paths.fish | Block writes to .env, credentials, .git/ |
| PreToolUse (Bash) | prompt-based | Guard against destructive git/rm operations |
| Stop | verify-rust.fish | Run fmt, check, clippy, test before session ends |

## Optional Components

- **envoy/atheneum** — Knowledge graph server with HTTP API for cross-session memory and agent coordination. If not running, atheneum and perf skills degrade gracefully.
