#!/bin/bash
# Phase 2b: pull latest fix, build, install (run after phase2 failed on tsc)
set -euo pipefail
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

cd ~/openclaw-custom

echo "--- Git pull (latest TypeScript fix) ---"
git pull origin main

echo "--- pnpm build ---"
pnpm build

echo "--- npm i -g . ---"
npm i -g .

echo "--- openclaw --version ---"
openclaw --version

echo "--- openclaw doctor ---"
openclaw doctor

echo "--- Restarting gateway ---"
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway

sleep 5

echo "--- Health check ---"
openclaw health 2>&1 || true
openclaw gateway status 2>&1 || true

echo "=== Phase 2b complete ==="
