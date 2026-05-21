---
name: grounded-coding-verification
description: Use before claiming work is done, fixed, or passing. Run the full local gate (tests, clippy, audit, deny, gitleaks, semgrep) then verify CI passed. Evidence before assertions always.
---

# Grounded Coding — Verification

**Saying "done" without running verification is dishonesty.**

Local "looks good" means nothing if you didn't run the commands. CI green means nothing if you didn't check it. This skill exists because every "should work" claim that turned out wrong cost more debugging time than running the verification would have.

---

## The Two-Layer Verification Model

```
LAYER 1 — LOCAL GATE:   Tests, lints, security scans. Preflight check on your machine.
LAYER 2 — CI AUTHORITY: GitHub Actions runs the same gates in a clean environment.
```

The local gate catches the obvious. CI catches what local missed (env drift, dirty worktree, dependency cache poisoning, OS-specific failures). **You need both.** Skipping local burns CI minutes; skipping CI lets broken code live in `main`.

---

## Before Claiming Any Status

```
1. IDENTIFY: What command proves this claim?
2. RUN:      Execute the FULL command (fresh, complete)
3. READ:     Full output, check exit code, count failures
4. VERIFY:   Does output confirm the claim?
5. PUSH:     Then push (if applicable)
6. WATCH CI: gh run list → gh run watch <id>
7. ONLY THEN: Make the claim
```

---

## The Local Gate

Run these BEFORE pushing. They are the same gates CI runs, so if local fails, CI will fail too — save the round-trip.

```bash
# 1. Formatting (cheapest check — run first, fails the rest if dirty)
cargo fmt --check

# 2. Build + tests
cargo build --workspace
cargo test --workspace

# 3. Lints (warnings treated as errors)
cargo clippy --all-targets -- -D warnings

# 4. Dependency vulnerability scan
cargo audit

# 5. License + advisory policy
cargo deny check

# 6. Secret leak detection
gitleaks detect --verbose --config .gitleaks.toml

# 7. Static analysis (SAST)
semgrep ci --oss-only --config .semgrep/rules/
```

**Why all of them?** Each catches a different failure mode:
- `cargo fmt --check` — whitespace/line drift that breaks CI on machines where someone forgot to run fmt
- `cargo test` — behavioral correctness
- `cargo clippy` — code smell, common bugs, anti-patterns
- `cargo audit` — known CVEs in transitive deps
- `cargo deny` — license violations, banned crates, duplicate versions
- `gitleaks` — credentials accidentally committed
- `semgrep` — pattern-based static analysis (insecure crypto, command injection, etc.)

Skipping any of them means you don't actually know the change is safe to merge.

**If fmt fails:** run `cargo fmt` (no flags) to fix, then re-run the gate. Don't push the unformatted code "just to see if CI catches it" — that wastes a CI run and clutters history with style-only commits.

---

## After Pushing: Verify CI

The local gate is a preflight, not the authority. After `git push`, **always** verify CI:

```bash
gh run list --limit 3                    # See latest runs and status
gh run watch <run-id>                    # Block until completion
gh run view <run-id> --log-failed        # Inspect failing jobs
```

**Never claim work is done while CI is failing or pending.** "Local passes" doesn't count if CI is red. If CI fails, fix it before moving on — don't push another commit on top hoping it'll resolve.

If CI shows a flaky test (passes on re-run with no code change), record it — flakiness is a real bug, not a pass.

---

## What Proves What

| Claim | Required Evidence | Not Sufficient |
|-------|-------------------|----------------|
| Tests pass | `cargo test`: 0 failures, exit 0 | Previous run, "should pass" |
| Build succeeds | `cargo build`: exit 0 | Linter passing |
| Formatting clean | `cargo fmt --check`: exit 0 | "I usually run fmt", "rustfmt should agree" |
| Lints clean | `cargo clippy ... -D warnings`: exit 0 | "no new warnings" |
| No vulnerabilities | `cargo audit`: 0 reported | "I checked last week" |
| Policy compliant | `cargo deny check`: exit 0 | `deny.toml` exists |
| No secrets leaked | `gitleaks detect`: 0 findings | `.gitleaks.toml` exists |
| No SAST issues | `semgrep`: 0 blocking findings | "semgrep ran in CI" |
| Bug fixed | Original-symptom test passes | Code changed, assumed fixed |
| Requirements met | Line-by-line checklist | Tests passing alone |
| **Work complete** | **CI green on the pushed commit** | **Local passes** |

---

## Verification Report Template

Use this exact shape when finishing non-trivial work:

```text
Changed:
- <files and behavior>

Verified locally:
- cargo fmt --check: <pass/fail>
- cargo test: <pass count>/<total> passing, exit 0
- cargo clippy -- -D warnings: <pass/fail>
- cargo audit: <N advisories>
- cargo deny check: <pass/fail>
- gitleaks: <N findings>
- semgrep: <N findings>

CI:
- Run: <gh run url>
- Status: <success | failure | pending>
- Confirmed via: <`gh run view <id> --json conclusion` — DON'T trust `gh run watch --exit-status` alone, it has returned 0 on failures>
- All required jobs passed: <yes/no>

Not run / still failing:
- <exact command or known issue>: <reason>
```

Distinguish status precisely: `fixed` | `verified` | `not run` | `skipped` | `still failing` | `flaky`.

---

## Handling Suppressions

Some advisories cannot be fixed today (upstream un-patched, dep not yet bumped). When you suppress in `deny.toml` or `.gitleaks.toml`:

1. Reference the specific advisory ID (RUSTSEC-YYYY-NNNN).
2. State *why* the suppression is safe: "unused code path", "false positive in test fixture", "waiting on upstream PR #123".
3. If possible, add an expiry — date or upstream version to revisit.

Never add a blanket ignore. Every suppressed line is a deferred decision that someone will rediscover at the worst time.

---

## Common Verification Traps

| Trap | Why It's Wrong |
|------|---------------|
| "Should work now" | Run the verification |
| Tests passed once | Might be flaky, run again |
| Code compiled = done | Tests, lints, audit all must pass |
| Local passes = done | CI is the authority |
| Subagent said success | Verify independently |
| "I'll check CI later" | Check it now — failures compound |
| `cargo audit` had warnings, I ignored them | Triage each: fix, suppress with rationale, or escalate |
| New `deny.toml` ignore without comment | Future you won't remember why |

---

## When You Cannot Run a Check

Be explicit. "Did not run" is honest; silent omission is not.

Examples of legitimate skips (always state them):
- "Did not run `semgrep` — not installed on this machine. CI will run it."
- "Skipped `cargo audit` — offline, can't fetch advisory DB. Will verify CI."
- "Did not push — task was local-only by request."

If you skip something CI also doesn't run, the work is not verified. Say so.

---

Return to `grounded-coding-core` when verification is complete.
