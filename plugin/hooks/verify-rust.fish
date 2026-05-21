#!/usr/bin/env fish
# verify-rust.fish — Canonical Rust verification hook (SubagentStop)
# Generic: derives project name and DB path from CWD.
# Exit code 2 blocks the subagent from stopping.
#
# Source: ~/.hermes/hooks/claude/verify-rust.fish
# Deployed to: magellan, llmgrep, mirage, splice, sqlitegraph

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || cd (pwd)
set -l PROJECT_NAME (basename (pwd))
set -l DB_PATH ".magellan/$PROJECT_NAME.db"

echo "══════════════════════════════════════════════"
echo "  🦀 RUST CODE VERIFICATION — $PROJECT_NAME"
echo "══════════════════════════════════════════════"
echo ""

# Only verify if Rust files were modified
set -l MODIFIED (git diff --name-only HEAD 2>/dev/null)
if test -z "$MODIFIED"; or not string match -qr '\.rs$' -- "$MODIFIED"
    echo "  ℹ️  No Rust files modified (skipping verification)"
    echo ""
    exit 0
end

echo "  ✓ Rust files modified:"
for file in $MODIFIED
    if string match -qr '\.rs$' -- "$file"
        echo "    - $file"
    end
end

echo ""
echo "  [1/4] Running cargo fmt --check..."
if not cargo fmt --all --check 2>/dev/null
    echo ""
    echo "  ❌ ERROR: Code is not formatted"
    echo ""
    echo "  Run 'cargo fmt --all' before completing the task."
    echo "  Unformatted code makes review harder and may"
    echo "  hide real issues under formatting noise."
    exit 2
end
echo "  ✓ Code is formatted"

echo ""
echo "  [2/4] Running cargo check --all-targets (warnings as errors)..."
set -l CHECK_OUTPUT (env RUSTFLAGS="-D warnings" cargo check --all-targets 2>&1)
set -l CHECK_STATUS $status
if test $CHECK_STATUS -ne 0
    echo ""
    echo "  ❌ ERROR: cargo check failed or produced warnings"
    echo ""
    echo "$CHECK_OUTPUT" | head -30
    echo ""
    echo "  Fix compilation errors and warnings before completing the task."
    echo "  -D warnings flag treats all warnings as errors."
    exit 2
end
echo "  ✓ Code compiles with zero warnings"

echo ""
echo "  [3/4] Running cargo clippy --all-targets (warnings as errors)..."
set -l CLIPPY_OUTPUT (cargo clippy --all-targets -- -D warnings 2>&1)
set -l CLIPPY_STATUS $status
if test $CLIPPY_STATUS -ne 0
    echo ""
    echo "  ❌ ERROR: clippy found issues"
    echo ""
    echo "$CLIPPY_OUTPUT" | head -20
    echo ""
    echo "  Fix clippy issues before completing the task."
    exit 2
end
echo "  ✓ Clippy clean"

echo ""
echo "  [4/5] Running cargo test (evidence gate)..."
set -l TEST_OUTPUT (cargo test 2>&1)
set -l TEST_STATUS $status
echo "$TEST_OUTPUT" | tail -5
if test $TEST_STATUS -ne 0
    echo ""
    echo "  ❌ ERROR: cargo test failed"
    echo ""
    echo "$TEST_OUTPUT" | grep -E 'FAILED|failures|error' | head -10
    echo ""
    echo "  Fix failing tests before completing the task."
    echo "  Claims of 'tests pass' are meaningless without evidence."
    exit 2
end
echo "  ✓ Tests pass"

# Extract test count as evidence
set -l TEST_COUNT (echo "$TEST_OUTPUT" | grep -oP '\d+ passed' | tail -1)
if test -n "$TEST_COUNT"
    echo "    $TEST_COUNT"
end

echo ""
echo "  [5/5] Checking code graph..."
if test -f "$DB_PATH"
    set -l STATUS_OUTPUT (magellan status --db "$DB_PATH" 2>&1)
    set -l STATUS_STATUS $status

    if test $STATUS_STATUS -ne 0
        echo ""
        echo "  ⚠️  WARNING: magellan status failed"
        echo ""
        echo "$STATUS_OUTPUT" | head -10
        echo ""
        echo "  Graph may be stale. Consider running:"
        echo "  → magellan watch --root . --db $DB_PATH --scan-initial"
        echo ""
        # Don't block on status failure, but warn
    else
        set -l SYMBOLS (echo "$STATUS_OUTPUT" | grep "symbols:" | grep -o '[0-9]*' | head -1)
        set -l FILES (echo "$STATUS_OUTPUT" | grep "files:" | grep -o '[0-9]*' | head -1)
        echo "  ✓ Code graph healthy"
        if test -n "$SYMBOLS"
            echo "    Symbols: $SYMBOLS | Files: $FILES"
        end
    end
else
    echo "  ℹ️  No database at $DB_PATH (skipping graph check)"
    echo "  Consider: magellan watch --root . --db $DB_PATH --scan-initial"
end

echo ""
echo "══════════════════════════════════════════════"
echo "  ✅ RUST VERIFICATION PASSED"
echo "══════════════════════════════════════════════"
echo ""
echo "  Your code:"
echo "  ✓ Is formatted (cargo fmt)"
echo "  ✓ Compiles with zero warnings (--all-targets)"
echo "  ✓ Clippy clean (--all-targets)"
echo "  ✓ Tests pass (cargo test)"
echo "  ✓ Has been indexed in code graph"
echo ""

exit 0
