#!/bin/bash
# Phase 3b: Set up and start SparkyFitness (Docker already installed)
# Usage: bash /tmp/phase3b-sparky-start.sh

set -euo pipefail

SPARKY_DIR="$HOME/sparky"
mkdir -p "$SPARKY_DIR"
cd "$SPARKY_DIR"

echo "=== Phase 3b: SparkyFitness setup ==="

# Download compose file from correct path
echo "--- Downloading docker-compose.prod.yml ---"
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/CodeWithCJ/SparkyFitness/main/docker/docker-compose.prod.yml

# Generate secrets using node (already installed)
DB_PASS=$(node -e "console.log(require('crypto').randomBytes(16).toString('hex'))")
APP_PASS=$(node -e "console.log(require('crypto').randomBytes(16).toString('hex'))")
ENC_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
AUTH_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

# Write .env (only if not already configured)
if [ ! -f .env ] || grep -q "changeme" .env 2>/dev/null; then
  cat > .env <<EOF
SPARKY_FITNESS_DB_NAME=sparkyfitness_db
SPARKY_FITNESS_DB_USER=sparky
SPARKY_FITNESS_DB_PASSWORD=${DB_PASS}
SPARKY_FITNESS_APP_DB_USER=sparky_app
SPARKY_FITNESS_APP_DB_PASSWORD=${APP_PASS}
SPARKY_FITNESS_API_ENCRYPTION_KEY=${ENC_KEY}
BETTER_AUTH_SECRET=${AUTH_SECRET}
SPARKY_FITNESS_FRONTEND_URL=http://localhost:3004
SPARKY_FITNESS_EXTRA_TRUSTED_ORIGINS=http://192.168.122.82:3004,http://192.168.122.83:3004
ALLOW_PRIVATE_NETWORK_CORS=true
SPARKY_FITNESS_DISABLE_SIGNUP=false
SPARKY_FITNESS_LOG_LEVEL=ERROR
SPARKY_FITNESS_FORCE_EMAIL_LOGIN=true
TZ=Africa/Johannesburg
NODE_ENV=production
EOF
  chmod 600 .env
  echo "--- .env written with generated secrets ---"
else
  echo "--- .env already exists with custom values, not overwriting ---"
fi

echo "--- Pulling images ---"
docker compose pull

echo "--- Starting containers ---"
docker compose up -d

echo "--- Waiting 15 seconds for DB init ---"
sleep 15

echo "--- Container status ---"
docker compose ps

echo ""
echo "============================================================"
echo "SparkyFitness is starting at: http://localhost:3004"
echo "(from Windows browser: http://192.168.122.82:3004)"
echo ""
echo "NEXT: Create your account at that URL, then:"
echo "  1. Go to Settings > API Keys"
echo "  2. Create a new API key"
echo "  3. Run: echo 'YOUR_TOKEN' > ~/.openclaw/secrets/sparky-token && chmod 600 ~/.openclaw/secrets/sparky-token"
echo "============================================================"
echo "=== Phase 3b complete ==="
