#!/usr/bin/env bash
# WhatsApp: agent replies only to listed E.164 numbers in DMs and groups.
# The message archive (when enabled) still records all inbound/outbound traffic before allowlist gating.
#
# Edit ALLOW_JSON below to your real numbers before running on the VM. Do not commit real numbers to a public repo.
set -euo pipefail
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

# JSON array of allowed senders (must match dmPolicy/groupPolicy allowlist expectations).
ALLOW_JSON='["+270000000001","+270000000002","+270000000003"]'

echo "=== Step 1: Set dmPolicy to allowlist first ==="
openclaw config set channels.whatsapp.dmPolicy allowlist

echo "=== Step 2: Set allowFrom ==="
openclaw config set --json channels.whatsapp.allowFrom "$ALLOW_JSON"

echo "=== Step 3: Groups — same sender allowlist (not open) ==="
openclaw config set channels.whatsapp.groupPolicy allowlist
openclaw config set --json channels.whatsapp.groupAllowFrom "$ALLOW_JSON"

echo ""
echo "=== Final WhatsApp config ==="
openclaw config get channels.whatsapp
