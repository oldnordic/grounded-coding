# Grounded Coding

Graph-powered code intelligence, TDD discipline, and verification gates for Claude Code.

## What Is This?

Grounded Coding is a code intelligence environment that gives Claude Code (and you) deep, structured understanding of your codebase through graph databases, control flow analysis, and span-safe refactoring.

**The core idea:** The database is truth. Memory is not.

Instead of guessing about code structure, you query a symbol graph. Instead of hoping tests cover the right thing, you trace control flow. Instead of hoping refactors don't break things, you use span-safe edits.

## Tools

| Tool | Purpose | Crate |
|------|---------|-------|
| **magellan** | Codebase indexing, symbol graph, context queries, FTS5 search | `magellan` |
| **llmgrep** | Semantic and structural queries over magellan DB | `llmgrep` |
| **mirage** | CFG analysis, paths, loops, dominance, hotspots | `mirage-analyzer` |
| **splice** | Span-safe refactoring, cross-file rename, program slicing | `splice` |

## Install

### Claude Code Plugin (Recommended)

Install from the Claude Code marketplace. The setup skill handles everything.

### Standalone CLI

```bash
curl -fsSL https://github.com/luizspies/grounded-coding/install.sh | sh
```

### From Source

```bash
cargo install magellan llmgrep mirage-analyzer splice
```

### Contributors

```bash
git clone https://github.com/luizspies/grounded-coding
cd grounded-coding
./install.sh --dev
```

## How It Works

1. **Index** your codebase: `magellan watch --root ./src --db .magellan/myproject.db --scan-initial`
2. **Query** symbols and relationships: `magellan find`, `llmgrep search`, `magellan refs`
3. **Analyze** control flow: `mirage cfg`, `mirage paths`, `mirage hotspots`
4. **Refactor** safely: `splice patch`, `splice rename`
5. **Verify** before claiming done: tests, clippy, security gates

The Claude Code plugin wraps all of this into skills and hooks so Claude follows the discipline automatically.

## What's in the Plugin

- **12 skills** — core, setup, doctor, planning, TDD, debugging, verification, tools, subagents, atheneum, perf, workspace
- **3 hooks** — session bootstrap, sensitive-path protection, Rust verification
- **17 CLI scripts** — context composition, wiki tools, agent messaging, profiling

## Requirements

- Linux x86_64 (prebuilt binaries) or any platform with Rust toolchain
- Claude Code (for plugin features)
- Fish shell (for hooks)

## License

MIT
