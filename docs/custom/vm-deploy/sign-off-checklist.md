# Deployment Sign-off Checklist

Run through this after every full deployment. Tick each item only after you have seen the evidence, not just assumed it passed.

---

## Pre-deployment

- [ ] All code changes pushed: `git push origin main` + `git push kws main`
- [ ] VM is reachable: `ssh -i C:\Users\henza\.ssh\id_rsa henzard@192.168.122.82 "echo OK"`
- [ ] No uncommitted changes in `TOOLS.md` or `calendar-2026.json`

---

## Phase 2 — Code deployed

- [ ] `git pull` succeeded on VM (`~/openclaw-custom`)
- [ ] `pnpm build` passed (no TypeScript errors)
- [ ] `npm i -g .` installed without errors
- [ ] `openclaw doctor` shows no errors
- [ ] Gateway restarted: `systemctl --user restart openclaw-gateway`
- [ ] Gateway healthy: `curl http://localhost:18789/health` returns `{"status":"ok"}` or similar

---

## Phase 3 — SparkyFitness running

- [ ] `docker ps` shows 3 containers: `sparkyfitness-server`, `sparkyfitness-db`, `nginx` (or equivalent)
- [ ] All containers status: `Up` (not `Restarting`)
- [ ] Web UI accessible: `http://192.168.122.82:3004/login`
- [ ] API responds: `curl -s -H "x-api-key: $(cat ~/.openclaw/secrets/sparky-token)" http://localhost:3004/api/dashboard/stats?date=$(date +%Y-%m-%d)` → HTTP 200
- [ ] Goals are set in the web UI (calories, protein, carbs, fat)

---

## Phase 4 — MCP server deployed

- [ ] `grep -c 'server.tool(' ~/openclaw-custom/tools/openclaw-mcp-server.mjs` returns ≥14
- [ ] Cursor: Command Palette → **MCP: Reconnect servers** → all 14 tools visible
- [ ] `sparky_fitness summary` tool works in Cursor without error

---

## Phase 5 — Workspace files deployed

- [ ] `~/.openclaw/workspace/TOOLS.md` exists and is up to date
- [ ] `~/.openclaw/workspace/calendar-2026.json` exists
- [ ] `~/.openclaw/workspace/MEMORY.md` exists (even if empty scaffold)
- [ ] `~/.openclaw/secrets/contacts.env` exists with real phone numbers (copy from `contacts.env.example`)

---

## Phase 6 — Cron jobs

- [ ] `~/.npm-global/bin/openclaw cron list | wc -l` ≥ 52
- [ ] Spot-check crons present: `morning-anchor`, `daily-briefing`, `nagmal`, `state-of-me-report`, `yom-kippur-morning`, `alicia-bday`
- [ ] No duplicate cron names (check with `openclaw cron list | sort | uniq -d`)

---

## Phase 7 — Todoist setup

- [ ] Projects exist: Shopping, Weighsoft, Nedbank, Home, Books to Read
- [ ] Label `in-progress` exists (ID: `2183350196`)
- [ ] Project IDs in `TOOLS.md` match actual IDs from `todoist_tasks list`

---

## E2E verification

- [ ] Run `e2e-test.sh`: **34 passed, 0 failed**
- [ ] WhatsApp test message received on phone (number from `~/.openclaw/secrets/contacts.env`)
- [ ] `habitica(dashboard)` via gateway returns health/exp data
- [ ] `todoist_tasks(list)` via gateway returns task data

---

## Manual check — agent behaviour

Send each of these to the WhatsApp agent and verify the response:

| Message | Expected |
|---|---|
| `macros?` | sparky_fitness summary call, shows kcal/protein/carbs/fat |
| `water bottle done` | sparky_fitness log_water 1200ml |
| `buy milk` | Todoist Shopping project task created |
| `Weighsoft: fix export bug` | Todoist Weighsoft project task created |
| `dailies?` | habitica dashboard, shows incomplete dailies |
| Any stress message | Spiritual anchor first, then practical help |

---

## Post-deployment cleanup

- [ ] All `/tmp/oc-*.sh` scripts removed from VM (they are single-use)
- [ ] Passwordless sudo removed (if it was temporarily enabled):
  ```bash
  ls /etc/sudoers.d/  # should NOT contain henzard-nopasswd
  ```
- [ ] No test data left in SparkyFitness: check diary for today, should not contain `TEST_E2E`
- [ ] No test tasks left in Todoist: `[TEST]` prefix tasks should be gone

---

## Sign-off

Once all boxes are checked:

```
Deployment signed off: [Date]
Signed by: [Name]
Gateway version: [openclaw --version output]
E2E result: 34/34 passed
```
