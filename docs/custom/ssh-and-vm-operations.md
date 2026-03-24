# SSH and VM operations

> Everything you need to SSH into the production VM, run commands safely, debug the gateway, and avoid the pitfalls we hit. Read this alongside [implementation-guide.md](implementation-guide.md).

---

## Table of contents

1. [VM details](#1-vm-details)
2. [SSH key setup (Windows)](#2-ssh-key-setup-windows)
3. [Connecting — interactive vs non-interactive shells](#3-connecting--interactive-vs-non-interactive-shells)
4. [PATH and environment on the VM](#4-path-and-environment-on-the-vm)
5. [PowerShell SSH gotchas](#5-powershell-ssh-gotchas)
6. [Temporary sudo without password](#6-temporary-sudo-without-password)
7. [Deploying changes](#7-deploying-changes)
8. [Gateway operations](#8-gateway-operations)
9. [Diagnostics and log reading](#9-diagnostics-and-log-reading)
10. [Config management](#10-config-management)
11. [Model selection and switching](#11-model-selection-and-switching)
12. [Quick reference](#12-quick-reference)

---

## 1. VM details

| Property | Value |
|---|---|
| Host | `192.168.122.82` |
| User | `henzard` |
| OS | Ubuntu 20.04 |
| Node | 22.x |
| npm global prefix | `~/.npm-global` |
| OpenClaw source | `~/openclaw-custom/` |
| OpenClaw config | `~/.openclaw/openclaw.json` |
| Gateway port | `18789` |
| Systemd service | `openclaw-gateway` (user-level) |

---

## 2. SSH key setup (Windows)

### Key location

```powershell
# Your SSH private key
$sshKey = "C:\Users\henza\.ssh\id_rsa"

# Your SSH public key (already on the VM)
# C:\Users\henza\.ssh\id_rsa.pub
```

### Test the connection

```powershell
ssh -i $sshKey henzard@192.168.122.82
```

You should get a shell prompt. If you get a password prompt instead of a key-based login, the public key is not in `~/.ssh/authorized_keys` on the VM.

### Add your public key to the VM (if needed)

```powershell
# Option A — if you can still log in with a password
$pubKey = Get-Content "C:\Users\henza\.ssh\id_rsa.pub"
ssh henzard@192.168.122.82 "mkdir -p ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

# Option B — use ssh-copy-id from WSL
ssh-copy-id -i ~/.ssh/id_rsa.pub henzard@192.168.122.82
```

### `BatchMode=yes` — required for MCP

The MCP server config uses `BatchMode=yes` so the connection never hangs waiting for a password or host verification prompt:

```json
{
  "mcpServers": {
    "openclaw": {
      "command": "ssh",
      "args": [
        "-i", "C:/Users/henza/.ssh/id_rsa",
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "henzard@192.168.122.82",
        "cd ~/openclaw-custom && node --no-warnings tools/openclaw-mcp-server.mjs"
      ]
    }
  }
}
```

`StrictHostKeyChecking=accept-new` accepts the host key automatically on first connect but rejects unexpected changes (protects against MITM).

**Why `BatchMode=yes`:** Cursor spawns the SSH process in the background. If SSH asks for input (password, "are you sure?"), the process hangs indefinitely with no visible prompt. `BatchMode=yes` makes SSH fail immediately instead of prompting.

---

## 3. Connecting — interactive vs non-interactive shells

This is the most common source of "command not found" and missing environment variable bugs on the VM.

### Shell types and what they source

| How you connect | Shell type | Sources |
|---|---|---|
| `ssh user@host` (interactive) | Interactive login shell | `~/.profile`, `~/.bash_profile`, `~/.bashrc` |
| `ssh user@host "command"` | Non-interactive, non-login | **Nothing** — raw minimal environment |
| `ssh user@host -t "bash"` | Interactive non-login | `~/.bashrc` only |
| Systemd service | Non-interactive | Service file `Environment=` lines only |
| Cron job | Non-interactive | Service file `Environment=` lines only |
| `openclaw agent --local` | Spawned process | Inherits parent's env |

### The problem

Running `ssh henzard@192.168.122.82 "openclaw gateway restart"` fails with `openclaw: command not found` because:

1. `~/.bashrc` is NOT sourced for `ssh host "command"` runs
2. `~/.npm-global/bin` is set in `~/.bashrc`
3. So `openclaw` is not on PATH

### Solutions

**For interactive SSH sessions (the normal case):**

```powershell
ssh -i $sshKey henzard@192.168.122.82
# Once connected, run:
source ~/.profile
# Now ~/.npm-global/bin is in PATH and openclaw works
```

**Or, in one command:**

```powershell
ssh -i $sshKey henzard@192.168.122.82 "source ~/.profile && openclaw --version"
```

**For scripts run via `ssh host "..."`:**

Always prepend the PATH manually:

```bash
ssh -i $sshKey henzard@192.168.122.82 \
  "export PATH=\$HOME/.npm-global/bin:\$HOME/.local/bin:\$PATH && openclaw --version"
```

**For the MCP server (spawning sub-processes):**

The `runCLI` function in `openclaw-mcp-server.mjs` always prepends `~/.npm-global/bin` in the `env` passed to `child_process.spawn`. Do not remove this — it is critical.

---

## 4. PATH and environment on the VM

### The npm global prefix

When OpenClaw was installed on the VM, npm was configured to use a **user-owned** prefix so `sudo` is never needed:

```bash
npm config set prefix ~/.npm-global
# Results in:
# Binaries: ~/.npm-global/bin/
# Packages: ~/.npm-global/lib/node_modules/
```

This means `openclaw` is at `~/.npm-global/bin/openclaw`.

### ~/.bashrc additions

These lines were added to `~/.bashrc` during initial setup:

```bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
export HABITICA_USER_ID="<your-habitica-user-id>"
export HABITICA_API_KEY="<your-habitica-api-key>"
export OPENROUTER_API_KEY="sk-or-..."
```

These are only active for interactive shells and `openclaw agent --local` runs. The gateway process reads its env from the **systemd service file** instead.

### Systemd service environment

```ini
# ~/.config/systemd/user/openclaw-gateway.service (excerpt)
[Service]
Environment="HABITICA_USER_ID=<your-habitica-user-id>"
Environment="HABITICA_API_KEY=<your-habitica-api-key>"
Environment="OPENROUTER_API_KEY=sk-or-..."
Environment="OPENCLAW_GATEWAY_TOKEN=your-token"
```

To edit:

```bash
systemctl --user edit openclaw-gateway.service
# This opens a drop-in override file in $EDITOR
# Add [Service] Environment= lines
```

After editing **always run:**

```bash
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
```

Forgetting `daemon-reload` means the old config is still running even if you edited the file.

---

## 5. PowerShell SSH gotchas

This is the single biggest source of wasted time. **Read this before running any complex SSH command from PowerShell.**

### What PowerShell mangles

PowerShell treats these characters as its own operators **before** SSH sees them:

| Character | PowerShell meaning | What you wanted SSH to see |
|---|---|---|
| `&&` | AND operator | "run next command if first succeeds" (bash) |
| `\|\|` | OR operator | "run next command if first fails" (bash) |
| `<` | Input redirect | stdin redirect |
| `>` | Output redirect | stdout redirect |
| `<<'EOF'` | Heredoc | heredoc (broken entirely) |
| `$var` | PowerShell variable | bash variable (use `\$var` or single quotes) |

### What breaks

```powershell
# BROKEN — PowerShell parses && before SSH sees it
ssh -i $sshKey henzard@192.168.122.82 "cd ~/openclaw-custom && git pull && npm i -g ."

# BROKEN — heredoc
ssh -i $sshKey henzard@192.168.122.82 "cat > /tmp/test.sh << 'EOF'
echo hello
EOF"
```

### The correct pattern: SCP a script

```powershell
# 1. Write the script to a local temp file
$script = @"
#!/bin/bash
export PATH=`$HOME/.npm-global/bin:`$HOME/.local/bin:`$PATH
cd ~/openclaw-custom
git pull origin main
pnpm install
pnpm build
npm i -g .
openclaw gateway restart
"@
$tmpFile = "$env:TEMP\deploy-openclaw.sh"
$script | Out-File -FilePath $tmpFile -Encoding UTF8 -NoNewline

# 2. SCP to VM
scp -i $sshKey $tmpFile "henzard@192.168.122.82:/tmp/deploy-openclaw.sh"

# 3. Run it
ssh -i $sshKey henzard@192.168.122.82 "bash /tmp/deploy-openclaw.sh"

# 4. Clean up
ssh -i $sshKey henzard@192.168.122.82 "rm /tmp/deploy-openclaw.sh"
Remove-Item $tmpFile
```

### Simple single commands are fine

Single commands without `&&`, `<`, `>` or heredocs work fine directly:

```powershell
# These work from PowerShell
ssh -i $sshKey henzard@192.168.122.82 "systemctl --user restart openclaw-gateway"
ssh -i $sshKey henzard@192.168.122.82 "openclaw health"
ssh -i $sshKey henzard@192.168.122.82 "cat ~/.openclaw/openclaw.json"
```

### `$sshKey` variable reminder

```powershell
# Always set this first in your PowerShell session
$sshKey = "C:\Users\henza\.ssh\id_rsa"
```

---

## 6. Temporary sudo without password

During deployment setup you may need `sudo` for things like `apt install`. The VM was set up without a memorable sudo password. Here is how to grant temporary passwordless sudo:

### Grant NOPASSWD (temporary)

```bash
# On the VM
sudo visudo
# Add this line (at the END of the file, after all other rules):
henzard ALL=(ALL) NOPASSWD: ALL
```

Or using a drop-in file (safer, easy to remove):

```bash
echo "henzard ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/henzard-nopasswd
sudo chmod 440 /etc/sudoers.d/henzard-nopasswd
```

### Remove NOPASSWD when done

```bash
sudo rm /etc/sudoers.d/henzard-nopasswd
```

**Important:** Remove this as soon as you're done with the privileged operations. Do not leave passwordless sudo permanently on a production box.

### Why you rarely need sudo for OpenClaw

The whole npm prefix and node setup is **user-owned**. For normal OpenClaw operations you never need sudo:
- `npm i -g .` — no sudo (user-owned prefix)
- `systemctl --user ...` — no sudo (user-level systemd)
- `pnpm install && pnpm build` — no sudo
- Reading/writing `~/.openclaw/` — no sudo

Sudo is only needed for `apt install`, `add-apt-repository`, Python venv setup, or firewall rules.

---

## 7. Deploying changes

### Option A: Git pull on VM (recommended for normal releases)

```powershell
# On Windows — commit and push first
git add -A
git commit -m "your changes"
git push origin main
git push kws main   # also push to org remote

# Then on VM
ssh -i $sshKey henzard@192.168.122.82
source ~/.profile
cd ~/openclaw-custom
git pull origin main
pnpm install     # only needed if package.json changed
pnpm build       # only needed for TypeScript source changes
npm i -g .       # only needed if the CLI entry changed
openclaw gateway restart
```

### Option B: SCP for fast iteration on the MCP server

The MCP server is a plain `.mjs` file — no build step. SCP it directly:

```powershell
scp -i $sshKey tools/openclaw-mcp-server.mjs "henzard@192.168.122.82:~/openclaw-custom/tools/openclaw-mcp-server.mjs"
# No gateway restart needed. Reconnect MCP in Cursor: Command Palette → "MCP: Reconnect servers"
```

### What requires a gateway restart vs what doesn't

| Change | Requires gateway restart? |
|---|---|
| TypeScript source (`extensions/`, `src/`) | Yes — build first, then restart |
| `openclaw.json` config | Yes — gateway reads config on startup |
| `tools/openclaw-mcp-server.mjs` | No — it's a separate process |
| `~/.openclaw/workspace/TOOLS.md` | No — read at each agent turn |
| Cron jobs (added via CLI/UI) | No — persisted in gateway state |
| Systemd service env vars | Yes — `daemon-reload` then restart |

### Full deploy script (PowerShell)

```powershell
$sshKey = "C:\Users\henza\.ssh\id_rsa"
$vm = "henzard@192.168.122.82"

$script = @"
#!/bin/bash
export PATH=`$HOME/.npm-global/bin:`$HOME/.local/bin:`$PATH
cd ~/openclaw-custom
git pull origin main
pnpm install
pnpm build
npm i -g .
openclaw doctor
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
sleep 3
openclaw health
"@

$tmpFile = "$env:TEMP\oc-deploy.sh"
$script | Out-File -FilePath $tmpFile -Encoding UTF8 -NoNewline
scp -i $sshKey $tmpFile "${vm}:/tmp/oc-deploy.sh"
ssh -i $sshKey $vm "bash /tmp/oc-deploy.sh"
ssh -i $sshKey $vm "rm /tmp/oc-deploy.sh"
Remove-Item $tmpFile
```

---

## 8. Gateway operations

### Start / stop / restart

```bash
# Restart (most common)
systemctl --user restart openclaw-gateway
# or via CLI (works if gateway is already up):
openclaw gateway restart

# Stop
systemctl --user stop openclaw-gateway

# Start
systemctl --user start openclaw-gateway

# Status
systemctl --user status openclaw-gateway

# Enable on boot (already done during setup)
systemctl --user enable openclaw-gateway
```

**Critical rule:** Always use `systemctl --user`. Never `sudo systemctl` — the gateway is a user-level service. `sudo systemctl restart openclaw-gateway` will say "Unit openclaw-gateway.service not found."

### After editing the service file

```bash
# MANDATORY after any change to the .service file
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
```

Forgetting `daemon-reload` means the old unit definition is still in systemd's memory. Your edits have no effect until you reload.

### Gateway service file

```bash
# Location
~/.config/systemd/user/openclaw-gateway.service

# Edit safely (creates a drop-in override, preserves the original)
systemctl --user edit openclaw-gateway.service
```

### Check if gateway is reachable

```bash
curl -s http://localhost:18789/health | python3 -m json.tool
```

Or from Windows:

```powershell
ssh -i $sshKey henzard@192.168.122.82 "curl -s http://localhost:18789/health"
```

---

## 9. Diagnostics and log reading

### Standard first checks

Run these in order when something isn't working:

```bash
# 1. Check the config for invalid keys
openclaw doctor
# If there are errors:
openclaw doctor --fix     # auto-removes unrecognized keys

# 2. Check gateway health
openclaw health
openclaw gateway status

# 3. Tail gateway logs
openclaw logs --follow
# or:
journalctl --user -u openclaw-gateway -f

# 4. Check WhatsApp channel status
openclaw channels status --channel whatsapp

# 5. Verify plugins loaded
# Look in logs for:
#   [plugins] habitica: loaded
#   [whatsapp] WhatsApp archive enabled at ...
```

### When the gateway refuses to start

If `openclaw gateway restart` immediately fails, the almost always the cause is an **invalid config**. Run:

```bash
openclaw doctor
```

The output will say exactly which key is unrecognized. The most common case in this fork:

```
channels.whatsapp: Unrecognized key: "archive"
```

This means the schema doesn't know about `archive`. Either `openclaw doctor --fix` (removes the key) or re-add it to the Zod schema (see [implementation-guide.md §3](implementation-guide.md#3-feature-1-whatsapp-message-archive)).

### Checking env vars are set

```bash
# Check gateway process sees the right env
systemctl --user show openclaw-gateway.service | grep Environment

# Check your shell sees them
echo $HABITICA_USER_ID
echo $OPENROUTER_API_KEY
```

### Test a gateway tool manually

```bash
TOKEN=$(python3 -c "import json; print(json.load(open('/root/.openclaw/openclaw.json' if 0 else (open('/home/henzard/.openclaw/openclaw.json'))))['gateway']['auth']['token'])" 2>/dev/null || echo "check-your-config")

curl -s -X POST http://localhost:18789/tools/invoke \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tool":"habitica","args":{"action":"dashboard"}}' \
  | python3 -m json.tool
```

### Check if MCP server starts correctly

```bash
cd ~/openclaw-custom
node --no-warnings tools/openclaw-mcp-server.mjs &
MCP_PID=$!
sleep 2
kill $MCP_PID 2>/dev/null

# Count registered tools
grep -c "server.tool(" tools/openclaw-mcp-server.mjs
# Should be 14
```

### Verify archive is working

```bash
# Check DB exists and has rows
ls -lh ~/.openclaw/whatsapp/archive.sqlite
sqlite3 ~/.openclaw/whatsapp/archive.sqlite "SELECT count(*) FROM messages;"
```

### Check cron jobs

```bash
openclaw cron list
# Look for jobs with enabled: true that aren't using native tools in their prompts
```

---

## 10. Config management

### Config file location

```
~/.openclaw/openclaw.json
```

### Known-good config shape for this fork

```jsonc
{
  "gateway": {
    "auth": {
      "token": "your-gateway-token-here"
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/x-ai/grok-4.1-fast",
        "fallbacks": ["openrouter/deepseek/deepseek-chat-v3-0324"]
      }
    }
  },
  "tools": {
    "profile": "coding",
    "alsoAllow": ["group:plugins"]
  },
  "channels": {
    "whatsapp": {
      "archive": {
        "enabled": true,
        "retentionDays": 90,
        "persistAudio": true
      },
      "outboundRateLimit": {
        "maxMessages": 30,
        "windowSeconds": 60
      },
      "accounts": {
        "default": {
          "name": "HenzardBot"
        }
      }
    }
  }
}
```

### Switching models

**Via CLI (immediate):**

```bash
openclaw config set agents.defaults.model.primary "openrouter/x-ai/grok-4.1-fast"
openclaw gateway restart
```

**Via JSON (precise):**

```bash
# Edit the config directly
nano ~/.openclaw/openclaw.json
# Change agents.defaults.model.primary value
openclaw doctor    # validate
openclaw gateway restart
```

**Models we have used and why:**

| Model | Verdict |
|---|---|
| `openrouter/anthropic/claude-haiku-4-5` | Too expensive for continuous use |
| `openrouter/x-ai/grok-4.1-fast` | Current primary — fast, cheap, works well |
| `openrouter/deepseek/deepseek-v3.2` | Tried briefly — adequate fallback |
| `openrouter/deepseek/deepseek-chat-v3-0324` | Current fallback — used when grok hits capacity |

**Grok capacity errors:** `x-ai/grok-4.1-fast` occasionally returns "model at capacity". This is transient. The `fallbacks` config handles it automatically — the agent retries with deepseek without user intervention.

### After any config change

```bash
openclaw doctor         # validates — tells you about unrecognized keys
openclaw gateway restart
openclaw health         # confirms gateway came up
```

---

## 11. Model selection and switching

See [§10](#10-config-management) for the quick commands. Here is the full history and reasoning.

### Model history for this deployment

1. **`openrouter/anthropic/claude-haiku-4-5`** — Initial model. Good quality, but too expensive for a 24/7 running agent (crons + WhatsApp responses).

2. **`openrouter/x-ai/grok-4.1-fast`** — Switched to this. Fast, cheap, handles WhatsApp/Habitica tools correctly. Occasionally hits capacity (transient, ~5 min recovery).

3. **`openrouter/deepseek/deepseek-v3.2`** — Tried for a short period. Works for basic tasks but less reliable with complex tool chaining.

4. **Back to `openrouter/x-ai/grok-4.1-fast`** — Returned to this as primary. Added `deepseek-chat-v3-0324` as fallback to handle capacity events.

### Recommended config

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

### Changing model via chat (agent turn)

You can ask the agent to switch its own model. It reads the request, edits `openclaw.json`, and restarts:

> "Switch my OpenClaw to openrouter/x-ai/grok-4.1-fast"

The agent will use the `config set` tool or edit the JSON directly. Always verify with `openclaw doctor` after.

---

## 12. Quick reference

### PowerShell SSH one-liners (safe to run directly)

```powershell
$sshKey = "C:\Users\henza\.ssh\id_rsa"
$vm    = "henzard@192.168.122.82"

# Connect interactively
ssh -i $sshKey $vm

# Gateway status
ssh -i $sshKey $vm "systemctl --user status openclaw-gateway"

# Restart gateway
ssh -i $sshKey $vm "systemctl --user restart openclaw-gateway"

# Tail logs (Ctrl+C to stop)
ssh -i $sshKey $vm "journalctl --user -u openclaw-gateway -f"

# Run doctor
ssh -i $sshKey $vm "source ~/.profile; openclaw doctor"

# Check health
ssh -i $sshKey $vm "source ~/.profile; openclaw health"

# Show current model
ssh -i $sshKey $vm "python3 -c \"import json; d=json.load(open('/home/henzard/.openclaw/openclaw.json')); print(d.get('agents',{}).get('defaults',{}).get('model',{}))\""

# Reconnect MCP after SCP deploy (in Cursor)
# Command Palette → "MCP: Reconnect servers"
```

### Systemd cheatsheet

```bash
# User-level service commands (ALL need --user)
systemctl --user start    openclaw-gateway
systemctl --user stop     openclaw-gateway
systemctl --user restart  openclaw-gateway
systemctl --user status   openclaw-gateway
systemctl --user enable   openclaw-gateway   # auto-start on login
systemctl --user disable  openclaw-gateway

# MANDATORY after any .service file change
systemctl --user daemon-reload

# See service file and env
systemctl --user cat openclaw-gateway.service
systemctl --user show openclaw-gateway.service | grep Environment

# Edit the service (creates drop-in, safe)
systemctl --user edit openclaw-gateway.service
```

### Common error → fix table

| Error | Cause | Fix |
|---|---|---|
| `openclaw: command not found` | `~/.npm-global/bin` not in PATH | `source ~/.profile` or add to PATH explicitly |
| `Unit openclaw-gateway.service not found` | Used `sudo systemctl` instead of `systemctl --user` | Always use `systemctl --user` |
| `Config invalid: Unrecognized key: "archive"` | Schema doesn't have the key | `openclaw doctor --fix` or fix the Zod schema |
| `Gateway aborted: config is invalid` | Config has bad keys or malformed JSON | `openclaw doctor`, then `openclaw doctor --fix` |
| `spawn openclaw ENOENT` (in MCP) | PATH not set in spawn env | Check `runCLI` has `PATH` with `~/.npm-global/bin` |
| `"gateway client stopped"` (in MCP) | CLI WebSocket drops in SSH | Use HTTP `/tools/invoke` instead of CLI for this tool |
| `ExperimentalWarning: SQLite` breaks MCP | Node 22 writes to stderr | Use `node --no-warnings` in `.cursor/mcp.json` |
| `Cannot find package '@modelcontextprotocol/sdk'` | Wrong working directory | Add `cd ~/openclaw-custom &&` before `node` in SSH args |
| Cursor shows "No tools, prompts or resources" | `z.record(z.unknown())` in schema | Use `z.record(z.string(), z.any())` |
| `model at capacity` (grok) | Transient OpenRouter capacity | Add `fallbacks` in config — auto-retries |
| `sudo npm i -g .` puts binary in wrong place | Root's npm prefix, not user's | Drop `sudo` — use `npm i -g .` only |
| Agent uses wrong tool name | `TOOLS.md` outdated | Update TOOLS.md tool inventory; native `habitica` plugin + shell scripts via exec |
| Memory Synthesis overwrote TOOLS.md | Synthesis prompt didn't forbid it | Add "Do NOT edit TOOLS.md" to synthesis cron prompt |
