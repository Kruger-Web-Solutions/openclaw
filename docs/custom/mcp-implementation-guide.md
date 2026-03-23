# OpenClaw MCP Server — Implementation Guide

> **Audience:** Developers extending this fork, future contributors, and anyone wanting to add new MCP tools or replicate this setup from scratch.
>
> This guide covers the MCP server specifically. For the full end-to-end story (WhatsApp archive, faster-whisper, Habitica, rate limiter, deployment, cron alignment, upstream merge), see [implementation-guide.md](implementation-guide.md).
>
> This guide captures the full plan, every architectural decision, every painful bug, and everything we learned building the OpenClaw MCP server. If you are doing this again or adding to it, read this first.

---

## Table of Contents

1. [What we built](#1-what-we-built)
2. [Architecture](#2-architecture)
3. [The plan — original requirements](#3-the-plan--original-requirements)
4. [WhatsApp outbound rate limiter](#4-whatsapp-outbound-rate-limiter)
5. [MCP server implementation](#5-mcp-server-implementation)
6. [Todoist integration](#6-todoist-integration)
7. [Deployment](#7-deployment)
8. [Bugs and fixes — full log](#8-bugs-and-fixes--full-log)
9. [Lessons learned](#9-lessons-learned)
10. [How to add a new tool](#10-how-to-add-a-new-tool)
11. [File map](#11-file-map)
12. [SparkyFitness tool — complete reference](#12-sparkyFitness-tool--complete-reference)

---

## 1. What we built

A **Model Context Protocol (MCP) server** that lets Cursor (or any MCP-compatible client) talk to a live OpenClaw instance as a set of AI-callable tools — with Cursor's native approval flow for every action.

| Capability | Tools |
|---|---|
| WhatsApp | `whatsapp_status`, `whatsapp_contacts`, `whatsapp_send`, `whatsapp_poll`, `whatsapp_react`, `whatsapp_archive` |
| Habitica | `habitica` (dashboard / dailies / habits / todos / stats / complete / create_todo / score_habit) |
| Todoist | `todoist_tasks`, `todoist_projects`, `todoist_labels`, `todoist_sections` |
| Cron | `cron` |
| SparkyFitness | `sparky_fitness` (diary / log_food / log_water / goals / weight / summary / sleep) |
| Gateway | `gateway_health` |

**Total: 14 tools.**

Secondary deliverable: a per-account **WhatsApp outbound rate limiter** baked into the OpenClaw extension layer, protecting all send paths (not just MCP) from anti-spam bans.

---

## 2. Architecture

```
Cursor IDE (Windows dev machine)
  │
  │  SSH stdio tunnel (BatchMode, no password)
  ▼
node --no-warnings tools/openclaw-mcp-server.mjs   ← runs ON the VM
  │
  ├── spawn openclaw CLI           ~/.npm-global/bin/openclaw
  │     used by: contacts, cron
  │
  ├── HTTP → localhost:18789        OpenClaw Gateway
  │     used by: whatsapp_send, whatsapp_poll, whatsapp_react, habitica, gateway_health
  │
  ├── node:sqlite (direct read)     ~/.openclaw/whatsapp/archive.sqlite
  │     used by: whatsapp_archive
  │
  ├── fs.readFileSync               ~/.openclaw/credentials/whatsapp/<account>/creds.json
  │     used by: whatsapp_status
  │
  └── fetch → api.todoist.com/api/v1
        token: ~/.openclaw/secrets/todoist-token
        config: ~/.openclaw/workspace/config/todoist-groceries.json
        used by: todoist_tasks, todoist_projects, todoist_labels, todoist_sections
```

### Why the server runs on the VM, not locally

The `openclaw` CLI only exists on the VM. The gateway WebSocket is only reachable on `localhost:18789` from the VM. Running the server locally would require SSH tunnels for everything and still wouldn't work well due to WebSocket latency and connection drops.

**The correct mental model:** The MCP server is a thin adapter — it just translates MCP JSON-RPC calls into local CLI/HTTP/SQLite calls on the VM. Cursor tunnels its stdio over SSH to reach it.

#### The pivot story — why we didn't stay local

The server was **initially built to run locally on Windows**, with SSH helper functions (`sshRun`, `runOnVM`, `queryArchiveOnVM`) to execute CLI commands remotely and `queryArchiveOnVM` using `ssh … sqlite3` for archive reads.

This failed in three ways:

1. **"Tool not available: message"** — The gateway's `tools.profile: "coding"` didn't include `message` in its allowlist. `/tools/invoke` rejected it. Workaround needed: add `"message"` to `tools.alsoAllow`.

2. **"gateway client stopped"** — Even after allowing `message`, the CLI-via-SSH path for `openclaw message send` dropped its WebSocket connection 3–5 seconds into every call. No controlling terminal in the SSH session meant keepalives didn't work.

3. **MCP SDK not found** — When we moved the server to the VM but launched it from `~` instead of `~/openclaw-custom`, `Cannot find package '@modelcontextprotocol/sdk'` crashed the server on every startup.

The decision to run the server **directly on the VM** (launched via `ssh … node tools/openclaw-mcp-server.mjs`) eliminated all three issues at once: CLI runs locally (no SSH overhead), the gateway WebSocket is local, and the SDK is in `node_modules` right there.

**Lesson: do not try to bridge two machines in an MCP server. Run where the tools are.**

### Why SSH stdio (not HTTP/WebSocket transport)

- Zero extra ports to open or firewall
- Cursor natively supports `command`/`args` in `.cursor/mcp.json`
- SSH gives mutual auth for free
- The MCP SDK's `StdioServerTransport` handles framing

---

## 3. The plan — original requirements

These were the requirements gathered before implementation:

### Must-have

- **WhatsApp send** — compose and send a message to a JID or group
- **Contact resolution** — list contacts/groups so the AI can confirm the right recipient before sending
- **Message archive** — query past messages (full-text, by contact, recent N)
- **WhatsApp session status** — know if the account is authenticated before trying to send
- **Habitica** — dashboard, dailies, complete tasks
- **Cron management** — list/add/update/remove/run scheduled jobs
- **Gateway health** — surface gateway errors without SSH-ing in
- **Security** — every tool call requires Cursor's explicit approval; tokens never committed

### Should-have

- Anti-spam rate limiting on all WhatsApp outbound sends (built into the extension, not the MCP)
- Voice note awareness in archive results (`is_voice_note` boolean)
- Todoist integration (was a standalone Python script; needed MCP exposure)
- `.cursor/mcp.json.example` template so any developer can set up in minutes

### Explicitly out of scope

- Incoming message notifications / push (MCP is request-response only; use `whatsapp_archive` to poll)
- Multi-account selection at runtime (account is fixed per MCP server instance via `openclaw.json`)

---

## 4. WhatsApp outbound rate limiter

### Why it was needed

The AI can call `whatsapp_send` in a loop (e.g. broadcasting to multiple groups). WhatsApp will ban numbers that send too fast. This needed to be in the **extension layer**, not the MCP server, so it protects all send paths — auto-reply, agent tools, and MCP.

### Files changed

| File | Change |
|---|---|
| `extensions/whatsapp/src/outbound-rate-limit.ts` | New — sliding window limiter, `WhatsAppRateLimitError`, `createOutboundRateLimiter` |
| `extensions/whatsapp/src/outbound-rate-limit.test.ts` | New — unit tests |
| `extensions/whatsapp/src/inbound/monitor.ts` | Wrap `sock.sendMessage` with the limiter |
| `extensions/whatsapp/src/auto-reply/monitor.ts` | Pass `outboundRateLimit` config through |
| `extensions/whatsapp/src/accounts.ts` | Add `outboundRateLimit` to `ResolvedWhatsAppAccount` |
| `src/config/types.whatsapp.ts` | Add `outboundRateLimit` to `WhatsAppSharedConfig` |
| `src/config/zod-schema.providers-whatsapp.ts` | Add Zod schema for `outboundRateLimit` |

### How it works

```typescript
export class WhatsAppRateLimitError extends Error {
  readonly retryAfterMs: number;
  constructor(retryAfterMs: number, windowConfig: { maxMessages: number; windowSeconds: number }) {
    super(
      `Outbound rate limit exceeded (${windowConfig.maxMessages} messages in ${windowConfig.windowSeconds}s). ` +
      `Retry in ${Math.ceil(retryAfterMs / 1000)}s.`
    );
    this.name = "WhatsAppRateLimitError";
    this.retryAfterMs = retryAfterMs;
  }
}

// Sliding window: track timestamps of recent sends
// acquire() throws WhatsAppRateLimitError if window is full
// wrapSendMessage() wraps sock.sendMessage transparently

const limiter = createOutboundRateLimiter({
  maxMessages: 10,
  windowSeconds: 60,
});
const send = limiter.wrapSendMessage(sock.sendMessage.bind(sock));
```

### Config

```json
{
  "providers": {
    "whatsapp": {
      "outboundRateLimit": {
        "maxMessages": 10,
        "windowSeconds": 60
      }
    }
  }
}
```

Omitting `outboundRateLimit` disables the limiter (backward-compatible).

---

## 5. MCP server implementation

### File: `tools/openclaw-mcp-server.mjs`

Plain ES module (`.mjs`) — no build step, no TypeScript. This was intentional: the file gets SCP'd to the VM and run directly. A TypeScript compile step would add friction to the deploy loop.

### Key helpers

#### `runCLI(args, timeoutMs)` — spawn openclaw locally

```javascript
function runCLI(args, timeoutMs = 15_000) {
  return new Promise((resolve) => {
    const env = {
      ...process.env,
      PATH: `${HOME}/.npm-global/bin:${HOME}/.local/bin:${process.env.PATH}`,
    };
    const child = spawn(OPENCLAW, [...args, "--json"], { env, stdio: ["ignore","pipe","pipe"] });
    // ... timeout, stdout collect, JSON parse
  });
}
```

**Critical:** SSH sessions don't inherit `~/.bashrc` PATH. Always prepend `~/.npm-global/bin` explicitly, otherwise `openclaw` is not found.

#### `fetchWithTimeout(url, opts, ms)` — HTTP with deadline

```javascript
async function fetchWithTimeout(url, opts = {}, ms = 10_000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await fetch(url, { ...opts, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}
```

Always use this instead of bare `fetch`. The gateway can hang connections.

#### `invokeGatewayTool(tool, params)` — POST to `/tools/invoke`

Used for `whatsapp_send`, `whatsapp_poll`, `whatsapp_react`, `habitica`. These go via HTTP because the CLI's WebSocket connection to the gateway is unreliable in non-interactive SSH sessions (see bug log §8.3).

**Gateway prerequisite:** The gateway must have `message` in its tool allowlist or the call will return `"Tool not available: message"`. The `coding` profile does not include it by default:

```json
{
  "tools": {
    "profile": "coding",
    "alsoAllow": ["message"]
  }
}
```

Without this, `invokeGatewayTool("message", ...)` returns a 403-like error and WhatsApp sends silently fail.

#### `toContent(result)` — normalise to MCP response

```javascript
function toContent(result) {
  const text = result.ok
    ? JSON.stringify(result.data ?? result.raw ?? result, null, 2)
    : `Error: ${result.error}`;
  return { content: [{ type: "text", text }], ...(result.ok ? {} : { isError: true }) };
}
```

### Tool routing decisions

| Tool | Implementation | Reason |
|---|---|---|
| `whatsapp_send/poll/react` | HTTP `POST /tools/invoke` | CLI WebSocket unreliable in SSH session |
| `whatsapp_contacts` | CLI `openclaw directory peers list` | No HTTP equivalent |
| `whatsapp_status` | Direct file read + HTTP `/health` | CLI `channels status` takes ~28s (Ollama model scan timeout) |
| `whatsapp_archive` | `node:sqlite` direct read | Fastest; avoids CLI entirely |
| `habitica` | HTTP `POST /tools/invoke` | Native gateway tool |
| `todoist_*` | Direct HTTPS to `api.todoist.com` | External API, no gateway involvement |
| `cron` | CLI `openclaw cron *` | No HTTP equivalent |
| `gateway_health` | HTTP `GET /health` | Gateway exposes this directly |

### `whatsapp_status` — why we rewrote it

Initially used `openclaw channels status`. This command scans for Ollama models, taking ~28 seconds. The 15s timeout would kill it every time.

**Fix:** Read `~/.openclaw/credentials/whatsapp/<account>/creds.json` directly for auth state, and hit `GET /health` for gateway liveness. Returns in under 1 second.

### `node:sqlite` and the `--no-warnings` flag

`node:sqlite` is experimental in Node 22. It prints a warning to stderr on startup:

```
ExperimentalWarning: SQLite is an experimental feature and might change at any time
```

This warning goes to stderr which is part of the MCP stdio stream and will break the JSON-RPC framing. **Always run with `node --no-warnings`** in `.cursor/mcp.json`.

### Zod schema gotcha — `z.record()`

The `cron` tool originally used `z.record(z.unknown())` for the `job` and `patch` fields. This caused `Cannot read properties of undefined (reading '_zod')` during MCP schema generation, resulting in Cursor showing "No tools, prompts or resources".

**Fix:**

```javascript
// Wrong:
job: z.record(z.unknown())
// Correct:
job: z.record(z.string(), z.any())
```

Always use the two-argument form of `z.record()` when accepting arbitrary objects.

---

## 6. Todoist integration

### Background

The Todoist integration was **discovered**, not planned from scratch. When investigating why Todoist "didn't seem right," we found:

1. A standalone Python script (`~/.openclaw/workspace/scripts/add-todoist-grocery.py`) on the VM that added grocery items directly to Todoist via `urllib.request`. It had never been exposed to the AI agent — it was a manual script.
2. A grocery store config at `~/.openclaw/workspace/config/todoist-groceries.json` mapping stores to Todoist project/section IDs.
3. A Todoist token at `~/.openclaw/secrets/todoist-token`.
4. **A critical bug in the script** (see below).

The right path was: fix the script, then expose the full Todoist CRUD surface via MCP tools so the AI can use it natively. We:

1. Fixed the critical bug in the script
2. Added grocery-config-aware store detection to the MCP server
3. Exposed full CRUD for all Todoist resource types

### The grocery script bug

```python
# Original — NameError: payload referenced before assignment
if store.get('section_id'):
    payload['section_id'] = store['section_id']  # payload not defined yet!
payload = {
    'content': content,
    'project_id': CONFIG['project']['id'],
    'section_id': store['section_id'],  # also: ignores null section_id
}

# Fixed
payload = {
    "content": content,
    "project_id": CONFIG["project"]["id"],
}
if store.get("section_id"):
    payload["section_id"] = store["section_id"]
```

### Todoist API v1 — key facts

- Base URL: `https://api.todoist.com/api/v1`
- Auth: `Authorization: Bearer <token>`
- Every mutating request should include `X-Request-Id: <uuid>` (idempotency)
- Tasks use `POST /<id>` for updates (not `PATCH`)
- `close` and `reopen` are separate endpoints: `POST /tasks/<id>/close` / `POST /tasks/<id>/reopen`
- Sections support `archive`/`unarchive` just like projects
- `DELETE` returns 204 No Content — handle empty response body

### Grocery config shape

Stored at `~/.openclaw/workspace/config/todoist-groceries.json`. Full production config:

```json
{
  "project": { "id": "6CrfjhGM476WQJX7", "name": "Shopping" },
  "default_store": "checkers",
  "stores": {
    "checkers":         { "section_id": "6g9Gp2H3W3M3vpJf", "section_name": "Checkers",        "aliases": ["checkers"] },
    "dischem":          { "section_id": "6g9Gp2RQxxpvpcW7", "section_name": "Dischem",          "aliases": ["dischem","dis-chem"] },
    "takealot":         { "section_id": "6g9Gp2WPCvJjH5cf", "section_name": "TakeALot",         "aliases": ["takealot","take a lot"] },
    "faithfultonature": { "section_id": "6g9Gp2gx3gmRF5xf", "section_name": "FaithfulToNature", "aliases": ["faithfultonature","faithful to nature","nature"] },
    "pharmacy":         { "section_id": "6g9Gp2RQxxpvpcW7", "section_name": "Pharmacy",         "aliases": ["pharmacy","meds","supplements","pharma"] },
    "djvleis":          { "section_id": "6g9Gp2hJwQ7jWVm7", "section_name": "DJ Vleis",         "aliases": ["djvleis","dj vleis","butcher"] },
    "pnp":              { "section_id": "6g9Gp2f5Rmw26CH7", "section_name": "PnP",              "aliases": ["pnp","pick n pay","picknpay","pick and pay"] },
    "woolies":          { "section_id": "6g9Gp2hJwQ7jWVm7", "section_name": "Woolies",          "aliases": ["woolies","woolworths"] },
    "builders":         { "section_id": null,                "section_name": "Builders",         "aliases": ["builders"] }
  }
}
```

**Note:** `builders` has `section_id: null`. The grocery action must handle this gracefully by skipping `section_id` in the API payload — this was part of the script bug fix.

Store is auto-detected from the task content string by matching aliases. Falls back to `default_store` ("checkers") if nothing matches.

### Tool split decision

Originally one `todoist` tool with 4 actions. Expanded to 4 tools:

| Tool | Actions | Resource type |
|---|---|---|
| `todoist_tasks` | list, get, create, grocery, update, delete, close, reopen, move | Task |
| `todoist_projects` | list, get, create, update, delete, archive, unarchive | Project |
| `todoist_labels` | list, get, create, update, delete | Label |
| `todoist_sections` | list, get, create, update, delete, archive, unarchive | Section |

Splitting by resource type rather than having one giant enum makes it clearer to the AI which tool to pick, and keeps each schema focused.

---

## 7. Deployment

### One-time VM setup

```bash
# 1. Node.js ≥ 20 with user-owned global prefix
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 2. Install openclaw globally (from repo root on VM)
npm install -g .

# 3. Create the secrets directory
mkdir -p ~/.openclaw/secrets
echo "your-todoist-token" > ~/.openclaw/secrets/todoist-token
chmod 600 ~/.openclaw/secrets/todoist-token

# 4. MCP SDK is in the repo's node_modules — no extra install needed
# Just run the server from ~/openclaw-custom (the project root)
```

### Deploy the MCP server (after any code change)

```bash
# From repo root on dev machine (Windows)
scp tools/openclaw-mcp-server.mjs <user>@<vm-ip>:~/openclaw-custom/tools/openclaw-mcp-server.mjs
```

> **No gateway restart needed.** The MCP server is a separate process — changes take effect immediately on the next Cursor MCP reconnect.

### Deploy gateway changes (TypeScript source changes)

```bash
# Build
npm run build

# SCP the compiled output to VM  (or git pull on VM)
scp -r dist/ <user>@<vm-ip>:~/openclaw-custom/dist/

# Restart gateway — user-level systemd (NOT sudo systemctl)
systemctl --user daemon-reload          # required after any .service file change
systemctl --user restart openclaw-gateway
```

**Common mistake:** using `sudo systemctl restart openclaw-gateway`. The gateway runs as a user service — this will say "Unit not found".

### Environment variables — need BOTH locations

| Location | Used by |
|---|---|
| Systemd service env (`~/.config/systemd/user/openclaw-gateway.service`) | Gateway process |
| `~/.bashrc` or `~/.profile` | CLI commands (`openclaw agent --local`, etc.) |

SSH sessions source neither by default. The MCP server works around this by constructing `PATH` explicitly in `runCLI`.

### `.cursor/mcp.json` setup (dev machine)

```bash
cp .cursor/mcp.json.example .cursor/mcp.json
# Fill in: SSH key path, username, VM IP
```

`.cursor/mcp.json` is git-ignored. Never commit it — it contains the path to your SSH key.

---

## 8. Bugs and fixes — full log

This is the full history of issues encountered and how they were resolved. Read this before debugging.

### 8.1 `openclaw` CLI not found in SSH session

**Symptom:** `runCLI` resolves `{ ok: false, error: "spawn openclaw ENOENT" }`.

**Cause:** SSH sessions don't source `~/.bashrc`. `~/.npm-global/bin` is not in `PATH`.

**Fix:** Prepend `HOME/.npm-global/bin:HOME/.local/bin` to `PATH` in the `env` passed to `spawn`. This is already in `runCLI` — don't remove it.

### 8.2 Zod `z.record(z.unknown())` breaks MCP schema generation

**Symptom:** Cursor shows "No tools, prompts or resources".

**Cause:** The MCP SDK's JSON Schema converter chokes on the single-arg `z.record()` form.

**Fix:** `z.record(z.string(), z.any())` for all record-typed fields.

### 8.3 CLI `openclaw message send` fails with "gateway client stopped"

**Symptom:** `openclaw message send` returns `Error: gateway client stopped` ~3–5 seconds after starting.

**Cause:** The CLI uses a WebSocket connection to the gateway. In an SSH session, the process has no controlling terminal and the WebSocket handshake/keepalive behaves differently. The connection drops before the command completes.

**Fix:** Route `whatsapp_send`, `whatsapp_poll`, `whatsapp_react` through HTTP `POST /tools/invoke` instead of the CLI.

**Prerequisite:** The gateway's tool policy must allow the `message` tool:
```json
{
  "tools": {
    "alsoAllow": ["message"]
  }
}
```

### 8.4 `openclaw channels status` takes ~28 seconds

**Symptom:** `whatsapp_status` always returns "timed out".

**Cause:** `channels status` scans for Ollama models as part of its health check. This scan times out at ~25s on the VM because Ollama isn't running.

**Fix:** Bypass the CLI entirely. Read auth state from `~/.openclaw/credentials/whatsapp/<account>/creds.json` directly, check gateway liveness with a fast HTTP call to `/health`.

### 8.5 `node:sqlite` warning breaks MCP stdio

**Symptom:** On the very first MCP call, Cursor shows a parse error or the connection drops.

**Cause:** Node 22 prints `ExperimentalWarning: SQLite is an experimental feature` to stderr. The MCP SDK reads both stdout and stderr for the stdio transport.

**Fix:** Add `--no-warnings` to the node command in `.cursor/mcp.json`:
```
"node --no-warnings tools/openclaw-mcp-server.mjs"
```

### 8.6 MCP SDK not found — "Cannot find package '@modelcontextprotocol/sdk'"

**Symptom:** The server exits immediately with a module resolution error.

**Cause:** The server was being launched from `~` (home directory), not from `~/openclaw-custom` where `node_modules` lives.

**Fix:** Always `cd` to the project root before running the server:
```
"cd ~/openclaw-custom && node --no-warnings tools/openclaw-mcp-server.mjs"
```

### 8.7 `whatsapp_contacts` times out (25s)

**Symptom:** `openclaw directory peers list` consistently takes 20–30 seconds.

**Cause:** The `directory` command connects to the gateway WebSocket to resolve peers. In SSH sessions this is slow.

**Fix:** Increased the `runCLI` timeout for this specific command to 25,000ms. Accept the latency — there's no faster path for directory listing.

### 8.8 PowerShell mangles multi-line SSH commands

**Symptom:** Any `ssh host "..."` command with newlines, heredocs (`<<'EOF'`), or `&&` fails with PowerShell parse errors.

**Root cause:** PowerShell treats `<`, `>`, `&&`, `||` as operators in the outer shell before SSH sees them.

**Workaround pattern:**
1. Write the script to a local temp file
2. `scp` it to `/tmp/` on the VM
3. `ssh host "bash /tmp/script.sh"` (simple, no special chars)
4. `ssh host "rm /tmp/script.sh"` to clean up

**Do not attempt** to pass multi-line scripts inline via PowerShell `ssh`. It will never work.

### 8.9 Todoist `payload` referenced before assignment (Python script)
**Symptom:** `add-todoist-grocery.py` throws `NameError: name 'payload' is not defined`.

**Cause:** The original script tried to set `payload['section_id']` on line N, but `payload = {}` was on line N+3.

**Fix:** Initialize `payload` first, then conditionally add `section_id`:
```python
payload = { "content": content, "project_id": CONFIG["project"]["id"] }
if store.get("section_id"):
    payload["section_id"] = store["section_id"]
```

### 8.10 `sudo npm install -g .` fails on user-owned npm prefix

**Symptom:** `sudo npm i -g .` installs to `/usr/local/lib` but `openclaw` command not found for the user.

**Cause:** npm global prefix is `~/.npm-global` (user-owned). `sudo` installs to root's prefix.

**Fix:** Always use `npm install -g .` **without sudo**. The prefix is user-owned and doesn't need elevated permissions.

---

### 8.11 Gateway blocked `message` tool — "Tool not available: message"

**Symptom:** `whatsapp_send` returns `{ ok: false, error: "Tool not available: message" }` even though the gateway is up and healthy.

**Cause:** The gateway `tools.profile: "coding"` profile does not include the `message` tool by default. `POST /tools/invoke` with `tool: "message"` returns a 403-equivalent error.

**Fix:** Add `"message"` to `tools.alsoAllow` in `~/.openclaw/openclaw.json`:

```json
{
  "tools": {
    "profile": "coding",
    "alsoAllow": ["message"]
  }
}
```

Then restart the gateway: `systemctl --user restart openclaw-gateway`.

This is a **one-time config change** on the VM. It must be done before any WhatsApp sends from the MCP server will work.

---

### 8.12 `whatsapp_contacts` returned `[]` — not a bug

**Symptom:** `whatsapp_contacts` consistently returns an empty array.

**Initial suspicion:** MCP invocation error, or `openclaw directory peers list` broken.

**Root cause:** The WhatsApp directory was genuinely empty. No peers had been added yet.

**Verification:**
```bash
ssh -i $sshKey henzard@192.168.122.82 "source ~/.profile && openclaw directory peers list --channel whatsapp --json"
# Returns: []
```

**Takeaway:** An empty response from `whatsapp_contacts` is valid. The directory populates as WhatsApp messages are sent and received. Do not debug the MCP layer until you've verified the underlying CLI returns data.

---

### 8.13 `runCLILenient` created then removed

**Context:** Before the `whatsapp_status` bypass was implemented, we introduced a `runCLILenient` function — a variant of `runCLI` that returned partial results or `null` instead of an error object if the CLI timed out. This was intended to let `whatsapp_status` return something rather than nothing.

**Why it was removed:** `runCLILenient` with a 20s timeout still timed out on `openclaw channels status` (which took ~28s due to Ollama scan). The output was incomplete and unusable. The approach was abandoned in favour of the direct file read + HTTP health check combination (which takes < 1s).

**Lesson:** Don't try to make a slow CLI call work by tolerating failures — replace it entirely with a faster data source.

---

## 9. Lessons learned

### Architecture

- **Run the MCP server on the VM, not locally.** The CLI is only on the VM. Trying to tunnel everything via SSH from a local server adds complexity and failure modes with no benefit. We tried local with SSH helpers — it failed on WebSocket drops, tool allowlist blocks, and module resolution. Moving to VM fixed all three at once.
- **Use HTTP for gateway-native tools, CLI for everything else.** The gateway's WebSocket-based CLI commands are fragile in non-interactive SSH sessions. The REST API (`/tools/invoke`) is reliable.
- **Direct file/SQLite reads beat the CLI for frequently-called, latency-sensitive tools.** `whatsapp_status` and `whatsapp_archive` are both faster and more reliable reading files directly.
- **One tool per resource type, not one tool per concept.** A single "todoist" tool with 20 actions is hard for the AI to use correctly. Four focused tools with 5–9 actions each are better.
- **Don't tolerate a slow CLI call — replace it.** `runCLILenient` with a generous timeout still timed out. The right fix was to bypass the CLI entirely.

### Security

- **Never put tokens in `.cursor/mcp.json`.** Use files in `~/.openclaw/secrets/` (not in the repo) and read them at runtime.
- **`.cursor/mcp.json` must be git-ignored.** It contains your SSH key path and may contain secrets. Add it to `.gitignore` before the first commit.
- **Cursor's native tool approval is your safety net.** The MCP server should never auto-approve or batch actions. Let Cursor ask for each one.

### Deployment

- **Always `systemctl --user`** — never `sudo systemctl` — for the OpenClaw gateway.
- **Always `systemctl --user daemon-reload`** after editing the `.service` file.
- **Env vars need to be in the systemd service AND `.bashrc`.** The gateway process reads from systemd; CLI commands in a login shell read from `.bashrc`. You need both.
- **SCP is more reliable than `git pull` for rapid iteration.** When iterating fast, SCP the changed file directly. Save `git pull` for larger syncs.

### Node.js

- **`node:sqlite` needs `--no-warnings`** on any Node < 26 where it's still experimental.
- **Always add explicit `PATH` in `spawn` env** when running from SSH sessions.
- **`crypto.randomUUID()` is a global in Node ≥ 19** — no import needed.
- **`.mjs` extension is required** for ES modules without a `type: "module"` in `package.json`. The MCP server is standalone and easier as `.mjs`.

### Debugging workflow

1. SCP a test shell script to `/tmp/` on the VM, run it via `ssh host "bash /tmp/test.sh"`, delete it.
2. Test the Todoist/gateway API directly with `curl` on the VM before writing Node code.
3. To verify tool count without starting the full MCP server: `grep -c "server.tool(" tools/openclaw-mcp-server.mjs`
4. To check gateway tool invocability: `curl -s -X POST http://localhost:18789/tools/invoke -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{"tool":"message","args":{"action":"send",...}}'`
5. **Verify the underlying CLI before blaming the MCP layer.** `whatsapp_contacts` returning `[]` looked like a bug but was an empty directory. Always SSH and run the CLI command manually to check the raw output first.
6. **Empty response ≠ error.** Many valid CLI/API calls return empty lists. Distinguish between "the tool failed" and "there's genuinely no data."

---

## 10. How to add a new tool

### Step 1 — Decide the transport

| Your tool needs to... | Use |
|---|---|
| Call an external REST API | Direct `fetchWithTimeout` in the tool handler |
| Use a gateway-native tool | `invokeGatewayTool("tool-name", params)` |
| Run an `openclaw` CLI command | `runCLI(["command", "subcommand", ...])` |
| Read local files/SQLite | `readFileSync` / `new DatabaseSync(...)` |

### Step 2 — Write the tool

```javascript
server.tool(
  "my_tool",
  "One-line description of what this tool does and when to use it.",
  {
    action:    z.enum(["list", "get", "create", "update", "delete"]).describe("Action to perform."),
    id:        z.string().optional().describe("Item ID — required for get, update, delete."),
    name:      z.string().optional().describe("Item name — required for create."),
    // ... other fields
  },
  async ({ action, id, name }) => {
    if (["get","update","delete"].includes(action) && !id) {
      return { content: [{ type: "text", text: `id is required for action=${action}.` }], isError: true };
    }
    // ... action routing
    return toContent(await someRequest(...));
  },
);
```

**Rules:**
- Use `z.record(z.string(), z.any())` — never `z.record(z.unknown())`
- Always validate required params upfront and return `isError: true` with a clear message
- Use `toContent()` for all responses
- Add a descriptive `.describe()` to every parameter — the AI uses this to know what to pass

### Step 3 — Update the header comment

```javascript
/**
 * Exposes N tools:
 *   ...
 *   MySection (1): my_tool
 */
```

### Step 4 — Deploy and verify

```bash
scp tools/openclaw-mcp-server.mjs <user>@<vm-ip>:~/openclaw-custom/tools/openclaw-mcp-server.mjs

# Count registered tools on VM
ssh <user>@<vm-ip> "grep -c 'server.tool(' ~/openclaw-custom/tools/openclaw-mcp-server.mjs"
```

Then reconnect the MCP server in Cursor: Command Palette → **MCP: Reconnect servers**.

### Step 5 — Add secrets if needed

For any new external API token:

```bash
# On the VM
echo "your-api-token" > ~/.openclaw/secrets/<service>-token
chmod 600 ~/.openclaw/secrets/<service>-token
```

Define a constant at the top of the server:

```javascript
const MY_SERVICE_TOKEN_PATH = `${HOME}/.openclaw/secrets/myservice-token`;
```

Read it at call time (not at startup) so the server doesn't fail to start if the token is missing — just return an error from the specific tool.

---

## 11. File map

```
tools/
  openclaw-mcp-server.mjs         MCP server (runs on VM)
  openclaw-mcp-server.test.mjs    Integration tests (vitest)
  add-todoist-grocery.py          Fixed Python grocery script (also on VM)
  README.md                       Quick-start guide

.cursor/
  mcp.json.example                Template — copy to mcp.json and fill in
  mcp.json                        ← git-ignored, contains your SSH key path

extensions/whatsapp/src/
  outbound-rate-limit.ts          Sliding-window rate limiter
  outbound-rate-limit.test.ts     Unit tests
  inbound/monitor.ts              Wraps sock.sendMessage with the limiter
  auto-reply/monitor.ts           Passes outboundRateLimit config through
  accounts.ts                     ResolvedWhatsAppAccount gets outboundRateLimit
  archive/agent-tool.ts           is_voice_note field added to archive results

src/config/
  types.whatsapp.ts               outboundRateLimit TypeScript type
  zod-schema.providers-whatsapp.ts  outboundRateLimit Zod schema

docs/custom/
  mcp-implementation-guide.md     ← this file

On VM only (not in repo):
  ~/.openclaw/secrets/todoist-token
  ~/.openclaw/secrets/sparky-token
  ~/.openclaw/workspace/config/todoist-groceries.json
  ~/openclaw-custom/              Clone of the repo on the VM
  ~/sparky/                       SparkyFitness Docker Compose
```

---

## 12. SparkyFitness tool — complete reference

This section is a supplement to the Phase 2 deployment record in `implementation-guide.md §16–20`. It focuses specifically on the MCP tool implementation.

### Tool name: `sparky_fitness`

**Important:** This tool is only accessible via the Cursor MCP connection. The OpenClaw gateway agent (WhatsApp) does NOT have access to it — the gateway uses its own plugin registry. To expose SparkyFitness to the WhatsApp agent, build a proper `extensions/sparkyfitness` OpenClaw plugin.

### Auth

```javascript
const SPARKY_TOKEN_PATH = `${HOME}/.openclaw/secrets/sparky-token`;
// Header: "x-api-key": token   (NOT Authorization: Bearer)
```

The SparkyFitness middleware maps `Authorization: Bearer <token>` to `x-api-key` automatically for 64+ alphanumeric tokens, but `x-api-key` direct is more reliable.

### Actions and correct endpoints

```javascript
// diary: read food entries
GET /api/food-entries?selectedDate=YYYY-MM-DD        // NOT /diary?date=

// summary: dashboard + goals combined
GET /api/dashboard/stats?date=YYYY-MM-DD             // returns {eaten, goal, burned, remaining}
GET /api/goals/by-date/YYYY-MM-DD                    // returns {calories, protein, carbs, fat, water_goal_ml, ...}

// goals: just nutrition goals
GET /api/goals/by-date/YYYY-MM-DD

// log_food: 2-step — create food THEN create entry
POST /api/foods     body: {name, is_custom:true, serving_size, serving_unit, calories, protein, carbs, fat}
POST /api/food-entries  body: {food_id, variant_id, entry_date, meal_type, quantity, unit}

// log_water: container-based (+250ml per drink)
POST /api/measurements/water-intake  body: {entry_date, change_drinks, container_id:null}

// weight (GET)
GET /api/measurements/check-in/YYYY-MM-DD

// weight (POST)
POST /api/measurements/check-in  body: {entry_date, weight}  // weight in kg

// sleep
GET /api/sleep?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD  // both required
```

### Meal type normalization

```javascript
const mealTypeMap = {
  breakfast: "breakfast",
  lunch: "lunch",
  dinner: "dinner",
  snack: "snacks",   // ← must be plural
  snacks: "snacks",
};
```

### Food creation: flat body

The `NormalizedFoodSchema` TypeScript type uses `default_variant` nesting. The actual `POST /api/foods` endpoint uses a **flat** body. Sending nested `default_variant` causes a null constraint violation on the `food_variants.serving_size` column.

### Water undo pattern

```javascript
// Undo 1 drink:
POST /api/measurements/water-intake  body: {entry_date, change_drinks: -1, container_id: null}
```

---

*Last updated: March 2026. Covers the full implementation from initial plan through Todoist CRUD expansion, SparkyFitness integration, and route corrections.*
