---
name: grounded-coding-doctor
description: Lightweight health check for grounded coding environment. Probes binaries, project DB, envoy/atheneum, wiki, security tools, and handoff paths. No interactive questions — just probes and reports. Run when something feels wrong or to verify after setup.
---

# Grounded Coding — Doctor

**Probe everything. Report what's missing. Suggest fixes.**

This is a read-only diagnostic. It changes nothing.

---

## How to Run

Execute each layer in order. Collect results, then print the health report.

---

## Layer 0 — Binaries

```bash
for cmd in magellan llmgrep mirage splice cargo; do
  echo -n "$cmd: "; command -v "$cmd" >/dev/null 2>&1 && echo "OK" || echo "MISSING"
done
```

---

## Layer 1 — Project DB

```bash
# Detect project DB — look for .magellan/*.db in current directory
DB=$(find .magellan -name '*.db' -maxdepth 1 2>/dev/null | head -1)

if [ -z "$DB" ]; then
  echo "Project DB: MISSING (no .magellan/*.db found)"
else
  magellan status --db "$DB" 2>&1 | head -5
fi
```

If 0 files or no DB found: user needs to run `magellan watch --root ./src --db .magellan/<project>.db --scan-initial`.

---

## Layer 2 — Envoy/Atheneum

```bash
curl -sf http://127.0.0.1:9876/health >/dev/null 2>&1 && echo "Envoy: OK" || echo "Envoy: DOWN"
```

---

## Layer 3 — Wiki

```bash
test -d ~/wiki && echo "Wiki: OK" || echo "Wiki: MISSING"
```

---

## Layer 4 — Security Tools

```bash
echo -n "cargo-audit: "; cargo audit --version >/dev/null 2>&1 && echo "OK" || echo "MISSING"
echo -n "cargo-deny: "; cargo deny --version >/dev/null 2>&1 && echo "OK" || echo "MISSING"
echo -n "gitleaks: "; command -v gitleaks >/dev/null 2>&1 && echo "OK" || echo "MISSING"
echo -n "semgrep: "; command -v semgrep >/dev/null 2>&1 && echo "OK" || echo "MISSING"
echo -n "gh: "; command -v gh >/dev/null 2>&1 && echo "OK" || echo "MISSING"
```

---

## Layer 5 — Handoff Paths

```bash
test -d .claude/handoffs && echo "Handoffs (project-local): OK" || echo "Handoffs (project-local): MISSING"
test -d ~/.claude/handoffs && echo "Handoffs (global): OK" || echo "Handoffs (global): MISSING"
```

---

## Report Format

After collecting all layer results, format the output like this:

```
Grounded Coding Health Report
═════════════════════════════
Binaries:     magellan✓ llmgrep✓ mirage✓ splice✓
Project DB:   ✓ 29 files, 480 symbols
Envoy:        DOWN
Wiki:         ✓ ~/wiki
Security:     audit✓ deny✓ gitleaks✓ semgrep✓ gh✓
Handoffs:     project-local✗ global✗

Missing:      envoy, project handoff dir, wiki sync
Fix:          load grounded-coding-setup
```

**Use ✓ for OK, ✗ for MISSING.** Summarize missing items at the bottom with a suggestion to load `grounded-coding-setup` for interactive configuration.

---

## Exit Behavior

- If all layers OK → report success, no further action needed
- If any layer MISSING → report what's missing, suggest `grounded-coding-setup`
- Do NOT attempt to fix anything — this is diagnostic only

Return to `grounded-coding-core` after reviewing the report.
