# Grounded Coding — Plugin Instructions

This plugin provides the grounded coding environment for Claude Code.

## What It Provides

- **12 skills** covering the full development lifecycle: planning, TDD, debugging, verification, and more
- **3 hooks** for automatic session bootstrapping, sensitive-path protection, and Rust verification
- **17 CLI helper scripts** for code intelligence, wiki management, and agent coordination

## First Run

After installing this plugin, load the `grounded-coding-setup` skill for first-run configuration:

```
/load grounded-coding-setup
```

The setup skill will:
1. Detect which tools are installed (magellan, llmgrep, mirage, splice)
2. Offer to install missing tools via prebuilt binaries or cargo
3. Symlink helper scripts to `~/.local/bin`
4. Generate a project CLAUDE.md template

## Core Workflow

Load `grounded-coding-core` to start any coding task. It enforces the five-phase discipline:

1. **Propose** — Analyze with graph tools, brainstorm grounded in evidence
2. **Before coding** — Query the graph, no guessing
3. **While coding** — Write tests first, watch them fail, minimal fix
4. **After coding** — Run full verification, no stubs
5. **Before claiming** — Read output, report evidence, distinguish status

## Tools Reference

Load `grounded-coding-tools` for complete CLI syntax.

## Health Check

Load `grounded-coding-doctor` to verify your environment is healthy.
