#!/bin/bash
# Phase 2: Deploy OpenClaw code changes to VM
# Run this AFTER: pushing changes to origin/kws from Windows
# SCP this file to VM: scp -i $sshKey this-file.sh "henzard@<VM_IP>:/tmp/oc-phase2-deploy.sh"
# Then: ssh -i $sshKey henzard@<VM_IP> "bash /tmp/oc-phase2-deploy.sh"

set -euo pipefail

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

echo "=== Phase 2: Deploying OpenClaw code to VM ==="

cd ~/openclaw-custom

echo "--- Git pull ---"
git pull origin main

echo "--- pnpm install ---"
pnpm install

echo "--- pnpm build ---"
pnpm build

echo "--- npm i -g . ---"
npm i -g .

echo "--- openclaw doctor ---"
openclaw doctor

echo "--- Reloading systemd ---"
systemctl --user daemon-reload

echo "--- Restarting gateway ---"
systemctl --user restart openclaw-gateway

echo "--- Waiting 5 seconds ---"
sleep 5

echo "--- Health check ---"
openclaw health
openclaw gateway status

echo "=== Phase 2 complete ==="
