#!/usr/bin/env fish
# session-bootstrap.fish — SessionStart hook for grounded coding environment
#
# Two modes:
#   NEW PROJECT — no .magellan/*.db + no CLAUDE.md + git repo → auto-bootstrap
#   EXISTING    — has graph DB → health check + status report
#
# Never blocks. Always exits 0.

set -l PROJECT_DIR "$CLAUDE_PROJECT_DIR"
if test -z "$PROJECT_DIR"
    set PROJECT_DIR (pwd)
end

set -l PROJECT_NAME (basename "$PROJECT_DIR")

# ── Detect mode ──────────────────────────────────────────────

set -l IS_GIT false
git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; and set IS_GIT true

set -l HAS_DB false
test -f "$PROJECT_DIR/.magellan/$PROJECT_NAME.db"; and set HAS_DB true

set -l HAS_CLAUDE_MD false
test -f "$PROJECT_DIR/CLAUDE.md" -o -f "$PROJECT_DIR/.claude/CLAUDE.md"; and set HAS_CLAUDE_MD true

set -l NEW_PROJECT false
if test "$IS_GIT" = true -a "$HAS_DB" = false -a "$HAS_CLAUDE_MD" = false
    set NEW_PROJECT true
end

# ── Set session env vars ─────────────────────────────────────

if test -n "$CLAUDE_ENV_FILE"
    echo "export GROUNDED_PROJECT=\"$PROJECT_NAME\"" >> "$CLAUDE_ENV_FILE"
    echo "export GROUNDED_PROJECT_DIR=\"$PROJECT_DIR\"" >> "$CLAUDE_ENV_FILE"
end

# ── Mode: NEW PROJECT ────────────────────────────────────────

if test "$NEW_PROJECT" = true
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  🆕 NEW PROJECT DETECTED — $PROJECT_NAME"
    echo "  Auto-bootstrapping grounded coding environment"
    echo "══════════════════════════════════════════════"
    echo ""

    # [1] Detect language
    set -l LANG "unknown"
    set -l BUILD_CMD ""
    set -l TEST_CMD ""
    set -l LINT_CMD ""
    set -l WATCH_ROOT "./src"

    if test -f "$PROJECT_DIR/Cargo.toml"
        set LANG "rust"
        set BUILD_CMD "cargo build"
        set TEST_CMD "cargo test"
        set LINT_CMD "cargo clippy --all-targets -- -D warnings"
    else if test -f "$PROJECT_DIR/pyproject.toml" -o -f "$PROJECT_DIR/setup.py"
        set LANG "python"
        set BUILD_CMD "pip install -e ."
        set TEST_CMD "pytest"
        set LINT_CMD "ruff check"
    else if test -f "$PROJECT_DIR/go.mod"
        set LANG "go"
        set BUILD_CMD "go build ./..."
        set TEST_CMD "go test ./..."
        set LINT_CMD "golangci-lint run"
    else if test -f "$PROJECT_DIR/package.json"
        set LANG "node"
        set BUILD_CMD "npm run build"
        set TEST_CMD "npm test"
        set LINT_CMD "npx eslint ."
    end

    echo "  Detected: $LANG"

    # [2] Set env vars
    if test -n "$CLAUDE_ENV_FILE"
        echo "export GROUNDED_LANG=\"$LANG\"" >> "$CLAUDE_ENV_FILE"
        echo "export GROUNDED_NEW_PROJECT=\"1\"" >> "$CLAUDE_ENV_FILE"
    end

    # [3] Create .magellan/ directory and start indexing
    set -l DB_PATH "$PROJECT_DIR/.magellan/$PROJECT_NAME.db"
    if command -v magellan >/dev/null 2>&1
        mkdir -p "$PROJECT_DIR/.magellan"
        # Check if src/ exists for watch root
        if not test -d "$PROJECT_DIR/src"
            set WATCH_ROOT "."
        end
        echo "  Starting magellan index ($WATCH_ROOT)..."
        magellan watch --root "$WATCH_ROOT" --db "$DB_PATH" --scan-initial >/dev/null 2>&1 &
        if test -n "$CLAUDE_ENV_FILE"
            echo "export GROUNDED_DB=\"$DB_PATH\"" >> "$CLAUDE_ENV_FILE"
        end
        echo "  ✓ magellan indexing started (background)"
    else
        echo "  ⚠️  magellan not installed — skip indexing"
    end

    # [4] Generate CLAUDE.md
    set -l CLAUDE_MD_PATH "$PROJECT_DIR/CLAUDE_MD"
    if not test -f "$PROJECT_DIR/CLAUDE.md"
        set -l DATE (date +%Y-%m-%d)

        echo "# $PROJECT_NAME" > "$PROJECT_DIR/CLAUDE.md"
        echo "" >> "$PROJECT_DIR/CLAUDE.md"
        echo "**Language:** $LANG" >> "$PROJECT_DIR/CLAUDE.md"
        echo "**Generated:** $DATE by grounded-coding bootstrap" >> "$PROJECT_DIR/CLAUDE.md"
        echo "" >> "$PROJECT_DIR/CLAUDE.md"
        echo "## Quick Start" >> "$PROJECT_DIR/CLAUDE.md"
        echo "" >> "$PROJECT_DIR/CLAUDE.md"
        echo '```bash' >> "$PROJECT_DIR/CLAUDE.md"
        echo "$BUILD_CMD" >> "$PROJECT_DIR/CLAUDE.md"
        echo "$TEST_CMD" >> "$PROJECT_DIR/CLAUDE.md"
        echo "$LINT_CMD" >> "$PROJECT_DIR/CLAUDE.md"
        echo '```' >> "$PROJECT_DIR/CLAUDE.md"
        echo "" >> "$PROJECT_DIR/CLAUDE.md"
        echo "## Database Convention" >> "$PROJECT_DIR/CLAUDE.md"
        echo "" >> "$PROJECT_DIR/CLAUDE.md"
        echo "Project database: \`.magellan/$PROJECT_NAME.db\`" >> "$PROJECT_DIR/CLAUDE.md"
        echo "" >> "$PROJECT_DIR/CLAUDE.md"
        echo "## Graph Tools" >> "$PROJECT_DIR/CLAUDE.md"
        echo "" >> "$PROJECT_DIR/CLAUDE.md"
        echo '```bash' >> "$PROJECT_DIR/CLAUDE.md"
        echo "magellan status --db .magellan/$PROJECT_NAME.db" >> "$PROJECT_DIR/CLAUDE.md"
        echo "magellan watch --root $WATCH_ROOT --db .magellan/$PROJECT_NAME.db --scan-initial" >> "$PROJECT_DIR/CLAUDE.md"
        echo '```' >> "$PROJECT_DIR/CLAUDE.md"

        echo "  ✓ Generated CLAUDE.md"
    end

    # [5] Report other tools
    for tool in llmgrep mirage splice
        if command -v $tool >/dev/null 2>&1
            echo "  ✓ $tool available"
        end
    end

    echo ""
    echo "══════════════════════════════════════════════"
    echo "  Bootstrap complete. Edit CLAUDE.md to customize."
    echo "══════════════════════════════════════════════"
    echo ""

    exit 0
end

# ── Mode: EXISTING PROJECT (health check) ────────────────────

echo ""
echo "══════════════════════════════════════════════"
echo "  🔧 GROUNDED CODING ENVIRONMENT — $PROJECT_NAME"
echo "══════════════════════════════════════════════"
echo ""

# [1] Check magellan binary
set -l MAGELLAN_OK false
if command -v magellan >/dev/null 2>&1
    set -l VERSION (magellan --version 2>/dev/null | head -1)
    echo "  ✓ magellan: $VERSION"
    set MAGELLAN_OK true
else
    echo "  ⚠️  magellan not found — graph queries unavailable"
end

# [2] Check graph database
set -l DB_PATH "$PROJECT_DIR/.magellan/$PROJECT_NAME.db"
if test "$MAGELLAN_OK" = true -a -f "$DB_PATH"
    set -l STATUS (magellan status --db "$DB_PATH" 2>&1)
    if test $status -eq 0
        set -l SYMBOLS (echo "$STATUS" | grep "symbols:" | grep -o '[0-9]*' | head -1)
        set -l FILES (echo "$STATUS" | grep "files:" | grep -o '[0-9]*' | head -1)
        set -l REFS (echo "$STATUS" | grep "references:" | grep -o '[0-9]*' | head -1)
        echo "  ✓ graph DB: $SYMBOLS symbols, $FILES files, $REFS refs"
        if test -n "$CLAUDE_ENV_FILE"
            echo "export GROUNDED_DB=\"$DB_PATH\"" >> "$CLAUDE_ENV_FILE"
        end
    else
        echo "  ⚠️  graph DB exists but status failed — may need refresh"
    end
else if test "$MAGELLAN_OK" = true
    echo "  ℹ️  no graph DB — run: magellan watch --root ./src --db $DB_PATH --scan-initial"
end

# [3] Check envoy/atheneum
set -l ENVOY_UP (curl -sf http://127.0.0.1:9876/health >/dev/null 2>&1 && echo "true" || echo "false")
if test "$ENVOY_UP" = true
    echo "  ✓ envoy/atheneum: running"
    set -l DISCOVERIES (curl -sf "http://127.0.0.1:9876/atheneum/knowledge?project=$PROJECT_NAME" 2>/dev/null | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    count = len(d) if isinstance(d, list) else d.get('count', 0)
    print(count)
except:
    print(0)
" 2>/dev/null)
    if test -n "$DISCOVERIES" -a "$DISCOVERIES" != "0"
        echo "    cached discoveries: $DISCOVERIES"
    end
else
    echo "  ℹ️  envoy/atheneum: not running"
end

# [4] Check key binaries
for tool in llmgrep mirage splice
    if command -v $tool >/dev/null 2>&1
        echo "  ✓ $tool: "(command $tool --version 2>/dev/null | head -1 || echo "available")
    end
end

# [5] Set lang env var from detected project files
set -l LANG "unknown"
test -f "$PROJECT_DIR/Cargo.toml"; and set LANG "rust"
test -f "$PROJECT_DIR/pyproject.toml" -o -f "$PROJECT_DIR/setup.py"; and set LANG "python"
test -f "$PROJECT_DIR/go.mod"; and set LANG "go"
test -f "$PROJECT_DIR/package.json"; and set LANG "node"
if test -n "$CLAUDE_ENV_FILE" -a "$LANG" != "unknown"
    echo "export GROUNDED_LANG=\"$LANG\"" >> "$CLAUDE_ENV_FILE"
end

echo ""
echo "══════════════════════════════════════════════"
echo ""

exit 0
