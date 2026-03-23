# OpenClaw custom build — full implementation guide

> **Audience:** Any future Cursor session, developer, or operator working on this fork.
>
> This is the complete record of every feature we built, every decision we made, every bug we hit, and everything we learned — from the first WhatsApp archive line through to the MCP server, upstream merge, and production deployment. Read this before making any changes.

---

## Table of contents

1. [What this fork contains](#1-what-this-fork-contains)
2. [System architecture](#2-system-architecture)
3. [Feature 1: WhatsApp message archive](#3-feature-1-whatsapp-message-archive)
4. [Feature 2: Voice note transcription (faster-whisper)](#4-feature-2-voice-note-transcription-faster-whisper)
5. [Feature 3: Habitica plugin](#5-feature-3-habitica-plugin)
6. [Feature 4: WhatsApp outbound rate limiter](#6-feature-4-whatsapp-outbound-rate-limiter)
7. [Feature 5: MCP server for Cursor](#7-feature-5-mcp-server-for-cursor)
8. [Production: Linux VM setup](#8-production-linux-vm-setup)
9. [Agent alignment: tools, cron, TOOLS.md](#9-agent-alignment-tools-cron-toolsmd)
10. [Model selection history](#10-model-selection-history)
11. [Upstream merge workflow](#11-upstream-merge-workflow)
12. [All bugs and fixes](#12-all-bugs-and-fixes)
13. [Lessons learned](#13-lessons-learned)
14. [How to add a new feature](#14-how-to-add-a-new-feature)
15. [File map](#15-file-map)

**Phase 2 — Personal assistant deployment (March 2026)**

16. [Feature 6: SparkyFitness self-hosted nutrition tracker](#16-feature-6-sparkyFitness-self-hosted-nutrition-tracker)
17. [Feature 7: Personal assistant cron system (52 jobs)](#17-feature-7-personal-assistant-cron-system)
18. [Feature 8: Todoist project structure + in-progress sync](#18-feature-8-todoist-project-structure)
19. [Phase 2 deployment journal](#19-phase-2-deployment-journal)
20. [Phase 2 bugs and fixes](#20-phase-2-bugs-and-fixes)
21. [Phase 2 lessons learned](#21-phase-2-lessons-learned)
22. [E2E test harness](#22-e2e-test-harness)
23. [Updated file map](#23-updated-file-map)

**Companion documents** (also in `docs/custom/`):
- [ssh-and-vm-operations.md](ssh-and-vm-operations.md) — Full SSH reference, PowerShell gotchas, `sudo` without password, gateway ops, diagnostics, model switching
- [mcp-implementation-guide.md](mcp-implementation-guide.md) — Deep-dive on the MCP server specifically

---

## 1. What this fork contains

This fork adds to the upstream [openclaw/openclaw](https://github.com/openclaw/openclaw) project:

| Feature | What it does | Status |
|---|---|---|
| **WhatsApp archive** | Captures every inbound/outbound WhatsApp message to SQLite | Live |
| **faster-whisper** | Transcribes WhatsApp voice notes locally using the `large-v3` model | Live |
| **Habitica plugin** | Native agent tool for Habitica tasks/dailies/dashboard, `create_todo`, `score_habit` | Live |
| **WhatsApp rate limiter** | Sliding-window outbound send limiter protecting all send paths | Live |
| **MCP server** | stdio MCP server giving Cursor 14 tools over SSH to a running OpenClaw instance | Live |
| **SparkyFitness** | Self-hosted nutrition + health tracker; Docker on VM; MCP tool for macro/water/weight/sleep | Live |
| **Personal assistant system** | 52 cron jobs covering daily schedule, health, sacred calendar, birthdays, accountability, weekend | Live |
| **Todoist project structure** | 5 projects + `in-progress` label for VIP task cross-sync with Habitica | Live |

**Remotes:**
- `origin` — `https://github.com/henzard/openclaw.git`
- `kws` (org) — `https://github.com/Kruger-Web-Solutions/openclaw.git`
- `upstream` — `https://github.com/openclaw/openclaw.git`

---

## 2. System architecture

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
  └── tools/openclaw-mcp-server.mjs (spawned by Cursor via SSH)
        ├── CLI calls → openclaw binary
        ├── HTTP POST → localhost:18789/tools/invoke
        ├── Direct SQLite read → archive.sqlite
        └── HTTPS → api.todoist.com
```

### Key paths on the VM

| Path | Purpose |
|---|---|
| `~/openclaw-custom/` | Cloned fork (the custom build source) |
| `~/.openclaw/openclaw.json` | Runtime config |
| `~/.openclaw/workspace/` | Agent workspace (TOOLS.md, MEMORY.md, scripts, config) |
| `~/.openclaw/whatsapp/archive.sqlite` | WhatsApp message archive |
| `~/.openclaw/whatsapp/audio/` | Persisted voice note audio files |
| `~/.openclaw/secrets/todoist-token` | Todoist API token (not in repo) |
| `~/.config/systemd/user/openclaw-gateway.service` | Systemd user service file |

---

## 3. Feature 1: WhatsApp message archive

### What it does

Every inbound and outbound WhatsApp message is written to a local SQLite database (`archive.sqlite`). Voice notes are transcribed by faster-whisper and stored as text. The agent can query the archive via the native `whatsapp_archive` tool.

### Files added

```
extensions/whatsapp/src/archive/
  db.ts              Schema creation, migration
  db.test.ts
  writer.ts          archiveInboundMessage(), archiveOutboundMessage()
  writer.test.ts
  reader.ts          search(), recent(), stats()
  reader.test.ts
  agent-tool.ts      createWhatsAppArchiveTool() — native agent tool
  agent-tool.test.ts
  media-persist.ts   persistAudioFile() — copy audio to stable path
  media-persist.test.ts
  index.ts           Re-exports
```

### Files modified

| File | Change |
|---|---|
| `extensions/whatsapp/src/channel.ts` | Open archiveDb, register archive tool, wire `onRawMessage` callback and hooks |
| `extensions/whatsapp/src/auto-reply/types.ts` | Add `onRawMessage` to `MonitorWebInboxOptions` |
| `src/config/types.whatsapp.ts` | Add `archive` to `WhatsAppSharedConfig` |
| `src/config/zod-schema.providers-whatsapp.ts` | Add `WhatsAppArchiveSchema` to both account-level and top-level schemas |

### Config (user-facing)

```jsonc
{
  "channels": {
    "whatsapp": {
      "accounts": {
        "default": {
          "archive": {
            "enabled": true,
            "retentionDays": 90,
            "persistAudio": true
          }
        }
      }
    }
  }
}
```

The `archive` key can also be placed at the **top level** of the `whatsapp` block (flat config), which is what most single-account users have. The schema supports both.

### Critical schema lesson

The `archive` key was initially only added to `WhatsAppAccountSchema`, not to `WhatsAppConfigSchema`. This caused:

```
Config invalid: channels.whatsapp: Unrecognized key: "archive"
```

...and the **gateway refused to start**. The fix was to add `archive` to **both** schemas. For any new key that should be valid at both the top-level and per-account, add it to **`WhatsAppSharedSchema`** (the shared base) so it's inherited by both automatically — the same pattern as `debounceMs`.

### How archive is wired in channel.ts

`startAccount` in `channel.ts` opens the DB and registers:
1. An `onRawMessage` callback passed to `monitorWebChannel` — fires before access control, so all messages are archived even if the sender is not in the allowlist.
2. A `message:sent` hook — archives outbound messages.
3. A `message:transcribed` hook — persists the audio file and updates `media_path` in the DB.

### Agent tool: `whatsapp_archive`

Actions: `search`, `recent`, `stats`

```
whatsapp_archive { action: "recent", limit: 20 }
whatsapp_archive { action: "search", query: "meeting tomorrow" }
whatsapp_archive { action: "stats" }
```

Results include `is_voice_note: boolean` (derived from `media_type LIKE 'audio/%'`) so the AI can say "John left a voice note saying..." vs. "John typed...".

---

## 4. Feature 2: Voice note transcription (faster-whisper)

### What it does

When WhatsApp delivers a voice note (OGG/Opus format), the media understanding pipeline sends it through `faster-whisper large-v3` running locally on the VM. The transcript is stored in the archive as the message text.

### Files modified

| File | Change |
|---|---|
| `src/media-understanding/runner.ts` | Added faster-whisper as a CLI provider |
| `src/media-understanding/runner.entries.ts` | Registered the provider |
| `src/media-understanding/runner.faster-whisper.test.ts` | Unit tests |

### VM setup (one-time)

```bash
# Python 3.9+ required (Ubuntu 20.04 has 3.8 which is too old)
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt install -y python3.9 python3.9-venv python3.9-pip

# Create a dedicated venv
python3.9 -m venv ~/whisper-env
source ~/whisper-env/bin/activate
pip install faster-whisper==1.2.1

# Create a CLI wrapper (faster-whisper is a library, not a CLI)
cat > ~/whisper-env/bin/faster-whisper-cli.py << 'EOF'
#!/usr/bin/env python3
import sys
from faster_whisper import WhisperModel

audio_path = sys.argv[1]
model_size = sys.argv[2] if len(sys.argv) > 2 else "large-v3"
model = WhisperModel(model_size, device="cpu", compute_type="int8")
segments, info = model.transcribe(audio_path)
for segment in segments:
    print(segment.text.strip())
EOF
chmod +x ~/whisper-env/bin/faster-whisper-cli.py

# Bash wrapper to activate venv first
cat > ~/whisper-env/bin/fw-cli.sh << 'EOF'
#!/bin/bash
source ~/whisper-env/bin/activate
python ~/whisper-env/bin/faster-whisper-cli.py "$@"
EOF
chmod +x ~/whisper-env/bin/fw-cli.sh

# Symlink to PATH
ln -sf ~/whisper-env/bin/fw-cli.sh ~/.npm-global/bin/faster-whisper

# Pre-download the model (3 GB, CPU-only VM: ~30–60s per 30s audio clip)
faster-whisper /dev/null 2>&1 || true
```

**Key finding from testing:** `large-v3` works correctly. Medium gave poor results. Use `large-v3`.

### Why faster-whisper isn't a real CLI

`faster-whisper` is a **Python library**, not a CLI tool. Running `pip install faster-whisper` gives you a library. We created a wrapper script to bridge this. Do not remove `fw-cli.sh`.

---

## 5. Feature 3: Habitica plugin

### What it does

A native OpenClaw agent tool for managing Habitica tasks. The agent calls it directly — no exec, no shell script.

### Files added

```
extensions/habitica/
  index.ts                Plugin entry point — unconditionally registers the tool
  openclaw.plugin.json    Manifest — enabledByDefault: true
  src/
    tool.ts               createHabiticaTool() — lazy auth, 8 actions
    tool.test.ts
    api.ts                Habitica REST API client
    api.test.ts
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
| `create_todo` | Create a new todo, daily, or habit (requires `title`; optional `task_type`, `notes`, `priority`) |
| `score_habit` | Score a habit up or down (requires `task_id`, optional `direction` up/down, default up) |

### Auth pattern: lazy, not eager

**Critical pattern.** Originally the plugin checked `HABITICA_USER_ID` and `HABITICA_API_KEY` at **registration time** in `index.ts`. If the env vars were missing in the process that loaded the plugin (e.g. CLI without systemd env), the tool was silently not registered.

The fix — applied in both `index.ts` and `src/tool.ts`:

```typescript
// index.ts — ALWAYS register, regardless of env
export function register(api) {
  api.registerTool(createHabiticaTool() as AnyAgentTool);
  // Do NOT check env vars here
}

// src/tool.ts — resolve auth at EXECUTION time
function resolveAuth(authOverride?: HabiticaAuth): HabiticaAuth {
  if (authOverride) return authOverride;
  const userId = process.env.HABITICA_USER_ID?.trim();
  const apiKey = process.env.HABITICA_API_KEY?.trim();
  if (!userId || !apiKey) {
    throw new Error(
      "Habitica credentials not configured. Set HABITICA_USER_ID and HABITICA_API_KEY."
    );
  }
  return { userId, apiKey };
}
```

This ensures the tool is always visible to the AI. If credentials are missing, the error surfaces at call time with a clear message rather than silently not working.

### Plugin manifest

```json
{
  "id": "habitica",
  "enabledByDefault": true,
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {}
  }
}
```

`enabledByDefault: true` ensures the plugin loads without requiring explicit config in `openclaw.json`.

### Environment variables

Set in **both** locations:

```bash
# 1. Systemd user service (for gateway process)
systemctl --user edit openclaw-gateway.service
# Add:
# [Service]
# Environment="HABITICA_USER_ID=f84544da-0d30-488e-a66f-82adf4ea26c3"
# Environment="HABITICA_API_KEY=d08e556e-6ff3-427f-ba34-e4066fba3520"

systemctl --user daemon-reload
systemctl --user restart openclaw-gateway

# 2. Shell profile (for CLI agent and cron)
echo 'export HABITICA_USER_ID="f84544da-0d30-488e-a66f-82adf4ea26c3"' >> ~/.bashrc
echo 'export HABITICA_API_KEY="d08e556e-6ff3-427f-ba34-e4066fba3520"' >> ~/.bashrc
```

---

## 6. Feature 4: WhatsApp outbound rate limiter

### Why it exists

The AI can call `whatsapp_send` in rapid succession (broadcast, cron jobs). WhatsApp bans numbers that send too fast. This must live in the **extension layer** (not the MCP), so it protects all send paths: CLI, agent, auto-reply, MCP, cron.

### Files added/modified

| File | Change |
|---|---|
| `extensions/whatsapp/src/outbound-rate-limit.ts` | `WhatsAppRateLimitError` + `createOutboundRateLimiter` |
| `extensions/whatsapp/src/outbound-rate-limit.test.ts` | Vitest unit tests |
| `extensions/whatsapp/src/inbound/monitor.ts` | Wrap `sock.sendMessage` after socket creation |
| `extensions/whatsapp/src/auto-reply/monitor.ts` | Pass `outboundRateLimit` from resolved account |
| `src/config/types.whatsapp.ts` | `outboundRateLimit` type in `WhatsAppSharedConfig` |
| `src/config/zod-schema.providers-whatsapp.ts` | Zod schema in `WhatsAppSharedSchema` |

### How the wrap works

```typescript
// In inbound/monitor.ts, after socket creation:
const rateLimiter = createOutboundRateLimiter(options.outboundRateLimit);
const originalSendMessage = sock.sendMessage.bind(sock);
sock.sendMessage = rateLimiter.wrapSendMessage(originalSendMessage);
```

This single wrap covers **both** send paths:
- Path A: `send.ts → ActiveWebListener → createWebSendApi → sock.sendMessage`
- Path B: `auto-reply → msg.reply / msg.sendMedia → monitor.ts closures → sock.sendMessage`

On reconnect, `monitorWebInbox` exits and is restarted with a fresh socket. Each new socket gets a fresh rate limiter instance — this is correct.

### Config

```json
{
  "channels": {
    "whatsapp": {
      "outboundRateLimit": {
        "maxMessages": 30,
        "windowSeconds": 60
      }
    }
  }
}
```

Omitting `outboundRateLimit` disables it entirely (backward-compatible passthrough).

---

## 7. Feature 5: MCP server for Cursor

See [mcp-implementation-guide.md](mcp-implementation-guide.md) for the detailed MCP server reference. Summary here.

### File: `tools/openclaw-mcp-server.mjs`

Plain ES module (`.mjs`), no build step. Runs on the VM. Cursor connects via SSH stdio.

### Tools exposed (13 total)

| Group | Tools |
|---|---|
| WhatsApp (6) | `whatsapp_status`, `whatsapp_contacts`, `whatsapp_send`, `whatsapp_poll`, `whatsapp_react`, `whatsapp_archive` |
| Habitica (1) | `habitica` |
| Todoist (4) | `todoist_tasks`, `todoist_projects`, `todoist_labels`, `todoist_sections` |
| Cron (1) | `cron` |
| Gateway (1) | `gateway_health` |

### Transport per tool

| Tool | Transport | Why |
|---|---|---|
| `whatsapp_send/poll/react` | HTTP `/tools/invoke` | CLI WebSocket drops in non-interactive SSH |
| `whatsapp_contacts` | CLI `openclaw directory peers list` | No HTTP equivalent |
| `whatsapp_status` | Direct file + HTTP `/health` | CLI takes ~28s (Ollama scan timeout) |
| `whatsapp_archive` | `node:sqlite` direct read | Fastest; no gateway involved |
| `habitica` | HTTP `/tools/invoke` | Native gateway tool |
| `todoist_*` | HTTPS to `api.todoist.com` | External API |
| `cron` | CLI `openclaw cron *` | No HTTP equivalent |
| `gateway_health` | HTTP `GET /health` | Direct endpoint |

### Cursor config: `.cursor/mcp.json`

```json
{
  "mcpServers": {
    "openclaw": {
      "command": "ssh",
      "args": [
        "-i", "/path/to/your/id_rsa",
        "-o", "BatchMode=yes",
        "user@vm-ip",
        "cd ~/openclaw-custom && node --no-warnings tools/openclaw-mcp-server.mjs"
      ]
    }
  }
}
```

**This file is git-ignored.** Copy `.cursor/mcp.json.example` and fill in your SSH key path, username, and VM IP.

### MCP server gotchas

- **`--no-warnings`** is required — `node:sqlite` prints to stderr which breaks the JSON-RPC framing.
- **`cd ~/openclaw-custom` first** — the MCP SDK is in `node_modules`, which only exists in the project root.
- **PATH must be explicit in `spawn`** — SSH sessions don't source `~/.bashrc`. Always prepend `~/.npm-global/bin` in the `env` passed to `child_process.spawn`.
- **`z.record(z.string(), z.any())`** — never `z.record(z.unknown())`. The single-argument form breaks MCP schema generation and causes Cursor to show "No tools, prompts or resources".

---

## 8. Production: Linux VM setup

### VM details

| Property | Value |
|---|---|
| OS | Ubuntu 20.04 |
| GPU | None |
| Node | 22.x |
| Install method | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| Gateway | User systemd service (`systemctl --user`) |
| npm prefix | `~/.npm-global` (user-owned, no sudo) |

### First-time custom build setup

```bash
ssh -i ~/.ssh/id_rsa henzard@192.168.122.82

# Source profile for PATH
source ~/.profile
# Or manually:
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# Clone the fork
cd ~
git clone https://github.com/Kruger-Web-Solutions/openclaw.git openclaw-custom
cd ~/openclaw-custom

# Add upstream for future merges
git remote add upstream https://github.com/openclaw/openclaw.git

# Install deps and build
pnpm install
pnpm build

# Install globally (no sudo — prefix is user-owned)
npm i -g .

# Verify
which openclaw
openclaw --version

# Run doctor
openclaw doctor

# Restart gateway
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway

# Verify
openclaw health
openclaw gateway status
openclaw logs --follow
```

### Routine update (dev → VM)

```bash
# On dev machine (Windows)
git add -A
git commit -m "your change"
git push origin main
git push kws main  # push to org remote too

# On VM
ssh -i ~/.ssh/id_rsa henzard@192.168.122.82
source ~/.profile
cd ~/openclaw-custom
git pull origin main
pnpm install
pnpm build
npm i -g .
openclaw doctor         # ALWAYS run — catches config regressions before restart
openclaw gateway restart
openclaw health         # verify it came back up
```

### When gateway refuses to start: the doctor flow

If `openclaw gateway restart` exits immediately, the cause is almost always a config validation failure. Symptoms:

```
Config invalid; doctor will run with best-effort config.
channels.whatsapp: Unrecognized key: "archive"
Gateway aborted: config is invalid.
```

Fix it:

```bash
# Step 1: see what's wrong
openclaw doctor

# Step 2a: auto-remove unrecognized keys (safe, non-destructive)
openclaw doctor --fix

# Step 2b: or manually edit the config and remove the offending key
nano ~/.openclaw/openclaw.json

# Step 3: retry
openclaw gateway restart
openclaw health
```

This exact error bit us when `archive` was only added to one schema level. See [B1 in §11](#b1-config-invalid-unrecognized-key-on-channelswhatsapparchive).

### PowerShell SSH escaping workaround

**Never** inline multi-line commands in `ssh host "..."` from PowerShell. `&&`, `<`, `>`, `<<'EOF'` are all interpreted by PowerShell before SSH sees them.

**Pattern:**
```powershell
# 1. Write script to local temp file
$script = "cd ~/openclaw-custom && git pull && pnpm install && pnpm build && npm i -g ."
$script | Out-File -FilePath "$env:TEMP\deploy.sh" -Encoding UTF8

# 2. SCP to VM
scp -i $sshKey "$env:TEMP\deploy.sh" "henzard@192.168.122.82:/tmp/deploy.sh"

# 3. Run
ssh -i $sshKey "henzard@192.168.122.82" "bash /tmp/deploy.sh"

# 4. Clean up
ssh -i $sshKey "henzard@192.168.122.82" "rm /tmp/deploy.sh"
Remove-Item "$env:TEMP\deploy.sh"
```

### Gateway environment variables

```ini
# ~/.config/systemd/user/openclaw-gateway.service
[Service]
Environment="HABITICA_USER_ID=your-id"
Environment="HABITICA_API_KEY=your-key"
Environment="OPENROUTER_API_KEY=sk-or-..."
```

After editing: `systemctl --user daemon-reload` then `systemctl --user restart openclaw-gateway`.

---

## 9. Agent alignment: tools, cron, TOOLS.md

This section covers the operational work needed to keep the agent using the right tools rather than falling back to exec or shell scripts.

### Tool allowlist

The `tools.profile: "coding"` profile does **not** include plugin tools by name. Without the right allowlist, the agent will try to use `exec` or `~/bin/habitica` instead of the native tools.

```json
{
  "tools": {
    "profile": "coding",
    "alsoAllow": ["group:plugins"]
  }
}
```

`group:plugins` is a special group that expands to all registered plugin tools. This is the correct way to allow `habitica`, `whatsapp_archive`, and any future plugin tools without naming them individually.

**Do not** use `tools.alsoAllow: ["habitica", "whatsapp_archive"]` — these will produce "unknown entries" warnings until the corresponding plugins are loaded, and the warnings are noisy.

### Model with fallback

The primary model (`x-ai/grok-4.1-fast`) occasionally hits capacity. Add a fallback:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/x-ai/grok-4.1-fast",
        "fallbacks": ["openrouter/deepseek/deepseek-chat-v3-0324"]
      }
    }
  }
}
```

### TOOLS.md

The agent reads `~/.openclaw/workspace/TOOLS.md` at boot. If it's outdated (e.g. still says to use `~/bin/habitica`), the agent will use the wrong path even though the native tool is available.

**Keep TOOLS.md accurate:**

```markdown
## Native Agent Tools

### habitica
- Actions: dashboard, dailies, habits, todos, stats, complete
- Usage: call the `habitica` tool directly — NOT exec, NOT ~/bin/habitica
- Auth: resolved from env at runtime (HABITICA_USER_ID, HABITICA_API_KEY)

### whatsapp_archive
- Actions: search, recent, stats
- Usage: call the `whatsapp_archive` tool directly — NOT exec, NOT raw SQL
```

**Protect TOOLS.md from Memory Synthesis cron:** The Memory Synthesis cron can rewrite TOOLS.md if its prompt doesn't say otherwise. Always include this in the synthesis prompt: **"Do NOT edit TOOLS.md"**.

### Cron job hygiene

**Use native tools in cron prompts.** Old cron jobs used hardcoded SQLite paths and custom scripts that no longer exist. Rewrite them to use native tools:

```
# Bad — brittle, breaks when paths change
node ~/.openclaw/workspace/scripts/whatsapp-archive-query.mjs

# Good — uses the native tool, survives upgrades
Use the native whatsapp_archive tool with action "recent" and limit 200.
Do NOT use exec or raw SQL.
```

**Avoid high-frequency agent crons.** An agent-turn cron (agent processes a prompt, calls a model) every 1 minute costs significant API credits. Acceptable schedules: daily, twice-daily, hourly at most for lightweight jobs.

**Removed crons** (burned credits or ran stale scripts):
- System Heartbeat Logger (every 1 minute — too expensive)
- vm-heartbeat-logger (every 5 minutes — ran `/tmp/vm-heartbeat.sh` which didn't exist)
- worker-watchdog (every 5 minutes — no longer needed)

**Disabled crons:**
- Background Bug Fixer (was fixing bugs we'd already fixed)

---

## 10. Model selection history

We changed the primary model several times. This is the full record so future sessions understand why the current config exists.

| Model | Period | Reason for change |
|---|---|---|
| `openrouter/anthropic/claude-haiku-4-5` | Initial | Default — good quality but too expensive for continuous 24/7 use (crons + WhatsApp) |
| `openrouter/x-ai/grok-4.1-fast` | Current primary | Fast, cheap, handles tool calling reliably, low per-token cost |
| `openrouter/deepseek/deepseek-v3.2` | Brief trial | Tested as alternative; adequate but less consistent with multi-tool chaining |
| `openrouter/deepseek/deepseek-chat-v3-0324` | Current fallback | Used automatically when grok-4.1-fast hits capacity |

### Capacity errors

`x-ai/grok-4.1-fast` occasionally returns `"model at capacity"`. This is transient — usually clears in under 5 minutes. The `fallbacks` config handles it without user intervention:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/x-ai/grok-4.1-fast",
        "fallbacks": ["openrouter/deepseek/deepseek-chat-v3-0324"]
      }
    }
  }
}
```

### Switching models

```bash
# Via CLI (immediate, auto-restarts gateway)
openclaw config set agents.defaults.model.primary "openrouter/x-ai/grok-4.1-fast"

# Or edit ~/.openclaw/openclaw.json directly, then:
openclaw doctor && openclaw gateway restart
```

You can also ask the agent in chat: *"Switch my OpenClaw to openrouter/x-ai/grok-4.1-fast"* — it will make the config change itself.

---

## 11. Upstream merge workflow

The upstream [openclaw/openclaw](https://github.com/openclaw/openclaw) is very active (600+ commits in our first sync). We sync periodically.

### Sync process

```bash
git checkout main
git pull origin main
git checkout -b merge-upstream-main
git fetch upstream
git merge upstream/main --no-edit
```

### Expected conflict files

| File | Conflict type | Resolution |
|---|---|---|
| `extensions/whatsapp/src/channel.ts` | Our archive block vs. upstream import refactors | Keep upstream's import structure; graft our archive block |
| `docs/tools/plugin.md` | Our capability table vs. upstream's provider list | Keep upstream's structure |
| `pnpm-lock.yaml` | Always conflicts | `git checkout --theirs pnpm-lock.yaml` then `pnpm install` |

### channel.ts conflict rule

Upstream periodically moves imports from `openclaw/plugin-sdk/whatsapp` to local files (`./runtime-api.js`, `./directory-config.js`, `./group-policy.js`, `./session-route.js`) and renames plugin API methods (`listActions` → `describeMessageTool`).

**Rule:** Always take upstream's structure for imports and API shape. Re-apply **only** our additions:
- Archive imports (`openArchiveDb`, `archiveInboundMessage`, `archiveOutboundMessage`, `createWhatsAppArchiveTool`, `persistAudioFile`)
- `archiveDb` module-level variable
- Extended `agentTools()` that pushes the archive tool
- The entire archive initialization block in `startAccount` (DB open, `onRawMessage`, hooks, pruning)
- `onRawMessage` passed into `monitorWebChannel`

### After merge

```bash
git add <resolved files>
git commit -m "Merge upstream/main: resolve channel.ts and plugin.md conflicts"
git checkout main
git merge merge-upstream-main -m "Merge branch 'merge-upstream-main'"
git push origin main
git push kws main

# If kws rejects (non-fast-forward), first:
git fetch kws
git merge kws/main -m "Merge kws/main to preserve remote commits"
git push kws main
```

---

## 12. All bugs and fixes

### B1. Config invalid: "Unrecognized key" on `channels.whatsapp.archive`

**Root cause:** `archive` added to `WhatsAppAccountSchema` only; not to `WhatsAppConfigSchema`. The user's flat config used `channels.whatsapp.archive` (top-level), which the schema didn't recognize. Gateway abort on startup.

**Fix:** Modify `src/config/zod-schema.providers-whatsapp.ts` and `extensions/whatsapp/src/channel.ts` to accept `archive` at both the flat top-level and the per-account level.

**Prevention:** For any new WhatsApp config key valid at both levels, add it to **`WhatsAppSharedSchema`**, not separately to each schema. The shared schema flows into both via `.extend()`.

---

### B2. Habitica tool missing in CLI (but present in gateway)

**Root cause:** Plugin registered the tool only if `HABITICA_USER_ID` env var was set at registration time. The CLI spawns its own process which doesn't inherit systemd env vars. So `openclaw agent --local` never saw the `habitica` tool.

**Fix:** Always register the tool; resolve credentials lazily at execution time (`resolveAuth()` in `tool.ts`).

---

### B3. Agent used `~/bin/habitica` instead of native `habitica` tool

**Root cause:** Two issues combined:
1. `tools.alsoAllow` contained `["habitica", "whatsapp_archive"]` — these were flagged as "unknown entries" because the tool allowlist system didn't know them at the time the warning was generated.
2. `TOOLS.md` contained instructions to use `~/bin/habitica`.

**Fix:** Change `tools.alsoAllow` to `["group:plugins"]`. Rewrite `TOOLS.md` to explicitly state the native tools and say "do NOT use exec or shell wrappers".

---

### B4. `python3 -m pip install faster-whisper` fails on Ubuntu 20.04

**Root cause:** Ubuntu 20.04 ships Python 3.8. `faster-whisper` 1.2.x requires Python 3.9+.

**Fix:** Install Python 3.9 from deadsnakes PPA, create a dedicated venv, install there.

---

### B5. `faster-whisper` is a library, not a CLI

**Root cause:** Running `faster-whisper /path/to/audio.ogg` fails with "command not found" or "no such file" depending on install state. The `pip` package provides a Python library, not a CLI entry point.

**Fix:** Create `~/whisper-env/bin/faster-whisper-cli.py` (Python wrapper) and `~/whisper-env/bin/fw-cli.sh` (bash wrapper that activates the venv), symlinked to `~/.npm-global/bin/faster-whisper`.

---

### B6. SSH PATH missing `~/.npm-global/bin`

**Root cause:** SSH sessions start with a minimal environment. `~/.bashrc` is not sourced in non-interactive sessions. `~/.profile` is sourced in login shells, but `ssh host "command"` is often not a login shell.

**Fix (deployment):** Always `source ~/.profile` first when SSHing in, or prefix with `export PATH="$HOME/.npm-global/bin:...PATH"`.

**Fix (MCP server):** Explicitly construct PATH in the `env` passed to `child_process.spawn`:
```javascript
PATH: `${HOME}/.npm-global/bin:${HOME}/.local/bin:${process.env.PATH}`
```

---

### B7. `sudo npm i -g .` installs to wrong prefix

**Root cause:** npm global prefix is `~/.npm-global` (user-owned). `sudo npm` uses root's prefix (`/usr/local/lib`). The user's shell finds neither, or finds the old official version.

**Fix:** `npm i -g .` without `sudo`. The user prefix is writable.

---

### B8. `systemctl restart openclaw-gateway` says "Unit not found"

**Root cause:** The gateway runs as a **user** systemd service, not a system service. `systemctl` without `--user` operates on system services.

**Fix:** Always `systemctl --user restart openclaw-gateway`. After editing the service file: `systemctl --user daemon-reload` first.

---

### B9. Memory Synthesis cron overwrote TOOLS.md

**Root cause:** The Memory Synthesis cron's prompt didn't explicitly forbid editing TOOLS.md. The agent saw TOOLS.md as stale and rewrote it during synthesis.

**Fix:** Add **"IMPORTANT RULES: Do NOT edit TOOLS.md"** to the Memory Synthesis cron prompt.

---

### B10. MCP `node:sqlite` warning breaks JSON-RPC framing

**Root cause:** `node:sqlite` is experimental in Node 22. On startup it prints `ExperimentalWarning: SQLite is an experimental feature` to stderr. The MCP SDK's stdio transport reads both stdout and stderr for framing.

**Fix:** Run with `node --no-warnings tools/openclaw-mcp-server.mjs`.

---

### B11. `z.record(z.unknown())` breaks MCP tool listing

**Root cause:** The `@modelcontextprotocol/sdk` JSON Schema converter doesn't handle the single-argument form of `z.record()`.

**Symptom:** Cursor shows "No tools, prompts or resources".

**Fix:** Use `z.record(z.string(), z.any())` for all record-typed fields.

---

### B12. `openclaw channels status` takes ~28 seconds

**Root cause:** `channels status` scans for Ollama models as part of startup. Ollama isn't running on the VM, so the scan times out (~25s).

**Fix:** Bypass CLI. Read auth state directly from `~/.openclaw/credentials/whatsapp/<account>/creds.json`. Check gateway liveness with a fast HTTP call to `/health`.

---

### B13. CLI `openclaw message send` fails with "gateway client stopped"

**Root cause:** The CLI uses a WebSocket connection to the gateway. In non-interactive SSH sessions, the WebSocket handshake/keepalive behaves differently and drops before the command completes (~3-5s).

**Fix:** Route `whatsapp_send`, `whatsapp_poll`, `whatsapp_react` through HTTP `POST /tools/invoke` instead of CLI.

**Prerequisite:** The gateway must allow the `message` tool:
```json
{ "tools": { "alsoAllow": ["message"] } }
```

---

### B14. Habitica test expected `jsonResult` error return but tool threw

**Root cause:** `readStringParam(..., { required: true })` throws a `ToolInputError`, not returns an error object. The test was checking the return value.

**Fix:**
```typescript
// Before:
const result = await tool.execute(...);
expect(result).toContain("task_id required");

// After:
await expect(tool.execute(...)).rejects.toThrow("task_id required");
```

---

## 13. Lessons learned

### Architecture

- **Config schema: use the shared schema for shared fields.** Any WhatsApp config key valid at top-level AND per-account must go in `WhatsAppSharedSchema`. Putting it only in the account schema causes "Unrecognized key" and gateway abort.
- **Plugin registration must be unconditional.** Never gate `api.registerTool()` on env var presence. Register always; validate credentials at call time.
- **`tools.alsoAllow: ["group:plugins"]` is the correct way to allow plugin tools.** Named entries like `["habitica"]` produce warnings and are fragile to load order.
- **Run the MCP server on the VM.** The CLI only exists on the VM. Tunneling from a local server adds failure modes.
- **HTTP for gateway tools, CLI for non-HTTP.** The CLI's WebSocket connection is unreliable in non-interactive SSH sessions. `/tools/invoke` is rock-solid.
- **One tool per resource type.** A single tool with 20 actions is hard for the AI to use. 4–6 focused tools with 5–9 actions each is better.

### Operations

- **Env vars need to be in TWO places:** systemd service (for the gateway process) and `~/.bashrc`/`~/.profile` (for CLI and cron). They are different processes.
- **`systemctl --user`** — never `sudo systemctl`. The gateway is a user service.
- **`systemctl --user daemon-reload`** is required after every `.service` file edit.
- **`npm i -g .` without `sudo`** when using a user-owned npm prefix (`~/.npm-global`).
- **SCP temp scripts to the VM** rather than inlining complex commands in `ssh host "..."` from PowerShell.
- **SSH sessions don't inherit `~/.bashrc`.** Always construct PATH explicitly or `source ~/.profile` first.

### Agent behavior

- **Keep TOOLS.md accurate.** The agent reads it at boot. If it says to use a shell script, the agent uses the shell script.
- **Cron prompts must name native tools explicitly.** "Use the native `whatsapp_archive` tool" > "run the archive script".
- **High-frequency agent crons are expensive.** Every agent turn calls the model. Daily/task-based schedules are far more cost-effective.
- **Memory Synthesis can overwrite workspace files.** Always add "Do NOT edit TOOLS.md" to its prompt if you've customized that file.

### Node.js / tooling

- **`node:sqlite` needs `--no-warnings`** in Node < 26.
- **`z.record(z.string(), z.any())`** not `z.record(z.unknown())`.
- **`.mjs` extension** for standalone ES modules without `type: "module"` in `package.json`.
- **`crypto.randomUUID()` is a global** in Node ≥ 19 — no import needed.
- **Line number references in plans are approximate.** Upstream changes shift them. Always verify by reading the actual file.

---

## 14. How to add a new feature

### 14.1 New agent plugin tool

1. Create `extensions/<plugin-name>/` with `index.ts`, `openclaw.plugin.json`, `src/tool.ts`, `src/tool.test.ts`
2. Set `"enabledByDefault": true` in `openclaw.plugin.json`
3. Register unconditionally in `index.ts`; resolve credentials at call time in `tool.ts`
4. Add `pnpm test:extension <plugin-name>` to verify tests pass
5. Document in `~/.openclaw/workspace/TOOLS.md` on the VM
6. Deploy: `git pull` on VM, `pnpm install && pnpm build && npm i -g .`, restart gateway

### 14.2 New WhatsApp config key

1. Add to `WhatsAppSharedConfig` interface in `src/config/types.whatsapp.ts`
2. Add to `WhatsAppSharedSchema` Zod object in `src/config/zod-schema.providers-whatsapp.ts` (not to account or config schema separately)
3. Run `openclaw doctor` after deployment to verify no "Unrecognized key" errors
4. Test in flat config (`channels.whatsapp.<key>`) AND per-account (`channels.whatsapp.accounts.default.<key>`)

### 14.3 New MCP tool

See [mcp-implementation-guide.md](mcp-implementation-guide.md) §10 "How to add a new tool" for the full pattern. Summary:

1. Choose transport: external API → `fetchWithTimeout`, gateway tool → `invokeGatewayTool`, CLI → `runCLI`, file/SQLite → direct read
2. Add `server.tool("name", "description", { ...zSchema }, async (params) => { ... })` in `tools/openclaw-mcp-server.mjs`
3. Use `z.record(z.string(), z.any())` for object params — never `z.record(z.unknown())`
4. Use `toContent()` for all return values
5. SCP the updated `.mjs` to the VM — no gateway restart needed
6. Reconnect MCP in Cursor (Command Palette → `MCP: Reconnect servers`)

### 14.4 New cron job

1. Use `openclaw cron add` or the Control UI
2. Write the `payload.message` to explicitly use native tools:
   > "Use the native `<tool-name>` tool with action `<action>`. Do NOT use exec, shell scripts, or raw SQL."
3. Schedule daily or less unless there's a specific reason for higher frequency
4. If the cron involves boot files or memory: add "Do NOT edit TOOLS.md" to the prompt

---

## 15. File map

```
# Fork-specific additions (not in upstream)

extensions/habitica/
  index.ts                         Plugin entry, unconditional registration
  openclaw.plugin.json             Manifest (enabledByDefault: true)
  src/
    tool.ts                        6-action Habitica agent tool (lazy auth)
    tool.test.ts
    api.ts                         Habitica REST client
    api.test.ts

extensions/whatsapp/src/
  outbound-rate-limit.ts           Sliding-window rate limiter
  outbound-rate-limit.test.ts
  inbound/monitor.ts               (MODIFIED) wraps sock.sendMessage with limiter
  auto-reply/monitor.ts            (MODIFIED) passes outboundRateLimit config
  channel.ts                       (MODIFIED) archive init, agentTools, hooks
  archive/
    db.ts                          Schema, migrations
    db.test.ts
    writer.ts                      archiveInboundMessage, archiveOutboundMessage
    writer.test.ts
    reader.ts                      search, recent, stats queries
    reader.test.ts
    agent-tool.ts                  createWhatsAppArchiveTool (native agent tool)
    agent-tool.test.ts
    media-persist.ts               persistAudioFile
    media-persist.test.ts
    index.ts                       Re-exports

src/config/
  types.whatsapp.ts                (MODIFIED) archive + outboundRateLimit types
  zod-schema.providers-whatsapp.ts (MODIFIED) archive + outboundRateLimit schemas

src/media-understanding/
  runner.ts                        (MODIFIED) faster-whisper provider
  runner.entries.ts                (MODIFIED) registered faster-whisper
  runner.faster-whisper.test.ts    Tests

tools/
  openclaw-mcp-server.mjs          MCP server (runs on VM, 14 tools)
  openclaw-mcp-server.test.mjs     Integration tests

.cursor/
  mcp.json.example                 Template (committed)
  mcp.json                         ← git-ignored, contains SSH key path

docs/
  custom/
    implementation-guide.md        ← this file
    mcp-implementation-guide.md    Detailed MCP server reference
  openclaw-best-practices.md       Post-install optimization guide
  contributing-fork-workflow.md    Upstream sync + deployment workflow

DEPLOY.md                          Deployment guide (+ corrections documented within)
CHANGELOG.md                       (MODIFIED) fragments for new features

changelog/fragments/
  whatsapp-archive-habitica-faster-whisper.md  Fragment for our features

# On VM only (not in repo)
~/.openclaw/openclaw.json          Runtime config
~/.openclaw/workspace/TOOLS.md     Agent boot file (native tool documentation)
~/.openclaw/whatsapp/archive.sqlite
~/.openclaw/whatsapp/audio/
~/.openclaw/secrets/todoist-token
~/.openclaw/workspace/config/todoist-groceries.json
~/openclaw-custom/                 Clone of the repo
```

---

*Last updated: March 2026. Covers the full implementation: WhatsApp archive, faster-whisper, Habitica plugin, rate limiter, MCP server, production deployment, agent alignment, upstream merge, SparkyFitness, personal assistant cron system, Todoist structure, and full E2E verification.*

---

---

# Phase 2 — Personal assistant deployment (March 2026)

> This phase transformed the OpenClaw gateway from a developer tool into a fully automated personal assistant, health coach, and life accountability system. Everything below is a verbatim record of what was built, every failure encountered, every fix applied, and every decision made.

---

## 16. Feature 6: SparkyFitness self-hosted nutrition tracker

### What it is

[SparkyFitness](https://github.com/CodeWithCJ/SparkyFitness) is a self-hosted, privacy-first nutrition and health tracker. It replaces MyFitnessPal (no third-party data sharing, no account required). It runs entirely on the VM via Docker Compose and exposes a REST API on port 3004.

### Why self-hosted

The original plan used MyFitnessPal via its unofficial API. That was replaced because:
- MFP's unofficial API is fragile and frequently breaks
- Privacy: macro/weight data is sensitive
- SparkyFitness runs on the same VM, so API calls are localhost — zero latency, no auth complexity beyond an API key

### Architecture

```
VM: Docker Compose
  ├── sparkyfitness-server   (Node.js Express, port 3004 via Nginx)
  ├── sparkyfitness-db       (postgres:16-alpine, port 5432)
  └── nginx                  (reverse proxy, exposes 3004)

~/.openclaw/secrets/sparky-token   ← API key (x-api-key header)
```

### Deployment

Docker Compose source is `~/sparky/`. The override file `~/sparky/docker-compose.override.yml` pins the DB to postgres:16-alpine (see B-SF2 below).

```bash
cd ~/sparky
docker compose up -d
docker ps   # verify sparkyfitness-server + db + nginx are Up
```

Web UI: `http://192.168.122.82:3004/login` — register your account here first, then generate an API key under Settings → API.

### API key storage

```bash
echo "YOUR_KEY" > ~/.openclaw/secrets/sparky-token
chmod 600 ~/.openclaw/secrets/sparky-token
```

The MCP server reads this file at call time via `getSparkyToken()`. If the file doesn't exist, the tool returns a helpful error message rather than crashing at startup.

### Correct SparkyFitness API routes (hard-won)

The SparkyFitness API routes are **not** what the TypeScript `NormalizedFoodSchema` implies. The schema is for search responses; the actual endpoint structure is:

| Action | Method | Endpoint | Key params |
|---|---|---|---|
| Read food diary | GET | `/api/food-entries?selectedDate=YYYY-MM-DD` | `selectedDate` (not `date`) |
| Read goals | GET | `/api/goals/by-date/YYYY-MM-DD` | date in path |
| Dashboard summary | GET | `/api/dashboard/stats?date=YYYY-MM-DD` | returns `eaten`, `goal`, `burned` |
| Read sleep | GET | `/api/sleep?startDate=...&endDate=...` | both dates required |
| Read weight/check-in | GET | `/api/measurements/check-in/YYYY-MM-DD` | date in path |
| Log water | POST | `/api/measurements/water-intake` | `{entry_date, change_drinks, container_id}` |
| Log weight | POST | `/api/measurements/check-in` | `{entry_date, weight}` (kg) |
| Create food | POST | `/api/foods` | **flat** structure (not nested `default_variant`) |
| Create food entry | POST | `/api/food-entries` | `{food_id, variant_id, entry_date, meal_type, quantity, unit}` |
| Delete food entry | DELETE | `/api/food-entries/:id` | |
| Delete food | DELETE | `/api/foods/:id` | |

**Auth header:** `x-api-key: YOUR_TOKEN` (not `Authorization: Bearer`). The middleware auto-maps Bearer to x-api-key if the token looks like an API key (≥64 alphanumeric chars), but using `x-api-key` directly is safer.

**Meal types:** The valid values are `breakfast`, `lunch`, `dinner`, `snacks` (plural). Passing `"snack"` gives "Invalid meal type" error.

**Food creation (flat, not nested):**
```json
{
  "name": "Chicken Breast",
  "is_custom": true,
  "serving_size": 100,
  "serving_unit": "g",
  "calories": 165,
  "protein": 31,
  "carbs": 0,
  "fat": 3.6
}
```
Response includes `id` and `default_variant.id`. Both are needed for the food entry.

**Food entry creation:**
```json
{
  "food_id": "<food.id>",
  "variant_id": "<food.default_variant.id>",
  "entry_date": "2026-03-23",
  "meal_type": "snacks",
  "quantity": 100,
  "unit": "g"
}
```

**Water logging:** Water is container-based. `change_drinks: 1` adds 1 serving of the default container (~250ml). `change_drinks: -1` removes one. The response includes the new running total as `water_ml`.

### Water containers

The user's default container has `volume: 2000ml` with `servings_per_container: 8` (250ml each). `container_id: null` uses the default. The MCP tool converts `amount` (ml) to drinks: `Math.round(amount / 250) || 1`.

### MCP tool (`sparky_fitness`)

The tool is in `tools/openclaw-mcp-server.mjs`. It is a **Cursor MCP tool only** — it is NOT a gateway plugin. The gateway agent (WhatsApp) cannot call it unless a proper OpenClaw extension is built (see §21 notes).

Actions: `diary`, `summary`, `goals`, `log_food`, `log_water`, `weight`, `sleep`.

---

## 17. Feature 7: Personal assistant cron system

### Overview

52 cron jobs covering the user's full daily life. These run inside the OpenClaw gateway via `openclaw cron add`. Each cron fires an agent prompt with `--announce` (WhatsApp delivery) and an optional `--channel whatsapp --to "+27711304241"` for accountability partner messages.

### Cron categories

| Category | Count | Examples |
|---|---|---|
| Weekday morning | 5 | morning-anchor (5am), daily-briefing (6:30am), post-rhyno-call, water-bottle-1 |
| Weekday work | 6 | Nedbank standups, Weighsoft work block, NFPE/NDM standups |
| Weekday afternoon | 6 | water checks, brunch reminder, macro/mood check, day-reflection, family-time |
| Weekday evening | 6 | dinner-water, accountability-audit, exercise-reminder, kealyn-bedtime, evening-meds, sleep-prep |
| Weekend | 4 | saturday-anchor, saturday-shopping, sunday-meal-prep, state-of-me-report (Sunday 8pm) |
| Weekly specials | 3 | nagmal (Friday 6pm), friday-week-close, weekly-intentions-monday |
| Sacred calendar | 14 | Seven Feasts of Israel 2026 with 7-day advance notices + eves |
| Family birthdays | 6 | Alicia 12 June (14-day, 7-day, eve, day), Kealyn 1 August (14-day, 7-day, day) |
| Pre-existing | 7 | Memory Synthesis (every 4h), Daily WhatsApp Summary, Weighsoft daily 8am, Step Tracker, PathCare, Email Reminders |

**Total: 52 active crons**

### Correct `openclaw cron add` syntax

The CLI uses **named flags**, not a `--job` JSON blob:

```bash
openclaw cron add \
  --name "morning-anchor" \
  --cron "0 5 * * 1-5" \
  --timezone "Africa/Johannesburg" \
  --message "Good morning Henzard. It is 5am. Time for Bible reading..." \
  --announce \
  --channel whatsapp \
  --to "+27711304241"
```

`--announce` sends the result to WhatsApp. `--channel` + `--to` are only needed when sending to a different recipient (e.g., accountability partners).

The script is at `docs/custom/vm-deploy/phase7-crons-v2.sh`.

### Accountability partners

If Henzard has 3+ Habitica dailies incomplete by 6pm AND hasn't responded to 3 consecutive cron messages → the `accountability-audit` cron sends WhatsApp messages to both Alicia (+27...) and Rhyno (+27...).

### Sacred calendar cron pattern

Each feast has a 7-day advance notice cron AND an eve cron AND a day-of cron. The cron prompts include the scripture reference (Leviticus 23) and the biblical meaning only — no tradition, no rabbinic addition.

---

## 18. Feature 8: Todoist project structure

### Projects created

| Project | ID | Purpose |
|---|---|---|
| Shopping | `6CrfjhGM476WQJX7` | Pre-existing: grocery and shopping backlog |
| Weighsoft | `6CrfjhGM4V85H3wj` | Pre-existing: Weighsoft client work tasks |
| Nedbank | `6CrfjhGM4HhFMc3h` | Pre-existing: Nedbank tasks |
| Home | `6gF6W9VPrmQJF8Q8` | New: personal and family tasks |
| Books to Read | `6gF6W9fw2w7MvfjJ` | New: reading backlog |

### Labels created

| Label | ID | Purpose |
|---|---|---|
| `in-progress` | `2183350196` | VIP cross-system sync: tasks with this label are also synced to Habitica todos |

### VIP sync routing rule

When the agent receives "in progress: X" or "starting X" via WhatsApp:
1. Create Todoist task with `in-progress` label
2. Create Habitica todo (VIP sync)

When "done with X":
1. Complete Habitica todo
2. Close Todoist task

---

## 19. Phase 2 deployment journal

This section records what was actually done in order. Use this to understand state and reproduce the deployment.

### Step 1 — Fix monitor.ts TypeScript error (pre-requisite for build)

`extensions/whatsapp/src/inbound/monitor.ts` had a TS2345 error where `sock.sendMessage.bind(sock)` was passed to `rateLimiter.wrapSendMessage` whose parameter type was `(...args: unknown[]) => Promise<unknown>`. The specific sendMessage type was incompatible with this generic constraint.

**Fix:** Explicit cast before passing:
```typescript
const _origSendMessage = sock.sendMessage.bind(sock) as (...args: unknown[]) => Promise<unknown>;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
(sock as any).sendMessage = rateLimiter.wrapSendMessage(_origSendMessage);
```

### Step 2 — Habitica plugin: add create_todo and score_habit actions

Extended `extensions/habitica/src/tool.ts` with two new actions:
- `create_todo` — creates a Habitica todo from the agent (VIP sync from WhatsApp)
- `score_habit` — increments or decrements a habit by ID

Both use the existing `habiticaFetch` helper in `src/api.ts`.

### Step 3 — SparkyFitness MCP tool (first version)

Added `sparky_fitness` tool to `tools/openclaw-mcp-server.mjs`. Initial version used wrong routes (see B-SF1 below). After API discovery on the live VM, all routes were corrected (see §16 for the correct table).

Key discovery process:
1. Found the actual route files by running `docker exec sparkyfitness-server ls /app/SparkyFitnessServer/routes/`
2. Read `SparkyFitnessServer.js` for all `app.use()` route registrations
3. Tested each endpoint with curl from the VM using the `x-api-key` header
4. Read the TypeScript schema files inside the container to understand required fields

### Step 4 — Docker install and SparkyFitness deployment

Ubuntu 20.04 (focal) is EOL. The Docker install script warned about this and failed on `docker-model-plugin`. Fix: install without that package:

```bash
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# Re-login or run: newgrp docker
```

SparkyFitness docker-compose: `~/sparky/docker-compose.prod.yml` (in `docker/` subdir of the repo — not root).

PostgreSQL 18+ issue: the stock docker-compose uses the latest postgres image which was 18+. It conflicts with the volume mount path (`/var/lib/postgresql/data` vs `/var/lib/postgresql/18/data`). Solution: pin to `postgres:16-alpine` via a docker-compose override file.

```yaml
# ~/sparky/docker-compose.override.yml
services:
  sparkyfitness-db:
    image: postgres:16-alpine
```

After creating the override: `docker compose down && docker volume prune` (remove stale volumes) + `rm -rf ~/sparky/postgresql ~/sparky/backup ~/sparky/uploads` then `docker compose up -d`.

### Step 5 — Passwordless sudo (deployment-only, reverted)

To streamline automated deployment scripts, temporarily enabled passwordless sudo:
```bash
echo 'henzard ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/henzard-nopasswd
sudo chmod 440 /etc/sudoers.d/henzard-nopasswd
```
**This was removed at the end of the session:**
```bash
sudo rm /etc/sudoers.d/henzard-nopasswd
```
sudo now requires a password again.

### Step 6 — Cron deployment (phase7-crons-v2.sh)

The first cron script (`phase7-crons.sh`) used `--job "$json"` syntax. That was wrong. Discovery: run `openclaw cron add --help`. The correct syntax uses named flags. The entire script was rewritten as `phase7-crons-v2.sh` (45 new crons + 7 pre-existing = 52 total).

### Step 7 — TOOLS.md deployment

`~/.openclaw/workspace/TOOLS.md` is the agent's identity and routing document. It is deployed via SCP from `docs/custom/vm-deploy/TOOLS.md`. Never edit the live file directly — always update the repo copy and SCP it.

### Step 8 — SparkyFitness token received and stored

User registered account at `http://192.168.122.82:3004/login`, generated API key under Settings → API, and provided the token. Stored as:
```bash
echo "TOKEN" > ~/.openclaw/secrets/sparky-token
chmod 600 ~/.openclaw/secrets/sparky-token
```

### Step 9 — MCP route corrections

After storing the token, tested all endpoints and found every route was wrong. Discovery process documented in §16. All 6 actions tested live (HTTP 200) before committing.

### Step 10 — Todoist project setup (phase8-todoist-setup.sh)

Ran `phase8-todoist-setup.sh` from the VM using direct Todoist API calls. Created Home and Books to Read projects, confirmed Weighsoft/Nedbank/Shopping already existed, created the `in-progress` label, and added 4 initial Home tasks.

### Step 11 — E2E verification

Ran `e2e-test.sh`: 34/34 passing. All test data created, verified, and cleaned up. WhatsApp test messages confirmed received on phone.

### Step 12 — sudo restored, all committed

Removed passwordless sudo, committed and pushed all changes.

---

## 20. Phase 2 bugs and fixes

### B-SF1. All SparkyFitness routes were wrong

**Symptom:** Every `sparky_fitness` tool call returned 404.

**Root cause:** The MCP server was built using the TypeScript schema (`NormalizedFoodSchema`, `FoodVariantSchema`) which describes the API response format, not the request format. The actual endpoint paths differ entirely from the schema field names.

**Wrong routes used initially:**
- `/diary?date=...` → actual: `/food-entries?selectedDate=...`
- `/goals` → actual: `/goals/by-date/:date`
- `/water` → actual: `/measurements/water-intake`
- `/weight` → actual: `/measurements/check-in/:date`
- `/sleep?date=...` → actual: `/sleep?startDate=...&endDate=...`

**Fix:** Discovered correct routes by reading the server's actual route files inside the Docker container. See §16 for the full correct table.

---

### B-SF2. PostgreSQL 18+ volume conflict

**Symptom:** `sparkyfitness-db` container kept restarting with "PostgreSQL data in: /var/lib/postgresql/data (unused mount/volume)" and "data directory has wrong ownership".

**Root cause:** PostgreSQL 18 changed the expected data directory path. The old volume from an initial failed run used the old path. The new 18+ image expected a different mount structure.

**Fix:**
1. `docker compose down`
2. Remove old volume: `docker volume ls` + `docker volume rm <id>`
3. Remove data dirs: `rm -rf ~/sparky/postgresql ~/sparky/backup ~/sparky/uploads`
4. Create override file pinning to `postgres:16-alpine`
5. `docker compose up -d`

---

### B-SF3. Wrong `Authorization` header

**Symptom:** API calls returned `{"error":"Authentication required."}` even with the correct token.

**Root cause:** Initial MCP server used `Authorization: Bearer <token>`. SparkyFitness API keys use `x-api-key: <token>`. The middleware only maps Bearer to x-api-key automatically if the token has certain characteristics (64+ chars, alphanumeric-only). The provided token had mixed case, which made the auto-map unreliable.

**Fix:** Changed the MCP server to use `x-api-key` directly.

---

### B-SF4. Food creation: nested `default_variant` structure

**Symptom:** `POST /api/foods` returned HTTP 500 — "null value in column `serving_size` of relation `food_variants` violates not-null constraint".

**Root cause:** The MCP server sent a nested payload matching `NormalizedFoodSchema`:
```json
{ "default_variant": { "serving_size": 100, ... } }
```
But `food.js` model's `createFood` function reads `foodData.serving_size` (flat), not `foodData.default_variant.serving_size`. The repository INSERT uses positional `$2` for `sanitizeNumeric(foodData.serving_size)` which is `null` when the flat field is missing.

**Fix:** Flatten the food payload:
```json
{ "name": "...", "serving_size": 100, "serving_unit": "g", "calories": 165, ... }
```

---

### B-SF5. Food entry: wrong meal type and missing `variant_id`

**Symptom:** `POST /api/food-entries` returned "Invalid meal type: snack".

**Root cause:**
1. SparkyFitness stores meal types as `breakfast`, `lunch`, `dinner`, `snacks` (plural). The MCP tool was sending `snack` (singular).
2. The food entry model requires both `food_id` AND `variant_id`. Without `variant_id`, the JOIN `FROM foods f JOIN food_variants fv ON f.id = fv.food_id WHERE f.id = $1 AND fv.id = $2` returns no rows and the snapshot is null.

**Fix:**
1. Map `snack` → `snacks` in the MCP server: `const mealTypeMap = { snack: "snacks", ... }`
2. Return `default_variant.id` from the food creation step and pass it as `variant_id` in the entry.

---

### B-SF6. Auth header broken in SSH one-liner (PowerShell)

**Symptom:** SSH commands with quotes inside the remote command string failed with `unexpected EOF` or PowerShell parse errors.

**Root cause:** PowerShell mangles quotes inside `ssh host "remote command with 'quotes'"`. Single quotes, double quotes, and backticks all cause different parse errors.

**Fix:** SCP a bash script to the VM (`/tmp/test-xxx.sh`) and execute it with `ssh host "bash /tmp/test-xxx.sh"`. No quoting issues because the script file handles its own quoting.

---

### B-CRON1. `openclaw cron add --job "$json"` syntax error

**Symptom:** `error: required option '--name <name>' not specified`

**Root cause:** The initial cron script was written with `--job '{"name":"...","cron":"...","message":"..."}'` assuming the CLI accepted a JSON blob. This syntax does not exist in the OpenClaw cron CLI.

**Fix:** Discovered by running `openclaw cron add --help`. The correct syntax uses individual flags: `--name`, `--cron`, `--timezone`, `--message`, `--announce`, `--channel`, `--to`.

---

### B-CRON2. SSH PATH missing `openclaw` binary in test

**Symptom:** In `e2e-test.sh`, `openclaw cron list` returned 0 lines because `openclaw` was not in the SSH session's PATH.

**Root cause:** SSH non-interactive sessions don't source `~/.bashrc` or `~/.profile`. `openclaw` lives at `~/.npm-global/bin/openclaw` which is not in the default SSH PATH.

**Fix:** Use the full path in scripts: `OPENCLAW="$HOME/.npm-global/bin/openclaw"`.

---

### B-DOCKER1. Ubuntu 20.04 EOL + docker-model-plugin missing

**Symptom:** `E: Unable to locate package docker-model-plugin` during `curl -fsSL https://get.docker.com | sudo sh`.

**Root cause:** Ubuntu 20.04 (focal) reached EOL. The Docker install script installs `docker-model-plugin` which doesn't have a focal package.

**Fix:** Skip the convenience script. Use the Docker apt repository directly and install only the core packages:
```bash
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin
```

---

### B-DOCKER2. `newgrp docker` failed in SSH session

**Symptom:** `newgrp: group 'docker' does not exist` after `sudo usermod -aG docker $USER`.

**Root cause:** `usermod -aG` adds the user to the group but the current SSH session's group membership isn't updated until the session ends and a new one starts. `newgrp docker` needs the group to exist in the current session context.

**Fix:** End the SSH session, reconnect, then `docker` commands work without `sudo`.

---

### B-WA1. `openclaw message send` CLI fails in SSH with "gateway timeout after 10000ms"

**Symptom:** Sending a WhatsApp message via `openclaw message send ...` from an SSH session failed every time.

**Root cause:** The CLI opens a WebSocket connection to the gateway. In a non-interactive SSH session the WebSocket handshake is unstable and times out.

**Fix:** Use the gateway HTTP API directly:
```bash
curl -s -X POST http://localhost:18789/tools/invoke \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json,sys; print(json.dumps({'tool':'message','args':{'action':'send','channel':'whatsapp','to':'+27711304241','message':sys.argv[1]}}))" "Your message here")"
```
Token is at `~/.openclaw/openclaw.json` → top-level `token` field.

---

## 21. Phase 2 lessons learned

### SparkyFitness API

- **Never trust schema files for route discovery.** Read the actual `app.use()` registrations in the server entry point and test with curl.
- **Auth headers matter.** Use `x-api-key` not `Authorization: Bearer` for API keys.
- **Meal types are plural.** `snacks` not `snack`. Always check enum values against the actual meal_types table (`GET /api/meal-types`).
- **Two-step food logging.** SparkyFitness requires: (1) create food → get `food.id` + `default_variant.id`, (2) create food entry with both IDs. There is no single-call "log food by name" endpoint.
- **Water is container-based.** You don't POST `amount_ml`. You POST `change_drinks` + `container_id`. The default container is ~250ml per drink. Undo by posting `change_drinks: -1`.
- **Flat food body.** The POST `/api/foods` body is flat (`serving_size`, `calories`, etc. at top level), NOT nested inside `default_variant`.
- **postgres:16-alpine for stability.** postgres:18+ changed the default data directory structure, breaking older volume mounts. Pin to 16.

### Docker on EOL systems

- **`docker-model-plugin` doesn't exist on Ubuntu 20.04.** Never use the convenience script on EOL distros. Use the apt repository and install only `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose-plugin`, `docker-buildx-plugin`.
- **Group membership requires session restart.** `sudo usermod -aG docker $USER` takes effect on the next login, not the current session. Don't try to `newgrp docker` in a non-login shell.

### Passwordless sudo for deployment

- **Useful for one-off deployment sessions; dangerous to leave on.** Add it, do all the deployment, remove it at the end. Document the removal step.
- **Pattern:** `echo 'user ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/user-nopasswd` + `sudo chmod 440 /etc/sudoers.d/user-nopasswd`. Remove with `sudo rm /etc/sudoers.d/user-nopasswd`.

### SparkyFitness as agent tool

- **`sparky_fitness` is Cursor-only.** It lives in the Cursor MCP server (`openclaw-mcp-server.mjs`). The gateway agent (WhatsApp) uses the plugin system. These are separate tool registries.
- **To make SparkyFitness available via WhatsApp**, build a proper OpenClaw extension (like `extensions/habitica`). The pattern is: create `extensions/sparkyfitness/`, add plugin manifest, register an agent tool that calls the SparkyFitness API via fetch.

### Cron system

- **`openclaw cron add` uses named flags, not JSON.** Run `--help` before writing any automation.
- **`--announce` delivers to WhatsApp.** No need to add a separate `--channel whatsapp --to "+27..."` unless sending to a different recipient than the primary WhatsApp account.
- **PATH must be explicit in cron tests.** Use `$HOME/.npm-global/bin/openclaw` not `openclaw`.
- **52 is a lot of crons.** Use `openclaw cron list` to audit before adding more. Check for near-duplicate prompts (e.g., two morning crons at the same time).

### E2E testing principle

- **Unit tests are not enough.** Real integration tests that create, read back, and delete actual data are the only way to verify an API integration works. Build the test harness before shipping.
- **Clean up after every test.** Every test that creates data must delete it. The test harness (`e2e-test.sh`) restores all state: water is reversed, weight is restored, food + entry are deleted, Todoist task is deleted.
- **Test the full stack.** A test that only calls curl directly misses MCP serialization bugs. The `e2e-test.sh` tests both direct API and gateway invoke paths.

---

## 22. E2E test harness

The file `docs/custom/vm-deploy/e2e-test.sh` is the canonical verification script. Run it any time you make changes to SparkyFitness, Todoist, or cron configuration.

### What it tests (34 checks)

| Section | Tests |
|---|---|
| Gateway health | Port 18789 responding |
| SparkyFitness reads | Dashboard stats, goals, check-in/weight, water, sleep |
| SparkyFitness writes | Water +250ml (verified + reversed), weight 75kg (verified + restored to original), custom food creation, diary entry, dashboard update |
| Todoist | Task creation with `in-progress` label, read-back (project + labels), project list |
| Gateway plugins | `todoist_tasks` via `/tools/invoke`, `habitica` via `/tools/invoke`, sparky direct API |
| Cron jobs | Count (≥50), spot-check 8 known names |
| WhatsApp | Test message sent (round-trip confirmed by human) |
| Cleanup | All 5 created objects deleted, original state restored |

### How to run

```bash
scp docs/custom/vm-deploy/e2e-test.sh henzard@192.168.122.82:/tmp/e2e-test.sh
ssh henzard@192.168.122.82 "bash /tmp/e2e-test.sh"
```

Expected: `34 passed, 0 failed`.

### Updating the test

If you add a new system (e.g., SparkyFitness exercise logging):
1. Add a CREATE section with `CLEANUP+=("type:id:")`
2. Add a VERIFY step (read back and assert)
3. Add a cleanup case in section 8

---

## 23. Updated file map

```
# Phase 2 additions to the repo

docs/custom/
  vm-deploy/
    TOOLS.md                         Agent identity, routing rules, project IDs, sacred calendar
    calendar-2026.json               Seven Feasts of Israel + family birthdays (JSON for agent)
    phase7-crons-v2.sh               45 new cron jobs (correct --name/--cron/--message syntax)
    phase8-todoist-setup.sh          Creates Todoist projects + in-progress label via REST API
    e2e-test.sh                      34-check E2E harness: create/verify/cleanup all systems
    check-habitica-full.sh           Audit existing Habitica dailies/habits/todos
    send-wa-sparky.sh                Standalone WhatsApp send via curl (bypasses CLI WebSocket)
    deploy-all.ps1                   PowerShell orchestrator (SCP + SSH phases)
    phase2-deploy-code.sh            VM: git pull + build + install
    phase2b-build-install.sh         Retry: build + install after prior failure
    phase3b-sparky-start.sh          Docker Compose SparkyFitness setup
    test-sparky-final.sh             Confirms all 6 SparkyFitness endpoints return HTTP 200
    [20+ other test/debug scripts]   API discovery scripts (safe to delete after onboarding)

tools/
  openclaw-mcp-server.mjs            (MODIFIED) sparky_fitness tool with correct routes + auth

extensions/habitica/src/
  tool.ts                            (MODIFIED) added create_todo + score_habit actions

extensions/whatsapp/src/inbound/
  monitor.ts                         (MODIFIED) TS2345 fix: explicit cast for sendMessage bind

# On VM only (not in repo)
~/.openclaw/secrets/sparky-token     SparkyFitness API key
~/.openclaw/secrets/todoist-token    Todoist API token
~/sparky/                            SparkyFitness Docker Compose dir
~/sparky/docker-compose.override.yml pins postgres:16-alpine
```

---

*Last updated: March 2026. Phase 2 complete: SparkyFitness, 52 crons, Todoist structure, Habitica integration verified, 34/34 E2E tests passing.*
