# Tool Reference

## magellan — Codebase Mapping

Index source code into a symbol graph with references, call graph, and full-text search.

```bash
# Index a project
magellan watch --root ./src --db .magellan/myproject.db --scan-initial

# Keep DB in sync (run in background)
magellan watch --root ./src --db .magellan/myproject.db

# Check health
magellan status --db .magellan/myproject.db

# Refresh after offline changes
magellan refresh --db .magellan/myproject.db
magellan refresh --db .magellan/myproject.db --dry-run
magellan refresh --db .magellan/myproject.db --include-untracked

# Find symbols
magellan find --db .magellan/myproject.db --name "symbol_name"

# Find references
magellan refs --db .magellan/myproject.db --name "func" --path src/lib.rs --direction in
magellan refs --db .magellan/myproject.db --name "func" --path src/lib.rs --direction out

# Context queries
magellan context symbol --db .magellan/myproject.db --name "func" --depth 2 --with-source
magellan context impact --db .magellan/myproject.db --name "func" --depth 3
magellan context affected --db .magellan/myproject.db --name "func" --depth 3

# Source inventory
magellan source-inventory --db .magellan/myproject.db --list
magellan source-inventory --db .magellan/myproject.db --scan ./docs docs
```

## llmgrep — Semantic Code Search

Query code semantically and structurally from the magellan database.

```bash
# Symbol search
llmgrep --db .magellan/myproject.db search --query "pattern" --output human

# Document search
llmgrep --db .magellan/myproject.db search --query "topic" --mode docs

# Fact search
llmgrep --db .magellan/myproject.db search --query "predicate" --mode facts
```

## mirage — CFG Analysis

Control flow graph analysis, path finding, loop detection, dominance, and hotspot identification.

```bash
# CFG for a function
mirage --db .magellan/myproject.db cfg --function "my_function"

# Path analysis
mirage --db .magellan/myproject.db paths --function "my_function"

# Hotspot detection
mirage --db .magellan/myproject.db hotspots

# Blast zone (impact analysis)
mirage --db .magellan/myproject.db blast --function "my_function"
```

## splice — Span-Safe Refactoring

Refactor with span-aware safety across files.

```bash
# Preview a patch
splice patch --file src/lib.rs --symbol old_name --with new_name --preview

# Apply a patch
splice patch --file src/lib.rs --symbol old_name --with new_name

# Cross-file rename
splice rename --db .magellan/myproject.db --name old_name --to new_name

# Program slicing
splice slice --file src/lib.rs --symbol my_function
```

## Helper Scripts

| Script | Usage |
|--------|-------|
| `grounded-context` | Compose magellan + llmgrep + mirage into one context artifact |
| `unified-query` | Query across envoy, atheneum, wiki simultaneously |
| `token-summary` | Print current session token usage |
| `build-unified-index` | Build LLM-readable metadata index |
| `wiki-search` | Semantic wiki search |
| `wiki-summary` | Summarize journal entries |
| `msg-check` | One-shot agent inbox check |
| `msg-monitor` | Watch agent inbox for new messages |
