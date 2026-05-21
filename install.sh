#!/bin/sh
# install.sh — Standalone CLI installer for grounded-coding tools
#
# Installs magellan, llmgrep, mirage, splice to ~/.local/bin
# Does NOT touch Claude Code settings or install scripts.
# For the full plugin experience, install the Claude Code plugin separately.
#
# Usage:
#   curl -fsSL https://github.com/luizspies/grounded-coding/install.sh | sh
#   ./install.sh --dev          # build from local source (contributors)
#   ./install.sh --version X.Y.Z  # install specific version
#
set -eu

REPO="luizspies/grounded-coding"
PREFIX="${HOME}/.local/bin"
TOOL_BINARIES="magellan llmgrep mirage splice"
VERSION="latest"
DEV_MODE=false
TMPDIR=""

cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT

info()  { printf "  [INFO]  %s\n" "$1"; }
warn()  { printf "  [WARN]  %s\n" "$1"; }
error() { printf "  [ERROR] %s\n" "$1" >&2; exit 1; }

# ── Parse args ──────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        --dev)     DEV_MODE=true; shift ;;
        --version) VERSION="$2"; shift 2 ;;
        --prefix)  PREFIX="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: install.sh [--dev] [--version X.Y.Z] [--prefix PATH]"
            exit 0 ;;
        *) error "Unknown option: $1" ;;
    esac
done

# ── Preflight ───────────────────────────────────────────────

info "Grounded Coding CLI Installer"
info "Install prefix: $PREFIX"

mkdir -p "$PREFIX"

# ── Dev mode: build from local source ───────────────────────

if [ "$DEV_MODE" = true ]; then
    info "Dev mode: building from local source"
    for tool in $TOOL_BINARIES; do
        case "$tool" in
            mirage) crate="mirage-analyzer" ;;
            *)      crate="$tool" ;;
        esac
        info "Installing $crate from source..."
        cargo install "$crate" --force --root "$PREFIX" 2>&1 || warn "Failed to build $crate"
    done
    info "Dev install complete"
    exit 0
fi

# ── Detect platform ─────────────────────────────────────────

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS-$ARCH" in
    linux-x86_64|linux-amd64) PLATFORM="x86_64-linux" ;;
    linux-aarch64)            PLATFORM="aarch64-linux" ;;
    darwin-x86_64)            PLATFORM="x86_64-macos" ;;
    darwin-arm64)              PLATFORM="aarch64-macos" ;;
    *)
        warn "No prebuilt binaries for $OS-$ARCH"
        info "Falling back to cargo install (requires Rust toolchain)"
        FALLBACK_CARGO=true
        ;;
esac

# ── Resolve version ─────────────────────────────────────────

if [ "$VERSION" = "latest" ]; then
    VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"grounded-coding\/v\([^"]*\)".*/\1/')
    if [ -z "$VERSION" ]; then
        error "Could not determine latest version. Specify --version explicitly."
    fi
fi

info "Installing version: $VERSION"

# ── Install method: prebuilt binaries or cargo ──────────────

if [ "${FALLBACK_CARGO:-false}" = true ]; then
    # ── Cargo fallback ──────────────────────────────────────
    command -v cargo >/dev/null 2>&1 || error "cargo not found. Install Rust: https://rustup.rs"

    for tool in $TOOL_BINARIES; do
        case "$tool" in
            mirage) crate="mirage-analyzer" ;;
            *)      crate="$tool" ;;
        esac
        info "Installing $crate via cargo..."
        cargo install "$crate" --root "$PREFIX" --force 2>&1 || warn "Failed to install $crate"
    done
else
    # ── Download prebuilt binaries ──────────────────────────
    TMPDIR=$(mktemp -d)
    info "Downloading prebuilt binaries for $PLATFORM..."

    CHECKSUM_FILE="$TMPDIR/checksums.txt"
    curl -fsSL "https://github.com/$REPO/releases/download/grounded-coding/v${VERSION}/checksums.txt" \
        -o "$CHECKSUM_FILE" || error "Failed to download checksums"

    for tool in $TOOL_BINARIES; do
        ARCHIVE="${tool}-${PLATFORM}.tar.gz"
        URL="https://github.com/$REPO/releases/download/grounded-coding/v${VERSION}/${ARCHIVE}"

        info "Downloading $tool..."
        curl -fsSL "$URL" -o "$TMPDIR/$ARCHIVE" || error "Failed to download $tool"

        # Verify checksum
        if command -v sha256sum >/dev/null 2>&1; then
            EXPECTED=$(grep "$ARCHIVE" "$CHECKSUM_FILE" | awk '{print $1}')
            ACTUAL=$(sha256sum "$TMPDIR/$ARCHIVE" | awk '{print $1}')
            if [ "$EXPECTED" != "$ACTUAL" ]; then
                error "Checksum mismatch for $tool (expected $EXPECTED, got $ACTUAL)"
            fi
            info "  Checksum OK"
        else
            warn "  sha256sum not found, skipping checksum verification"
        fi

        # Extract and install
        tar -xzf "$TMPDIR/$ARCHIVE" -C "$TMPDIR"
        chmod +x "$TMPDIR/$tool"
        mv "$TMPDIR/$tool" "$PREFIX/$tool"
        info "  Installed to $PREFIX/$tool"
    done
fi

# ── Verify ──────────────────────────────────────────────────

info ""
info "Installed tools:"
for tool in $TOOL_BINARIES; do
    if command -v "$PREFIX/$tool" >/dev/null 2>&1; then
        VERSION_OUT=$("$PREFIX/$tool" --version 2>/dev/null || echo "unknown")
        info "  $tool: $VERSION_OUT"
    else
        warn "  $tool: not found"
    fi
done

info ""
info "CLI tools installed successfully."
info ""
info "For the full grounded coding experience (skills, hooks, scripts),"
info "install the Claude Code plugin: grounded-coding"
info ""
info "Make sure $PREFIX is in your PATH."
