# OpenClaw MCP Server

A [Model Context Protocol](https://modelcontextprotocol.io/) server that runs **on your OpenClaw VM** and exposes 13 tools to any MCP-compatible client (Cursor, Claude Desktop, etc.) over an SSH stdio tunnel.

## Tools

| Tool | Actions |
|---|---|
| `whatsapp_status` | Check WhatsApp auth state and gateway liveness |
| `whatsapp_contacts` | List known WhatsApp contacts/groups |
| `whatsapp_send` | Send a text or media message |
| `whatsapp_poll` | Create a poll message |
| `whatsapp_react` | React to a message with an emoji |
| `whatsapp_archive` | Query the local message archive (full-text search, voice note aware) |
| `habitica` | Manage Habitica tasks — dashboard, dailies, habits, todos, stats, complete |
| `todoist_tasks` | Full task CRUD: list, get, create, grocery, update, delete, close, reopen, move |
| `todoist_projects` | Project (list) CRUD: list, get, create, update, delete, archive, unarchive |
| `todoist_labels` | Label (category) CRUD: list, get, create, update, delete |
| `todoist_sections` | Section CRUD: list, get, create, update, delete, archive, unarchive |
| `cron` | Manage OpenClaw scheduled tasks: list, add, update, remove, run |
| `gateway_health` | Check OpenClaw gateway status and active config |

## Prerequisites

- OpenClaw gateway running on your Linux VM (`systemctl --user start openclaw-gateway`)
- Node.js ≥ 20 on the VM
- `@modelcontextprotocol/sdk` installed — it's already in the project's `node_modules`
- SSH key-based access from your dev machine to the VM (no password prompts)
- A Todoist API token if you want Todoist tools (free at <https://app.todoist.com/app/settings/integrations/developer>)

## Setup

### 1. Deploy to the VM

From the project root on your dev machine:

```bash
# From the repo root — scp the server script to your VM
scp tools/openclaw-mcp-server.mjs <user>@<vm-ip>:~/openclaw-custom/tools/openclaw-mcp-server.mjs
```

The server reads config directly from `~/.openclaw/openclaw.json` — no extra env vars needed.

### 2. Todoist secrets (optional)

On the VM, store your API token in:

```
~/.openclaw/secrets/todoist-token
```

And optionally a grocery-store config in:

```
~/.openclaw/workspace/config/todoist-groceries.json
```

See `tools/add-todoist-grocery.py` for the expected config shape. The `todoist_tasks grocery` action uses this config to auto-route items to the right project/section based on store keywords in the task name.

### 3. Configure Cursor (or Claude Desktop)

Copy the example config and fill in your details:

```bash
cp .cursor/mcp.json.example .cursor/mcp.json
# Edit .cursor/mcp.json — set your SSH key path, username, and VM IP
```

`.cursor/mcp.json` is git-ignored to keep secrets out of version control.

**Example `.cursor/mcp.json`:**

```json
{
  "mcpServers": {
    "openclaw": {
      "command": "ssh",
      "args": [
        "-i", "~/.ssh/id_rsa",
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ServerAliveInterval=30",
        "you@192.168.x.x",
        "cd ~/openclaw-custom && node --no-warnings tools/openclaw-mcp-server.mjs"
      ]
    }
  }
}
```

### 4. Reload Cursor

Open the Command Palette → **MCP: Reconnect servers** (or restart Cursor). You should see all 13 tools available.

## Architecture

```
Cursor IDE (dev machine)
  └── SSH stdio tunnel
        └── node tools/openclaw-mcp-server.mjs  (on VM)
              ├── openclaw CLI  (local spawn)
              ├── OpenClaw Gateway HTTP  http://localhost:18789
              ├── WhatsApp archive  ~/.openclaw/whatsapp/archive.sqlite
              └── Todoist API v1  https://api.todoist.com/api/v1
```

All tool calls go through Cursor's native approval flow — nothing runs without your explicit approval.

## Outbound Rate Limiting

All WhatsApp sends are protected by a per-account sliding-window rate limiter (configured in `openclaw.json` under `whatsapp.outboundRateLimit`). This prevents anti-spam bans when the AI sends multiple messages in quick succession.

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
