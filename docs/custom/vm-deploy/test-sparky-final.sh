#!/bin/bash
TOKEN="rsqwYSsihAZJoRuTbvUAfkmgnCYcnhboZYbBEWaMNHFglNdcHVTYeGpjQkgwqTrb"
BASE="http://localhost:3004/api"
TODAY="2026-03-23"

echo "=== FINAL SparkyFitness API verification ==="

check() {
  local label="$1"
  local code="$2"
  local resp="$3"
  if echo "$code" | grep -qE "^2"; then
    echo "✅ $label → HTTP $code"
  else
    echo "❌ $label → HTTP $code: $(echo $resp | head -c 100)"
  fi
}

R1=$(curl -s -o /tmp/sr.txt -w "%{http_code}" -H "x-api-key: $TOKEN" "$BASE/food-entries?selectedDate=$TODAY")
check "GET food-entries (diary)" "$R1" "$(cat /tmp/sr.txt)"

R2=$(curl -s -o /tmp/sr.txt -w "%{http_code}" -H "x-api-key: $TOKEN" "$BASE/goals/by-date/$TODAY")
check "GET goals/by-date (goals)" "$R2" "$(cat /tmp/sr.txt)"

R3=$(curl -s -o /tmp/sr.txt -w "%{http_code}" -H "x-api-key: $TOKEN" "$BASE/dashboard/stats?date=$TODAY")
check "GET dashboard/stats (summary)" "$R3" "$(cat /tmp/sr.txt)"

R4=$(curl -s -o /tmp/sr.txt -w "%{http_code}" -H "x-api-key: $TOKEN" "$BASE/sleep?startDate=$TODAY&endDate=$TODAY")
check "GET sleep" "$R4" "$(cat /tmp/sr.txt)"

R5=$(curl -s -o /tmp/sr.txt -w "%{http_code}" -H "x-api-key: $TOKEN" "$BASE/measurements/check-in/$TODAY")
check "GET check-in/weight" "$R5" "$(cat /tmp/sr.txt)"

R6=$(curl -s -w "%{http_code}" \
  -H "x-api-key: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"entry_date\":\"$TODAY\",\"change_drinks\":1,\"container_id\":null}" \
  -o /tmp/sr.txt "$BASE/measurements/water-intake")
check "POST water (log_water)" "$R6" "$(cat /tmp/sr.txt)"

echo ""
echo "=== Water today after test ==="
curl -s -H "x-api-key: $TOKEN" "$BASE/measurements/water-intake/$TODAY"
echo ""
echo "=== All tests done ==="
