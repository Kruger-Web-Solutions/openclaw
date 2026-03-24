---
name: habitica-tasks
description: Habitica and Todoist task management, completion tracking, VIP sync, shopping lists, and project routing. Use when Henzard asks about tasks, todos, dailies, habits, says "done with X", "what's outstanding", "buy X", "add to shopping", or any task/project management query.
---

# Task Management

## Habitica Commands (exec via `~/bin/habitica`)

```
habitica dashboard              # stats + due dailies + todos + habits
habitica dailies                # all dailies with streak and notes
habitica habits                 # all habits
habitica todos                  # incomplete todos with due dates
habitica complete "Task Name"   # complete by title (fuzzy match)
habitica create_todo "Title"    # create new todo
```

Output includes `notes` after a `—` separator. Notes contain actual detail (supplement names, exercise lists, scripture). **Always read the real notes. Never make up content.**

## Todoist Commands (exec via `~/bin/todoist_tasks`)

```
todoist_tasks list                      # all active tasks
todoist_tasks list Nedbank              # filter by project name
todoist_tasks list --label in-progress  # VIP tasks
todoist_tasks create "Task" Weighsoft   # create in project
todoist_tasks close "Task fragment"     # close by name match
todoist_tasks grocery "Item Store"      # add to Shopping project
```

## Project Routing

| User says | Project | Command |
|-----------|---------|---------|
| "buy X" / "add X to shopping" | Shopping | `todoist_tasks grocery "X"` |
| "X for home" | Home | `todoist_tasks create "X" Home` |
| "X for Weighsoft" | Weighsoft | `todoist_tasks create "X" Weighsoft` |
| "X for Nedbank" | Nedbank | `todoist_tasks create "X" Nedbank` |
| "book: X" / "read: X" | Books to Read | `todoist_tasks create "X" Books` |

## VIP Sync (Todoist ↔ Habitica)

When user says "starting X" or "in progress: X":
1. `todoist_tasks create "X" [project]` with label `in-progress`
2. `habitica create_todo "X"` (mirror to Habitica)

When user says "done with X":
1. `habitica complete "X"`
2. `todoist_tasks close "X"`

## "What's my plan?" Response Pattern

Run both:
1. `habitica dashboard` — shows due dailies, incomplete todos, habits
2. `todoist_tasks list --label in-progress` — shows VIP tasks

Combine into a single clean response.

## Habitica Habits (exec via `~/bin/habitica`)

```
habitica score_habit "Habit Name"        # score a habit UP (positive)
habitica score_habit "Habit Name" down   # score a habit DOWN (negative)
```

Current habits: "fermented foods daily ritual", "ACV pre-meal ritual", "Drink 3L of water", "Limit to 2 Cups of Coffee"

## Streak Celebration

When reporting dailies or dashboard, check streaks and celebrate milestones:
- 7-day streak: "7-day streak on [X]. That is a habit forming."
- 14-day streak: "Two weeks straight. Momentum is building."
- 30-day streak: "30 days of [X]. This is not willpower anymore. This is who you are."
- Any daily with streak 0 after being > 7: "Streak broke on [X]. No shame. Start again today."

## Pattern Detection

When showing the dashboard or during end-of-day reconciliation:
- If a specific daily has been missed 3+ consecutive days, suggest a micro-commitment:
  - "7000 steps has been tough this week. What about 4000 today?"
  - "Workout missed 3 days. Even 5 minutes of stretching counts."
- If ALL dailies are completed: "All dailies done. Rare discipline. Well done."

## Win Reinforcement

After completing a task, reinforce proportionally:
- Single task: quick acknowledgment ("Done.")
- Multiple in one go: "3 for 3. Strong."
- All dailies by 6pm: "All dailies before 6pm. That is rare discipline."

## Response Rules

- **Never show UUIDs or IDs.** Always use the task name.
- Format as numbered/bulleted lists with task names only.
- Completion prompts: "Say 'done with [task name]' to complete."
- Lead with the answer. Don't narrate which tools you called.
- After every completion, show progress snapshot: "Done. Today: X/Y dailies complete."
