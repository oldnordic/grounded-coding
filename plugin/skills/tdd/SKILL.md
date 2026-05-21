---
name: grounded-coding-tdd
description: Use when implementing any feature or bugfix. Write tests first, watch them fail, implement minimal fix, verify regression. Tests passing immediately proves nothing — watching them fail first proves they catch something.
---

# Grounded Coding — Test-Driven Development

**Tests written after code pass immediately — and passing immediately proves nothing.**

---

## The Red-Green-Refactor Cycle

```
RED:    Write failing test → Run → Watch it fail
GREEN:  Write minimal code → Run → Watch it pass
REFACTOR: Clean up → Run → Still green
```

**Write code before test? Delete it. Start over.**

---

## Before Writing Implementation

1. Load `grounded-coding-planning` — Analysis should already be done
2. Write the test FIRST
3. Run the test — confirm it FAILS
4. If it passes, the test doesn't catch anything — delete and rewrite

---

## Regression Tests

For bug fixes, prove the test catches the bug:

```
Write failing test → Run (fails) → Fix → Run (passes)
→ Revert fix → Run (MUST FAIL) → Restore → Run (passes)
```

If the test passes without the fix, it doesn't test the right thing.

---

## Common TDD Traps

| Trap | Why It's Wrong | What To Do Instead |
|------|---------------|-------------------|
| Tests after implementation | Passing immediately proves nothing | Write test first, watch it fail |
| "I'll add tests later" | Never happens | No test, no code |
| Testing implementation details | Brittle, breaks on refactoring | Test behavior, not internals |
| Mocking everything | Tests mock behavior, not real code | Use real dependencies when possible |
| Asserting on exceptions without message | False positives | Check error message content |

---

## Rust Test Patterns

```rust
#[test]
fn test_behavior() {
    // Arrange
    let input = "...";

    // Act
    let result = function_under_test(input);

    // Assert
    assert_eq!(result, expected);
}

#[test]
#[should_panic(expected = "specific error message")]
fn test_panic_with_message() {
    function_that_panics();
}
```

---

## What To Test

- **Happy path** — Normal usage
- **Error cases** — Invalid inputs, edge cases
- **Invariants** — Properties that must always hold
- **Integration points** — Where modules connect

**What NOT to test:**
- Private implementation details (test via public API)
- Trivial getters/setters
- Third-party library behavior

---

## Before Marking the TDD Cycle Complete

Green tests are necessary but not sufficient. The change is not done until the local gate passes:

```bash
cargo fmt --check                                     # rejects unformatted code — CI will catch this otherwise
cargo test --workspace                                # all tests, not just the one you wrote
cargo clippy --all-targets -- -D warnings             # lints must be clean
cargo audit                                           # no new vulnerable deps
cargo deny check                                      # license + policy compliant
gitleaks detect --verbose --config .gitleaks.toml     # no leaked secrets
semgrep ci --oss-only --config .semgrep/rules/        # no new SAST findings
```

Then push and watch CI. Verify the conclusion with `gh run view <id> --json conclusion` rather than trusting `gh run watch --exit-status` alone — the watch exit code has been observed returning 0 even on failed runs. Only after CI is confirmed green does the cycle close. See `grounded-coding-verification` for full discipline.

A common failure mode: the unit test you wrote passes, but `cargo test --workspace` reveals you broke something elsewhere. Always re-run the full suite, not the single test, before claiming done.

---

Return to `grounded-coding-core` when TDD cycle is complete.
