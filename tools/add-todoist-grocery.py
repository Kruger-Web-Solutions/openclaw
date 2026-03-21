#!/usr/bin/env python3
import json, os, sys, uuid
from pathlib import Path
from urllib import request

CONFIG = json.loads(Path("/home/henzard/.openclaw/workspace/config/todoist-groceries.json").read_text())
TOKEN = Path("/home/henzard/.openclaw/secrets/todoist-token").read_text().strip()
API = "https://api.todoist.com/api/v1/tasks"

if len(sys.argv) < 2:
    print("usage: add-todoist-grocery.py <item text> [store]")
    sys.exit(2)

content = sys.argv[1].strip()
explicit_store = sys.argv[2].strip().lower() if len(sys.argv) > 2 and sys.argv[2].strip() else None

stores = CONFIG["stores"]


def detect_store(text):
    lower = text.lower()
    for key, meta in stores.items():
        for alias in meta.get("aliases", []):
            if alias in lower:
                return key
    return None


store_key = explicit_store or detect_store(content) or CONFIG["default_store"]
if store_key not in stores:
    print(json.dumps({"ok": False, "error": f"unknown store: {store_key}"}))
    sys.exit(2)

store = stores[store_key]

payload = {
    "content": content,
    "project_id": CONFIG["project"]["id"],
}
# Only set section_id if the store has one (builders has null)
if store.get("section_id"):
    payload["section_id"] = store["section_id"]

body = json.dumps(payload).encode("utf-8")
req = request.Request(API, data=body, method="POST")
req.add_header("Authorization", f"Bearer {TOKEN}")
req.add_header("Content-Type", "application/json")
req.add_header("X-Request-Id", str(uuid.uuid4()))
with request.urlopen(req) as resp:
    data = json.loads(resp.read().decode("utf-8"))

print(json.dumps({
    "ok": True,
    "store": store["section_name"],
    "project": CONFIG["project"]["name"],
    "task": data,
}, indent=2))
