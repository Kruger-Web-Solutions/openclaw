# Agent Intelligence System (Phase 3)

> This document covers the cross-service chaining, coaching intelligence, macro estimation, and proactive anticipation layers added in Phase 3. These transform the agent from a tool dispatcher into an intelligent coach.

---

## Overview

Phase 2 shipped a working personal assistant with isolated tools. Phase 3 made it intelligent:

| Layer | What it does | Where it lives |
|---|---|---|
| Cross-Service Chaining | One input triggers ALL related services | TOOLS.md → "Cross-Service Chaining" section |
| Coaching Intelligence | AI interprets data, adapts reminders, celebrates wins | TOOLS.md → "Coaching Intelligence" section |
| Macro Estimation | AI estimates nutritional macros from food descriptions | health-coach skill → "Macro Estimation Protocol" |
| Proactive Anticipation | 6 crons that push context before it's asked for | TOOLS.md → "Proactive Anticipation" + `add-proactive-crons.sh` |

---

## Cross-Service Chaining

**Core principle:** Every user input that maps to a service should trigger ALL related services in one turn.

### Chain rules

| User reports | Primary action | Also do |
|---|---|---|
| "morning meds done" | Read medication skill | `habitica complete "Morning Vitamins & Supplements"` |
| "evening meds done" | Read medication skill | `habitica complete "Evening Vitamins & Supplements"` |
| Steps >= 7000 | Acknowledge | `habitica complete "7000 steps"` |
| Steps < 7000 | Encourage | Do NOT complete. Suggest a walk. |
| Food logged as dinner | `sparky_fitness log_food ... dinner` | `habitica complete "Dinner: Light & Easy Digest"` |
| Food logged as lunch | `sparky_fitness log_food ... lunch` | `habitica complete "Lunch Feast: GAPS Power Meal"` |
| "calming tea" (after 6pm) | `sparky_fitness log_food snack` | `habitica complete "Evening Wind-Down Tea"` |
| "water bottle done" | `sparky_fitness log_water 1200` | `habitica score_habit "Drink 3L of water"` |
| Coffee (3rd+) | `sparky_fitness log_food snack` | `habitica score_habit "Limit to 2 Cups" down` + nudge |
| Fermented foods | Acknowledge | `habitica score_habit "fermented foods daily ritual"` |
| ACV / apple cider vinegar | Acknowledge | `habitica score_habit "ACV pre-meal ritual"` |
| "morning routine done" | Multi-chain | Morning Vitamins + Bible Time + morning shake log |

### Time-of-day inference

- "meds done" before 12pm = morning meds
- "meds done" after 5pm = evening meds
- "tea" before 6pm = green tea (snack log only)
- "tea" after 6pm = calming tea (snack + Evening Wind-Down daily)
- Between 12-5pm for ambiguous inputs → ask the user

### Progress snapshot

After every chained action, append:
```
Done. Today: 5/8 dailies | 1750/5285ml water | 410/2710 cal
```
Generated from `habitica dashboard` + `sparky_fitness summary`.

---

## Coaching Intelligence

### After every food/water log

Interpret, don't just report:
- Calories < 30% of goal by 2pm → suggest specific GAPS-friendly food
- Protein specifically low → suggest collagen, eggs, bone broth
- On track → "Solid. Tracking well today."
- Water behind schedule → "Finish that bottle before your next task."
- All macros hit → "Macros locked in. Full marks."

### Micro-commitments (missed 3+ consecutive days)

Replace repeated reminders with smaller targets:
- 7000 steps missed 3 days → "What about 4000 today?"
- Workout missed 3 days → "5 minutes of stretching. Something beats nothing."
- Bible missed 3 days → "Even 5 minutes with one verse counts."

### Win celebration (proportional to effort)

- Single task completed → "Done."
- All dailies by 6pm → "All dailies before 6pm. That is rare discipline."
- 7-day streak → "That is a habit forming."
- 30-day streak → "This is not willpower anymore. This is who you are."

### Powerful questioning (replace instructions)

- 3+ dailies incomplete at end of day → "What got in the way today?"
- After a good day → "What made today work? Let's bottle that."
- Monday morning → "What is the ONE thing this week that would make everything else easier?"

### Reframing (never catalogue failure)

When user says "I failed" / "I'm useless" / "I can't do this":
1. Spiritual anchor first
2. Reframe: "You didn't fail. You showed up and told me."
3. One question: "What is one small win from today?"
4. Never list what went wrong

### Compound statement parsing

- "finished bottle 1 and almost done with 2" → log 1200ml + acknowledge bottle 2
- "had bone broth with spinach for dinner" → estimate macros, log food, complete dinner daily
- "morning routine done" → Morning Vitamins + Bible Time + morning shake

---

## Macro Estimation Protocol

**Problem:** SparkyFitness has no food database. It stores whatever you send. Zero macros = useless tracking.

**Solution:** The AI IS the food database.

### Steps

1. Parse the food description ("bone broth with spinach and an egg")
2. Estimate portion size in grams
3. Estimate calories, protein, carbs, fat
4. Call `sparky_fitness log_food "name" meal grams cal prot carbs fat`

**Rule: Never log food with 0/0/0/0 macros.**

### Common GAPS foods reference table

| Food | Grams | Cal | Protein | Carbs | Fat |
|---|---|---|---|---|---|
| Morning Shake (L-Glutamine + Collagen + Creatine) | 300 | 80 | 15 | 2 | 1 |
| Bone Broth (1 cup/250ml) | 250 | 40 | 9 | 0 | 0.5 |
| 2 Eggs (boiled/scrambled) | 100 | 155 | 13 | 1 | 11 |
| Coffee with milk | 250 | 25 | 2 | 3 | 1 |
| Black coffee | 250 | 5 | 0 | 0 | 0 |
| Green tea / Calming tea | 250 | 2 | 0 | 0 | 0 |
| Chicken breast (grilled, 150g) | 150 | 230 | 43 | 0 | 5 |
| Salmon fillet (150g) | 150 | 310 | 34 | 0 | 18 |
| Spinach (cooked, 100g) | 100 | 23 | 3 | 4 | 0.4 |
| Zucchini (cooked, 150g) | 150 | 25 | 2 | 5 | 0.5 |
| Sauerkraut (100g) | 100 | 19 | 1 | 4 | 0.1 |
| Kefir (250ml) | 250 | 100 | 6 | 8 | 5 |
| Avocado (half) | 70 | 115 | 1.5 | 6 | 10.5 |
| Sweet potato (medium, baked) | 150 | 130 | 2 | 30 | 0.2 |

For compound meals, add up individual components. When uncertain, estimate conservatively.

If description is too vague → ask: "What did you have? Even a rough description helps."

---

## Proactive Anticipation (6 crons)

These crons push context BEFORE it's needed. Key design principle: **silent when on track.**

| Cron | Schedule | Behavior |
|---|---|---|
| `pre-standup-weighsoft` | 7:25 Mon/Wed/Fri | Pull `wa_archive today Weighsoft` + `todoist_tasks list Weighsoft` → 3-line brief |
| `pre-standup-trade` | 9:25 weekdays | Pull `todoist_tasks list Nedbank` → compact summary before call |
| `macro-gap-coach` | 14:00 weekdays | If calories < 30% goal: nudge with GAPS food suggestion. On track: **silence** |
| `dinner-prep-nudge` | 17:00 weekdays | If dinner daily not done: suggest meal + "Family time starts." Done: **silence** |
| `steps-check` | 20:00 daily | If steps not done: "How many today?" Done: **silence** |
| `eod-reconciliation` | 21:15 daily | List all incomplete dailies. "Did you do [X]?" End with gratitude question |

Deploy script: `docs/custom/vm-deploy/add-proactive-crons.sh`

---

## Skills reference

| Skill | Key Phase 3 additions |
|---|---|
| `medication` | Mandatory cross-service completion, time-of-day inference |
| `health-coach` | Macro Estimation Protocol, after-log coaching, coffee tracking, fermented food/ACV scoring |
| `habitica-tasks` | `score_habit` command, streak celebration, pattern detection, win reinforcement |
| `exercise` | Unchanged |
| `spiritual` | Unchanged |

Skills are deployed to `~/.openclaw/workspace/skills/<name>/SKILL.md` on the VM. Repo copies in `docs/custom/vm-deploy/skills/`.

---

## `habitica score_habit` command

Added to `~/bin/habitica` for scoring habits up/down by name (fuzzy match):

```bash
habitica score_habit "water" up       # score positively
habitica score_habit "coffee" down    # score negatively
```

Used by cross-service chains for water bottles, fermented foods, ACV, coffee limit.

---

*~300 lines. Covers: cross-service chaining, coaching intelligence, macro estimation, proactive crons, skills, score_habit.*
