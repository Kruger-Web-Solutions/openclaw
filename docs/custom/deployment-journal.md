# Deployment Journal

> Chronological record of everything that was done, when, and in what order. Use this to understand the current state of the system and reproduce a deployment.

---

## Phase 1 — Core features (February-March 2026)

### What was built

1. WhatsApp message archive (SQLite + agent tool)
2. faster-whisper voice note transcription
3. Habitica native plugin (8 actions, lazy auth)
4. WhatsApp outbound rate limiter
5. MCP server for Cursor (14 tools over SSH)

### Key decisions

- Archive wired at the extension layer (before access control) so all messages are captured
- faster-whisper runs locally (no cloud API, privacy-first)
- Habitica plugin uses lazy auth (register always, validate at call time)
- Rate limiter wraps `sock.sendMessage` at the socket level (covers all send paths)
- MCP server runs on the VM (not locally) because CLI only exists there

### Production deployment

1. Clone fork to `~/openclaw-custom/` on VM
2. `pnpm install && pnpm build && npm i -g .`
3. Configure systemd user service with env vars
4. Run `openclaw doctor` then restart gateway
5. Configure WhatsApp archive in `openclaw.json`
6. Set up faster-whisper venv with Python 3.9
7. Deploy MCP server to `tools/openclaw-mcp-server.mjs`
8. Configure `.cursor/mcp.json` on Windows dev machine

---

## Phase 2 — Personal assistant deployment (March 2026)

### Step-by-step record

**Step 1: Fix monitor.ts TypeScript error.** `sock.sendMessage.bind(sock)` had a TS2345 error. Fixed with explicit cast.

**Step 2: Habitica plugin extensions.** Added `create_todo` and `score_habit` actions to `extensions/habitica/src/tool.ts`.

**Step 3: SparkyFitness MCP tool.** Initial version used wrong routes. Discovered correct routes by:
1. `docker exec sparkyfitness-server ls /app/SparkyFitnessServer/routes/`
2. Read `SparkyFitnessServer.js` for `app.use()` registrations
3. Test each endpoint with curl
4. Read TypeScript schema files for required fields

**Step 4: Docker install on Ubuntu 20.04.** Convenience script failed on `docker-model-plugin`. Installed packages directly via apt.

**Step 5: Passwordless sudo.** Enabled temporarily for deployment scripts. **Removed at end of session.**

**Step 6: Cron deployment.** First script (`phase7-crons.sh`) used wrong `--job` syntax. Discovered correct syntax via `openclaw cron add --help`. Rewrote as `phase7-crons-v2.sh` (45 new crons).

**Step 7: TOOLS.md deployment.** SCP'd to `~/.openclaw/workspace/TOOLS.md`. Contains identity, routing, tool inventory, sacred calendar.

**Step 8: SparkyFitness token.** User registered account, generated API key, stored at `~/.openclaw/secrets/sparky-token`.

**Step 9: MCP route corrections.** Every SparkyFitness route was wrong. All 6 actions tested live (HTTP 200) before committing.

**Step 10: Todoist setup.** Created Home and Books to Read projects. Confirmed existing projects. Created `in-progress` label.

**Step 11: E2E verification.** Ran `e2e-test.sh`: 34/34 passing. All test data created, verified, cleaned up.

**Step 12: Sudo restored.** Removed passwordless sudo. Committed and pushed.

### SparkyFitness first-time setup

After running `phase3b-sparky-start.sh`:
1. Configure `~/sparky/.env` with `DB_PASSWORD` and `SECRET_KEY`
2. `docker compose pull && docker compose up -d`
3. Register account at `http://VM_IP:3004/login`
4. Set macro goals in Settings → Goals
5. Generate API key: Settings → API
6. Store: `echo "KEY" > ~/.openclaw/secrets/sparky-token && chmod 600 ~/.openclaw/secrets/sparky-token`

---

## Phase 3 — Deep audit + agentic intelligence (March 2026)

### Why the audit was needed

Phase 2 passed all 34 E2E tests. Real-world usage exposed:
- Water logging → exit 22 (API schema mismatch in shell script)
- Food logging → exit 22 (wrong field names in shell script)
- `habitica dashboard` → KeyError (API field removed)
- `habitica` script → unbound variable (non-login shell)
- Phantom tool references in docs and crons

**Key insight:** The E2E test tested the MCP server code. The shell scripts (`~/bin/`) have their own code paths with their own bugs. Both need testing.

### What was fixed

| Bug | What broke | Root cause |
|---|---|---|
| `habitica maxHealth` | Dashboard crashed | API removed field; hardcoded to 50 |
| `habitica unbound variable` | Script failed in cron | `.profile` not sourced; added fallback |
| `sparky_fitness log_water` | Exit 22 | Wrong field names; aligned with API |
| `sparky_fitness summary` water | Always 0ml | Missing separate water API call |
| `sparky_fitness log_food` | Exit 22 | Wrong field names; aligned with MCP server |
| `wa_archive` dates | Wrong day after midnight | UTC→SAST offset added |
| Phantom tools in docs | Agent confusion | Replaced across all files |
| Cron pronouns/numbers | Wrong gender, hardcoded | Fixed pronouns, use contacts.env |
| Food zero macros | Useless tracking | AI estimates macros now |

### What was built

1. **Cross-service chaining** — TOOLS.md section mapping inputs to ALL related services
2. **Coaching intelligence** — TOOLS.md section with micro-commitments, win celebration, questioning
3. **Macro Estimation Protocol** — health-coach skill with GAPS food reference table
4. **`habitica score_habit`** — new action in `~/bin/habitica` for scoring habits
5. **6 proactive crons** — pre-standup, macro coach, dinner nudge, steps, EOD reconciliation
6. **Updated skills** — medication (mandatory cross-service), health-coach (macro estimation), habitica-tasks (streaks)

### Phase 3 deployment

Files deployed to VM:
```
TOOLS.md              → ~/.openclaw/workspace/TOOLS.md
HELP.md               → ~/.openclaw/workspace/HELP.md
habitica              → ~/bin/habitica (chmod +x)
skills/medication/    → ~/.openclaw/workspace/skills/medication/SKILL.md
skills/health-coach/  → ~/.openclaw/workspace/skills/health-coach/SKILL.md
skills/habitica-tasks/→ ~/.openclaw/workspace/skills/habitica-tasks/SKILL.md
add-proactive-crons.sh → executed via SSH
```

Deploy command pattern:
```powershell
scp -o BatchMode=yes "docs\custom\vm-deploy\FILE" henzard@192.168.122.82:/tmp/FILE
ssh -o BatchMode=yes henzard@192.168.122.82 "cp /tmp/FILE ~/.openclaw/workspace/FILE"
```

Sessions cleaned up. Total crons after Phase 3: ~58.

---

## E2E test harness

File: `docs/custom/vm-deploy/e2e-test.sh`

### What it tests (34 checks)

| Section | Tests |
|---|---|
| Gateway health | Port 18789 responding |
| SparkyFitness reads | Dashboard stats, goals, weight, water, sleep |
| SparkyFitness writes | Water +250ml, weight 75kg, food creation, diary entry |
| Todoist | Task creation, read-back, project list |
| Gateway plugins | todoist_tasks, habitica, sparky direct API |
| Cron jobs | Count (>=50), 8 known names |
| WhatsApp | Test message sent |
| Cleanup | All created objects deleted, state restored |

### How to run

```bash
scp docs/custom/vm-deploy/e2e-test.sh henzard@192.168.122.82:/tmp/e2e-test.sh
ssh henzard@192.168.122.82 "bash /tmp/e2e-test.sh"
```

Expected: `34 passed, 0 failed`.

---

## VM quick reference

| Property | Value |
|---|---|
| IP | `192.168.122.82` (may change) |
| User | `henzard` |
| OS | Ubuntu 20.04 (focal) |
| Node | 22.x |
| Gateway port | `18789` |
| SparkyFitness port | `3004` |
| Systemd service | `openclaw-gateway` (user-level) |
| Secrets | `~/.openclaw/secrets/` |

---

*~250 lines. Chronological record of all three phases with deployment commands and VM reference.*
