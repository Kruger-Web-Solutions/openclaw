# HELP — OpenClaw Personal Assistant

Type **`help`** anytime to see this guide.

---

## Quick Status Checks

| You say | What happens |
|---------|-------------|
| "What's outstanding on Habitica?" | `habitica dashboard` — shows due dailies, todos, habits |
| "Macros?" / "How am I doing?" | `sparky_fitness summary` — today's calorie/macro progress |
| "What did I eat today?" | `sparky_fitness diary` — full food log |
| "What's my plan?" / "Today's tasks?" | `habitica dashboard` + `todoist_tasks list --label in-progress` |
| "What are the exercises for today?" | Reads `exercise-plan.md` — full plan with sets/reps/RPE/links |
| "What happened in Weighsoft?" | `wa_archive today Weighsoft` — summarizes today's group messages |
| "Weighsoft yesterday?" | `wa_archive yesterday Weighsoft` — yesterday's group summary |

---

## Smart Features (Cross-Service Intelligence)

Sarel chains actions across services automatically:

| You say | What happens behind the scenes |
|---------|-------------------------------|
| "morning meds done" | Habitica daily "Morning Vitamins" completed + progress snapshot |
| "evening meds done" | Habitica daily "Evening Vitamins" completed + progress snapshot |
| "8000 steps today" | Habitica daily "7000 steps" auto-completed |
| "had dinner" / food logged as dinner | SparkyFitness food log + Habitica "Dinner" daily completed |
| "water bottle done" | SparkyFitness 1200ml logged + Habitica "Drink 3L" habit scored |
| "coffee" (3rd+) | SparkyFitness food log + Habitica "Limit to 2 Cups" scored down + nudge |
| "sauerkraut" / "kefir" | Habitica "fermented foods" habit scored |
| "ACV before meal" | Habitica "ACV pre-meal ritual" habit scored |
| "morning routine done" | Morning Vitamins + Bible Time + morning shake — all at once |

After every action, you get a progress snapshot: `Done. Today: 5/8 dailies | 1750/5285ml water | 410/2710 cal`

### Coaching Behaviors

- Sarel coaches after every food log (not just numbers — actual meal suggestions when behind)
- Missed a daily 3+ days in a row? Sarel suggests a smaller version instead of repeating the same reminder
- 7-day streak? Sarel celebrates. 30-day streak? "This is who you are."
- Self-critical? Spiritual anchor first, then reframe, then one forward-looking question
- Before standups, Sarel pulls group chat context + your open tasks automatically

---

## Logging (Health & Nutrition)

| You say | Tool called |
|---------|------------|
| "Morning shake done" | `sparky_fitness log_food "Morning Shake" breakfast ...` |
| "Coffee" / "2nd coffee" | `sparky_fitness log_food "Morning Coffee" ...` |
| "Water bottle done" | `sparky_fitness log_water 1200` |
| "I weigh X" | `sparky_fitness weight X` |
| "Had [food] for [meal]" | `sparky_fitness log_food ...` (auto-detects meal) |

After every food log, the agent replies: "Logged. Today: [cal] cal | P: Xg | C: Xg | F: Xg"

---

## Task Management

| You say | Action |
|---------|--------|
| "Done with [task name]" | `habitica complete` + `todoist_tasks close` |
| "Buy X" / "Add X to shopping" | `todoist_tasks grocery "X"` |
| "X for Weighsoft" / "X for Nedbank" | `todoist_tasks create "X" [project]` |
| "Book: X" / "Read: X" | `todoist_tasks create "X" Books` |
| "Starting X" / "In progress: X" | Todoist (label: in-progress) + Habitica VIP sync |

---

## Spiritual & Emotional

| Situation | Agent response |
|-----------|---------------|
| Stress / overwhelm / food cravings | Spiritual anchor first, then practical redirect |
| "I failed today" / "I slipped" | "It's okay. Every day is a new start." Then one question. |
| Log an unplanned meal (chips, chocolate, off-plan food) | Logs macros → spiritual anchor → FASTER check → reflection questions (Carr Big Monster model) → belief check → summary → logged to MEMORY.md |
| "I keep doing this / it keeps happening" | Adds Derek Prince pattern layer — looks for recurring cycle, not just the moment |
| "bible done" / "bible reading done" | S.W.O.R.D. drill sent (5 questions, one-reply) → Sarel reflects back + names your D-action → logged to MEMORY.md → Bible daily completed |
| "What does the Bible say about..." | Scripture reference + personal connection |

---

## 7-Day Mission (Weekly)

Each Sunday 20:00 State of Me report ends with a proposed mission for the coming week:

| Step | What happens |
|------|-------------|
| Sunday 20:00 | Sarel reads this week's FASTER flags, SWORD D-actions, eating triggers, Friday reflection, and task patterns → proposes a 7-Day Mission across Faith, Health, Work, Emotional |
| Reply "mission confirmed" | Mission locked and stored in MEMORY.md under `## Current Mission` |
| Reply "mission: [your adjustments]" | Sarel adjusts and stores the updated mission |
| Friday 16:00 | Week-close asks which mission items you completed → debrief logged |

---

## Reflections (Weekly + Monthly)

Every Friday after wins and mission review, Sarel asks a quick 3-field reflection:

```
well: [what went well] | more: [what I should do more of] | stop: [what I should stop]
```

Reply in one line — Sarel logs it to MEMORY.md under `## Weekly Reflections`. You never have to think about format.

| When | What happens |
|------|-------------|
| Friday 16:00 | After wins + mission review, Sarel asks the reflection prompt — reply in one line |
| Sunday 20:00 | Sarel reads your Friday reflection and uses "more" + "stop" to inform the 7-Day Mission |
| Last Friday of the month | Month-close: Sarel reads 4 weeks of entries, surfaces recurring patterns, asks for one monthly commitment |

Monthly pattern alert: if the same "stop" item appears 3+ times across Friday reflections, Sarel names it directly in the month-close: "That is not a preference — that is a pattern."

---

## Book Coaching Frameworks

Two frameworks available (see `BOOK-COACHING-USAGE.md`):

- **Derek Prince — *Blessing or Curse***: For repeating patterns, generational cycles, spiritual blockages
- **Allen Carr — *Easy Way to Quit Emotional Eating***: For comfort eating, food cravings, reframing

---

## System & Debugging

| Command | What it does |
|---------|-------------|
| `systemctl --user status openclaw-gateway.service` | Gateway status |
| `systemctl --user restart openclaw-gateway.service` | Restart gateway |
| `openclaw channels status` | WhatsApp connection check |
| `openclaw logs --follow` | Live gateway logs |
| `openclaw cron list` | Show active cron jobs |

---

## Tools Available

| Tool | Type | What it does |
|------|------|-------------|
| `habitica` | Shell script (`~/bin/`) | Dashboard, dailies, habits, todos, complete, create_todo |
| `sparky_fitness` | Shell script (`~/bin/`) | Summary, diary, goals, log_water, weight, sleep, log_food |
| `todoist_tasks` | Shell script (`~/bin/`) | List, create, close, grocery |
| `wa_archive` | Node script (`~/bin/`) | Today, yesterday, date, recent, search, groups |
| `message` | Gateway core tool | Send WhatsApp message |
| `cron` | Gateway CLI | List, add, edit, rm, run |

---

## Key Files

| File | Purpose |
|------|---------|
| `TOOLS.md` | Routing rules, schedule, tool inventory (the brain — slim, ~7KB) |
| `BACKLOG.md` | Active work items and known issues |
| `SOUL.md` | Agent persona & values |
| `MEMORY.md` | Long-term memories & context |
| `USER.md` | Info about Henzard |
| `HELP.md` | This file |
| `exercise-plan.md` | Weekly workout plan with sets/reps/RPE/YouTube links |
| `BOOK-COACHING-USAGE.md` | How to use book coaching frameworks |
| `AGENTS.md` | Workspace conventions |
| `IDENTITY.md` | Agent identity metadata |
| `HEARTBEAT.md` | Heartbeat checklist (empty = skip) |
| `MEMORY-SYNTHESIS.md` | Protocol for learning from daily logs |
| **Skills** (loaded on-demand): | |
| `skills/health-coach/` | GAPS diet, macros, SparkyFitness, hydration |
| `skills/exercise/` | Weekly workout plan with sets/reps/RPE/links |
| `skills/medication/` | Morning + evening med protocol, safety rules |
| `skills/spiritual/` | Bible plan, feasts, coaching frameworks, anchor |
| `skills/habitica-tasks/` | Habitica + Todoist task management, VIP sync |

---

## Daily Workflow

1. **5:00am** — Wake up, Bible reading
2. **6:30am** — Morning meds, shake, planning. Agent sends daily briefing.
3. **Throughout day** — Cron reminders for hydration, tasks, standups
4. **17:00** — Work apps close. Family time boundary enforced.
5. **19:00** — Exercise (agent provides plan from `exercise-plan.md`)
6. **21:00** — Evening meds reminder
7. **Sunday 20:00** — State of Me weekly report → ends with proposed 7-Day Mission for next week
8. **Friday 16:00** — Week close: task summary + 3 wins + mission review + quick reflection (well/more/stop)
9. **Last Friday of month** — Month close: 4 weeks of reflections synthesised → patterns named → one commitment

---

Just type what you need. The agent knows your schedule, tools, and routing rules from `TOOLS.md`.
