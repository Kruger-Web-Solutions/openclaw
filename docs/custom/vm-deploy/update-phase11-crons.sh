#!/usr/bin/env bash
# Phase 11 cron updates — monthly 48h fast with Giel
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

FAST_PREP_MSG="Check if this is a fast prep week. Load the health-coach skill and read the Monthly 48-Hour Fast section schedule. If this Friday is a scheduled fast date, follow the Prep Week Protocol: send the prep message to Henzard AND send a separate message to Giel using the message tool with channel whatsapp and to the GIEL_NUMBER from ~/.openclaw/secrets/contacts.env. If this Friday is NOT a scheduled fast date, say nothing - do not send any message at all."

FAST_START_MSG="Check if tonight is a scheduled fast start. Load the health-coach skill and read the Monthly 48-Hour Fast section schedule. If today is a scheduled fast Friday, follow the Friday Fast Start protocol: send the reminder to Henzard AND send a separate message to Giel using the message tool with channel whatsapp and to the GIEL_NUMBER from ~/.openclaw/secrets/contacts.env. If today is NOT a scheduled fast Friday, say nothing - do not send any message at all."

FAST_END_MSG="Check if today is a scheduled fast end. Load the health-coach skill and read the Monthly 48-Hour Fast section schedule. If today is the Sunday of a scheduled fast weekend, follow the Sunday Break-Fast protocol: send the break-fast message to Henzard. Log to MEMORY.md under Fast Log as instructed in the skill. If today is NOT a scheduled fast Sunday, say nothing - do not send any message at all."

echo "=== Adding fast-prep-monday ==="
openclaw cron add \
  --name "fast-prep-monday" \
  --cron "30 6 * * 1" \
  --tz "Africa/Johannesburg" \
  --session isolated \
  --announce \
  --channel whatsapp \
  --to "+27711304241" \
  --message "$FAST_PREP_MSG"

echo "=== Adding fast-start-friday ==="
openclaw cron add \
  --name "fast-start-friday" \
  --cron "0 17 * * 5" \
  --tz "Africa/Johannesburg" \
  --session isolated \
  --announce \
  --channel whatsapp \
  --to "+27711304241" \
  --message "$FAST_START_MSG"

echo "=== Adding fast-end-sunday ==="
openclaw cron add \
  --name "fast-end-sunday" \
  --cron "0 18 * * 0" \
  --tz "Africa/Johannesburg" \
  --session isolated \
  --announce \
  --channel whatsapp \
  --to "+27711304241" \
  --message "$FAST_END_MSG"

echo "=== Done ==="
openclaw cron list | grep -E "fast-"
