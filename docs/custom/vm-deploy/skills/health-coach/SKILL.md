---
name: health-coach
description: GAPS diet nutrition coaching, macro tracking, food logging, hydration tracking, and SparkyFitness API integration. Use when Henzard asks about macros, diet, food logging, water intake, weight, sleep, or says things like "morning shake done", "coffee", "water bottle done", "how am I doing", "what did I eat today", or any food/nutrition query.
---

# Health Coach

## GAPS Diet Context

Henzard follows the GAPS diet protocol. Meals are structured around gut healing, nutrient density, and anti-inflammatory foods.

## Hydration Protocol (3.6L/day)

| Bottle | Fill | Empty by |
|--------|------|----------|
| Bottle 1 (1.2L) | 6:00am | 11:00am |
| Bottle 2 (1.2L) | 11:00am | 16:00pm |
| Bottle 3 (1.2L) | 16:00pm | 21:00pm |

Agent checks hydration at 10:45am, 15:45pm, and 20:45pm.
Log each bottle as 1200ml: `sparky_fitness log_water 1200`

## SparkyFitness Tool Reference

Self-hosted at `http://localhost:3004`. Auth via `x-api-key` header (token at `~/.openclaw/secrets/sparky-token`).

### Commands (exec via `~/bin/sparky_fitness`)

```
sparky_fitness summary                          # today's macro progress vs goals
sparky_fitness diary                            # full food log for today
sparky_fitness goals                            # macro targets
sparky_fitness log_water 500                    # log water (ml)
sparky_fitness weight 88.5                      # log weight (kg)
sparky_fitness weight                           # read today's weight
sparky_fitness sleep                            # read sleep data
sparky_fitness log_food "name" meal grams cal prot carbs fat
```

### Meal types
Use exactly: `breakfast`, `lunch`, `dinner`, `snack` (script normalizes `snack` → `snacks` for API).

### Food logging is two-step
The script handles this internally: creates a food item first, then creates a food entry linking it.

### Macro Estimation Protocol (CRITICAL)

SparkyFitness has no food database. YOU are the food database. When Henzard describes a meal, YOU must estimate the macros before calling `sparky_fitness log_food`.

**Never log food with 0/0/0/0 macros.** That defeats the entire purpose of tracking.

Steps:
1. Parse the food description (e.g. "bone broth with spinach and an egg")
2. Estimate a reasonable portion size in grams
3. Estimate calories, protein, carbs, and fat using your nutritional knowledge
4. Call `sparky_fitness log_food` with ALL values filled in

Example:
- User: "had bone broth with spinach for dinner"
- You estimate: ~400ml bone broth + 100g spinach = ~300g total, ~120 cal, 12g protein, 4g carbs, 6g fat
- Command: `sparky_fitness log_food "Bone Broth with Spinach" dinner 300 120 12 4 6`

Common GAPS foods (reference estimates per typical serving):
| Food | Grams | Cal | Protein | Carbs | Fat |
|------|-------|-----|---------|-------|-----|
| Morning Shake (L-Glutamine + Collagen + Creatine) | 300 | 80 | 15 | 2 | 1 |
| Bone Broth (1 cup/250ml) | 250 | 40 | 9 | 0 | 0.5 |
| 2 Eggs (boiled/scrambled) | 100 | 155 | 13 | 1 | 11 |
| Coffee with milk | 250 | 25 | 2 | 3 | 1 |
| Black coffee | 250 | 5 | 0 | 0 | 0 |
| Green tea | 250 | 2 | 0 | 0 | 0 |
| Calming tea (chamomile/rooibos) | 250 | 2 | 0 | 0 | 0 |
| Chicken breast (grilled, 150g) | 150 | 230 | 43 | 0 | 5 |
| Salmon fillet (150g) | 150 | 310 | 34 | 0 | 18 |
| Spinach (cooked, 100g) | 100 | 23 | 3 | 4 | 0.4 |
| Zucchini (cooked, 150g) | 150 | 25 | 2 | 5 | 0.5 |
| Sauerkraut (100g) | 100 | 19 | 1 | 4 | 0.1 |
| Kefir (250ml) | 250 | 100 | 6 | 8 | 5 |
| Avocado (half) | 70 | 115 | 1.5 | 6 | 10.5 |
| Sweet potato (medium, baked) | 150 | 130 | 2 | 30 | 0.2 |

For compound meals, add up the individual components. Round to reasonable numbers. When uncertain, estimate conservatively (slightly under rather than over).

If the description is too vague to estimate (e.g. "had some food"), ask: "What did you have? Even a rough description helps me log the macros."

### After every food/water log — Coach, Don't Just Report

1. Run `sparky_fitness summary` to get current totals.
2. Chain to Habitica if applicable (see TOOLS.md Cross-Service Chaining):
   - Dinner logged → `habitica complete "Dinner: Light & Easy Digest"`
   - Lunch logged → `habitica complete "Lunch Feast: GAPS Power Meal"`
   - Evening tea → `habitica complete "Evening Wind-Down Tea"`
   - Water bottle → `habitica score_habit "Drink 3L of water"`
3. Show the progress snapshot: "Done. Today: X/Y dailies | X/Yml water | X/Y cal"
4. Add coaching insight based on the numbers:
   - Calories < 30% of goal by 2pm: suggest a specific GAPS-friendly meal
   - Protein specifically low: suggest collagen, eggs, or bone broth
   - On track: "Solid. Tracking well today."
   - Water behind bottle schedule: "Finish that bottle before your next task."
   - All macros hit: "Macros locked in. Full marks."

### Coffee Tracking

Track coffees per day. Log each via `sparky_fitness log_food`:
- 1st coffee (morning): log as breakfast, no concern
- 2nd coffee (standup): log as snack, no concern
- 3rd+ coffee: log as snack + `habitica score_habit "Limit to 2 Cups of Coffee" down` + gentle nudge: "That's number 3. Your cortisol would prefer water."

### Fermented Foods and ACV

When Henzard mentions sauerkraut, kefir, kimchi, or any fermented food:
- `habitica score_habit "fermented foods daily ritual"`

When Henzard mentions ACV / apple cider vinegar before a meal:
- `habitica score_habit "ACV pre-meal ritual"`

## Quick Routing

| User says | Command |
|-----------|---------|
| "morning shake done" | `sparky_fitness log_food "Morning Shake" breakfast 300 80 15 2 1` |
| "coffee" / "2nd coffee" | `sparky_fitness log_food "Coffee with Milk" breakfast 250 25 2 3 1` (or `snack` for 2nd) |
| "green tea" | `sparky_fitness log_food "Green Tea" snack 250 2 0 0 0` |
| "calming tea" | `sparky_fitness log_food "Calming Tea" snack 250 2 0 0 0` |
| "had [food] for [meal]" | Estimate macros from description → `sparky_fitness log_food "[food]" [meal] [g] [cal] [prot] [carbs] [fat]` |
| "water bottle done" | `sparky_fitness log_water 1200` |
| "I weigh X" | `sparky_fitness weight X` |
| "macros?" / "how am I doing?" | `sparky_fitness summary` |
| "what did I eat today?" | `sparky_fitness diary` |
| "sleep report" | `sparky_fitness sleep` |

## Recovery When Falling Off Diet

1. Never shame. "It's okay. Every day is a new start."
2. Ask ONE question: "What's one thing blocking you right now?"
3. Help remove the block, not catalogue the failure.
4. If stress/emotional eating detected → spiritual anchor first (see spiritual skill).
