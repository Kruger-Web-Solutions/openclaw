# Feature Reference

> Detailed documentation for every feature added to this fork. For architecture overview, see [architecture.md](architecture.md). For bugs, see [bugs-and-fixes.md](bugs-and-fixes.md).

---

## Feature 1: WhatsApp message archive

Every inbound and outbound WhatsApp message is written to SQLite (`archive.sqlite`). Voice notes are transcribed by faster-whisper. The agent queries via the `wa_archive` shell script (`~/bin/wa_archive`).

### Files added

```
extensions/whatsapp/src/archive/
  db.ts              Schema creation, migration
  writer.ts          archiveInboundMessage(), archiveOutboundMessage()
  reader.ts          search(), recent(), stats()
  agent-tool.ts      createWhatsAppArchiveTool() — native agent tool
  media-persist.ts   persistAudioFile() — copy audio to stable path
  index.ts           Re-exports
```

### Files modified

| File | Change |
|---|---|
| `extensions/whatsapp/src/channel.ts` | Open archiveDb, register archive tool, wire `onRawMessage` callback and hooks |
| `extensions/whatsapp/src/auto-reply/types.ts` | Add `onRawMessage` to `MonitorWebInboxOptions` |
| `src/config/types.whatsapp.ts` | Add `archive` to `WhatsAppSharedConfig` |
| `src/config/zod-schema.providers-whatsapp.ts` | Add `WhatsAppArchiveSchema` to both account-level and top-level schemas |

### Config

```jsonc
{
  "channels": {
    "whatsapp": {
      "archive": { "enabled": true, "retentionDays": 90, "persistAudio": true }
    }
  }
}
```

The `archive` key must exist in **`WhatsAppSharedSchema`** so it's valid at both the top-level and per-account. This was a critical bug — see [bugs-and-fixes.md](bugs-and-fixes.md) B1.

### How archive is wired in channel.ts

`startAccount` opens the DB and registers:
1. An `onRawMessage` callback → fires before access control, so all messages are archived
2. A `message:sent` hook → archives outbound messages
3. A `message:transcribed` hook → persists the audio file and updates `media_path` in the DB

### Agent tool: `wa_archive`

Shell script in `~/bin/wa_archive` (Node.js). Supports SAST timezone correction.

```
wa_archive today Weighsoft        — today's group messages
wa_archive yesterday              — yesterday's messages
wa_archive search "meeting" 20    — search by text
wa_archive groups                 — list all groups
```

---

## Feature 2: Voice note transcription (faster-whisper)

Voice notes (OGG/Opus) are transcribed by `faster-whisper large-v3` running locally on the VM.

### Files modified

| File | Change |
|---|---|
| `src/media-understanding/runner.ts` | Added faster-whisper as a CLI provider |
| `src/media-understanding/runner.entries.ts` | Registered the provider |

### VM setup (one-time)

```bash
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt install -y python3.9 python3.9-venv python3.9-pip
python3.9 -m venv ~/whisper-env
source ~/whisper-env/bin/activate
pip install faster-whisper==1.2.1
```

**Key finding:** `faster-whisper` is a Python library, not a CLI tool. We created wrapper scripts (`~/whisper-env/bin/faster-whisper-cli.py` and `~/whisper-env/bin/fw-cli.sh`) and symlinked to `~/.npm-global/bin/faster-whisper`. Use `large-v3` model — medium gave poor results.

---

## Feature 3: Habitica plugin

Native OpenClaw agent tool for managing Habitica tasks.

### Files added

```
extensions/habitica/
  index.ts                Plugin entry — unconditionally registers the tool
  openclaw.plugin.json    Manifest — enabledByDefault: true
  src/tool.ts             8-action Habitica agent tool (lazy auth)
  src/api.ts              Habitica REST API client
```

### Actions

| Action | Description |
|---|---|
| `dashboard` | Full Habitica profile, XP, gold, stats |
| `dailies` | List daily tasks with completion status |
| `habits` | List habits |
| `todos` | List todos |
| `stats` | Character stats |
| `complete` | Mark a task complete (requires `task_id`) |
| `create_todo` | Create a new todo (requires `title`; optional `task_type`, `notes`, `priority`) |
| `score_habit` | Score a habit up or down (requires `task_id`, optional `direction`) |

### Critical pattern: lazy auth

Registration is **unconditional** — never gate `api.registerTool()` on env var presence. Credentials are resolved at execution time via `resolveAuth()`. This ensures the tool is always visible to the AI; missing credentials surface as a clear error at call time.

### Environment variables

Set in **both** locations:
1. Systemd user service: `systemctl --user edit openclaw-gateway.service`
2. Shell profile: `~/.bashrc` or `~/.profile` (for CLI and cron)

---

## Feature 4: WhatsApp outbound rate limiter

Protects against WhatsApp bans from rapid sending (broadcast, cron jobs). Lives in the extension layer so it protects ALL send paths.

### Files added/modified

| File | Change |
|---|---|
| `extensions/whatsapp/src/outbound-rate-limit.ts` | `WhatsAppRateLimitError` + `createOutboundRateLimiter` |
| `extensions/whatsapp/src/inbound/monitor.ts` | Wrap `sock.sendMessage` after socket creation |

### How the wrap works

```typescript
const rateLimiter = createOutboundRateLimiter(options.outboundRateLimit);
const originalSendMessage = sock.sendMessage.bind(sock);
sock.sendMessage = rateLimiter.wrapSendMessage(originalSendMessage);
```

Covers both send paths (direct send API and auto-reply). Each reconnect gets a fresh rate limiter.

### Config

```json
{ "channels": { "whatsapp": { "outboundRateLimit": { "maxMessages": 30, "windowSeconds": 60 } } } }
```

Omitting `outboundRateLimit` disables it (backward-compatible passthrough).

---

## Feature 5: MCP server for Cursor

See [mcp-implementation-guide.md](mcp-implementation-guide.md) for the full deep-dive. Summary here.

### File: `tools/openclaw-mcp-server.mjs`

Plain ES module, no build step. Runs on the VM. Cursor connects via SSH stdio.

### Tools (14 total)

| Group | Tools |
|---|---|
| WhatsApp (2) | `message` (gateway core), `wa_archive` (shell script) |
| Habitica (1) | `habitica` |
| Todoist (4) | `todoist_tasks`, `todoist_projects`, `todoist_labels`, `todoist_sections` |
| Cron (1) | `cron` |
| SparkyFitness (1) | `sparky_fitness` |

### Transport per tool

| Tool | Transport | Why |
|---|---|---|
| `message` | Gateway core tool | Send WhatsApp via gateway |
| `wa_archive` | Shell script, `node:sqlite` direct read | Fastest; no gateway involved |
| `habitica` | HTTP `/tools/invoke` | Native gateway plugin |
| `sparky_fitness` | Shell script, HTTPS to SparkyFitness API | External API |
| `todoist_tasks` | Shell script, HTTPS to Todoist API | External API |
| `cron` | CLI `openclaw cron *` | No HTTP equivalent |

### MCP gotchas

- **`--no-warnings`** required — `node:sqlite` prints to stderr which breaks JSON-RPC framing
- **`z.record(z.string(), z.any())`** — never `z.record(z.unknown())`, breaks MCP schema generation
- **PATH must be explicit in `spawn`** — SSH sessions don't source `~/.bashrc`

---

## Feature 6: SparkyFitness self-hosted nutrition tracker

Self-hosted, privacy-first nutrition and health tracker. Runs on the VM via Docker Compose. Replaces MyFitnessPal.

### Architecture

```
VM: Docker Compose
  ├── sparkyfitness-server   (Node.js Express, port 3004 via Nginx)
  ├── sparkyfitness-db       (postgres:16-alpine, port 5432)
  └── nginx                  (reverse proxy, exposes 3004)
```

### Correct API routes (hard-won — see bugs-and-fixes.md for discovery story)

| Action | Method | Endpoint | Key params |
|---|---|---|---|
| Read food diary | GET | `/api/food-entries?selectedDate=YYYY-MM-DD` | `selectedDate` (not `date`) |
| Read goals | GET | `/api/goals/by-date/YYYY-MM-DD` | date in path |
| Dashboard summary | GET | `/api/dashboard/stats?date=YYYY-MM-DD` | returns `eaten`, `goal`, `burned` |
| Log water | POST | `/api/measurements/water-intake` | `{entry_date, change_drinks, container_id}` |
| Log weight | POST | `/api/measurements/check-in` | `{entry_date, weight}` (kg) |
| Create food | POST | `/api/foods` | **flat** structure (not nested `default_variant`) |
| Create food entry | POST | `/api/food-entries` | `{food_id, variant_id, entry_date, meal_type, quantity, unit}` |

**Auth:** `x-api-key: YOUR_TOKEN` (not `Authorization: Bearer`).

**Meal types:** `breakfast`, `lunch`, `dinner`, `snacks` (plural — not `snack`).

**Water:** Container-based. `change_drinks: N` adds N servings (~250ml each). `container_id: null` uses default.

**Food logging is two-step:** (1) create food → get `food.id` + `default_variant.id`, (2) create food entry with both IDs.

**SparkyFitness has no food database.** The AI estimates macros from food descriptions. See [agent-intelligence.md](agent-intelligence.md).

---

## Feature 7: Personal assistant cron system (~58 jobs)

~58 cron jobs covering the user's full daily life. Run inside the OpenClaw gateway via `openclaw cron add`.

### Cron categories

| Category | Count | Examples |
|---|---|---|
| Weekday morning | 5 | morning-anchor, water-bottle-1, daily-briefing |
| Weekday work | 6 | Standups, Weighsoft work block |
| Weekday afternoon | 6 | Water checks, brunch, macro/mood, day-reflection |
| Weekday evening | 6 | Dinner, accountability-audit, exercise, evening-meds |
| Weekend | 4 | Saturday anchor, shopping, meal-prep, state-of-me |
| Weekly specials | 3 | Nagmal, friday-week-close, weekly-intentions |
| Sacred calendar | 14 | Seven Feasts of Israel 2026 |
| Birthdays | 6 | Alicia (4 crons), Kealyn (3 crons) |
| Pre-existing | 7 | Memory Synthesis, WhatsApp Summary, Step Tracker |
| **Proactive (Phase 3)** | 6 | Pre-standup briefs, macro coach, dinner nudge, steps check, EOD reconciliation |

### Correct syntax

```bash
openclaw cron add --name "morning-anchor" --cron "0 5 * * 1-5" --tz "Africa/Johannesburg" \
  --session isolated --announce --channel whatsapp --to "$OWNER_WA" --message "..."
```

**Do not use `--job '{"name":"..."}'`** — that syntax does not exist. See [bugs-and-fixes.md](bugs-and-fixes.md) B-CRON1.

---

## Feature 8: Todoist project structure + in-progress sync

### Projects

| Project | Purpose |
|---|---|
| Shopping | Grocery and shopping backlog |
| Weighsoft | Client work tasks |
| Nedbank | Nedbank tasks |
| Home | Personal and family tasks |
| Books to Read | Reading backlog |

### VIP sync

When "in progress: X" → create Todoist task with `in-progress` label + create Habitica todo.
When "done with X" → complete Habitica todo + close Todoist task.

---

*~400 lines. Covers: all 8 features with files, config, API routes, and key patterns.*
