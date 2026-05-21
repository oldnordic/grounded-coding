# Getting Started

## Prerequisites

- Claude Code installed and running
- Fish shell (for hooks)
- One of:
  - Linux x86_64 (for prebuilt binaries)
  - Rust toolchain (for source builds on any platform)

## Install the Plugin

1. Open Claude Code
2. Install the `grounded-coding` plugin from the marketplace
3. Restart Claude Code

The SessionStart hook will automatically detect your environment.

## First Run

When you open a project for the first time, the setup skill activates:

1. It probes for installed tools (magellan, llmgrep, mirage, splice)
2. If tools are missing, it offers to install them:
   - **Prebuilt binaries** — fast, no Rust needed (Linux x86_64)
   - **cargo install** — source build (any platform)
3. It symlinks helper scripts to `~/.local/bin`
4. It generates a project `CLAUDE.md` with build commands and tool paths

## Index Your Project

```bash
magellan watch --root ./src --db .magellan/myproject.db --scan-initial
```

This creates the symbol graph that powers all other tools.

## Daily Workflow

```bash
# Start the watcher (runs in background, keeps DB in sync)
magellan watch --root ./src --db .magellan/myproject.db

# Check graph health
magellan status --db .magellan/myproject.db

# Find a symbol
magellan find --db .magellan/myproject.db --name "my_function"

# Search semantically
llmgrep --db .magellan/myproject.db search --query "error handling" --output human

# Trace callers
magellan refs --db .magellan/myproject.db --name "my_function" --direction in

# Analyze control flow
mirage --db .magellan/myproject.db cfg --function "my_function"

# Refactor safely
splice patch --file src/lib.rs --symbol old_name --with new_name --preview
```

## Health Check

Load the `grounded-coding-doctor` skill at any time:

```
/load grounded-coding-doctor
```

It probes all tools, databases, and services and reports what's healthy.
