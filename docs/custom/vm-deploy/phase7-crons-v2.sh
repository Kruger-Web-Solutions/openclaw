#!/bin/bash
# Phase 7 v2: Create all personal-assistant cron jobs using openclaw CLI flags
# Run on the VM: bash /tmp/phase7-crons-v2.sh
# All times in Africa/Johannesburg (SAST = UTC+2)
#
# REQUIRES: ~/.openclaw/secrets/contacts.env
#   Copy docs/custom/vm-deploy/contacts.env.example to that path and fill in real numbers.

set -euo pipefail
source ~/.profile 2>/dev/null || true
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# ── Load phone numbers from secrets (never hardcoded) ────────
source ~/.openclaw/secrets/contacts.env 2>/dev/null || {
  echo "ERROR: ~/.openclaw/secrets/contacts.env not found."
  echo "Copy docs/custom/vm-deploy/contacts.env.example to ~/.openclaw/secrets/contacts.env and fill in real phone numbers."
  exit 1
}
: "${OWNER_WA:?OWNER_WA not set in contacts.env}"
: "${ALICIA_WA:?ALICIA_WA not set in contacts.env}"
: "${RHYNO_WA:?RHYNO_WA not set in contacts.env}"

TO="$OWNER_WA"
TZ_SAST="Africa/Johannesburg"

echo "=== Phase 7 v2: Creating personal-assistant cron jobs ==="

add() {
  echo "  Adding: $1"
  shift
  openclaw cron add "$@" 2>&1 | tail -1
}

# ── WEEKDAY CRONS (Mon-Fri) ───────────────────────────────────────────────────

add "morning-anchor" \
  --name "morning-anchor" --cron "0 5 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Check habitica dailies for today. Compose a morning anchor message: Start with: 'Good morning. Bible Day [N] — open YouVersion Chronological plan. Jesus is your source of peace today.' Then ask: 'Sleep quality 1-5? Reply with a number.' Use habitica tool for dailies."

add "water-bottle-1" \
  --name "water-bottle-1" --cron "0 6 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Compose a short morning message: 'Fill your 1.2L bottle — empty by 11am. Morning shake (L-Glutamine, Collagen, Creatine) and morning meds (TRIPLIXAM, Staminogro, Ultraflora, Vit C, CoQ10, Zinc, Vit A) at 6:30. Ready?' Then use sparky_fitness with action log_water if he replies yes. If not, just send the reminder."

add "daily-briefing" \
  --name "daily-briefing" --cron "30 6 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Generate the morning briefing for Henzard. Steps: 1. Use todoist_tasks list with label=in-progress to get VIP tasks. 2. Use habitica dashboard for dailies overview. 3. Use sparky_fitness goals for macro targets. Format this message: GOOD MORNING HENZARD — [Day] [Date] ━━━━━━━━━━━━━━━━━━━ YESTERDAY: [X/Y dailies] completed TODAY VIP TASKS (in-progress): [list up to 5] ━━━━━━━━━━━━━━━━━━━ SCHEDULE: [Mon=Weighsoft 7:30|Tue=Bot work|Wed=Weighsoft|Thu=Bot work|Fri=Weighsoft] FAITH: Bible Day [N] — open YouVersion Chronological HEALTH: Target [X]cal | [X]g protein today ━━━━━━━━━━━━━━━━━━━ Jesus is your source of peace — not productivity, not food, not any other thing."

add "weekly-intentions-monday" \
  --name "weekly-intentions-monday" --cron "35 6 * * 1" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "It is Monday. After the daily briefing send this: 'New week. What are your 3 intentions for this week, aligned with your 2026 goals? Reply and I will store them in MEMORY.md.'"

add "post-rhyno-call" \
  --name "post-rhyno-call" --cron "35 7 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Rhyno call should be done. Prompt: 'Rhyno call done — any action items? Reply and I will add them to Todoist with a due date.'"

add "post-standup-trade" \
  --name "post-standup-trade" --cron "35 9 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Trade standup should be done. Prompt: 'Trade standup done — any actions to log? Reply with the task and I will add it to Todoist.'"

add "post-nfpe-standup" \
  --name "post-nfpe-standup" --cron "5 10 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "NFPE standup should be done. Prompt: 'NFPE standup done — any actions to log?'"

add "post-ndm-standup" \
  --name "post-ndm-standup" --cron "35 10 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "NDM standup should be done. Prompt: 'NDM standup done — any actions to log?'"

add "water-check-1" \
  --name "water-check-1" --cron "45 10 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Bottle 1 check: 15 min to brunch. Remind Henzard: 'Almost empty? Finish it up. Brunch in 15 minutes.'"

add "brunch-reminder" \
  --name "brunch-reminder" --cron "0 11 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Use sparky_fitness with action summary to get today macro status. Then compose: 'Brunch time. Green tea. Fill Bottle 2. Log what you eat.' Then show current macro progress (calories and protein vs target)."

add "macro-mood-check" \
  --name "macro-mood-check" --cron "0 14 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Midday FASTER check-in. First run sparky_fitness summary and show it. Then send this message exactly: 'FASTER check — circle what fits: F = Forgetting priorities (something important slipped today) | A = Anxiety/Avoidance (putting something off) | S = Speeding up (rushing, reactive) | T = Ticked off (frustration building) | E = Exhausted (drained physically or emotionally) | R = Relapse risk (small compromise — 3rd coffee, skipped lunch, ignoring a task) | Reply with letters e.g. A E or clear if none.' After Henzard replies: if clear → say Good. Keep the momentum. and stop. If 1 letter → acknowledge it briefly, ask one thing he can do RIGHT NOW. If 2+ letters → say That is a cluster. Address [highest risk flag] first. Ask ONE question. If R is flagged → say R means relapse risk is already active. Name the compromise. Let's close it now before it becomes a meal. If 3+ letters → say Full FASTER state. You are running hot. Before your next task: 5 minutes outside or 10 deep breaths. Not optional."

add "water-check-2" \
  --name "water-check-2" --cron "45 15 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Bottle 2 check: 'Almost time to fill Bottle 3 at 4pm. Last call to empty Bottle 2.'"

add "day-reflection" \
  --name "day-reflection" --cron "0 16 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Use habitica dailies to show incomplete dailies count. Compose: 'Reflect time. What did you complete today? Any tasks to close? Fill Bottle 3.' Then show the incomplete daily count."

add "family-time" \
  --name "family-time" --cron "0 17 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Close of work day reminder: 'Close work apps. Family time starts now. Kealyn and Alicia are waiting. Work will still be there tomorrow.'"

add "dinner-water" \
  --name "dinner-water" --cron "0 18 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Use sparky_fitness with action summary for dinner-time macro check. Compose: 'Dinner time. Calming tea. Log your food. Fill Bottle 3.' Then show macro summary for the day."

add "exercise-reminder" \
  --name "exercise-reminder" --cron "0 19 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Exercise reminder: 'Exercise with Kealyn time — let us go! This is your daily win.'"

add "kealyn-bedtime" \
  --name "kealyn-bedtime" --cron "0 20 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Kealyn bedtime: 'Bath, story, prayer with Kealyn. This time is sacred. Work and screens can wait.'"

add "quiet-time" \
  --name "quiet-time" --cron "45 20 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Evening quiet time: '15 min for you. No screens. What are you grateful for today?'"

add "evening-meds" \
  --name "evening-meds" --cron "0 21 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Evening meds reminder: 'Evening meds: Mag Glycinate, Ashwagandha, Zinc, Vit D3+K2, Moringa. Log Bottle 3 if not done. Tomorrow is a new start.'"

add "sleep-prep" \
  --name "sleep-prep" --cron "45 21 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Sleep prep: '15 min to sleep. Screens off. One win from today — what was it?'"

# ── ACCOUNTABILITY AUDIT (Weekdays 18:30) ────────────────────────────────────

add "accountability-audit" \
  --name "accountability-audit" --cron "30 18 * * 1-5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Run accountability audit. Use habitica dailies to count incomplete dailies. Use wa_archive today to check last inbound message time from Henzard. If 3 or more dailies are incomplete AND no inbound message in last 3 hours: use the message tool (action: send, channel: whatsapp) to send to Alicia (see contacts.env for number): 'Hey Alicia, just a gentle nudge — Henzard might need some encouragement today. No pressure, just a heads-up.' And send to Rhyno (see contacts.env): 'Hey Rhyno, just a gentle nudge — Henzard might need some encouragement today. No pressure, just a heads-up.' Then summarize what action was taken."

# ── FRIDAY CRONS ─────────────────────────────────────────────────────────────

add "friday-week-close" \
  --name "friday-week-close" --cron "0 16 * * 5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "It is Friday. Use todoist_tasks list for all projects to review unfinished tasks. Send a week summary: count of tasks closed this week across Nedbank, Weighsoft, Home, Books to Read. Then ask: 'What are 3 wins from this week?' Then do a mission review: read ~/.openclaw/workspace/MEMORY.md under ## Current Mission. If a mission entry is present for this week, list the mission items and ask: 'Which of these did you complete this week? Reply with the numbers or all.' After Henzard replies, update the mission entry in MEMORY.md marking completed items with [x] then append one debrief line: [date] | Week [N] mission closed: [X/Y] completed | [one-line insight]. If no Current Mission entry exists, skip this step silently. Then send this exact reflection prompt: 'Quick reflection - one line only: well: [what went well this week] | more: [what you should do more of] | stop: [what you should stop doing]'. After Henzard replies, parse the three fields from his response. Append silently to ~/.openclaw/workspace/MEMORY.md under ## Weekly Reflections (create section if missing): YYYY-MM-DD | week [N] | well: [phrase] | more: [phrase] | stop: [phrase]. Do not echo or confirm the log. Just say: 'Logged. See you Sunday.'"

add "monthly-reflection-close" \
  --name "monthly-reflection-close" --cron "0 16 25-31 * 5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "It is the last Friday of the month. Do a monthly reflection close. Read ~/.openclaw/workspace/MEMORY.md under ## Weekly Reflections and collect all entries from the last 30 days. For each of the 3 fields (well, more, stop), identify which phrases appear 2 or more times - these are the patterns that matter. Format and send as: --- MONTH CLOSE - [Month Name] --- WHAT KEPT GOING WELL: [recurring well themes, or top 1-2 from the last 4 weeks] WHAT YOU KEPT SAYING YOU WANT MORE OF: [recurring more themes] WHAT YOU KEPT SAYING YOU SHOULD STOP: [recurring stop themes - these are the signals that deserve a mission item] --- PATTERN ALERT (only if a stop item appears 3+ times): Name it directly: [item] has come up [N] times. That is not a preference - that is a pattern that needs structural change. --- Then ask: 'One commitment for next month based on this? One sentence.' After Henzard replies, append to ~/.openclaw/workspace/MEMORY.md under ## Monthly Reflections (create if missing): YYYY-MM | well-pattern: [phrase] | more-pattern: [phrase] | stop-pattern: [phrase] | commitment: [Henzard answer]. Do this silently after logging."

add "nagmal" \
  --name "nagmal" --cron "0 18 * * 5" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Friday Nagmal: 'Nagmal time. Bless Alicia and Kealyn. Light a candle. Enter God is peace. Work is finished for the week. Rest now.'"

# ── WEEKEND CRONS ─────────────────────────────────────────────────────────────

add "saturday-anchor" \
  --name "saturday-anchor" --cron "0 8 * * 6" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Saturday morning: 'Good morning! Is Kealyn awake? 8:30am Afrikaans service or 10:10am English — your call. Enjoy God presence today.'"

add "saturday-shopping" \
  --name "saturday-shopping" --cron "30 9 * * 6" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Use todoist_tasks list to get the Shopping project tasks grouped by store section. Format as shopping list: 'Shopping list ready when you are:' then list items by store."

add "sunday-meal-prep" \
  --name "sunday-meal-prep" --cron "0 17 * * 0" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Sunday meal prep: 'Meal prep time. Plan this week meals. Check the Shopping project for anything you need. Preparing well on Sunday makes the week smooth.'"

add "state-of-me-report" \
  --name "state-of-me-report" --cron "0 20 * * 0" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Generate the weekly State of Me report. Gather: habitica dashboard (dailies streak, level, HP), sparky_fitness summary (avg calories, protein, water this week), todoist_tasks list for Nedbank and Weighsoft (count closed). Format: STATE OF ME — Week [N], [Date Range] ━━━━━━━━━━━━━━━━━━━ HABITICA: [X/Y] dailies | Level [X] | Streak: [X]d HEALTH: [macro summary] | Water: [avg]L/day WORK: Nedbank [X tasks] | Weighsoft [X tasks] FAITH: Bible days this week: [X/7] ━━━━━━━━━━━━━━━━━━━ FOCUS NEXT WEEK: [lowest area] ━━━━━━━━━━━━━━━━━━━ Your worth is not in these numbers. Jesus loves you regardless. Let us attack next week from a place of peace, not pressure. After sending the main report, do the following unplanned eating audit: STEP A — Count this week unplanned meals: Read ~/.openclaw/workspace/MEMORY.md and find all lines under '## Unplanned Eating Log' with dates from the last 7 days. Count them. List the triggers if more than 2 entries. STEP B — If count is 0 or 1: say nothing about unplanned eating. Skip to end. STEP C — If count is 2: mention briefly: 'Two off-plan meals this week — [triggers]. Watch that pattern next week.' STEP D — If count is 3 or more: issue a STERN WARNING. Do not soften it: State the count and trigger pattern clearly. Say: 'This is a pattern now, not a slip. It needs honest attention this week. Not shame — attention.' Give ONE specific structural change for next week. Then append a new warning entry to ~/.openclaw/workspace/MEMORY.md: echo '[date] | WARNING [N] issued | [count] unplanned meals | triggers: [summary]' >> ~/.openclaw/workspace/MEMORY.md where [N] is one more than current WARNING line count in '## Accountability Warnings' section (create section if missing). STEP E — Escalation check (only when a WARNING was just issued): Count all WARNING lines in '## Accountability Warnings' in MEMORY.md. If count is 3 or more AND last 2 WARNING entries show 3+ unplanned meals each: 1. Message Henzard: 'I have now issued 3 warnings about your eating pattern over consecutive weeks. I am notifying Alicia and Rhyno as we agreed. This is not punishment — it is the accountability system you asked for.' 2. Message Alicia (from ~/.openclaw/secrets/contacts.env): 'Hey Alicia, I need to flag something. Henzard has had 3+ unplanned meals per week for consecutive weeks and is aware I am telling you. Not an emergency — but he could genuinely use an intentional check-in from you. He asked me to do this.' 3. Message Rhyno (from contacts.env): 'Hey Rhyno, Henzard asked me to flag when his eating pattern becomes a multi-week issue. Three warnings issued. He is aware. A direct question from you on your morning call would help more than anything I can do.' 4. Append to MEMORY.md: '[date] | ESCALATED to Alicia and Rhyno | total warnings: [N]' Do NOT edit TOOLS.md. STEP F — Generate 7-Day Mission proposal: After all audit steps, read MEMORY.md for this week's patterns: (1) Under ## Unplanned Eating Log — note trigger phrases from the last 7 days. (2) Under ## Bible S.W.O.R.D. Log — find this week's D-actions. (3) Note FASTER flags if any were logged this week. (4) Under ## Weekly Reflections — find the most recent entry (this week's Friday reflection). If present, use the 'more' field to inform the FAITH or EMOTIONAL mission item, and use the 'stop' field to inform the HEALTH or WORK mission item. Also use the data already in this report (weakest Habitica area, lowest Todoist project, weakest macro). Generate a proposed 7-Day Mission covering all 4 areas. Format and send as: ━━━━━━━━━━━━━━━━━━━ 7-DAY MISSION WEEK [N] ━━━━━━━━━━━━━━━━━━━ OBJECTIVE: [one sentence - the single thing you are fighting this week] FAITH [ ] [action based on SWORD D-action or default Complete Bible Time daily] HEALTH [ ] [action based on weakest macro or eating trigger] [ ] [second action if eating pattern detected] WORK [ ] [action based on lowest Todoist project] EMOTIONAL [ ] [action based on dominant FASTER flag or pattern] ━━━━━━━━━━━━━━━━━━━ Reply mission confirmed to lock this in, or send your adjustments. Do NOT store the mission yet - wait for Henzard confirmation."

# ── SACRED CALENDAR — BIRTHDAYS ──────────────────────────────────────────────

add "alicia-bday-14days" \
  --name "alicia-bday-14days" --cron "0 8 29 5 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Alicia birthday is in 2 weeks (June 12). Reminder: 'Start planning. What would make her feel truly seen and celebrated?'"

add "alicia-bday-7days" \
  --name "alicia-bday-7days" --cron "0 8 5 6 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "One week to Alicia birthday (June 12): 'Is the plan ready? She deserves to feel truly celebrated.'"

add "alicia-bday-eve" \
  --name "alicia-bday-eve" --cron "0 8 11 6 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Tomorrow is Alicia birthday! 'Is everything prepared? She deserves to feel celebrated and deeply loved.'"

add "alicia-bday" \
  --name "alicia-bday" --cron "0 7 12 6 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Today is Alicia birthday! 'Make her feel like the most special person in your world. No work focus until 10am. Be fully present with her today.'"

add "kealyn-bday-14days" \
  --name "kealyn-bday-14days" --cron "0 8 18 7 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Kealyn birthday is in 2 weeks (August 1): 'Start planning. What adventure or special day would light up her world?'"

add "kealyn-bday-7days" \
  --name "kealyn-bday-7days" --cron "0 8 25 7 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "One week to Kealyn birthday (August 1): 'Is the plan ready? Kids remember birthdays forever.'"

add "kealyn-bday" \
  --name "kealyn-bday" --cron "0 7 1 8 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Today is Kealyn birthday! 'Be fully present with her today. No work focus until 10am. Make memories that last.'"

# ── SACRED CALENDAR — FEASTS 2026 ────────────────────────────────────────────

add "passover-7days" \
  --name "passover-7days" --cron "0 7 30 3 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "In 7 days: Passover begins at sundown (April 6). Read Leviticus 23:5. Remembrance of redemption — the Lamb."

add "passover-eve" \
  --name "passover-eve" --cron "0 17 6 4 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Passover begins at sundown tonight. Sundown to sundown. Scripture: Leviticus 23:5. Remembrance of redemption — the Lamb who was slain. No tradition, just what the text says."

add "unleavened-bread-7days" \
  --name "unleavened-bread-7days" --cron "0 7 31 3 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "In 7 days: Unleavened Bread begins (April 7, 7 days). Read Leviticus 23:6-8. Remove leaven. Reflect on sin and holiness."

add "firstfruits-7days" \
  --name "firstfruits-7days" --cron "0 7 11 4 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "In 7 days: Firstfruits (April 18). Read Leviticus 23:9-14. First of the harvest. New life."

add "firstfruits-eve" \
  --name "firstfruits-eve" --cron "0 17 18 4 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Firstfruits begins at sundown tonight. Scripture: Leviticus 23:9-14. The first of the harvest — new life. No tradition, just the plain text."

add "shavuot-7days" \
  --name "shavuot-7days" --cron "0 7 30 5 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "In 7 days: Feast of Weeks (Shavuot) begins (June 6). Read Leviticus 23:15-22. 50 days from Firstfruits. The giving of the Word and the Spirit."

add "trumpets-7days" \
  --name "trumpets-7days" --cron "0 7 15 9 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "In 7 days: Feast of Trumpets (Sept 22). Read Leviticus 23:23-25. The shofar. Awakening. Return."

add "yom-kippur-7days" \
  --name "yom-kippur-7days" --cron "0 7 24 9 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "In 7 days: Day of Atonement (Yom Kippur, Oct 1). Read Leviticus 23:26-32. The most solemn day. Fasting, afflicting the soul, rest."

add "yom-kippur-morning" \
  --name "yom-kippur-morning" --cron "0 6 1 10 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Today is Yom Kippur — the Day of Atonement. Leviticus 23:27 says: afflict your souls. This is a day of rest, reflection, and fasting. No task reminders today. No macro prompts. Rest in the presence of God."

add "tabernacles-7days" \
  --name "tabernacles-7days" --cron "0 7 29 9 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "In 7 days: Feast of Tabernacles (Sukkot) begins (Oct 6, 8 days). Read Leviticus 23:33-43. Dwell with God. Rejoice. Harvest completed."

add "tabernacles-eve" \
  --name "tabernacles-eve" --cron "0 17 6 10 *" --tz "$TZ_SAST" \
  --session isolated --announce --channel whatsapp --to "$TO" \
  --message "Feast of Tabernacles begins at sundown tonight. 8 days. Scripture: Leviticus 23:33-43. Dwell with God. Rejoice. Harvest completed. No tradition — just what the text says."

echo ""
echo "=== Phase 7 v2 complete ==="
echo "--- Verifying total cron count ---"
openclaw cron list 2>&1 | tail -5
