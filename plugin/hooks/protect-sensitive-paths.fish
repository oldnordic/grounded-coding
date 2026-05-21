#!/usr/bin/env fish
# protect-sensitive-paths.fish — PreToolUse Write|Edit hook
# Blocks writes to sensitive files: .env, credentials, keys, build artifacts, git internals.
# Allows .env.example, .env.template, .env.test patterns.
#
# Exit codes:
#   0 = path is safe (or no path found in input)
#   2 = blocked — sensitive file detected

# Read hook input from stdin
set -l INPUT (cat)

# Extract file_path from tool_input
set -l FILE_PATH (echo "$INPUT" | python3 -c "
import json, sys, os
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# No path found — allow
if test -z "$FILE_PATH"
    exit 0
end

# Normalize path
set -l BASENAME (basename "$FILE_PATH")

# Allow patterns (whitelist)
if string match -qr '\.env\.(example|template|sample|test|ci|local\.example)$' -- "$BASENAME"
    exit 0
end

# Block: .env and .env.* (except whitelisted above)
if string match -qr '^\.env$' -- "$BASENAME"
    echo ""
    echo "  BLOCKED: writing to .env"
    echo "  Sensitive environment file — secrets should not be committed."
    echo "  Use .env.example for the template instead."
    echo ""
    exit 2
end

if string match -qr '^\.env\.' -- "$BASENAME"
    echo ""
    echo "  BLOCKED: writing to $BASENAME"
    echo "  Environment files may contain secrets."
    echo "  Use .env.example or .env.template for shareable config."
    echo ""
    exit 2
end

# Block: credential files
if string match -qr 'credential' -- "$BASENAME"
    echo ""
    echo "  BLOCKED: writing to $BASENAME"
    echo "  Credential files must not be written by AI agents."
    echo ""
    exit 2
end

# Block: key/cert files
if string match -qr '\.(pem|key|secret|p12|pfx|jks)$' -- "$BASENAME"
    echo ""
    echo "  BLOCKED: writing to $BASENAME"
    echo "  Key/certificate files must not be written by AI agents."
    echo ""
    exit 2
end

# Block: git internals
if string match -qr '/\.git/' -- "$FILE_PATH"
    echo ""
    echo "  BLOCKED: writing to .git/ directory"
    echo "  Git internals should not be modified directly."
    echo ""
    exit 2
end

# Block: Rust build artifacts
if string match -qr '/target/' -- "$FILE_PATH"
    echo ""
    echo "  BLOCKED: writing to target/ directory"
    echo "  Build artifacts are regenerated — edit source files instead."
    echo ""
    exit 2
end

# Block: magellan DB files
if string match -qr '/\.magellan/.*\.db$' -- "$FILE_PATH"
    echo ""
    echo "  BLOCKED: writing to magellan database"
    echo "  Graph DB is managed by magellan watch — not direct writes."
    echo ""
    exit 2
end

# All clear
exit 0
