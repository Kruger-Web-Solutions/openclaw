#!/usr/bin/env bash
# Phase 8 cron updates — uses UUIDs
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

MACRO_MOOD_ID="c0d11a26-9656-42fe-9aac-a22e34af42cd"
FRIDAY_ID="32e8642a-9c40-4d56-abd0-7935c4a4dd2b"
STATE_OF_ME_ID="5502aeae-34c7-40c3-8be4-106113558664"

MACRO_MSG="Midday FASTER check-in. First run sparky_fitness summary and show it. Then send this message exactly: FASTER check - circle what fits: F = Forgetting priorities | A = Anxiety/Avoidance | S = Speeding up | T = Ticked off | E = Exhausted | R = Relapse risk. Reply with letters e.g. A E or clear if none. After Henzard replies: if clear say Good. Keep the momentum. and stop. If 1 letter acknowledge briefly, ask one thing he can do RIGHT NOW to address it. If 2+ letters say: That is a cluster. Address [highest risk flag] first. Ask ONE question only. If R is flagged say: R means relapse risk is already active. Name the compromise. Let us close it now before it becomes a meal. If 3+ letters say: Full FASTER state. You are running hot. Before your next task - 5 minutes outside or 10 deep breaths. Not optional."

FRIDAY_MSG="It is Friday. Use todoist_tasks list for all projects to review unfinished tasks. Send a week summary: count of tasks closed this week across Nedbank, Weighsoft, Home, Books to Read. Then ask: What are 3 wins from this week? Then do a mission review: read ~/.openclaw/workspace/MEMORY.md under the Current Mission section. If a mission entry is present for this week, list the mission items and ask: Which of these did you complete this week? Reply with the numbers or all. After Henzard replies, update the mission entry in MEMORY.md marking completed items with [x] then append one debrief line: [date] | Week [N] mission closed: [X/Y] completed | [one-line insight]. If no Current Mission entry exists, skip this step silently."

STATE_MSG="Generate the weekly State of Me report. Gather: habitica dashboard, sparky_fitness summary, todoist_tasks list for Nedbank and Weighsoft. Format: STATE OF ME - Week [N] | [Date Range] --- HABITICA: [X/Y] dailies | Level [X] | Streak: [X]d | HEALTH: [macro summary] | Water: [avg]L/day | WORK: Nedbank [X tasks] | Weighsoft [X tasks] | FAITH: Bible days this week: [X/7] --- FOCUS NEXT WEEK: [lowest area] --- Your worth is not in these numbers. Jesus loves you regardless. Let us attack next week from a place of peace, not pressure. STEP A: Count unplanned meals from MEMORY.md Unplanned Eating Log section for last 7 days. STEP B: If 0 or 1 say nothing, skip to STEP F. STEP C: If 2 mention briefly: Two off-plan meals this week - [triggers]. Watch that pattern next week. STEP D: If 3 or more issue STERN WARNING. State the count and trigger pattern clearly. Say: This is a pattern now, not a slip. It needs honest attention this week. Not shame - attention. Give ONE specific structural change for next week. Append to MEMORY.md Accountability Warnings section: [date] | WARNING [N] issued | [count] unplanned meals | triggers: [summary]. STEP E: Escalation check only when a WARNING was just issued. Count WARNING lines in Accountability Warnings section. If 3 or more AND last 2 entries show 3+ unplanned meals each: message Henzard that 3 warnings have been issued and Alicia and Rhyno are being notified as agreed. Message Alicia from contacts.env that Henzard has had 3+ unplanned meals per week for consecutive weeks, he is aware, an intentional check-in would help. Message Rhyno from contacts.env that Henzard asked for this flag, 3 warnings issued, he is aware, a direct question on the morning call would help. Append to MEMORY.md: [date] | ESCALATED to Alicia and Rhyno | total warnings: [N]. Do NOT edit TOOLS.md. STEP F: After all audit steps, read MEMORY.md for this week: under Unplanned Eating Log note trigger phrases, under Bible SWORD Log find D-actions, note FASTER flags if logged. Also use this report data for weakest areas. Generate a proposed 7-Day Mission for all 4 areas. Format and send as: --- 7-DAY MISSION WEEK [N] --- OBJECTIVE: [one sentence - the single thing you are fighting this week] | FAITH: [ ] [action based on SWORD D-action or default Complete Bible Time daily] | HEALTH: [ ] [action based on weakest macro or eating trigger] and [ ] [second action if eating pattern detected] | WORK: [ ] [action based on lowest Todoist project] | EMOTIONAL: [ ] [action based on dominant FASTER flag] --- Reply mission confirmed to lock this in, or send your adjustments. Do NOT store the mission yet - wait for Henzard confirmation."

echo "=== Updating macro-mood-check ($MACRO_MOOD_ID) ==="
openclaw cron edit "$MACRO_MOOD_ID" --message "$MACRO_MSG"

echo "=== Updating friday-week-close ($FRIDAY_ID) ==="
openclaw cron edit "$FRIDAY_ID" --message "$FRIDAY_MSG"

echo "=== Updating state-of-me-report ($STATE_OF_ME_ID) ==="
openclaw cron edit "$STATE_OF_ME_ID" --message "$STATE_MSG"

echo "=== Done ==="
openclaw cron list | grep -E "macro-mood|friday-week|state-of-me"
