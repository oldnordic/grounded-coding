---
name: grounded-coding-subagents
description: Use when delegating to subagents. Handoff protocol prevents silent degradation when context fills up. Subagents package state into manifests instead of producing stubs.
---

# Grounded Coding — Subagent Handoffs

**Subagents silently degrade when context fills up. Handoffs preserve state.**

> **Build flag:** the `/atheneum/*` endpoints below only exist when envoy is built with `--features atheneum`. The default `cargo build` skips them and you'll get 404s. If unsure, run `cargo build --bin envoy --features atheneum` and restart the server. The endpoints also need `ATHENEUM_DB` set in the environment so the bridge knows where to persist.

---

## When to Hand Off

At **~85% of token budget**, stop taking new work. Complete current gate, then send handoff.

**Gates are natural checkpoints:**
- After Phase 0 — Analysis + plan complete
- After Gate 0 — All queries done
- After Gate 1 — Tests written, seen failing
- After Gate 2 — Code done, verified, graph updated

---

## Sending a Handoff

The wire format below maps directly to envoy's `POST /atheneum/handoffs` body. Optional `project_id` scopes the handoff to a specific project so envoy/magellan/splice can share one atheneum DB without name collisions; omit it for the default unscoped behavior.

```bash
curl -X POST http://127.0.0.1:9876/atheneum/handoffs \
  -H "Content-Type: application/json" \
  -d '{
    "from_agent": "agent-1",
    "to_agent": "agent-2",
    "project_id": "envoy",
    "manifest": {
      "status": "NEEDS_CONTEXT",
      "context_remaining_pct": 15,
      "what_was_done": "wrote 3 failing tests for priority field",
      "what_is_stubbed": [],
      "remaining_work": ["implement field", "update 8 callers", "verify"],
      "verification_state": {
        "tests_passing": 0,
        "tests_failing": 3
      },
      "grounded_queries_used": [
        "magellan find Message",
        "mirage cfg Message::new"
      ],
      "evidence": [
        {"query": "...", "result": "..."}
      ]
    }
  }'
```

If atheneum isn't reachable (envoy not running, or built without `--features atheneum`), fall back to a file-based handoff at `.grounded/handoff.json` in the project root and have the receiver look there first.

---

## Handoff Fallback (When Envoy Is Down)

If `$ENVOY_UP = "false"`, write the handoff manifest to a file instead of envoy:

```bash
mkdir -p .claude/handoffs/claimed

cat > ".claude/handoffs/${AGENT_ID}-$(date +%s).json" << 'EOF'
{
  "status": "NEEDS_CONTEXT",
  "from_agent": "agent-1",
  "project": "forge",
  "context_remaining_pct": 15,
  "what_was_done": ["..."],
  "remaining_work": ["..."],
  "verification_state": {},
  "grounded_queries_used": []
}
EOF
```

**Path resolution:**
1. Project-local (preferred): `.claude/handoffs/{from_agent}-{timestamp}.json`
2. Global fallback: `~/.claude/handoffs/{from_agent}-{timestamp}.json`

**To pick up a pending handoff:**
1. Check `.claude/handoffs/*.json` for unclaimed manifests
2. Fallback: check `~/.claude/handoffs/*.json`
3. Read manifest, move to `.claude/handoffs/claimed/` to mark as claimed

See `handoff-fallback.md` in this skill directory for the full reference.

---

## Receiving a Handoff

```bash
# Check for pending handoffs (add &project=<id> to scope to one project)
AGENT_ID="your-name"
curl -s "http://127.0.0.1:9876/atheneum/handoffs/pending?agent=$AGENT_ID"

# Claim the handoff once you've read it (removes it from the queue)
HANDOFF_ID=$(...)
curl -X POST "http://127.0.0.1:9876/atheneum/handoffs/$HANDOFF_ID/claim"
```

**When you receive:**
1. Read the manifest data
2. Skip evidence already gathered
3. Pick up at first incomplete gate
4. Do NOT re-run cited queries
5. Send your own handoff when complete or at next checkpoint

---

## Subagent Trust Model

Subagent output is valid ONLY when:
- Hook gates passed (exit 2 = BLOCKED)
- They cite specific magellan/llmgrep queries run BEFORE coding
- `cargo check` and `cargo test` pass on their changes
- No stubs or `#[allow(dead_code)]` in the diff

**If hooks blocked:** Their summary is unreliable. Read the actual diff, fix violations, verify yourself.

---

## Token Economics

| Approach | Cost |
|----------|------|
| Full file read | ~15K tokens |
| Graph queries | ~2.5K tokens |
| Handoff manifest | ~500 tokens |

Handoffs preserve ~10K tokens of understanding for ~500 tokens.

---

Return to `grounded-coding-core` when handoff is complete.
