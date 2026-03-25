#!/usr/bin/env bash
# Phase 10 cron updates — weight tracking + NSV
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

FRIDAY_ID="32e8642a-9c40-4d56-abd0-7935c4a4dd2b"
STATE_OF_ME_ID="5502aeae-34c7-40c3-8be4-106113558664"
MONTHLY_ID="d177c9a0-22de-4f87-be72-8bdd93eb1a1c"

FRIDAY_MSG="It is Friday. Use todoist_tasks list for all projects to review unfinished tasks. Send a week summary: count of tasks closed this week across Nedbank, Weighsoft, Home, Books to Read. Then ask: What are 3 wins from this week? Then do a mission review: read ~/.openclaw/workspace/MEMORY.md under the Current Mission section. If a mission entry is present for this week, list the mission items and ask: Which of these did you complete this week? Reply with the numbers or all. After Henzard replies, update the mission entry in MEMORY.md marking completed items with [x] then append one debrief line: [date] | Week [N] mission closed: [X/Y] completed | [one-line insight]. If no Current Mission entry exists, skip this step silently. Then send this exact reflection prompt: Quick reflection - one line only: well: [what went well this week] | more: [what you should do more of] | stop: [what you should stop doing]. After Henzard replies, parse the three fields from his response. Append silently to ~/.openclaw/workspace/MEMORY.md under the Weekly Reflections section (create section if missing): YYYY-MM-DD | week [N] | well: [phrase] | more: [phrase] | stop: [phrase]. Do not echo or confirm the log. Just say: Logged. See you Sunday."

STATE_MSG="Generate the weekly State of Me report. Gather: habitica dashboard, sparky_fitness summary, todoist_tasks list for Nedbank and Weighsoft. Also read ~/.openclaw/workspace/MEMORY.md under Weight Log for this week's Monday entry and the health-coach skill for the monthly milestone table. Format: STATE OF ME - Week [N] | [Date Range] --- WEIGHT: [current]kg | Target this month: [milestone]kg | This week: [+/-delta]kg | Status: [on-track/behind/ahead] | HABITICA: [X/Y] dailies | Level [X] | Streak: [X]d | HEALTH: [macro summary] | Water: [avg]L/day | WORK: Nedbank [X tasks] | Weighsoft [X tasks] | FAITH: Bible days this week: [X/7] --- FOCUS NEXT WEEK: [lowest area] --- Your worth is not in these numbers. Jesus loves you regardless. Let us attack next week from a place of peace, not pressure. WEIGHT CHECK: If the last 2 or more Weight Log entries show zero change or increase, load the health-coach skill Plateau Protocol and follow it. If average daily calories from sparky_fitness exceeded the macro target this week AND weight status is behind, name it: Calories averaged [X] vs [target] goal and weight is [X]kg behind pace. The deficit is not there. Ask which meal is the biggest overshoot. After the main report and weight check, do the unplanned eating audit: STEP A: Count unplanned meals from MEMORY.md Unplanned Eating Log section for last 7 days. STEP B: If 0 or 1 say nothing, skip to STEP F. STEP C: If 2 mention briefly: Two off-plan meals this week - [triggers]. Watch that pattern next week. STEP D: If 3 or more issue STERN WARNING. State the count and trigger pattern clearly. Say: This is a pattern now, not a slip. It needs honest attention this week. Not shame - attention. Give ONE specific structural change for next week. Append to MEMORY.md Accountability Warnings section: [date] | WARNING [N] issued | [count] unplanned meals | triggers: [summary]. STEP E: Escalation check only when a WARNING was just issued. Count WARNING lines in Accountability Warnings section. If 3 or more AND last 2 entries show 3+ unplanned meals each: message Henzard that 3 warnings have been issued and Alicia and Rhyno are being notified. Message Alicia from contacts.env and Rhyno from contacts.env per the existing escalation protocol. Append to MEMORY.md: [date] | ESCALATED to Alicia and Rhyno | total warnings: [N]. Do NOT edit TOOLS.md. STEP F: After all audit steps, read MEMORY.md for this week's patterns: under Unplanned Eating Log note trigger phrases, under Bible SWORD Log find D-actions, note FASTER flags, under Weekly Reflections find the most recent entry from this week's Friday - use more field to inform FAITH or EMOTIONAL mission item and stop field to inform HEALTH or WORK mission item. Generate a proposed 7-Day Mission for all 4 areas. Format and send as: --- 7-DAY MISSION WEEK [N] --- OBJECTIVE: [one sentence] | FAITH: [ ] [action] | HEALTH: [ ] [action] and [ ] [second action if eating pattern] | WORK: [ ] [action] | EMOTIONAL: [ ] [action] --- Reply mission confirmed to lock this in, or send your adjustments. Do NOT store yet."

MONTHLY_MSG="It is the last Friday of the month. Do a monthly reflection close. Read ~/.openclaw/workspace/MEMORY.md under the Weekly Reflections section and collect all entries from the last 30 days. For each of the 3 fields - well, more, stop - identify which phrases appear 2 or more times. These are the patterns that matter. Format and send as: --- MONTH CLOSE - [Month Name] --- WHAT KEPT GOING WELL: [recurring well themes or top 1-2 from last 4 weeks] | WHAT YOU KEPT SAYING YOU WANT MORE OF: [recurring more themes] | WHAT YOU KEPT SAYING YOU SHOULD STOP: [recurring stop themes] --- If a stop item appears 3 or more times, name it directly: [item] has come up [N] times. That is not a preference - that is a pattern that needs structural change. --- Then ask: One commitment for next month based on this? One sentence. After Henzard replies, log the commitment. Then also read Weight Log in MEMORY.md and show the monthly weight trend: starting weight this month, current weight, monthly target, and total lost since March 2026 at 155kg. Then ask: Non-scale victory - what changed this month that the scale does not show? Energy, clothes, sleep, mood, strength - anything. After Henzard replies, append to MEMORY.md under Monthly Reflections: YYYY-MM | well-pattern: [phrase] | more-pattern: [phrase] | stop-pattern: [phrase] | commitment: [answer]. Also append to NSV Log: YYYY-MM | [NSV answer]. Do this silently."

WEIGHIN_MSG="Monday weigh-in. Step on the scale before eating. Reply: I weigh X. After Henzard replies, log via sparky_fitness weight [X]. Then load the health-coach skill and read the Weight Goal section. Calculate: current weight vs this month's milestone target. Calculate weekly delta from last Monday's weight in MEMORY.md under the Weight Log section. Respond per the Weight Response Rules in the skill. Then append silently to ~/.openclaw/workspace/MEMORY.md under Weight Log section - create if missing: YYYY-MM-DD | [X]kg | target: [monthly target]kg | delta: [+/- from last week]kg | status: [on-track/behind/ahead]. Do not announce the log."

MIDWEEK_MSG="Mid-week weight check. Read ~/.openclaw/workspace/MEMORY.md under Weight Log. Find the most recent Monday entry. If no entry exists for this Monday, send: No weigh-in logged this week. Step on the scale tomorrow morning and reply: I weigh X. If an entry exists, check the status field. If status is behind, load the health-coach skill and read the Weight Goal section. Suggest ONE structural fix from the skill. If status is on-track or ahead, say nothing - do not send this message at all."

echo "=== Updating friday-week-close ($FRIDAY_ID) ==="
openclaw cron edit "$FRIDAY_ID" --message "$FRIDAY_MSG"

echo "=== Updating state-of-me-report ($STATE_OF_ME_ID) ==="
openclaw cron edit "$STATE_OF_ME_ID" --message "$STATE_MSG"

echo "=== Updating monthly-reflection-close ($MONTHLY_ID) ==="
openclaw cron edit "$MONTHLY_ID" --message "$MONTHLY_MSG"

echo "=== Adding monday-weigh-in ==="
openclaw cron add \
  --name "monday-weigh-in" \
  --cron "45 5 * * 1" \
  --tz "Africa/Johannesburg" \
  --session isolated \
  --announce \
  --channel whatsapp \
  --to "+27711304241" \
  --message "$WEIGHIN_MSG"

echo "=== Adding wednesday-weight-nudge ==="
openclaw cron add \
  --name "wednesday-weight-nudge" \
  --cron "0 14 * * 3" \
  --tz "Africa/Johannesburg" \
  --session isolated \
  --announce \
  --channel whatsapp \
  --to "+27711304241" \
  --message "$MIDWEEK_MSG"

echo "=== Done ==="
openclaw cron list | grep -E "weigh-in|weight-nudge|friday-week|state-of-me|monthly"
