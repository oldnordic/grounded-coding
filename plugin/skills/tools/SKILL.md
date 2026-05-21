---
name: grounded-coding-tools
description: Reference for magellan, llmgrep, mirage, splice, and the security/CI tool chain (cargo audit, cargo deny, gitleaks, semgrep, gh). Use when you need specific tool syntax.
---

# Grounded Coding — Tool Reference

**Quick reference for graph intelligence tools.**

---

## Magellan — Code Graph Database

### Health & Maintenance

```bash
magellan status --db <db>                        # Database statistics (files, symbols, coverage)
magellan doctor --db <db>                        # Health check (readability, schema, indexes)
magellan verify --root <dir> --db <db>            # Verify DB vs filesystem
magellan migrate --db <db> [--dry-run]            # Upgrade to current schema
magellan backfill --db <db>                      # Recompute metrics and derived data
```

### Incremental Refresh (preferred over full reindex)

When the watcher wasn't running and files changed, use `magellan refresh` to sync the DB with git working tree changes — no full reindex needed:

```bash
magellan refresh --db <db>                        # Sync DB with git working tree (modified/deleted/new)
magellan refresh --db <db> --dry-run              # Preview changes without applying
magellan refresh --db <db> --include-untracked    # Include new untracked files
magellan refresh --db <db> --staged               # Only staged changes
magellan refresh --db <db> --unstaged             # Only unstaged changes
```

**When to use refresh vs full reindex:**
- **Refresh** — DB has data but is stale (watcher was down, files changed). Uses `git2` to detect working tree changes.
- **Full reindex** — Only when schema mismatch, first time, or `magellan status` shows 0 files/symbols.

### Symbol Discovery

```bash
magellan find --db <db> --name "<symbol>"              # Find by name (FTS5 prefix search)
magellan find --db <db> --symbol-id <ID>               # Find by stable symbol ID
magellan find --db <db> --ambiguous <NAME>             # Find all symbols matching name
magellan find --db <db> --name "<sym>" --first         # Return first match only
magellan query --db <db> --file <path>                 # List symbols in file
magellan query --db <db> --file <path> --kind <kind>   # Filter by kind
magellan files --db <db>                               # List indexed files
magellan files --db <db> --symbols                     # Include symbol counts per file
magellan label --db <db> --list                        # List all labels
magellan label --db <db> --label rust --show-code      # Symbols with label
magellan collisions --db <db>                          # Ambiguous symbol groups
```

### References & Call Graph

```bash
magellan refs --db <db> --name "<sym>" --direction in              # Who calls this
magellan refs --db <db> --name "<sym>" --direction out             # What this calls
magellan refs --db <db> --name "<sym>" --symbol-id <ID>            # By stable ID
magellan refs --db <db> --name "<sym>" --with-context              # Include source context
magellan refs --db <db> --name "<sym>" --with-semantics            # Include semantic info
magellan cross-file-refs --db <db> --fqn <FQN>                    # Cross-file references
```

### Source Retrieval

```bash
magellan get --db <db> --file <path> --symbol <name>     # Source for specific symbol
magellan get-file --db <db> --file <path>                # All chunks for a file
magellan chunks --db <db> [--file <pat>] [--kind <k>]    # List code chunks
magellan chunk-by-span --db <db> --file <path> --start <N> --end <N>
magellan chunk-by-symbol --db <db> --symbol <name>
```

### Context API

```bash
magellan context build --db <db>                          # Build context index
magellan context summary --db <db>                        # Project overview (~50 tokens)
magellan context list --db <db> [--kind <k>] [--page <n>] # Paginated symbol list
magellan context symbol --db <db> --name "<sym>"          # Symbol detail
  [--callers] [--callees] [--with-source] [--depth <n>]
magellan context file --db <db> --path <path>             # File-level context
magellan context impact --db <db> --name "<sym>" --depth 3    # Change blast radius
magellan context affected --db <db> --name "<sym>" --depth 3  # What this change affects
```

### Graph Algorithms

```bash
magellan cycles --db <db>                                 # Detect SCCs in call graph
magellan reachable --db <db> --symbol <ID> [--reverse]    # Reachability from symbol
magellan dead-code --db <db> --entry <ID>                 # Dead code analysis
magellan condense --db <db> [--members]                   # Condensation (collapsed SCCs)
magellan paths --db <db> --start <ID> [--end <ID>] [--max-depth <n>]
magellan slice --db <db> --target <ID> --direction backward|forward
```

### AST Queries

```bash
magellan ast --db <db> --file <path> [--position <offset>]
magellan find-ast --db <db> --kind <kind>
```

### Graph Memory

```bash
# Source inventory — scan external docs into graph for later retrieval
magellan source-inventory --db <db> --scan <dir> <kind>   # Scan directory (wiki, docs, etc.)
magellan source-inventory --db <db> --list                # List all source documents
magellan source-inventory --db <db> --list --kind <kind>  # Filter by kind (wiki, docs)
magellan source-inventory --db <db> --stale               # Show stale documents

# Candidate facts — semantic triples about the codebase
# Valid types: Task, Agent, Event, Failure, Module
# Valid predicates: assigned_to, caused_by, depends_on, implements, tests
magellan candidate-fact submit --db <db> \
  --from-source <ID> \
  --subject-type <TYPE> --subject-key <KEY> \
  --predicate <PRED> \
  --object-type <TYPE> --object-key <KEY>
magellan candidate-fact list --db <db> [--status <status>]  # pending, accepted, rejected
magellan candidate-fact validate --db <db> --candidate-id <ID>  # Validate against ontology
magellan candidate-fact review-queue --db <db> [--limit <n>]  # Rejected + ambiguous facts
```

### Watch Mode

```bash
magellan watch --root <dir> --db <db> [--debounce-ms <n>] [--scan-initial]
magellan watch ... --validate          # Validate on each batch
magellan watch ... --validate-only     # Validate only, don't index
magellan watch ... --gitignore-aware   # Respect .gitignore
```

### Registry & Export

```bash
magellan registry scan                 # Discover Magellan databases
magellan registry list                 # List known databases
magellan export --db <db> --format json|jsonl|csv|scip|dot|lsif [--output <path>]
magellan migrate-backend --input <db> --output <db> [--dry-run]
```

### Common Flags

```bash
--output human|json|pretty             # Output format (default: human)
--with-context                         # Include surrounding source context
--with-callers / --with-callees        # Include call relationships
--with-semantics                       # Include semantic info
--with-checksums                       # Include content hashes
--context-lines <N>                    # Lines of context around symbols
```

---

## llmgrep — Semantic Search

```bash
# Intent-based exploration (one command replaces 3-5 separate queries)
llmgrep explore --db <db> --intent "database connection pooling"
llmgrep explore --db <db> --intent "error handling" --output json
llmgrep explore --db <db> --intent "cfg" --limit 5

# Symbol search
llmgrep search --db <db> --query "<concept>" --mode symbols
llmgrep search --db <db> --query "<topic>" --min-complexity 10
llmgrep search --db <db> --query "<topic>" --max-complexity 20
llmgrep search --db <db> --query "<topic>" --min-fan-in 5
llmgrep search --db <db> --query "<topic>" --min-fan-out 3

# Path-aware search
llmgrep search --db <db> --paths-from <sym> --query ".*"     # Symbols on paths from X
llmgrep search --db <db> --paths-to <sym> --query ".*"       # Symbols on paths to X

# AST filtering
llmgrep search --db <db> --query "<topic>" --ast-kind loops  # loops, conditionals, functions
llmgrep search --db <db> --query "<topic>" --with-ast-context
llmgrep search --db <db> --query "<topic>" --inside function_item
llmgrep search --db <db> --query "<topic>" --contains await_expression

# Graph memory modes
llmgrep search --db <db> --query "<tag>" --mode docs        # Query source_documents by tag/wikilink
llmgrep search --db <db> --query "<pred>" --mode facts       # Query candidate_facts by predicate
# Example: llmgrep search --db code.db --query "assigned_to" --mode facts

# Sort options
--sort-by relevance|position|fan-in|fan-out|complexity|nesting-depth|ast-complexity

# Output modes
--output human|json|pretty
```

---

## Mirage — CFG Analysis

```bash
# Control flow graph
mirage cfg --db <db> --function "<function>"
mirage paths --db <db> --function "<function>"
mirage blast-zone --db <db> --function "<function>"

# Complexity & structure
mirage loops --db <db> --function "<function>"
mirage dominators --db <db> --function "<function>"

# Risk analysis
mirage hotspots --db <db> --top 20 [--verbose]              # High-risk functions (--top not --limit)
mirage hotpaths --db <db> --function "<fn>" --top 10         # Most-traversed paths
  [--min-score <n>] [--rationale]                           # Additional filters

# Inter-procedural CFG
mirage icfg --db <db> --entry "<entry>"                      # Inter-procedural call graph

# Coverage
mirage coverage --db <db>                                     # Coverage summary

# Document queries (graph memory)
mirage docs --db <db> [--kind <kind>] [--tag <tag>] [--limit <n>]
```

---

## Splice — Refactoring

```bash
# Cycles and dead code
splice cycles --db <db> [--symbol <name>] [--path <path>]
splice dead-code --db <db> --entry "<entry>" --path <path>

# Span-safe editing
splice patch --file <file> --symbol <name> --with <patch> --preview
```

If `splice` returns `SPL-E091` with `DB_COMPAT: sqlitegraph schema mismatch`, re-index the DB with the current Magellan/Splice toolchain:

```bash
splice explain --code SPL-E091
magellan watch --root ./src --db <db> --scan-initial
```

---

## Knowledge Navigator — Unified CLI

```bash
grounded-context --db <project-root>/.magellan/<project>.db --task "<task>" --output json
grounded-context --db <project-root>/.magellan/<project>.db --symbol <Symbol> --callers --callees --output json
knowledge-navigator "find <Symbol>" --project <name>
knowledge-navigator "who calls <Symbol>" --project <name>
knowledge-navigator "what <Symbol> calls" --project <name>
knowledge-navigator "context for <Symbol>" --project <name>
knowledge-navigator "complex functions" --project <name>
knowledge-navigator "search <concept>" --project <name>
```

Prefer `grounded-context --db ...` when a project uses `.magellan/<project>.db`; `--project <path>` can select `.magellan/magellan.db` depending on the tool version.

---

## When to Use Graph Memory

Graph memory extends magellan beyond code symbols to include external knowledge.

**Use source-inventory when:**
- You have wiki/docs with project knowledge that should be queryable alongside code
- You want to link documentation to code via semantic search
- You need to track what documentation exists for a project

**Use candidate-facts when:**
- You discover relationships that should persist across sessions (tasks, dependencies, decisions)
- You want to build a knowledge graph of project concepts
- You need to track "who is working on what" or "what caused what"

**Query graph memory:**
- `llmgrep search --mode docs` — Find docs by tag or wikilink
- `llmgrep search --mode facts` — Find facts by predicate (assigned_to, caused_by, etc.)
- `mirage docs --kind <kind>` — Query documents with mirage filters

**Ontology constraints:**
- Entity types: Task, Agent, Event, Failure, Module (extensible via source document types)
- Predicates: assigned_to, caused_by, depends_on, implements, tests
- Facts are validated against ontology before being accepted

---

## Security & Supply-Chain Tools

These run as part of the local gate and in CI. See `grounded-coding-verification` for when to run them; this section is the syntax reference.

### cargo audit — Vulnerability scan

```bash
cargo audit                              # Scan Cargo.lock against RustSec advisory DB
cargo audit --json                       # Machine-readable output
cargo audit --deny warnings              # Treat warnings as errors (exit non-zero)
cargo audit fix                          # Auto-bump to patched versions where possible
cargo audit fix --dry-run                # Preview the bumps
```

If an advisory cannot be fixed (upstream un-patched), document it in `deny.toml` with rationale (see below).

### cargo deny — License + advisory + duplicate policy

```bash
cargo deny check                         # Run all checks (advisories, bans, licenses, sources)
cargo deny check advisories              # Just CVE/yank checks (consumes RustSec DB)
cargo deny check licenses                # License compatibility only
cargo deny check bans                    # Banned crates + duplicate version detection
cargo deny check sources                 # Verify crate sources (allowlist)
cargo deny list                          # Dump all crates with license info
```

`deny.toml` controls policy. Every `[[advisories.ignore]]` or `[[bans.skip]]` must carry an inline comment with the advisory ID and reason. Example:

```toml
[[advisories.ignore]]
id = "RUSTSEC-2026-0002"  # lru IterMut UB — we don't use IterMut, verified by grep
```

### gitleaks — Secret detection

```bash
gitleaks detect --verbose --config .gitleaks.toml          # Scan committed history
gitleaks detect --verbose --no-git --source .              # Scan working tree only
gitleaks protect --staged --verbose                        # Pre-commit hook mode
gitleaks detect --report-path leaks.json --report-format json
```

Use `.gitleaks.toml` to allowlist false positives (test fixtures with fake keys, example tokens in docs). Always pin the gitleaks version in CI — its default rule set evolves and can cause sudden breakage.

### semgrep — SAST patterns

```bash
semgrep ci --oss-only --config .semgrep/rules/             # CI mode, only OSS rules
semgrep scan --config p/rust --config p/secrets .          # Scan with public rule packs
semgrep scan --config .semgrep/rules/ --error             # Local run, exit non-zero on finding
semgrep scan --json --output report.json .                # Machine-readable
```

Custom rules live in `.semgrep/rules/`. Default rule pack covers: insecure crypto, command injection, deserialization, hard-coded credentials, unsafe `unwrap` patterns. Keep the rule set small and high-signal — too many low-value rules cause findings fatigue.

### gh CLI — CI verification

```bash
# After pushing
gh run list --limit 5                                       # Recent runs across workflows
gh run list --workflow ci.yml --limit 3                     # Specific workflow
gh run view <run-id>                                        # Summary of one run
gh run view <run-id> --log-failed                           # Logs of just the failing jobs
gh run watch <run-id>                                       # Block until run finishes
gh run rerun <run-id>                                       # Rerun all failed jobs
gh run rerun <run-id> --failed                              # Rerun only the failed jobs

# Inspecting workflows
gh workflow list                                            # All workflows in the repo
gh workflow view <workflow>                                 # Workflow details + recent runs

# Branch protection / PR checks
gh pr checks <pr-number>                                    # Status of all checks on a PR
gh pr checks --watch                                        # Watch until checks complete
```

Common pattern after a push:

```bash
gh run list --limit 1                       # Find the run ID
gh run watch <id> --exit-status             # Block, exit non-zero if it fails
gh run view <id> --log-failed | head -200   # Triage if failed
```

---

## Per-Project DB Paths

**Convention:** Each project uses `.magellan/<project>.db` in its root directory.

| Project | Database Path | Notes |
|---------|---------------|-------|
| magellan | `.magellan/magellan.db` | Self-indexed, 2855 symbols |
| llmgrep | `.magellan/llmgrep.db` | Also has magellan.db for testing |
| mirage | `.magellan/mirage.db` | Also has magellan.db for testing |
| envoy | `.magellan/envoy.db` | Plugin runner project |
| splice | `.magellan/splice.db` | Within magellan project (test DB) |

**All tools** (magellan, llmgrep, mirage, splice) can query the same database - they share the magellan schema.

---

## Atheneum HTTP API

Envoy/atheneum provides knowledge sharing, planning, and coordination via HTTP at `http://127.0.0.1:9876`.

**Agent lifecycle:** Every session must register before making requests. The `X-Agent-Id` header must contain a registered agent's ID — unregistered IDs get 401 Unauthorized. When done, retire the agent so its ID is never reused.

```bash
# 1. Register — get a unique agent ID
AGENT_ID=$(curl -sf -X POST http://127.0.0.1:9876/agents \
  -H "Content-Type: application/json" \
  -d '{"name":"forge-session","kind":"claude"}' | jq -r '.agent_id')

# 2. Use AGENT_ID for all subsequent requests
curl -sf -H "X-Agent-Id: $AGENT_ID" http://127.0.0.1:9876/atheneum/knowledge?target=Symbol&project=forge

# 3. Retire when done (or before handoff)
curl -sf -H "X-Agent-Id: $AGENT_ID" -X POST http://127.0.0.1:9876/agents/$AGENT_ID/retire
```

**Connectivity guard:**
```bash
ENVOY_UP=$(curl -sf http://127.0.0.1:9876/health >/dev/null 2>&1 && echo "true" || echo "false")
```
Note: `/health` does not require agent registration.

**Most-used endpoints (curl):**

| Purpose | Command |
|---------|---------|
| Register agent | `curl -sf -X POST http://127.0.0.1:9876/agents -H "Content-Type: application/json" -d '{"name":"...","kind":"claude"}'` |
| Health | `curl -sf http://127.0.0.1:9876/health` |
| Query knowledge | `curl -sf -H "X-Agent-Id: {id}" "http://127.0.0.1:9876/atheneum/knowledge?target={symbol}&project={name}"` |
| Store discovery | `curl -sf -H "X-Agent-Id: {id}" -X POST http://127.0.0.1:9876/atheneum/discoveries -H "Content-Type: application/json" -d '{"agent":"...","discovery_type":"Symbol","target":"...","metadata":{...}}'` |
| Search | `curl -sf -H "X-Agent-Id: {id}" "http://127.0.0.1:9876/atheneum/search?q={query}&k=5"` |
| List tasks | `curl -sf -H "X-Agent-Id: {id}" "http://127.0.0.1:9876/atheneum/tasks?project={name}"` |
| Send message | `curl -sf -H "X-Agent-Id: {id}" -X POST http://127.0.0.1:9876/messages -H "Content-Type: application/json" -d '{"type":"message","from":"{id}","to":"...","parts":[{"type":"text","content":"..."}]}'` |
| Retire agent | `curl -sf -H "X-Agent-Id: {id}" -X POST http://127.0.0.1:9876/agents/{id}/retire` |

**If MCP `envoy_*` tools are in your tool list, prefer them for structured responses. Use curl as fallback.**

For the complete API reference (all 22 endpoints with request/response shapes), load `grounded-coding-atheneum`.

---

Return to `grounded-coding-core` when done.
