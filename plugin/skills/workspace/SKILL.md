---
name: grounded-coding-workspace
description: Project-level CLAUDE.md template and workspace conventions. Use when setting up a new project or generating project-level instructions for the grounded coding environment.
---

# Grounded Coding — Workspace

**Project conventions, not personal preferences.**

This skill generates a project-level CLAUDE.md that tells Claude how to work with a specific codebase using the grounded coding tools.

---

## When to Use

- New project onboarding — first session in a new repo
- Regenerating a stale CLAUDE.md
- Adding grounded coding conventions to an existing project

---

## Project CLAUDE.md Template

Generate this file at the project root as `CLAUDE.md`. Fill in the bracketed sections based on what the setup skill discovers.

```markdown
# <project-name>

## Build & Test

- Build: `<build-command>`
- Test: `<test-command>`
- Lint: `<lint-command>`

## Grounded Coding Tools

| Tool | Database |
|------|----------|
| magellan | `.magellan/<project>.db` |
| llmgrep | uses magellan DB |
| mirage | uses magellan DB |
| splice | uses magellan DB |

### First Index

```bash
magellan watch --root ./src --db .magellan/<project>.db --scan-initial
```

### Daily Workflow

```bash
# Check graph health
magellan status --db .magellan/<project>.db

# Refresh after changes (if watcher not running)
magellan refresh --db .magellan/<project>.db

# Query symbols
magellan find --db .magellan/<project>.db --name "<symbol>"
llmgrep --db .magellan/<project>.db search --query "<pattern>"

# Trace relationships
magellan refs --db .magellan/<project>.db --name "<symbol>" --path <file> --direction in
magellan context impact --db .magellan/<project>.db --name "<symbol>" --depth 3

# CFG analysis
mirage --db .magellan/<project>.db cfg --function "<function>"

# Span-safe edits
splice patch --file <file> --symbol <name> --with <patch> --preview
```

## Verification Gates

Before claiming any work is done:

1. `<lint-command>`
2. `<test-command>`
3. `<additional-checks>`

## Architecture Notes

<Describe the main modules, entry points, and data flow. This section
helps Claude understand the codebase structure without reading every file.>
```

---

## Generating the Template

When a user asks to set up a new project workspace:

1. Run the setup skill's Phase 1 probes to detect language, build system, and tooling
2. Fill in the template with discovered values
3. Write to `CLAUDE.md` in the project root
4. Offer to run `magellan watch --root ./src --db .magellan/<project>.db --scan-initial`

### Common Build Commands

| Language | Build | Test | Lint |
|----------|-------|------|------|
| Rust | `cargo build` | `cargo test` | `cargo clippy -- -D warnings` |
| Python | `pip install -e .` | `pytest` | `ruff check .` |
| TypeScript | `npm run build` | `npm test` | `npm run lint` |
| Go | `go build ./...` | `go test ./...` | `golangci-lint run` |

---

## Conventions

- Always use `--root ./src` with magellan watch, never `--root .`
- Database path: `.magellan/<project-name>.db`
- The CLAUDE.md at project root is checked into version control — it's team-shared
- Personal preferences go in `.claude/settings.local.json` or `CLAUDE.local.md`, not the shared CLAUDE.md
