#!/usr/bin/env bash
# Apply items that `openclaw security audit` commonly flags on a private VM.
# Safe to re-run (idempotent chmod; rate limit merge).
set -euo pipefail
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

CRED_DIR="$HOME/.openclaw/credentials"
if [[ -d "$CRED_DIR" ]]; then
  echo "=== chmod 700 credentials dir ==="
  chmod 700 "$CRED_DIR"
  ls -ld "$CRED_DIR"
fi

LOG_FILE="$HOME/.openclaw/logs/openclaw.log"
if [[ -f "$LOG_FILE" ]]; then
  echo "=== chmod 600 main gateway log (may contain tool output / messages) ==="
  chmod 600 "$LOG_FILE"
  ls -l "$LOG_FILE"
fi

echo "=== gateway.auth.rateLimit (brute-force mitigation when bind is not loopback) ==="
openclaw config set --json gateway.auth.rateLimit '{"maxAttempts":10,"windowMs":60000,"lockoutMs":300000,"exemptLoopback":true}'

echo ""
echo "=== gateway.auth (snippet) ==="
openclaw config get gateway.auth | head -20

echo ""
echo "Restart gateway to apply config: systemctl --user restart openclaw-gateway"
