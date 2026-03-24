# Architecture & Overview

> **Read first** if you are new to this fork or starting a new development session.

---

## What this fork contains

This fork adds to the upstream [openclaw/openclaw](https://github.com/openclaw/openclaw) project:

| Feature | What it does | Phase | Status |
|---|---|---|---|
| **WhatsApp archive** | Captures every inbound/outbound WhatsApp message to SQLite | 1 | Live |
| **faster-whisper** | Transcribes WhatsApp voice notes locally using the `large-v3` model | 1 | Live |
| **Habitica plugin** | Native agent tool for Habitica tasks/dailies/dashboard, `create_todo`, `score_habit` | 1 | Live |
| **WhatsApp rate limiter** | Sliding-window outbound send limiter protecting all send paths | 1 | Live |
| **MCP server** | stdio MCP server giving Cursor 14 tools over SSH to a running OpenClaw instance | 1 | Live |
| **SparkyFitness** | Self-hosted nutrition + health tracker; Docker on VM; shell script for macro/water/weight/sleep | 2 | Live |
| **Personal assistant system** | ~58 cron jobs covering daily schedule, health, sacred calendar, birthdays, accountability | 2+3 | Live |
| **Todoist project structure** | 5 projects + `in-progress` label for VIP task cross-sync with Habitica | 2 | Live |
| **Cross-service chaining** | One user input triggers ALL related services automatically | 3 | Live |
| **Coaching intelligence** | AI coaches after every log, uses micro-commitments, celebrates wins | 3 | Live |
| **Macro estimation** | AI estimates nutritional macros from food descriptions (SparkyFitness has no food DB) | 3 | Live |

**Remotes:**
- `origin` — `https://github.com/henzard/openclaw.git`
- `kws` (org) — `https://github.com/Kruger-Web-Solutions/openclaw.git`
- `upstream` — `https://github.com/openclaw/openclaw.git`

---

## System architecture

```
Windows dev machine (Cursor IDE)
  │
  │  SSH stdio tunnel
  ▼
Linux VM (~/.npm-global/bin/openclaw)
  │
  ├── openclaw gateway (systemd --user service, port 18789)
  │     ├── WhatsApp channel (Baileys)
  │     │     ├── archive writer → ~/.openclaw/whatsapp/archive.sqlite
  │     │     ├── faster-whisper transcription (voice notes)
  │     │     └── rate limiter (wraps sock.sendMessage)
  │     ├── Habitica plugin (env: HABITICA_USER_ID, HABITICA_API_KEY)
  │     └── HTTP /tools/invoke endpoint
  │
  ├── SparkyFitness (Docker Compose, port 3004)
  │     ├── sparkyfitness-server (Node.js Express)
  │     ├── sparkyfitness-db (postgres:16-alpine)
  │     └── nginx (reverse proxy)
  │
  ├── ~/bin/ shell scripts (called via exec by gateway agent)
  │     ├── wa_archive       — WhatsApp archive queries (Node.js)
  │     ├── habitica          — Habitica API wrapper (bash/python)
  │     ├── sparky_fitness    — SparkyFitness API wrapper (bash/python)
  │     └── todoist_tasks     — Todoist API wrapper (bash/python)
  │
  └── tools/openclaw-mcp-server.mjs (spawned by Cursor via SSH)
        ├── CLI calls → openclaw binary
        ├── HTTP POST → localhost:18789/tools/invoke
        ├── Direct SQLite read → archive.sqlite
        └── HTTPS → api.todoist.com
```

---

## Key paths on the VM

| Path | Purpose |
|---|---|
| `~/openclaw-custom/` | Cloned fork (the custom build source) |
| `~/.openclaw/openclaw.json` | Runtime config |
| `~/.openclaw/workspace/` | Agent workspace (TOOLS.md, HELP.md, MEMORY.md, skills/) |
| `~/.openclaw/workspace/skills/` | Skill files (medication, health-coach, habitica-tasks, exercise, spiritual) |
| `~/.openclaw/whatsapp/archive.sqlite` | WhatsApp message archive |
| `~/.openclaw/whatsapp/audio/` | Persisted voice note audio files |
| `~/.openclaw/secrets/` | Tokens (sparky-token, todoist-token, contacts.env) |
| `~/.config/systemd/user/openclaw-gateway.service` | Systemd user service file |
| `~/bin/` | Shell scripts (wa_archive, habitica, sparky_fitness, todoist_tasks) |
| `~/sparky/` | SparkyFitness Docker Compose directory |
| `~/.npm-global/bin/openclaw` | OpenClaw binary |

---

## Tool inventory

| Tool | Type | Key Actions |
|---|---|---|
| `habitica` | shell script (`~/bin/`) | dashboard, dailies, habits, todos, complete, create_todo, score_habit |
| `sparky_fitness` | shell script (`~/bin/`) | summary, diary, goals, log_water, weight, sleep, log_food |
| `todoist_tasks` | shell script (`~/bin/`) | list, create, close, grocery |
| `wa_archive` | Node script (`~/bin/`) | today, yesterday, date, recent, search, groups |
| `message` | gateway core tool | Send WhatsApp: `action: send, channel: whatsapp, to: <number>, message: <text>` |
| `cron` | gateway CLI | list, add, edit, rm, run |
| `habitica` (native) | gateway plugin | dashboard, dailies, habits, todos, stats, complete, create_todo, score_habit |

**Important:** The gateway agent (WhatsApp) uses `~/bin/` shell scripts via `exec`. The Habitica native plugin is also available but the shell scripts are the primary interface for most actions.

---

## File map (repo)

```
# Fork-specific additions (not in upstream)

extensions/habitica/
  index.ts                         Plugin entry, unconditional registration
  openclaw.plugin.json             Manifest (enabledByDefault: true)
  src/tool.ts                      8-action Habitica agent tool (lazy auth)
  src/api.ts                       Habitica REST client

extensions/whatsapp/src/
  outbound-rate-limit.ts           Sliding-window rate limiter
  inbound/monitor.ts               (MODIFIED) wraps sock.sendMessage with limiter
  channel.ts                       (MODIFIED) archive init, agentTools, hooks
  archive/                         db.ts, writer.ts, reader.ts, agent-tool.ts, media-persist.ts

src/config/
  types.whatsapp.ts                (MODIFIED) archive + outboundRateLimit types
  zod-schema.providers-whatsapp.ts (MODIFIED) archive + outboundRateLimit schemas

src/media-understanding/
  runner.ts                        (MODIFIED) faster-whisper provider

tools/
  openclaw-mcp-server.mjs          MCP server (runs on VM, 14 tools)

docs/custom/                       This documentation folder
  architecture.md                  ← this file
  features.md                      Feature reference (all 8 features)
  bugs-and-fixes.md                All bugs from all phases
  agent-intelligence.md            Cross-service chaining, coaching, macros
  lessons-learned.md               All lessons organized by topic
  deployment-journal.md            Chronological record of all deployments
  ssh-and-vm-operations.md         SSH, sudo, gateway ops, diagnostics
  mcp-implementation-guide.md      MCP server deep dive
  personal-assistant-runbook.md    Ongoing ops (IP change, tokens, calendar)
  vm-deploy/                       Deploy scripts, skills, TOOLS.md, HELP.md
```

---

## How to add a new feature

### New agent plugin tool

1. Create `extensions/<plugin-name>/` with `index.ts`, `openclaw.plugin.json`, `src/tool.ts`, `src/tool.test.ts`
2. Set `"enabledByDefault": true` in `openclaw.plugin.json`
3. Register unconditionally in `index.ts`; resolve credentials at call time in `tool.ts`
4. Add `pnpm test:extension <plugin-name>` to verify tests pass
5. Document in `~/.openclaw/workspace/TOOLS.md` on the VM
6. Deploy: `git pull` on VM, `pnpm install && pnpm build && npm i -g .`, restart gateway

### New WhatsApp config key

1. Add to `WhatsAppSharedConfig` interface in `src/config/types.whatsapp.ts`
2. Add to `WhatsAppSharedSchema` Zod object in `src/config/zod-schema.providers-whatsapp.ts` (not to account or config schema separately)
3. Run `openclaw doctor` after deployment to verify no "Unrecognized key" errors
4. Test in flat config (`channels.whatsapp.<key>`) AND per-account (`channels.whatsapp.accounts.default.<key>`)

### New MCP tool

See [mcp-implementation-guide.md](mcp-implementation-guide.md) for the full pattern. Summary:

1. Choose transport: external API → `fetchWithTimeout`, gateway tool → `invokeGatewayTool`, CLI → `runCLI`, file/SQLite → direct read
2. Add `server.tool(...)` in `tools/openclaw-mcp-server.mjs`
3. Use `z.record(z.string(), z.any())` for object params — never `z.record(z.unknown())`
4. SCP the updated `.mjs` to the VM — no gateway restart needed
5. Reconnect MCP in Cursor

### New cron job

1. Use `openclaw cron add` with named flags (`--name`, `--cron`, `--tz`, `--message`, `--announce`)
2. Write prompts to explicitly name tools: "Run: wa_archive today Weighsoft"
3. Schedule daily or less unless there's a specific reason for higher frequency
4. Include "Do NOT edit TOOLS.md" if the cron involves memory/workspace

### New shell script tool

1. Create in `docs/custom/vm-deploy/` (repo copy)
2. Deploy to `~/bin/` on VM, `chmod +x`
3. Add to tool inventory in `TOOLS.md`
4. Follow the pattern: `set -euo pipefail`, source `.profile` for env vars, use positional args

---

## Upstream merge workflow

```bash
git checkout main
git pull origin main
git checkout -b merge-upstream-main
git fetch upstream
git merge upstream/main --no-edit
```

### Expected conflict files

| File | Resolution |
|---|---|
| `extensions/whatsapp/src/channel.ts` | Take upstream's imports; re-apply our archive block |
| `pnpm-lock.yaml` | `git checkout --theirs pnpm-lock.yaml` then `pnpm install` |

### channel.ts conflict rule

Always take upstream's structure for imports and API shape. Re-apply **only** our additions:
- Archive imports and `archiveDb` variable
- Extended `agentTools()` that pushes the archive tool
- The entire archive initialization block in `startAccount`
- `onRawMessage` passed into `monitorWebChannel`

---

*~210 lines. Covers: what this fork is, system diagram, key paths, tool inventory, file map, how to extend, upstream merge.*
