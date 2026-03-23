#!/bin/bash
TOKEN=$(cat ~/.openclaw/secrets/sparky-token 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "ERROR: ~/.openclaw/secrets/sparky-token missing"; exit 1; fi
BASE="http://localhost:3004/api"
TODAY="2026-03-23"

echo "=== SparkyFitness API verification ==="

echo "--- 1. Bearer token on /food-diary ---"
CODE=$(curl -s -o /tmp/sparky-resp.txt -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE/food-diary?date=$TODAY")
echo "HTTP $CODE: $(cat /tmp/sparky-resp.txt | head -c 200)"

echo ""
echo "--- 2. Bearer token on /nutrition/goals ---"
CODE=$(curl -s -o /tmp/sparky-resp.txt -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE/nutrition/goals")
echo "HTTP $CODE: $(cat /tmp/sparky-resp.txt | head -c 200)"

echo ""
echo "--- 3. X-API-Key on /food-diary ---"
CODE=$(curl -s -o /tmp/sparky-resp.txt -w "%{http_code}" \
  -H "X-API-Key: $TOKEN" \
  "$BASE/food-diary?date=$TODAY")
echo "HTTP $CODE: $(cat /tmp/sparky-resp.txt | head -c 200)"

echo ""
echo "--- 4. Try /health ---"
curl -s "$BASE/health" | head -c 200

echo ""
echo "=== Done ==="
