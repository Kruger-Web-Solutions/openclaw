#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

REPO="$HOME/openclaw-custom"
cd "$REPO"

echo "=== [1/5] Pulling latest fix ==="
git pull origin merge-upstream-main

echo "=== [2/5] Building ==="
pnpm build 2>&1 | tail -30

echo "=== [3/5] Installing globally ==="
npm i -g .
openclaw --version

echo "=== [4/5] Running doctor ==="
openclaw doctor || true

echo "=== [5/5] Restarting gateway ==="
systemctl --user restart openclaw-gateway
sleep 4
systemctl --user is-active openclaw-gateway && echo "Gateway: ACTIVE" || echo "Gateway: FAILED"

echo "=== Build & deploy complete ==="
