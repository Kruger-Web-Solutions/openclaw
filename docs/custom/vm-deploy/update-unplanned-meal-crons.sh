#!/bin/bash
# Update cron prompts for unplanned meal pattern tracking and accountability escalation.
# Run once on the VM: bash /tmp/oc-unplanned-crons.sh

set -euo pipefail
export PATH=$HOME/.npm-global/bin:$HOME/.local/bin:$PATH

EOD_ID="95d0d97d-79bc-4dca-ac61-224e3ab99b34"
STATE_ID="5502aeae-34c7-40c3-8be4-106113558664"

echo "=== Updating EOD reconciliation cron ==="

openclaw cron edit "$EOD_ID" --message 'End-of-day check-in with Henzard. This is the most important cron of the day.

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

echo "  EOD updated"

echo "=== Updating state-of-me-report cron ==="

openclaw cron edit "$STATE_ID" --message 'Generate the weekly State of Me report. Gather: habitica dashboard (dailies streak, level, HP), sparky_fitness summary (avg calories, protein, water this week), todoist_tasks list for Nedbank and Weighsoft (count closed). Format: STATE OF ME — Week [N], [Date Range] ━━━━━━━━━━━━━━━━━━━ HABITICA: [X/Y] dailies | Level [X] | Streak: [X]d HEALTH: [macro summary] | Water: [avg]L/day WORK: Nedbank [X tasks] | Weighsoft [X tasks] FAITH: Bible days this week: [X/7] ━━━━━━━━━━━━━━━━━━━ FOCUS NEXT WEEK: [lowest area] ━━━━━━━━━━━━━━━━━━━ Your worth is not in these numbers. Jesus loves you regardless. Let us attack next week from a place of peace, not pressure.

After sending the main report, do the following unplanned eating audit:

STEP A — Count this week unplanned meals:
Read ~/.openclaw/workspace/MEMORY.md and find all lines under "## Unplanned Eating Log" with dates from the last 7 days. Count them. List the triggers if more than 2 entries.

STEP B — If count is 0 or 1: say nothing about unplanned eating. Skip to end.

STEP C — If count is 2: mention briefly: "Two off-plan meals this week — [triggers]. Watch that pattern next week."

STEP D — If count is 3 or more: issue a STERN WARNING. Do not soften it:
- State the count and the trigger pattern clearly.
- Say: "This is a pattern now, not a slip. It needs honest attention this week. Not shame — attention."
- Give ONE specific structural change for next week based on the triggers (e.g. "Afternoon snack planned before 14:00 would close this gap").
- Then append a new warning entry to ~/.openclaw/workspace/MEMORY.md using bash:
  echo "[date] | WARNING [N] issued | [count] unplanned meals | triggers: [summary]" >> ~/.openclaw/workspace/MEMORY.md
  where [N] is one more than the current count of lines containing "WARNING" under "## Accountability Warnings" section (create section if missing).

STEP E — Escalation check (only when a WARNING was just issued):
Read ~/.openclaw/workspace/MEMORY.md and count all lines containing "WARNING" in the "## Accountability Warnings" section. Also check if the last 2 WARNING entries show 3+ unplanned meals each (indicating no improvement across consecutive weeks).
If WARNING count is 3 or more AND last 2 weeks both showed 3+ unplanned meals:
1. Send Henzard a direct message first: "I have now issued 3 warnings about your eating pattern over consecutive weeks. I am notifying Alicia and Rhyno as we agreed. This is not punishment — it is the accountability system you asked for."
2. Send message to Alicia (get number from ~/.openclaw/secrets/contacts.env): "Hey Alicia, I need to flag something. Henzard has had 3+ unplanned meals per week for [N] consecutive weeks and is aware I am telling you. Not an emergency — but he could genuinely use an intentional check-in from you. He asked me to do this."
3. Send message to Rhyno (get number from contacts.env): "Hey Rhyno, Henzard asked me to flag when his eating pattern becomes a multi-week issue. Three warnings issued. He is aware. A direct question from you on your morning call would help more than anything I can do."
4. Append to MEMORY.md: "[date] | ESCALATED to Alicia and Rhyno | total warnings: [N]"

Do NOT edit TOOLS.md.'

echo "  State-of-me updated"
echo "=== Done ==="
