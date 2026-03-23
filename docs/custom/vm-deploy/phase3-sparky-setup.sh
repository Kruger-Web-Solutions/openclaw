#!/bin/bash
# Phase 3: Deploy SparkyFitness on VM via Docker
# SCP this file to VM and run it.
# NOTE: After this script runs, you must:
#   1. Edit ~/sparky/.env to set strong DB password + secret key
#   2. Run: cd ~/sparky && docker compose up -d
#   3. Open http://<VM_IP>:8080 to create account + set goals + create saved meals + get API token
#   4. Store token: echo "your-token" > ~/.openclaw/secrets/sparky-token && chmod 600 ~/.openclaw/secrets/sparky-token

set -euo pipefail

echo "=== Phase 3: Installing Docker and preparing SparkyFitness ==="

# Install Docker if not present
if ! command -v docker &>/dev/null; then
    echo "--- Installing Docker ---"
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    echo "NOTE: Docker installed. You may need to log out and back in (or run 'newgrp docker') for group to take effect."
fi

# Create sparky directory
mkdir -p ~/sparky
cd ~/sparky

echo "--- Downloading docker-compose.yml ---"
curl -L -o docker-compose.yml \
  https://raw.githubusercontent.com/CodeWithCJ/SparkyFitness/main/docker-compose.yml

echo "--- Downloading .env template ---"
curl -L -o .env.example \
  https://raw.githubusercontent.com/CodeWithCJ/SparkyFitness/main/.env.example

if [ ! -f .env ]; then
    cp .env.example .env
    echo ""
    echo "============================================================"
    echo "NEXT STEP: Edit ~/sparky/.env before starting the container."
    echo "  Set: DB_PASSWORD=<strong_password>"
    echo "  Set: SECRET_KEY=<random_64_char_string>"
    echo "  nano ~/sparky/.env"
    echo "Then run: cd ~/sparky && docker compose pull && docker compose up -d"
    echo "============================================================"
else
    echo ".env already exists — not overwriting."
fi

# Create secrets directory
mkdir -p ~/.openclaw/secrets

echo "=== Phase 3 prep complete ==="
echo "Remember to:"
echo "  1. Edit ~/sparky/.env with strong passwords"
echo "  2. Run: cd ~/sparky && docker compose pull && docker compose up -d"
echo "  3. Open http://localhost:8080 to set up account"
echo "  4. Get API token from Settings → API"
echo "  5. Store token: echo 'your-token' > ~/.openclaw/secrets/sparky-token && chmod 600 ~/.openclaw/secrets/sparky-token"
