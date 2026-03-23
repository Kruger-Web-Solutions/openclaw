#!/bin/bash
# Phase 7: Create all cron jobs via openclaw CLI
# Run this on the VM: bash /tmp/phase7-crons.sh
# All crons use native OpenClaw tools only. None edit TOOLS.md.

set -euo pipefail
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

echo "=== Phase 7: Creating all cron jobs ==="

add_cron() {
    local json="$1"
    openclaw cron add --job "$json"
    echo "  Added: $(echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','?'))")"
}

# ── WEEKDAY CRONS (Mon-Fri) ────────────────────────────────────────────────────

add_cron '{
  "id": "morning-anchor",
  "schedule": "0 5 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: Check habitica dailies for today. Start with: '\''Good morning. Bible Day [N] — open YouVersion Chronological plan. Jesus is your source of peace today.'\'' Then ask: '\''Sleep quality 1-5? Reply with a number.'\'' Use habitica and whatsapp_send tools. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "water-bottle-1",
  "schedule": "0 6 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Fill your 1.2L bottle — empty by 11am. Morning shake and meds at 6:30. Use sparky_fitness log_water if he confirms.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "daily-briefing",
  "schedule": "30 6 * * 1-5",
  "enabled": true,
  "prompt": "Generate the morning briefing for Henzard. Steps:\n1. Use todoist_tasks list with label=in-progress to get VIP tasks from Todoist.\n2. Use habitica todos to get current Habitica todo list.\n3. For each Todoist in-progress task whose notes do NOT contain todoist:<task_id> in any Habitica todo: call habitica create_todo with title=[task content], notes=todoist:<task_id>, task_type=todo.\n4. For each Habitica todo whose notes contain todoist:<id> where that Todoist task is now closed: call habitica complete.\n5. Use habitica dashboard for dailies overview. Use sparky_fitness goals for macro targets.\n6. Format and send this message via whatsapp_send:\nGOOD MORNING HENZARD — [Day] [Date]\n━━━━━━━━━━━━━━━━━━━━━━━━━━\nYESTERDAY: [X/Y dailies] completed\nTODAY VIP TASKS (in-progress):\n  1. [task]\n  2. [task]\n  3. [task]\n━━━━━━━━━━━━━━━━━━━━━━━━━━\nSCHEDULE: [Mon=Weighsoft 7:30|Tue=Bot work|Wed=Weighsoft|Thu=Bot work|Fri=Weighsoft]\nFAITH: Bible Day [N] — open YouVersion Chronological\nHEALTH: Target [X]cal | [X]g protein today\n━━━━━━━━━━━━━━━━━━━━━━━━━━\nJesus is your source of peace — not productivity, not food, not any other thing.\n\nDo NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "weekly-intentions-monday",
  "schedule": "35 6 * * 1",
  "enabled": true,
  "prompt": "It is Monday. Send a WhatsApp message to Henzard after the daily briefing: '\''New week. What are your 3 intentions for this week, aligned with your 2026 goals? Reply and I will store them in MEMORY.md.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "post-rhyno-call",
  "schedule": "35 7 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Rhyno call done — any action items? Reply and I will add them to Todoist with a due date.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "post-standup-trade",
  "schedule": "35 9 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Trade standup done — any actions to log? Reply with the task and I will add it to Todoist.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "post-nfpe-standup",
  "schedule": "5 10 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''NFPE standup done — any actions to log?'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "post-ndm-standup",
  "schedule": "35 10 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''NDM standup done — any actions to log?'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "water-check-1",
  "schedule": "45 10 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Bottle 1 check: 15 min to brunch. Almost empty? Finish it up.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "brunch-reminder",
  "schedule": "0 11 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard. Use sparky_fitness summary to get today macro status. Include: '\''Brunch time. Green tea. Fill Bottle 2. Log what you eat — I am watching your macros.'\'' Then show current macro status. Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "macro-mood-check",
  "schedule": "0 14 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard. Use sparky_fitness summary to get macro progress. Include the summary then ask: '\''Energy 1-10? Stress 1-10? Reply: e7 s4'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "water-check-2",
  "schedule": "45 15 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Bottle 2 check: almost time to fill Bottle 3 at 4pm. Last call to empty Bottle 2.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "day-reflection",
  "schedule": "0 16 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard. Use habitica dailies to show incomplete dailies count. Include: '\''Reflect time. What did you complete today? Any tasks to close? Fill Bottle 3.'\'' Show incomplete daily count. Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "family-time",
  "schedule": "0 17 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Close work apps. Family time starts now. Kealyn and Alicia are waiting. Work will still be there tomorrow.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "dinner-water",
  "schedule": "0 18 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard. Use sparky_fitness summary for dinner-time macro check. Include: '\''Dinner time. Calming tea. Log your food. Fill Bottle 3.'\'' Show macro summary. Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "exercise-reminder",
  "schedule": "0 19 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Exercise with Kealyn time — let us go! This is your daily win.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "kealyn-bedtime",
  "schedule": "0 20 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Bath, story, prayer with Kealyn. This time is sacred. Work and screens can wait.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "quiet-time",
  "schedule": "45 20 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''15 min for you. No screens. What are you grateful for today?'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "evening-meds",
  "schedule": "0 21 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Evening meds: Mag Glycinate, Ashwagandha, Zinc, Vit D3+K2, Moringa. Log Bottle 3 if not done. Tomorrow is a new start.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "sleep-prep",
  "schedule": "45 21 * * 1-5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''15 min to sleep. Screens off. One win from today — what was it?'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# ── ACCOUNTABILITY AUDIT (Daily, 18:30 weekdays) ──────────────────────────────

add_cron '{
  "id": "accountability-audit",
  "schedule": "30 18 * * 1-5",
  "enabled": true,
  "prompt": "Run accountability audit. Use habitica dailies to count incomplete dailies. Use whatsapp_archive to check last inbound message from Henzard. If 3+ dailies are incomplete AND no inbound message in last 3 hours: send a gentle escalation to Alicia (ALICIA_WA from contacts.env) and Rhyno (RHYNO_WA from contacts.env) via whatsapp_send: 'Hey [name], just a gentle nudge — Henzard might need some encouragement today. No pressure, just a heads-up.' Do NOT escalate if it is weekend. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# ── FRIDAY CRONS ──────────────────────────────────────────────────────────────

add_cron '{
  "id": "friday-week-close",
  "schedule": "0 16 * * 5",
  "enabled": true,
  "prompt": "It is Friday. Use todoist_tasks list for all projects to review unfinished tasks. Send a WhatsApp message to Henzard with a week summary: count of tasks closed this week across Nedbank, Weighsoft, Home, Personal Growth. Then ask: '\''What are 3 wins from this week?'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "nagmal",
  "schedule": "0 18 * * 5",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Nagmal time. Bless Alicia and Kealyn. Light a candle. Enter God is peace. Work is finished for the week. Rest now.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# ── WEEKEND CRONS ─────────────────────────────────────────────────────────────

add_cron '{
  "id": "saturday-anchor",
  "schedule": "0 8 * * 6",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Good morning! Is Kealyn awake? 8:30am Afrikaans service or 10:10am English — your call. Enjoy God presence today.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "saturday-shopping",
  "schedule": "30 9 * * 6",
  "enabled": true,
  "prompt": "Use todoist_tasks list to get the Shopping project tasks grouped by store section. Send a WhatsApp message to Henzard with the shopping list: '\''Shopping list ready when you are:'\'' then list items by store. Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "sunday-meal-prep",
  "schedule": "0 17 * * 0",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Meal prep time. Plan this week meals. Check the Shopping project for anything you need. Preparing well on Sunday makes the week smooth.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

add_cron '{
  "id": "state-of-me-report",
  "schedule": "0 20 * * 0",
  "enabled": true,
  "prompt": "Generate the weekly State of Me report for Henzard. Gather data: habitica dashboard (dailies streak, level, HP), sparky_fitness summary (avg calories, protein, water this week if available), todoist_tasks list for Nedbank and Weighsoft (count closed tasks). Format:\nSTATE OF ME — Week [N], [Date Range]\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nHABITICA:  [X/Y] dailies completed | Level [X] | Streak: [X]d\nHEALTH:    [macro summary] | Water: [avg]L/day\nWORK:      Nedbank [X tasks] | Weighsoft [X tasks]\nFAITH:     Bible days this week: [X/7]\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nFOCUS NEXT WEEK: [lowest-performing area]\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nYour worth is not in these numbers. Jesus loves you regardless. Let us attack next week from a place of peace, not pressure.\n\nSend via whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# ── SACRED CALENDAR 2026 — BIRTHDAY PRE-ALERTS ────────────────────────────────

# Alicia's birthday (June 12) — 14 days before = May 29
add_cron '{
  "id": "alicia-bday-14days",
  "schedule": "0 8 29 5 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Alicia birthday is in 2 weeks (June 12). Start planning. What would make her feel truly seen and celebrated?'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Alicia's birthday — 7 days before = June 5
add_cron '{
  "id": "alicia-bday-7days",
  "schedule": "0 8 5 6 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''One week to Alicia birthday (June 12). Is the plan ready? She deserves to feel truly celebrated.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Alicia's birthday eve — June 11
add_cron '{
  "id": "alicia-bday-eve",
  "schedule": "0 8 11 6 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Tomorrow is Alicia birthday! Is everything prepared? She deserves to feel celebrated and deeply loved.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Alicia's birthday — June 12
add_cron '{
  "id": "alicia-bday",
  "schedule": "0 7 12 6 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Today is Alicia birthday! Make her feel like the most special person in your world. No work focus until 10am. Be fully present with her today.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Kealyn's birthday (August 1) — 14 days before = July 18
add_cron '{
  "id": "kealyn-bday-14days",
  "schedule": "0 8 18 7 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Kealyn birthday is in 2 weeks (August 1). Start planning. What adventure or special day would light up his world?'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Kealyn's birthday — 7 days before = July 25
add_cron '{
  "id": "kealyn-bday-7days",
  "schedule": "0 8 25 7 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''One week to Kealyn birthday (August 1). Is the plan ready? Kids remember birthdays forever.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Kealyn's birthday — August 1
add_cron '{
  "id": "kealyn-bday",
  "schedule": "0 7 1 8 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Today is Kealyn birthday! Be fully present with him today. No work focus until 10am. Make memories that last.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# ── SACRED CALENDAR 2026 — FEAST PRE-ALERTS (7 days before) ──────────────────

# Passover (April 6) — 7 days before = March 30
add_cron '{
  "id": "passover-7days",
  "schedule": "0 7 30 3 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''In 7 days: Passover begins at sundown (April 6). Read Leviticus 23:5. Remembrance of redemption — the Lamb.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Passover eve (evening of April 6)
add_cron '{
  "id": "passover-eve",
  "schedule": "0 17 6 4 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Passover begins at sundown tonight. Sundown to sundown. Scripture: Leviticus 23:5. Remembrance of redemption — the Lamb who was slain. No tradition, just what the text says.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Unleavened Bread — 7 days before = March 31
add_cron '{
  "id": "unleavened-bread-7days",
  "schedule": "0 7 31 3 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''In 7 days: Unleavened Bread begins (April 7, 7 days). Read Leviticus 23:6-8. Remove leaven. Reflect on sin and holiness.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Firstfruits — 7 days before = April 11
add_cron '{
  "id": "firstfruits-7days",
  "schedule": "0 7 11 4 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''In 7 days: Firstfruits (April 18). Read Leviticus 23:9-14. First of the harvest. New life.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Firstfruits eve (April 18)
add_cron '{
  "id": "firstfruits-eve",
  "schedule": "0 17 18 4 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Firstfruits begins at sundown tonight. Scripture: Leviticus 23:9-14. The first of the harvest — new life. No tradition, just the plain text.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Weeks/Shavuot — 7 days before = May 30
add_cron '{
  "id": "shavuot-7days",
  "schedule": "0 7 30 5 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''In 7 days: Feast of Weeks (Shavuot) begins (June 6). Read Leviticus 23:15-22. 50 days from Firstfruits. The giving of the Word and the Spirit.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Trumpets — 7 days before = September 15
add_cron '{
  "id": "trumpets-7days",
  "schedule": "0 7 15 9 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''In 7 days: Feast of Trumpets (Sept 22). Read Leviticus 23:23-25. The shofar. Awakening. Return.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Yom Kippur — 7 days before = September 24
add_cron '{
  "id": "yom-kippur-7days",
  "schedule": "0 7 24 9 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''In 7 days: Day of Atonement (Yom Kippur, Oct 1). Read Leviticus 23:26-32. The most solemn day. Fasting, afflicting the soul, rest.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Yom Kippur morning — October 1 (replaces all other crons today)
add_cron '{
  "id": "yom-kippur-morning",
  "schedule": "0 6 1 10 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Today is Yom Kippur — the Day of Atonement. Leviticus 23:27 says: afflict your souls. This is a day of rest, reflection, and fasting. No task reminders today. No macro prompts. Rest in the presence of God.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Tabernacles — 7 days before = September 29
add_cron '{
  "id": "tabernacles-7days",
  "schedule": "0 7 29 9 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''In 7 days: Feast of Tabernacles (Sukkot) begins (Oct 6, 8 days). Read Leviticus 23:33-43. Dwell with God. Rejoice. Harvest completed.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

# Tabernacles eve (October 6)
add_cron '{
  "id": "tabernacles-eve",
  "schedule": "0 17 6 10 *",
  "enabled": true,
  "prompt": "Send a WhatsApp message to Henzard: '\''Feast of Tabernacles begins at sundown tonight. 8 days. Scripture: Leviticus 23:33-43. Dwell with God. Rejoice. Harvest completed. No tradition — just what the text says.'\'' Use whatsapp_send. Do NOT edit TOOLS.md.",
  "delivery": {"channel": "whatsapp", "to": "default"}
}'

echo ""
echo "=== Phase 7 complete ==="
echo "Verifying cron count..."
openclaw cron list --include-disabled | python3 -c "
import json, sys
data = json.load(sys.stdin)
jobs = data if isinstance(data, list) else data.get('jobs', data.get('crons', []))
print(f'Total crons: {len(jobs)}')
for j in jobs:
    print(f'  {j.get(\"id\",\"?\")}: {j.get(\"schedule\",\"?\")} enabled={j.get(\"enabled\",True)}')
" 2>/dev/null || openclaw cron list
