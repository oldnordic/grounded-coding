---
name: grounded-coding-setup
description: Interactive first-run setup for grounded coding environment. Detects installed tools, presents tier options with tradeoffs via AskUserQuestion, configures the appropriate level. Load when tools are missing or user wants to configure grounded coding for a new project.
---

# Grounded Coding — Setup

**First-run configuration. Detect, ask, configure.**

This skill walks through setting up a grounded coding environment for a new project or after a fresh install.

---

## Phase 1 — Detect Environment (Automatic)

Run these probes silently. Build a map of what's available.

```bash
# Binaries
for cmd in magellan llmgrep mirage splice; do
  echo -n "$cmd: "; command -v "$cmd" >/dev/null 2>&1 && echo "YES" || echo "NO"
done

# Envoy
curl -sf http://127.0.0.1:9876/health >/dev/null 2>&1 && echo "envoy: YES" || echo "envoy: NO"

# Wiki
test -d ~/wiki && echo "wiki: YES" || echo "wiki: NO"

# Security tools
echo -n "cargo-audit: "; cargo audit --version >/dev/null 2>&1 && echo "YES" || echo "NO"
echo -n "cargo-deny: "; cargo deny --version >/dev/null 2>&1 && echo "YES" || echo "NO"
echo -n "gitleaks: "; command -v gitleaks >/dev/null 2>&1 && echo "YES" || echo "NO"
echo -n "semgrep: "; command -v semgrep >/dev/null 2>&1 && echo "YES" || echo "NO"

# Handoff dirs
test -d .claude/handoffs && echo "project-handoffs: YES" || echo "project-handoffs: NO"
test -d ~/.claude/handoffs && echo "global-handoffs: YES" || echo "global-handoffs: NO"

# Project DB
DB=$(find .magellan -name '*.db' -maxdepth 1 2>/dev/null | head -1)
if [ -n "$DB" ]; then
  echo "project-db: $DB"
else
  echo "project-db: NONE"
fi
```

---

## Phase 2 — Ask What The User Wants (Interactive)

Use AskUserQuestion to present the tier options:

**Question:** "What level of grounded coding do you want?"

**Option 1 — "Code intelligence only"**
- Graph tools: magellan, llmgrep, mirage, splice
- Pro: Works offline, no running services needed
- Con: No cross-session memory, no multi-agent coordination

**Option 2 — "Solo + knowledge"**
- Graph tools + atheneum for local knowledge persistence
- Pro: Remembers discoveries across sessions
- Con: Needs envoy HTTP server running

**Option 3 — "Full stack"**
- Graph tools + atheneum + wiki + subagent handoff
- Pro: Everything available, multi-agent support
- Con: Most setup, requires all services running

**Option 4 — "Lightweight"**
- Graph tools + file-based handoffs (no running services)
- Pro: No server dependencies, works everywhere
- Con: No knowledge sharing, manual handoff management

---

## Phase 3 — Configure Based on Choice

### All Tiers (Always Execute)

1. **Verify graph binaries are installed.** If missing, show install commands:
   ```bash
   # If installed via cargo
   cargo install magellan-cli llmgrep mirage-analyzer splice

   # Or build from source if in the monorepo
   cargo build --release -p magellan -p llmgrep -p mirage -p splice
   ```

2. **Create .magellan/ directory and index the project:**
   ```bash
   mkdir -p .magellan
   PROJECT_NAME=$(basename "$(pwd)")
   magellan watch --root ./src --db ".magellan/${PROJECT_NAME}.db" --scan-initial
   ```

3. **Create security configs if missing:**
   ```bash
   # deny.toml — license/advisory policy
   test -f deny.toml || cat > deny.toml << 'DENY'
   [licenses]
   allow = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "MPL-2.0", "GPL-3.0"]
   DENY

   # .gitleaks.toml — secret detection
   test -f .gitleaks.toml || cat > .gitleaks.toml << 'GITLEAKS'
   [extend]
   useDefault = true
   GITLEAKS

   # .semgrep/rules/ — SAST rules
   mkdir -p .semgrep/rules
   test -f .semgrep/rules/.gitkeep || touch .semgrep/rules/.gitkeep
   ```

### Tier 2+ — Atheneum Setup

1. **Check envoy binary/service:**
   ```bash
   command -v envoy >/dev/null 2>&1 && echo "envoy binary: found" || echo "envoy binary: MISSING"
   ```

2. **If envoy is missing, show build/start commands:**
   ```bash
   # Build envoy with atheneum feature
   cargo build --bin envoy --features atheneum

   # Start the server
   envoy --port 9876 --atheneum-db ./atheneum.db
   ```

3. **Verify connectivity:**
   ```bash
   curl -sf http://127.0.0.1:9876/health || echo "envoy not reachable"
   ```

### Tier 3 — Full Stack

1. **Check wiki directory:**
   ```bash
   mkdir -p ~/wiki/pages ~/wiki/journals
   ```

2. **Create handoff directories:**
   ```bash
   mkdir -p .claude/handoffs/claimed
   mkdir -p ~/.claude/handoffs/claimed
   ```

3. **Suggest wiki sync if Logseq exists:**
   ```bash
   test -d ~/Documents/plans\ and\ ideas && echo "Logseq found — run sync-wiki to sync"
   ```

### Tier 4 — Lightweight

1. **Create file-based handoff directories (no envoy needed):**
   ```bash
   mkdir -p .claude/handoffs/claimed
   mkdir -p ~/.claude/handoffs/claimed
   ```

2. **No envoy or atheneum configuration.**

---

## Phase 4 — Verify Setup

After configuration, run `grounded-coding-doctor` to confirm everything is working.

```bash
# Quick verification
echo "=== Quick Setup Verification ==="
echo -n "magellan: "; command -v magellan >/dev/null 2>&1 && echo "OK" || echo "MISSING"
echo -n "project DB: "; find .magellan -name '*.db' -maxdepth 1 2>/dev/null | head -1 || echo "NONE"
```

Report what's working and what still needs attention. Direct the user to `grounded-coding-doctor` for ongoing health checks.

---

## Re-Running Setup

This skill is idempotent. Re-running it detects existing config and only sets up what's missing. If the user wants to change tiers, run Phase 2 again.

Return to `grounded-coding-core` after setup is complete.
