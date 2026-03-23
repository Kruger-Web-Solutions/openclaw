#!/bin/bash
# Todoist setup script - creates all required projects, sections, and labels
TODOIST_TOKEN="c3dbebe5e4d95b9a858c4cd7e222c18da7c4e0aa"
BASE="https://api.todoist.com/api/v1"

H="Authorization: Bearer $TODOIST_TOKEN"
CT="Content-Type: application/json"

echo "=== Todoist Setup ==="

# Helper: create project if it doesn't exist by name
get_or_create_project() {
  local name="$1"
  local color="${2:-charcoal}"
  local existing
  existing=$(curl -s -H "$H" "$BASE/projects" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for p in data.get('results', data) if isinstance(data, dict) else data:
    if p.get('name') == '$name':
        print(p['id'])
        break
" 2>/dev/null)
  if [ -n "$existing" ]; then
    echo "$existing"
  else
    curl -s -H "$H" -H "$CT" -X POST "$BASE/projects" \
      -d "{\"name\": \"$name\", \"color\": \"$color\"}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))"
  fi
}

# Helper: create label if it doesn't exist
get_or_create_label() {
  local name="$1"
  local color="${2:-charcoal}"
  local existing
  existing=$(curl -s -H "$H" "$BASE/labels" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for l in data if isinstance(data, list) else data.get('results', []):
    if l.get('name') == '$name':
        print(l['id'])
        break
" 2>/dev/null)
  if [ -n "$existing" ]; then
    echo "$existing"
  else
    curl -s -H "$H" -H "$CT" -X POST "$BASE/labels" \
      -d "{\"name\": \"$name\", \"color\": \"$color\"}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))"
  fi
}

echo ""
echo "--- Listing existing projects ---"
curl -s -H "$H" "$BASE/projects" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('results', [])
for p in items:
    print(f'  [{p[\"id\"]}] {p[\"name\"]}')
"

echo ""
echo "--- Creating/confirming projects ---"

echo -n "Weighsoft: "
WEIGHSOFT_ID=$(get_or_create_project "Weighsoft" "grape")
echo "$WEIGHSOFT_ID"

echo -n "Nedbank: "
NEDBANK_ID=$(get_or_create_project "Nedbank" "sky_blue")
echo "$NEDBANK_ID"

echo -n "Home: "
HOME_ID=$(get_or_create_project "Home" "green")
echo "$HOME_ID"

echo -n "Books to Read: "
BOOKS_ID=$(get_or_create_project "Books to Read" "taupe")
echo "$BOOKS_ID"

echo -n "Shopping: "
SHOPPING_ID=$(get_or_create_project "Shopping" "yellow")
echo "$SHOPPING_ID"

echo ""
echo "--- Creating in-progress label ---"
echo -n "in-progress label: "
INPROGRESS_ID=$(get_or_create_label "in-progress" "sky_blue")
echo "$INPROGRESS_ID"

echo ""
echo "--- Adding initial Home tasks ---"

add_task() {
  local content="$1"
  local project_id="$2"
  local priority="${3:-1}"
  curl -s -H "$H" -H "$CT" -X POST "$BASE/tasks" \
    -d "{\"content\": \"$content\", \"project_id\": \"$project_id\", \"priority\": $priority}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Created: {d.get(\"id\",\"?\")} - {d.get(\"content\",\"?\")}') if 'id' in d else print(f'  Error: {d}')"
}

if [ -n "$HOME_ID" ]; then
  add_task "Morning Bible reading - Chronological plan" "$HOME_ID" 2
  add_task "Evening family devotions" "$HOME_ID" 2
  add_task "Weekly Nagmal blessing with family" "$HOME_ID" 3
  add_task "Set up SparkyFitness goals and initial weight" "$HOME_ID" 4
fi

echo ""
echo "--- Final project list ---"
curl -s -H "$H" "$BASE/projects" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('results', [])
for p in items:
    print(f'  [{p[\"id\"]}] {p[\"name\"]}')
"

echo ""
echo "=== Done ==="
