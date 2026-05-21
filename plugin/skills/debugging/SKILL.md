---
name: grounded-coding-debugging
description: Use when encountering bugs, test failures, or unexpected behavior. Find root cause before proposing fixes. Random fixes waste time and create new bugs.
---

# Grounded Coding — Debugging

**Random fixes waste time. Symptom patches mask the real problem.**

---

## Four Phases

Complete each phase before moving to the next.

### Phase 1: Root Cause Investigation

1. **Read error messages completely** — line numbers, file paths, error codes, stack traces
2. **Reproduce consistently** — can you trigger it reliably?
3. **Check recent changes** — `git diff`, recent commits
4. **Gather evidence** — log data at component boundaries, verify config
5. **Trace data flow** — where does the bad value originate?

### Phase 2: Pattern Analysis

Find working examples. Compare working vs broken — list every difference.

### Phase 3: Hypothesis and Testing

Form a specific hypothesis: "X is the root cause because Y." Test with smallest possible change.

If it works → Phase 4. If not → NEW hypothesis (don't stack fixes).

### Phase 4: Implementation

Create failing test case. Fix addressing root cause. Verify.

**If 3+ fix attempts fail:** Stop — this is likely architectural, not a code problem. Discuss with user.

---

## Common Debugging Traps

| Trap | Why It's Wrong |
|------|---------------|
| Fixing without reproducing | Never confirmed the bug |
| Changing random things | Doesn't isolate root cause |
| Trusting memory instead of error messages | Error message has the answer |
| Stacking fixes on top of fixes | Can't tell which worked |

---

Return to `grounded-coding-core` when debugging is complete.
