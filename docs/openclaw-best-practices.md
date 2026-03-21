# OpenClaw best practices (for Cursor and operators)

This document helps **Cursor** (and operators) **optimize already-running OpenClaw instances** after installing an updated or custom build. Use it to check config, tools, cron, and deployment so the system stays stable and the agent uses native tools correctly.

---

## When to use this

- **After installing** an updated OpenClaw build (e.g. from this fork or a new upstream release).
- **When the agent** uses `exec` or shell scripts instead of native tools (e.g. `habitica`, `whatsapp_archive`).
- **When you see** "unknown entries" in tool allowlist warnings, config invalid, or gateway/cron misbehavior.
- **When adding** new plugins or channels and you want config and agent behavior to stay correct.

---

## 1. Post-install / post-upgrade checklist

Run these after deploying a new build:

| Step | Command / action |
|------|-------------------|
| Run doctor | `openclaw doctor` — migrates config and surfaces invalid keys. |
| Fix config if needed | `openclaw doctor --fix` or edit `~/.openclaw/openclaw.json` to remove/relocate invalid keys. |
| Restart gateway | `systemctl --user restart openclaw-gateway` (or `openclaw gateway restart`). |
| Check health | `openclaw health` and `openclaw gateway status`. |
| Verify plugins | In logs, look for e.g. `[plugins] habitica: loaded` and `[whatsapp] ... WhatsApp archive enabled at ...`. |
| Test native tools | Ask the agent to use the new tools (e.g. "Show my Habitica dailies", "What happened on WhatsApp today?") and confirm it uses the **tool**, not `exec` or a shell script. |

---

## 2. Tool policy: so the agent uses native tools

If the agent falls back to `exec` or shell wrappers instead of plugin tools (e.g. `habitica`, `whatsapp_archive`), the **tool allowlist** is usually the cause.

### 2.1 Allow plugin tools

- **`tools.profile`** (e.g. `"coding"`) defines a **base allowlist**. It does **not** include plugin tools by name.
- Add **`tools.alsoAllow: ["group:plugins"]`** so **all registered plugin tools** are allowed. That removes "unknown entries" warnings for plugin tools and lets the agent call them.

Example:

```json5
{
  "tools": {
    "profile": "coding",
    "alsoAllow": ["group:plugins"]
  }
}
```

- **Do not** set both `tools.allow` and `tools.alsoAllow` in the same scope with conflicting intent; prefer **profile + alsoAllow** for additive plugin access.
- Per-agent override: `agents.list[].tools.alsoAllow` (and `agents.list[].tools.profile`) if you need different tool sets per agent.

### 2.2 Boot files (TOOLS.md)

- The agent reads **workspace boot files** (e.g. `~/.openclaw/workspace/TOOLS.md`) to know what tools exist and how to use them.
- **Keep TOOLS.md aligned with reality**: document native tools (e.g. `habitica`, `whatsapp_archive`) and state that the agent should **use them directly**, not via `exec` or shell wrappers.
- If a **Memory Synthesis** (or similar) cron **edits TOOLS.md**, it can overwrite your wording. Add an explicit instruction in that cron’s prompt: **"Do NOT edit TOOLS.md"** so your tool documentation is preserved.

---

## 3. Model and reliability

- **Primary model** can hit capacity or rate limits. Add **fallbacks** so the agent can continue:

```json5
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

- Prefer a small set of fallbacks; avoid long chains that increase latency.

---

## 4. Environment variables (gateway + CLI)

- **Gateway process** gets env from **systemd** (or launchd), not from your shell profile.
- **CLI** (e.g. `openclaw agent --local`) and **cron-triggered agent runs** get env from the **user’s shell** (e.g. `~/.bashrc`, `~/.profile`).
- For plugins that need secrets (e.g. Habitica, API keys), set env in **both**:
  1. **Systemd user service** — e.g. `systemctl --user edit openclaw-gateway.service` and add `Environment=HABITICA_USER_ID=...` and `Environment=HABITICA_API_KEY=...`.
  2. **Shell profile** — e.g. in `~/.bashrc` / `~/.profile`: `export HABITICA_USER_ID=...` and `export HABITICA_API_KEY=...`.
- After editing the service file, run **`systemctl --user daemon-reload`** then restart the gateway.

---

## 5. Cron jobs: native tools and frequency

### 5.1 Use native tools in cron prompts

- Cron jobs that need **WhatsApp archive** or **Habitica** should instruct the agent to **call the native tools** (e.g. `whatsapp_archive`, `habitica`), not raw SQL, custom scripts, or `exec`.
- Example (daily summary): *"Use the native whatsapp_archive tool with action 'recent' and limit 200. Do NOT use exec or raw SQL."*
- Example (Habitica): *"Use the native habitica tool with action 'dailies'. Do NOT use exec or ~/bin/habitica."*

### 5.2 Avoid high-frequency agent crons

- **Agent-turn crons** (prompt + model call) every 1–5 minutes burn API credits and add little value. Prefer **daily** or **task-based** schedules.
- Remove or disable crons that only log heartbeat or run scripts that no longer exist.

### 5.3 Protect boot files from cron overwrite

- If a cron runs "memory synthesis" or similar and can **rewrite TOOLS.md** (or other boot files), add a clear rule in its prompt: **"Do NOT edit TOOLS.md"** (or list the files to leave unchanged).

---

## 6. Config schema (avoid "Unrecognized key")

- New **channel config** keys (e.g. WhatsApp `archive`, `outboundRateLimit`) must be valid in **both** the TypeScript types and the **Zod** schema.
- For keys that can live at **top-level and per-account**, add them to the **shared** schema (e.g. `WhatsAppSharedSchema`) so both positions are accepted. Adding only in one place causes **"Unrecognized key"** and can block gateway startup.
- After changing config, run **`openclaw doctor`** and fix any reported invalid keys before restarting.

---

## 7. Deployment (user service, no sudo)

- **Gateway** is often run as a **user** systemd service. Use **`systemctl --user`** (not `sudo systemctl`):
  - Restart: **`systemctl --user restart openclaw-gateway`**
  - After editing the unit: **`systemctl --user daemon-reload`**
- **Global install** on a VM with a user-owned npm prefix (e.g. `~/.npm-global`): use **`npm i -g .`** (no `sudo`).
- Full sequence: see [DEPLOY.md](/DEPLOY.md) and [Fork workflow](/docs/contributing-fork-workflow.md) for corrections (env in both places, daemon-reload, etc.).

---

## 8. Security and secrets

- **Secrets** (tokens, API keys) must not be committed. Use **env vars** or secret refs; keep files that contain secrets out of git (e.g. `.cursor/mcp.json` in `.gitignore`, provide `.cursor/mcp.json.example` instead).
- **Tool policy**: Prefer **`tools.profile: "coding"`** or **`messaging`** plus **`tools.alsoAllow: ["group:plugins"]`** over `full` when you want plugin tools without opening all tools. For exposed groups, consider `tools.profile: "messaging"` and sandboxing (see [Security](/docs/gateway/security/index.md)).

---

## 9. Quick optimization summary (Cursor-oriented)

When optimizing an **already-running** OpenClaw after an update:

1. **Config** — Run `openclaw doctor`; fix invalid keys; ensure `tools.alsoAllow: ["group:plugins"]` if using plugin tools.
2. **Models** — Add `agents.defaults.model.fallbacks` if the primary model often hits capacity.
3. **Env** — Set plugin secrets (e.g. Habitica) in **systemd service** and **shell profile**; `daemon-reload` and restart.
4. **TOOLS.md** — Align with native tools; instruct agent to use tools directly; protect from synthesis overwrite if needed.
5. **Cron** — Point prompts at **native tools**; remove or throttle very frequent agent crons; avoid cron overwriting TOOLS.md.
6. **Restart** — `systemctl --user daemon-reload` (if you edited the service) and `systemctl --user restart openclaw-gateway`.
7. **Verify** — `openclaw health`, gateway status, and a quick agent test of the new tools.

These steps keep an updated install stable and ensure the agent uses the new capabilities (plugins, archive, etc.) instead of falling back to exec or broken paths.
