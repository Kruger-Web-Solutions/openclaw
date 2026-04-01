#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"
REPO="${OPENCLAW_REPO:-$HOME/openclaw-custom}"
cd "$REPO"

echo "=== [1/6] Stash local tool edits if any (MCP, etc.) ==="
git stash push -m "pre-main-sync-$(date +%Y%m%d%H%M)" -- tools/openclaw-mcp-server.mjs 2>/dev/null || true

echo "=== [2/6] Fetch and checkout main ==="
git fetch origin
git checkout main
git pull origin main

echo "=== [3/6] Build ==="
pnpm build

echo "=== [4/6] Global install ==="
npm i -g .
openclaw --version

echo "=== [5/6] Doctor ==="
openclaw doctor || true

echo "=== [6/6] Restart gateway ==="
systemctl --user restart openclaw-gateway
sleep 4
systemctl --user is-active openclaw-gateway && echo "Gateway: ACTIVE" || echo "Gateway: FAILED"

echo "=== HEAD ==="
git log -1 --oneline
