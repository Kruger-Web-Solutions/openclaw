# Memory Synthesis & Integration Protocol

**Don't just log. Learn. Grow. Integrate.**

## The Problem
- Daily logs pile up in `memory/YYYY-MM-DD.md` (raw data)
- Long-term memory in `MEMORY.md` stays static (no learning)
- Lessons from failures don't affect how I work (repeat mistakes)
- SOUL.md, TOOLS.md don't evolve based on experience

## The Solution: Active Synthesis

Every 3-5 sessions or when significant events occur:

### Step 1: Read Recent Daily Logs
- Pull recent `memory/YYYY-MM-DD.md` files
- Extract: lessons learned, patterns, mistakes, insights

### Step 2: Identify What Should Persist
Ask these questions:
- **What did I do wrong?** How do I avoid it next time?
- **What worked well?** Why? How do I repeat it?
- **Did I make the same mistake twice?** Update MEMORY.md to flag this.
- **Did I learn something about Henzard?** Add to USER.md or MEMORY.md.
- **Did my process improve?** Update SOUL.md or AGENTS.md.

### Step 3: Update Core Files
These CAN be updated based on learnings:

**MEMORY.md** — Add/update:
- Lessons learned
- Patterns observed (e.g., "Henzard catches false confidence immediately")
- Things to remember
- Mistakes to avoid (e.g., "Verify before claiming success")

**SOUL.md** — Evolve:
- Add new commitments based on failures
- Refine values based on what matters to Henzard
- Update working style based on what's effective

**USER.md** — Extend:
- New preferences discovered
- Context updates (diet changes, schedule shifts)

**TOOLS.md** — Do NOT edit automatically. This file is human-maintained only.

### Step 4: Reflect in Daily Notes
Add to `memory/YYYY-MM-DD.md`:
- What was synthesized today
- What changed in core files
- What will be different next session

## Example: Stale Session Lesson

**What went wrong:**
- Agent kept showing task IDs instead of names
- Root cause: poisoned session cache + field name mismatch
- Took multiple rounds of user frustration to find

**What to update in MEMORY.md:**
```
## Working Lessons
- When agent output looks wrong despite code fixes, check for stale session files
- Always verify tool output format matches what TOOLS.md tells the model to expect
- User will catch false confidence quickly — verify always
```

## Triggers for Synthesis

Synthesize when:
- Major bug fixed (learn the lesson)
- User corrects me (integrate the feedback)
- Pattern noticed (3+ similar mistakes)
- Session complete (review & distill)
- Every 3-5 days (periodic review)

## Implementation

Add to session startup (already in AGENTS.md):
```
If this is not the first session:
1. Scan memory/ for daily logs from last 3-5 sessions
2. Read through them quickly
3. Extract 2-3 key learnings
4. Update MEMORY.md, SOUL.md, USER.md if needed
5. Note what changed for this session
```

---

That's real learning. Not just logging — integrating.
