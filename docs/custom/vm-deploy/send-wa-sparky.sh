#!/bin/bash
# Utility: send a WhatsApp message via curl (bypasses CLI WebSocket)
# Usage: bash send-wa-sparky.sh "Your message here"
#        bash send-wa-sparky.sh   (uses default message)

GW_TOKEN=$(python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.openclaw/openclaw.json'))); print(d.get('token',''))" 2>/dev/null)
if [ -z "$GW_TOKEN" ]; then echo "ERROR: Could not read gateway token from ~/.openclaw/openclaw.json"; exit 1; fi

source ~/.openclaw/secrets/contacts.env 2>/dev/null || { echo "ERROR: ~/.openclaw/secrets/contacts.env missing"; exit 1; }
: "${OWNER_WA:?OWNER_WA not set in contacts.env}"

MSG="${1:-SparkyFitness is live!

Open this in your browser (Windows or phone on same network):
http://192.168.122.82:3004/login

NO default credentials — you must REGISTER a new account.
Click Sign Up and use your own email and password.

After registering:
  Settings > API Keys > Create API key

Then paste this in SSH:
  echo 'YOUR_KEY' > ~/.openclaw/secrets/sparky-token
  chmod 600 ~/.openclaw/secrets/sparky-token

System status:
  Gateway: WhatsApp linked
  Crons: 52 active (45 new + 7 existing)
  MCP tools: 14
  Build: custom (create_todo + score_habit + sparky_fitness)}"

curl -s -X POST http://localhost:18789/tools/invoke \
  -H "Authorization: Bearer $GW_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
msg = sys.argv[1]
to  = sys.argv[2]
payload = {'tool': 'message', 'args': {'action': 'send', 'channel': 'whatsapp', 'to': to, 'message': msg}}
print(json.dumps(payload))
" "$MSG" "$OWNER_WA")"

echo "Exit: $?"
