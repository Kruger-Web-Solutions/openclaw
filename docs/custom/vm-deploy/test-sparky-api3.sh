#!/bin/bash
TOKEN="rsqwYSsihAZJoRuTbvUAfkmgnCYcnhboZYbBEWaMNHFglNdcHVTYeGpjQkgwqTrb"
BASE="http://localhost:3004/api"
TODAY="2026-03-23"

echo "=== Testing correct SparkyFitness endpoints ==="

check() {
  local label="$1"
  local url="$2"
  echo ""
  echo "--- $label ---"
  CODE=$(curl -s -o /tmp/sr.txt -w "%{http_code}" \
    -H "x-api-key: $TOKEN" "$url")
  echo "HTTP $CODE | $(cat /tmp/sr.txt | head -c 300)"
}

check "food-entries today"              "$BASE/food-entries?selectedDate=$TODAY"
check "goals/for-date"                  "$BASE/goals/for-date?date=$TODAY"
check "goals/by-date"                   "$BASE/goals/by-date/$TODAY"
check "sleep today"                     "$BASE/sleep?startDate=$TODAY&endDate=$TODAY"
check "water intake"                    "$BASE/measurements/water-intake/$TODAY"
check "check-in today"                  "$BASE/measurements/check-in/$TODAY"
check "dashboard stats"                 "$BASE/dashboard/stats?date=$TODAY"
check "food-entries nutrient summary"   "$BASE/food-entries?selectedDate=$TODAY&summary=true"

echo ""
echo "=== Done ==="
