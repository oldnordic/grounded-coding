---
name: grounded-coding-planning
description: Use when planning a feature, refactor, or change. Analyze the current state with graph tools, brainstorm grounded in evidence, write implementation plan with specific symbols/files/paths.
---

# Grounded Coding — Planning

**Plans written without graph evidence are plans built on assumptions.**

Load this skill BEFORE entering plan mode or writing any implementation code.

---

## Phase 0: Analyze, Brainstorm, Plan

### Step 1: Analyze the Current State (Four Layers)

**All four layers are mandatory.** Complete each before moving to the next.

**Layer 1 — Symbol discovery** (What exists?)

```bash
knowledge-navigator "find <related_symbol>" --project <name>
```

Or directly:
```bash
magellan find --db <project-db> --name "related_symbol"
llmgrep search --db <project-db> --query "feature area" --mode symbols
```

**Layer 2 — Call structure** (Who calls what?)

```bash
knowledge-navigator "who calls <target>" --project <name>
knowledge-navigator "what <target> calls" --project <name>
```

Or directly:
```bash
magellan refs --db <project-db> --name "target_func" --direction in
magellan refs --db <project-db> --name "target_func" --direction out
magellan context symbol --db <project-db> --name "target" --depth 2
```

**Layer 3 — Control flow** (How does it behave?)

This is the layer agents most often skip — and the one that catches the most bugs.

```bash
mirage cfg --db <project-db> --function "function_youll_change"
mirage blast-zone --db <project-db> --function "function_youll_change"
```

Reference the CFG output explicitly in your plan. If you haven't cited mirage output, you haven't completed Phase 0.

**Layer 4 — Structural health** (Any traps?)

```bash
mirage paths --db <project-db> --function "entry_point"
splice cycles --db <project-db>
```

---

### Step 2: Brainstorm Grounded in Evidence

With graph evidence in hand, brainstorm approaches.

**Don't propose solutions that contradict what the graph shows:**
- If `mirage blast-zone` reveals 15 callers, a signature change affects all of them
- If `magellan dead-code` shows the module is unused, maybe the feature should go elsewhere

**Key questions the graph answers:**
- **Where should this go?** — `magellan context symbol` shows module boundaries
- **What breaks?** — `magellan context impact --depth 3` shows blast radius
- **Is there precedent?** — `llmgrep search --mode symbols` finds existing patterns
- **What's the call path?** — `magellan refs --direction in` traces callers
- **What's the control flow?** — `mirage cfg` shows branches, loops, state assumptions

---

### Step 3: Write the Plan

Write the implementation plan referencing **actual symbols, files, and call paths** from the graph — not imagined ones.

**The plan should cite:**
- Specific files and functions that will change (from `magellan find`/`llmgrep`)
- Callers that need updating (from `magellan refs --direction in`)
- Control flow implications (from `mirage cfg`/`mirage paths`)
- Dead code or cycles to watch for (from `splice cycles`)

**Get user approval before proceeding to Gate 0.**

---

### Step 4: Execute with Checkpoints

After plan approval, proceed through Gates 0-3 using appropriate sub-skills:
- Gate 0: Load `grounded-coding-tools` for query commands
- Gate 1: Load `grounded-coding-tdd` for tests-first workflow
- Gate 2: Update graph, run verification
- Gate 3: Load `grounded-coding-verification` for evidence reporting

If the plan has independent tasks, dispatch subagents — but each subagent must also follow Phase 0 for its slice of work.

---

## Blast Radius Analysis

Before changing a symbol, understand the impact:

```bash
# Check all callers
knowledge-navigator "who calls <symbol>" --project <name>

# Check impact depth
magellan context impact --db <db> --name "<symbol>" --depth 3
```

If impact is large (>10 callers), consider:
- Can the change be made incrementally?
- Should the signature be preserved with a new function added?
- Is there a safer abstraction point?

---

## CFG Analysis for Complex Logic

For functions with complex control flow:

```bash
mirage cfg --db <db> --function "<function>"
mirage paths --db <db> --function "<function>"
```

**What to look for:**
- Multiple exit points → harder to reason about
- Deep nesting → consider refactoring
- State assumptions → document invariants
- Error paths → ensure they're tested

---

## Common Planning Traps

| Trap | Why It's Wrong | What To Do Instead |
|------|---------------|-------------------|
| "I remember this code" | Code changes between sessions | Query the graph |
| "This should be simple" | Simple code still has callers | Check refs first |
| Planning in isolation | Graph reveals dependencies | Analyze before planning |
| Assuming file locations | Projects vary | Use per-project DB paths |

---

Return to `grounded-coding-core` when planning is complete and approved.
