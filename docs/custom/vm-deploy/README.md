# vm-deploy — script index and deployment guide

This folder contains every file needed to deploy and operate the OpenClaw Personal Assistant system on the Linux VM. There are 41 files here. This README tells you which ones matter, in what order, and what all the rest are.

---

## TL;DR — fresh deploy in 7 steps

| Step | Script / Action | Where |
|---|---|---|
| 0 | Push latest code | Windows: `git push origin main` |
| 1 | Code: git pull + build + install | VM: `bash /tmp/oc-phase2.sh` |
| 2 | Docker + SparkyFitness first-time setup | VM: `bash /tmp/oc-phase3b.sh` |
| 3 | Deploy MCP server | Windows PowerShell SCP |
| 4 | Deploy TOOLS.md + calendar-2026.json | Windows PowerShell SCP |
| 5 | Create cron jobs | VM: `bash /tmp/oc-phase7.sh` |
| 6 | Todoist setup | VM: `bash /tmp/oc-phase8.sh` |
| 7 | E2E verification | VM: `bash /tmp/e2e.sh` |

**The orchestrator for steps 0–5:** `deploy-all.ps1` (Windows PowerShell from repo root).

---

## Canonical files (keep, never delete)

These are the production files actively used by the live system.

| File | What it is | When to update |
|---|---|---|
| `TOOLS.md` | Agent identity, schedule, routing rules, tool inventory, sacred calendar | When behaviour, routing, or IDs change |
| `calendar-2026.json` | Seven Feasts 2026 + family birthdays (machine-readable) | January each year → create `calendar-YYYY.json` |
| `phase2-deploy-code.sh` | VM: git pull + pnpm build + npm install + gateway restart | Rarely (only if build steps change) |
| `phase3b-sparky-start.sh` | VM: correct Docker install (Ubuntu 20.04 safe) + Compose up | Use instead of `phase3-sparky-setup.sh` |
| `phase5-workspace-setup.sh` | VM: verify TOOLS.md + calendar landed, create MEMORY.md | Rarely |
| `phase7-crons-v2.sh` | VM: create all 45 personal-assistant cron jobs (correct CLI syntax) | When cron schedule/message changes |
| `phase8-todoist-setup.sh` | VM: create Todoist projects + in-progress label | Once per account (idempotent) |
| `e2e-test.sh` | Full 34-check E2E harness: create data → verify → cleanup | After any system change |
| `deploy-all.ps1` | PowerShell orchestrator for full fresh deploy | When phases or paths change |
| `send-wa-sparky.sh` | VM: send WhatsApp message via curl (bypasses CLI WebSocket) | Utility — use any time |
| `check-habitica-full.sh` | VM: list all Habitica dailies/habits/todos via gateway | Audit tool |

---

## Deprecated / superseded (safe to ignore)

| File | Status | Replaced by |
|---|---|---|
| `phase3-sparky-setup.sh` | **Broken on Ubuntu 20.04** — uses `curl | sudo sh` which fails on `docker-model-plugin` | `phase3b-sparky-start.sh` |
| `phase7-crons.sh` | **Wrong syntax** — used `--job json` which doesn't exist | `phase7-crons-v2.sh` |
| `phase2b-build-install.sh` | Retry script used during a failed build session | `phase2-deploy-code.sh` |

---

## Debug/investigation scripts (can delete after onboarding)

These were created during API discovery and system debugging. They are harmless but clutter:

```
check-agent-tools.sh       check-env.sh           check-gw-tools.sh
check-gw-tools2.sh         check-habitica.sh      check-habitica2.sh
check-mcp-client.sh        find-token.sh
test-food-debug.sh         test-food-flat.sh      test-food-full.sh
test-food-model.sh         test-food-repo.sh      test-mealtypes.sh
test-sparky-api.sh         test-sparky-api2.sh    test-sparky-api3.sh
test-sparky-containers.sh  test-sparky-crud.sh    test-sparky-final.sh
test-sparky-food.sh        test-sparky-food2.sh   test-sparky-food3.sh
test-sparky-food4.sh       test-sparky-food5.sh   test-sparky-routes.sh
test-sparky-schema.sh
```

---

## Detailed script reference

### `TOOLS.md`

The agent's boot file. Deployed to `~/.openclaw/workspace/TOOLS.md` on the VM. Contains:
- Identity and spiritual anchor
- Full daily schedule table
- Medication protocol (morning + evening)
- Hydration protocol (3 × 1.2L bottles)
- Accountability partner contacts and escalation trigger
- Routing rules (health/nutrition, task management, spiritual/emotional, work boundaries)
- Tool inventory with all action names
- Credential/config paths table (Todoist project IDs, label IDs, secret paths)
- Sacred calendar (Seven Feasts 2026 + family birthdays)
- Annual goals framework reference
- Weekend structure (Nagmal, church, shopping, meal prep)
- Recovery protocol (no shaming, one question)

**Never edited by automated processes.** Memory Synthesis and cron prompts must include "Do NOT edit TOOLS.md".

SCP command:
```powershell
scp -i C:\Users\henza\.ssh\id_rsa docs\custom\vm-deploy\TOOLS.md "henzard@192.168.122.82:~/.openclaw/workspace/TOOLS.md"
```

---

### `calendar-2026.json`

Machine-readable calendar for the agent. Used in cron prompts and agent responses when referencing feast dates or birthdays. Fields:
- `birthdays[]` — name, date (YYYY-MM-DD), type (self/spouse/child)
- `feasts[]` — name, hebrew, scripture, start, end, note, fast (bool), suppress_crons (bool)

**Update each January:** Copy to `calendar-YYYY.json`, update feast dates using the Hebrew calendar conversion for that year. Yom Kippur dates are especially important (fast + cron suppression). Update the `--message` in `phase7-crons-v2.sh` feast blocks with the new dates, then re-run the feast crons.

SCP command:
```powershell
scp -i C:\Users\henza\.ssh\id_rsa docs\custom\vm-deploy\calendar-2026.json "henzard@192.168.122.82:~/.openclaw/workspace/calendar-2026.json"
```

---

### `phase2-deploy-code.sh`

Runs on the VM. Handles:
1. `git pull origin main` (from `~/openclaw-custom`)
2. `pnpm install`
3. `pnpm build`
4. `npm i -g .`
5. `openclaw doctor`
6. `systemctl --user daemon-reload && systemctl --user restart openclaw-gateway`
7. Health check

**Must complete before deploying TOOLS.md or crons** because it restarts the gateway.

---

### `phase3b-sparky-start.sh`

Correct Docker install for Ubuntu 20.04. Key difference from `phase3-sparky-setup.sh`: installs Docker packages directly via apt (not the convenience script), which avoids the `docker-model-plugin` failure on focal.

Also:
- Creates `~/sparky/docker-compose.override.yml` pinning `postgres:16-alpine`
- Runs `docker compose up -d`
- Verifies containers are running

**Requires:** `~/sparky/.env` to exist with `DB_PASSWORD` and `SECRET_KEY` set. See the [SparkyFitness setup section](#sparkyFitness-first-time-setup) below.

---

### `phase5-workspace-setup.sh`

Run after SCP'ing TOOLS.md and calendar-2026.json to the VM. Verifies both files are present, and creates `~/.openclaw/workspace/MEMORY.md` if it doesn't exist (with the scaffold for 2026 goals and weekly intentions).

---

### `phase7-crons-v2.sh`

Creates all 45 new personal-assistant cron jobs. Uses the correct CLI syntax:
```bash
openclaw cron add \
  --name "morning-anchor" \
  --cron "0 5 * * 1-5" \
  --tz "Africa/Johannesburg" \
  --session isolated \
  --announce \
  --channel whatsapp \
  --to "$OWNER_WA" \
  --message "..."
```

**Do not use `phase7-crons.sh`** — it uses `--job '{"name":"..."}'` which is not valid syntax.

Cron categories covered:
- Weekday morning: 5am–7:30am (morning-anchor, water-bottle-1, daily-briefing, weekly-intentions, post-rhyno-call)
- Weekday work: 9:35am–10:35am (post-standup-trade, post-nfpe-standup, post-ndm-standup)
- Weekday afternoon: 10:45am–16:00 (water-check-1, brunch-reminder, macro-mood-check, water-check-2, day-reflection)
- Weekday evening: 17:00–21:45 (family-time, dinner-water, exercise-reminder, kealyn-bedtime, quiet-time, evening-meds, sleep-prep)
- Accountability audit: 18:30 weekdays (checks Habitica dailies + WhatsApp response, escalates to Alicia + Rhyno if needed)
- Friday: week-close (16:00), nagmal (18:00)
- Weekend: saturday-anchor, saturday-shopping, sunday-meal-prep, state-of-me-report
- Birthdays: Alicia (4 crons: 14d, 7d, eve, day), Kealyn (3 crons: 14d, 7d, day)
- Feasts: 10 crons (7-day notices + eves/day-of for Passover, Unleavened Bread, Firstfruits, Shavuot, Trumpets, Yom Kippur, Tabernacles)

---

### `phase8-todoist-setup.sh`

Creates the Todoist project structure and labels via the REST API. Idempotent — uses `get_or_create_project` and `get_or_create_label` helpers that check if each item already exists before creating.

Projects created:
| Project | Color |
|---|---|
| Weighsoft | grape |
| Nedbank | sky_blue |
| Home | green |
| Books to Read | taupe |
| Shopping | yellow |

Label: `in-progress` (sky_blue)

After running, update the project IDs in `TOOLS.md` if any changed.

---

### `e2e-test.sh`

See [implementation-guide.md §22](../implementation-guide.md#22-e2e-test-harness) for the full reference.

**Run after any significant change.** Expected output: `34 passed, 0 failed`.

The script contains hardcoded credentials (gateway token, SparkyFitness token, Todoist token). These are VM-local values — see [Secrets](#secrets) below.

---

### `send-wa-sparky.sh`

Utility script. Sends a WhatsApp message via curl to the gateway HTTP API, bypassing the CLI WebSocket (which is unreliable in SSH sessions). Use any time you need to send a test message or deliver instructions manually.

---

### `check-habitica-full.sh`

Retrieves and displays all Habitica dailies, habits, and todos via the gateway HTTP API. Use to audit the Habitica configuration or check task IDs before creating cron prompts.

---

## SparkyFitness first-time setup

After running `phase3b-sparky-start.sh`:

### 1. Configure `.env`

```bash
nano ~/sparky/.env
```

Required values:
```
DB_PASSWORD=<strong_password_here>
SECRET_KEY=<64_random_alphanumeric_chars>
```

### 2. Start the containers

```bash
cd ~/sparky
docker compose pull
docker compose up -d
docker ps   # verify 3 containers: server, db, nginx
```

If the db container fails (volume conflict), run:
```bash
docker compose down
docker volume ls  # find sparkyfitness volume
docker volume rm <volume_id>
rm -rf ~/sparky/postgresql ~/sparky/backup ~/sparky/uploads
docker compose up -d
```

### 3. Create your account

Open `http://192.168.122.82:3004/login` (or the VM IP + port 3004) in a browser. Register your account. This is the only time you can set the email/password.

### 4. Configure goals and saved meals

In the web UI:
- Settings → Goals: set daily calorie and macro targets
- Foods → My Foods: create your saved meals (Morning Shake, Morning Coffee, etc.)

### 5. Get the API token

Settings → API → Generate API Key. Store it:
```bash
echo "your_token_here" > ~/.openclaw/secrets/sparky-token
chmod 600 ~/.openclaw/secrets/sparky-token
```

---

## Secrets

All secrets live in `~/.openclaw/secrets/` on the VM (not in the repo).

| File | Content | How to get/rotate |
|---|---|---|
| `sparky-token` | SparkyFitness API key | Settings → API in the web UI (`http://<VM_IP>:3004`) |
| `todoist-token` | Todoist personal API token | todoist.com → Settings → Integrations → Developer |

**Gateway token** (used in `e2e-test.sh` and `send-wa-sparky.sh`): Read from `~/.openclaw/openclaw.json` → top-level `token` field:
```bash
python3 -c "import json; d=json.load(open(os.path.expanduser('~/.openclaw/openclaw.json'))); print(d['token'])" 2>/dev/null || \
  cat ~/.openclaw/openclaw.json | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])"
```

**Habitica credentials**: Set as environment variables in the systemd service file. Check with:
```bash
systemctl --user cat openclaw-gateway | grep HABITICA
```

---

## VM details quick reference

| Property | Value |
|---|---|
| IP | `192.168.122.82` (may change — see [IP change procedure](../personal-assistant-runbook.md#vm-ip-changed)) |
| User | `henzard` |
| SSH key | `C:\Users\henza\.ssh\id_rsa` |
| OS | Ubuntu 20.04 (focal) |
| Node | 22.x |
| OpenClaw source | `~/openclaw-custom/` |
| OpenClaw binary | `~/.npm-global/bin/openclaw` |
| Gateway port | `18789` |
| SparkyFitness port | `3004` |
| Systemd service | `openclaw-gateway` (user-level: `systemctl --user`) |
| Agent workspace | `~/.openclaw/workspace/` |
| Secrets | `~/.openclaw/secrets/` |
| WhatsApp archive | `~/.openclaw/whatsapp/archive.sqlite` |

---

## Sign-off checklist

See [sign-off-checklist.md](sign-off-checklist.md) — run through this after every full deployment.
