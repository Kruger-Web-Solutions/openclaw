#!/bin/bash
TOKEN="rsqwYSsihAZJoRuTbvUAfkmgnCYcnhboZYbBEWaMNHFglNdcHVTYeGpjQkgwqTrb"
BASE="http://localhost:3004/api"
TODAY="2026-03-23"

echo "=== Testing real SparkyFitness endpoints ==="

for ENDPOINT in \
  "/food-entries?date=$TODAY" \
  "/user-goals" \
  "/goals" \
  "/sleep?date=$TODAY" \
  "/measurements?date=$TODAY" \
  "/dashboard?date=$TODAY" \
  "/food-entries/summary?date=$TODAY"
do
  echo ""
  echo "--- $ENDPOINT ---"
  CODE=$(curl -s -o /tmp/sr.txt -w "%{http_code}" \
    -H "x-api-key: $TOKEN" \
    "$BASE$ENDPOINT")
  echo "HTTP $CODE"
  cat /tmp/sr.txt | head -c 300
done

echo ""
echo "=== Done ==="
