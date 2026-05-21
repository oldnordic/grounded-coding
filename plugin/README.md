# Grounded Coding

Graph-powered code intelligence, TDD discipline, and verification gates for Claude Code.

## What's Included

### CLI Tools

| Tool | Purpose |
|------|---------|
| **magellan** | Codebase indexing, symbol graph, context queries, FTS5 search |
| **llmgrep** | Semantic and structural queries over the magellan database |
| **mirage** | CFG analysis, paths, loops, dominance, hotspots |
| **splice** | Span-safe refactoring, cross-file rename, program slicing |

### Claude Code Skills (12)

A complete development lifecycle: planning, TDD, debugging, verification, tool reference, subagent handoffs, and project setup.

### Hooks (3)

- **SessionStart** — Auto-detect project state, bootstrap new projects, health-check existing ones
- **PreToolUse** — Block writes to sensitive files (.env, credentials, .git/)
- **Stop** — Verify Rust code before session ends (fmt, check, clippy, test)

### Helper Scripts (17)

CLI utilities for context composition, wiki management, agent messaging, profiling, and more.

## Install

### Option 1: Claude Code Plugin (Recommended)

Install this plugin from the Claude Code marketplace. On first run, the setup skill will guide you through installing the CLI tools and configuring your environment.

### Option 2: Standalone CLI

```bash
curl -fsSL https://github.com/luizspies/grounded-coding/install.sh | sh
```

### Option 3: Cargo

```bash
cargo install magellan llmgrep mirage-analyzer splice
```

## Quick Start

1. Install the plugin
2. Open a project in Claude Code
3. The setup skill auto-detects your environment and configures everything
4. Start coding with graph-powered intelligence

## Requirements

- Linux (x86_64) or any platform with Rust toolchain
- Claude Code (for plugin features)
- Fish shell (for hooks)

## License

MIT
