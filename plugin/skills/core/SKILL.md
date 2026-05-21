---
name: grounded-coding-core
description: Use before writing ANY code in a project that has a magellan database. The core discipline: query graph before guessing, run security gates, verify CI before claiming done. Load sub-skills for specific phases (planning, TDD, debugging, verification, tools, subagents).
---

# Grounded Coding — Core

**The database is truth. Memory is not.**

Every wrong assumption compounds into debugging time. This core skill enforces the discipline: analyze what exists before changing it.

---

## The Five Phases

```
PHASE 0 — PROPOSED FEATURE:  Analyze with graph. Brainstorm grounded. Plan with evidence.
GATE 0 — BEFORE CODING:      Query the graph. No guessing.
GATE 1 — WHILE CODING:       Write test first. Watch it fail. Minimal fix.
GATE 2 — AFTER CODING:       Update graph. Run full verification. No stubs.
GATE 3 — BEFORE CLAIMING:    Read output. Report evidence. Distinguish status.
```

Skipping a phase doesn't save time — it shifts cost to debugging later.

---

## Environment Guard

Before any grounded-coding workflow, verify tool availability:

```bash
command -v magellan >/dev/null 2>&1 && echo "OK" || echo "MISSING"
```

If `magellan` is **MISSING**, load `grounded-coding-setup` for first-run configuration.

If tools exist but something feels wrong (queries fail, DB missing, unexpected errors), load `grounded-coding-doctor` for diagnostics.

---

## Core Discipline

**Query before reading files.** Graph tools are 8.5x more efficient than full file reads.

**The database is truth.** Memory is not.

**Evidence before assertions.** Run verification and read output before claiming done.

---

## When to Load Sub-Skills

This core skill tells you WHEN to load deeper skills. Load them BEFORE doing the work:

| Task | Load This Skill |
|------|-----------------|
| Planning a feature/refactor | `grounded-coding-planning` |
| Writing implementation code | `grounded-coding-tdd` |
| Encountering a bug/failure | `grounded-coding-debugging` |
| About to claim work is done | `grounded-coding-verification` |
| Need tool command reference | `grounded-coding-tools` |
| Delegating to subagents | `grounded-coding-subagents` |

**Before ANY code change, always:**
1. Check Atheneum for cached discoveries (curl-first, MCP as fallback)
2. Check graph health
3. Query what exists
4. THEN proceed with appropriate sub-skill

---

## Quick Start: Grounded Context

For task-level context, prefer an explicit DB path:

```bash
grounded-context --db <project-root>/.magellan/<project>.db --task "<task>" --output json
grounded-context --db <project-root>/.magellan/<project>.db --symbol <Symbol> --callers --callees --output json
```

For routed symbol queries, use the unified CLI:

```bash
# Check if Atheneum has cached discoveries first
knowledge-navigator "find <Symbol>" --project <name>
knowledge-navigator "who calls <Symbol>" --project <name>
knowledge-navigator "context for <Symbol>" --project <name>
knowledge-navigator "complex functions" --project <name>
```

The knowledge-navigator follows this workflow:
1. Check Atheneum for cached discoveries (observed local token savings)
2. Check graph health
3. Route to appropriate tool (magellan, llmgrep, mirage, splice)
4. Suggest follow-up actions

---

## Gate 0: Query Before Code

Before writing ANY code:

### 1. Check Atheneum (curl-first)

**If MCP `envoy_*` tools are in your tool list, prefer them for structured responses. Use curl as fallback.**

```bash
# Guard: test envoy HTTP connectivity
ENVOY_UP=$(curl -sf http://127.0.0.1:9876/health >/dev/null 2>&1 && echo "true" || echo "false")

# If up, query cached discoveries
curl -sf "http://127.0.0.1:9876/atheneum/knowledge?target=<symbol>"
```

If `$ENVOY_UP = "false"`, skip atheneum and proceed with graph tools.

If cached discovery exists and is recent (<7 days), reuse it. Skip graph queries.

For the full API reference, load `grounded-coding-atheneum`.

### 2. Check Graph Health

```bash
magellan status --db <project-db>
```

If 0 files/symbols or schema mismatch, re-index:
```bash
magellan watch --root ./src --db <project-db> --scan-initial
```

If the DB has data but is stale (watcher wasn't running, files changed), use incremental refresh instead of full reindex:
```bash
magellan refresh --db <project-db>                  # Sync DB with git working tree
magellan refresh --db <project-db> --dry-run        # Preview changes first
magellan refresh --db <project-db> --include-untracked  # Include new untracked files
```

### 3. Discover What Exists

```bash
knowledge-navigator "find <symbol>" --project <name>
```

Or directly:
```bash
magellan find --db <db> --name "symbol_name"
llmgrep search --db <db> --query "pattern" --mode symbols
```

### 4. Trace Relationships (before signature changes)

```bash
knowledge-navigator "who calls <symbol>" --project <name>
```

Or directly:
```bash
magellan refs --db <db> --name "func" --direction in
magellan context impact --db <db> --name "symbol" --depth 3
```

---

## Per-Project Databases

| Project | Database Path |
|---------|---------------|
| magellan | `~/Projects/magellan/.magellan/magellan.db` |
| llmgrep | `~/Projects/llmgrep/.magellan/llmgrep.db` |
| mirage | `~/Projects/mirage/.magellan/mirage.db` |
| splice | `~/Projects/splice/.magellan/splice.db` |
| envoy | `~/Projects/envoy/.magellan/envoy.db` |
| sqlitegraph | `~/Projects/sqlitegraph/.magellan/sqlitegraph.db` |
| geographdb-core | `~/Projects/geographdb-core/.magellan/geographdb.db` |
| codemcp | `~/Projects/codemcp/.magellan/codemcp.db` |

**Convention:** All projects use `.magellan/<project>.db` in their root directory.

When using `grounded-context`, pass `--db <project-root>/.magellan/<project>.db` unless the project actually uses `.magellan/magellan.db`.

---

## magellan watch --root

**Always use `--root ./src`** — indexing the project root pulls in Cargo.toml, .git/, target/, .magellan/, polluting the symbol graph with non-code noise.

---

## Red Flags — You're About To Violate The Rules

- About to write code without querying the graph first
- Using "should", "probably", "seems to" about code behavior
- Expressing satisfaction before running verification
- Writing production code before a failing test
- Proposing fixes without understanding root cause
- Trusting a subagent's self-reported success
- Thinking "just this once" or "it's too simple"
- 3+ fix attempts without questioning the architecture
- Adding `#[allow(dead_code)]`, `todo!()`, or stubs
- About to commit without `cargo test` passing

If you catch yourself doing these, STOP. Load the appropriate sub-skill. Query first.

---

## Security Gates — Run Before Claiming Done

Every code change must pass the local security gate before claiming completion:

```bash
# 0. Formatting (cheapest; CI rejects on diff)
cargo fmt --check

# 1. Dependency vulnerability scan
cargo audit

# 2. License + advisory policy check
cargo deny check

# 3. Secret leak detection
gitleaks detect --verbose --config .gitleaks.toml

# 4. Static analysis (SAST)
semgrep ci --oss-only --config .semgrep/rules/

# 5. Clippy (warnings as errors)
cargo clippy --all-targets -- -D warnings
```

If any gate fails, fix it before claiming done. Do not add ignores to `deny.toml` or `.gitleaks.toml` without documenting the justification.

---

## CI Verification — Always Check GitHub Actions

After pushing, verify CI passed before considering the task complete:

```bash
# Check latest run status
gh run list --limit 3

# Watch for completion
gh run watch <run-id>

# Confirm conclusion explicitly — `gh run watch --exit-status` has
# returned 0 even on failed runs, so don't trust it alone.
gh run view <run-id> --json conclusion
```

**Never claim work is done while CI is failing.** The local gate is a preflight; CI is the authority.

---

## Verification Report Template

When claiming work is done, use this template:

```text
Changed:
- <files and behavior>

Verified:
- <exact command>: <result>
- cargo fmt --check: <pass/fail>
- cargo audit: <pass/fail + count>
- cargo deny check: <pass/fail>
- gitleaks: <pass/fail>
- semgrep: <pass/fail + rule count>
- cargo clippy: <pass/fail>
- CI status: <url + conclusion via `gh run view --json conclusion`>

Not run / still failing:
- <exact command or known issue>: <reason>
```

Distinguish `fixed`, `verified`, `not run`, `skipped`, and `still failing`.

---

## Store Discoveries to Atheneum

After significant queries, store for other agents. **Prefer MCP `envoy_store_discovery` if available, otherwise curl:**

```bash
curl -sf -X POST http://127.0.0.1:9876/atheneum/discoveries \
  -H "Content-Type: application/json" \
  -d '{
    "agent": "your-name",
    "discovery_type": "Symbol",
    "target": "symbol_name",
    "metadata": {
      "file": "src/path.rs",
      "line": 42,
      "complexity": 8,
      "signature": "pub fn symbol_name()"
    }
  }'
```

---

## When NOT to Use Graph Tools

- File structure questions → `rg`, `find`, `tree`
- Build/debugging issues → Read logs, check Cargo.toml
- Documentation review → Read README.md directly
- Small files → If <100 lines, reading is faster
- First-time indexing → Must run `magellan watch` first

---

For complete tool reference, load `grounded-coding-tools`.
For planning guidance, load `grounded-coding-planning`.
For TDD workflow, load `grounded-coding-tdd`.
For debugging, load `grounded-coding-debugging`.
For verification, load `grounded-coding-verification`.
For subagent handoffs, load `grounded-coding-subagents`.
