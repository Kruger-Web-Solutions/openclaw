#!/bin/bash
TOKEN="2aa6a25578011d76b4663f1e01b18f28f1db4a5aa2b0050b"
MSG="SparkyFitness is live!

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
  Build: custom (create_todo + score_habit + sparky_fitness)"

curl -s -X POST http://localhost:18789/tools/invoke \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
msg = sys.argv[1]
payload = {'tool': 'message', 'args': {'action': 'send', 'channel': 'whatsapp', 'to': '+27711304241', 'message': msg}}
print(json.dumps(payload))
" "$MSG")"

echo "Exit: $?"
