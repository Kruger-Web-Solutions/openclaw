#!/usr/bin/env bash
# Phase 9 cron updates — reflection tracking
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

FRIDAY_ID="32e8642a-9c40-4d56-abd0-7935c4a4dd2b"
STATE_OF_ME_ID="5502aeae-34c7-40c3-8be4-106113558664"

FRIDAY_MSG="It is Friday. Use todoist_tasks list for all projects to review unfinished tasks. Send a week summary: count of tasks closed this week across Nedbank, Weighsoft, Home, Books to Read. Then ask: What are 3 wins from this week? Then do a mission review: read ~/.openclaw/workspace/MEMORY.md under the Current Mission section. If a mission entry is present for this week, list the mission items and ask: Which of these did you complete this week? Reply with the numbers or all. After Henzard replies, update the mission entry in MEMORY.md marking completed items with [x] then append one debrief line: [date] | Week [N] mission closed: [X/Y] completed | [one-line insight]. If no Current Mission entry exists, skip this step silently. Then send this exact reflection prompt: Quick reflection - one line only: well: [what went well this week] | more: [what you should do more of] | stop: [what you should stop doing]. After Henzard replies, parse the three fields from his response. Append silently to ~/.openclaw/workspace/MEMORY.md under the Weekly Reflections section (create section if missing): YYYY-MM-DD | week [N] | well: [phrase] | more: [phrase] | stop: [phrase]. Do not echo or confirm the log. Just say: Logged. See you Sunday."

STATE_MSG="Generate the weekly State of Me report. Gather: habitica dashboard, sparky_fitness summary, todoist_tasks list for Nedbank and Weighsoft. Format: STATE OF ME - Week [N] | [Date Range] --- HABITICA: [X/Y] dailies | Level [X] | Streak: [X]d | HEALTH: [macro summary] | Water: [avg]L/day | WORK: Nedbank [X tasks] | Weighsoft [X tasks] | FAITH: Bible days this week: [X/7] --- FOCUS NEXT WEEK: [lowest area] --- Your worth is not in these numbers. Jesus loves you regardless. Let us attack next week from a place of peace, not pressure. STEP A: Count unplanned meals from MEMORY.md Unplanned Eating Log section for last 7 days. STEP B: If 0 or 1 say nothing, skip to STEP F. STEP C: If 2 mention briefly: Two off-plan meals this week - [triggers]. Watch that pattern next week. STEP D: If 3 or more issue STERN WARNING. State the count and trigger pattern clearly. Say: This is a pattern now, not a slip. It needs honest attention this week. Not shame - attention. Give ONE specific structural change for next week. Append to MEMORY.md Accountability Warnings section: [date] | WARNING [N] issued | [count] unplanned meals | triggers: [summary]. STEP E: Escalation check only when a WARNING was just issued. Count WARNING lines in Accountability Warnings section. If 3 or more AND last 2 entries show 3+ unplanned meals each: message Henzard that 3 warnings have been issued and Alicia and Rhyno are being notified as agreed. Message Alicia from contacts.env: Henzard has had 3+ unplanned meals per week for consecutive weeks, he is aware, an intentional check-in would help. Message Rhyno from contacts.env: Henzard asked for this flag, 3 warnings issued, he is aware, a direct question on the morning call would help more than anything I can do. Append to MEMORY.md: [date] | ESCALATED to Alicia and Rhyno | total warnings: [N]. Do NOT edit TOOLS.md. STEP F: After all audit steps, read MEMORY.md for this week's patterns: (1) Under Unplanned Eating Log - note trigger phrases from last 7 days. (2) Under Bible SWORD Log - find this week's D-actions. (3) Note FASTER flags if any were logged this week. (4) Under Weekly Reflections - find the most recent entry from this week's Friday. If present, use the 'more' field to inform the FAITH or EMOTIONAL mission item, and use the 'stop' field to inform the HEALTH or WORK mission item. Also use this report's data for weakest areas. Generate a proposed 7-Day Mission for all 4 areas. Format and send as: --- 7-DAY MISSION WEEK [N] --- OBJECTIVE: [one sentence - the single thing you are fighting this week] | FAITH: [ ] [action from SWORD D-action or default Complete Bible Time daily] | HEALTH: [ ] [action from weakest macro or eating trigger] and [ ] [second action if eating pattern detected] | WORK: [ ] [action from lowest Todoist project] | EMOTIONAL: [ ] [action from dominant FASTER flag or stop-reflection pattern] --- Reply mission confirmed to lock this in, or send your adjustments. Do NOT store the mission yet - wait for Henzard confirmation."

MONTHLY_MSG="It is the last Friday of the month. Do a monthly reflection close. Read ~/.openclaw/workspace/MEMORY.md under the Weekly Reflections section and collect all entries from the last 30 days. For each of the 3 fields (well, more, stop), identify which phrases appear 2 or more times - these are the patterns that matter. Format and send as: --- MONTH CLOSE - [Month Name] --- WHAT KEPT GOING WELL: [recurring well themes or top 1-2 from last 4 weeks] | WHAT YOU KEPT SAYING YOU WANT MORE OF: [recurring more themes] | WHAT YOU KEPT SAYING YOU SHOULD STOP: [recurring stop themes - these are signals that deserve a mission item] --- If a stop item appears 3 or more times, name it directly: [item] has come up [N] times. That is not a preference - that is a pattern that needs structural change. --- Then ask: One commitment for next month based on this? One sentence. After Henzard replies, append silently to ~/.openclaw/workspace/MEMORY.md under Monthly Reflections (create if missing): YYYY-MM | well-pattern: [phrase] | more-pattern: [phrase] | stop-pattern: [phrase] | commitment: [Henzard answer]."

echo "=== Updating friday-week-close ($FRIDAY_ID) ==="
openclaw cron edit "$FRIDAY_ID" --message "$FRIDAY_MSG"

echo "=== Updating state-of-me-report ($STATE_OF_ME_ID) ==="
openclaw cron edit "$STATE_OF_ME_ID" --message "$STATE_MSG"

echo "=== Adding monthly-reflection-close ==="
openclaw cron add \
  --name "monthly-reflection-close" \
  --cron "0 16 25-31 * 5" \
  --tz "Africa/Johannesburg" \
  --session isolated \
  --announce \
  --channel whatsapp \
  --to "+27711304241" \
  --message "$MONTHLY_MSG"

echo "=== Done ==="
openclaw cron list | grep -E "friday-week|state-of-me|monthly"
