#!/bin/bash
set -euo pipefail
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/bin:$PATH"

TZ_SAST="Africa/Johannesburg"

if [ -f "$HOME/.openclaw/secrets/contacts.env" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.openclaw/secrets/contacts.env"
fi
TO="${OWNER_WA:?OWNER_WA not set — source contacts.env or export it}"

echo "=== Adding 6 proactive intelligence crons ==="

# 1. Pre-Standup Prep — Weighsoft (Mon/Wed/Fri 7:25)
echo "  [1/6] pre-standup-weighsoft..."
openclaw cron add \
  --name "pre-standup-weighsoft" --cron "25 7 * * 1,3,5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message 'Weighsoft standup in 5 minutes. Prepare a brief for Henzard.

Steps:
1. Run: wa_archive today Weighsoft
2. Run: todoist_tasks list Weighsoft
3. Send a compact 3-line brief:
   - Group context: key topics from today WhatsApp messages (1-2 lines)
   - Open tasks: list Weighsoft tasks by name
   - Blockers: anything that looks stalled or overdue

Keep it under 5 lines. No fluff. Henzard needs this before the call starts.'

# 2. Pre-Standup Prep — Trade (daily 9:25)
echo "  [2/6] pre-standup-trade..."
openclaw cron add \
  --name "pre-standup-trade" --cron "25 9 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message 'Trade standup in 5 minutes. Prepare a brief for Henzard.

Steps:
1. Run: todoist_tasks list Nedbank
2. Send a compact summary:
   - Open Nedbank tasks by name
   - Any tasks with approaching due dates

Keep it under 5 lines. Quick context before the call.'

# 3. Macro Gap Coach (weekdays 14:00)
echo "  [3/6] macro-gap-coach..."
openclaw cron add \
  --name "macro-gap-coach" --cron "0 14 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message 'Run sparky_fitness summary to check macro progress at 2pm.

Rules:
- If calories are LESS than 30% of goal (under ~810 cal): send a nudge with a specific GAPS-friendly meal suggestion. Example: "You are at X/2710 cal. A bowl of bone broth with egg and spinach would be a solid lunch."
- If protein is specifically low (under 30g by 2pm): suggest collagen in a drink or eggs.
- If on track (over 30% calories): say NOTHING. Do not send a message. Silence means on track.
- If no food has been logged at all: "Nothing logged yet today. Even a quick note helps me track your macros."

Only send a message if there is a genuine gap. Do NOT annoy with unnecessary praise at 2pm.'

# 4. Dinner Prep Nudge (weekdays 17:00)
echo "  [4/6] dinner-prep-nudge..."
openclaw cron add \
  --name "dinner-prep-nudge" --cron "0 17 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message 'Check if Henzard has completed the Dinner daily on Habitica.

Steps:
1. Run habitica dashboard to check if "Dinner: Light & Easy Digest" is completed.
2. If NOT completed: send a gentle dinner reminder with a GAPS-friendly suggestion. Example: "Dinner time approaching. Tonight could be slow-cooked chicken with zucchini and bone broth. What sounds good?"
3. Also remind: "Work apps closing. Family time starts now."
4. If already completed: say nothing.

Do NOT send if dinner is already done.'

# 5. Steps Check (daily 20:00)
echo "  [5/6] steps-check..."
openclaw cron add \
  --name "steps-check" --cron "0 20 * * *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message 'Check if Henzard has completed the "7000 steps" daily on Habitica.

Steps:
1. Run habitica dashboard.
2. If "7000 steps" is NOT completed: ask "How many steps today? Even a short walk with Kealyn counts."
3. If already completed: say nothing.

Do NOT send if steps are already done.'

# 6. End-of-Day Reconciliation (daily 21:15)
echo "  [6/6] eod-reconciliation..."
openclaw cron add \
  --name "eod-reconciliation" --cron "15 21 * * *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message 'End-of-day check-in with Henzard. This is the most important cron of the day.

Steps:
1. Run habitica dashboard to get all incomplete dailies.
2. Read ~/.openclaw/workspace/MEMORY.md and check for any lines under "## Unplanned Eating Log" that start with today'"'"'s date (YYYY-MM-DD format, use actual current date in SAST). If found, note what was logged.
3. List each incomplete daily by name and ask: "Did you do [X]? Say done with [X] or I will leave it."
4. If there is an unplanned meal entry for today: add this as a direct question — no shame, no lecture: "You logged [food] off-plan today. What one thing would have prevented it?" One question only. Wait for the answer.
5. After the list, end with: "One thing you are grateful for today?"

Rules:
- Keep it direct, not soft.
- Do not shame for incomplete items or off-plan eating.
- This check-in creates accountability. Knowing it happens changes behavior all day.
- If ALL dailies complete and no unplanned meal today: "All dailies done. Clean eating day. Well played. One thing you are grateful for?"
- Do NOT edit TOOLS.md.'

echo ""
echo "=== All 6 proactive crons added ==="
