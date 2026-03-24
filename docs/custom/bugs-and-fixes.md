# Bugs and Fixes

> Every bug encountered across all three phases, with root cause, symptom, and fix. Organized by category. Search this file when you hit an error.

---

## Config / Gateway Startup

### B1. "Unrecognized key" on `channels.whatsapp.archive` — gateway abort

**Symptom:** Gateway refused to start: `Config invalid: channels.whatsapp: Unrecognized key: "archive"`

**Root cause:** `archive` added to `WhatsAppAccountSchema` only; not to `WhatsAppConfigSchema`. Flat config used `channels.whatsapp.archive` which the schema didn't recognize.

**Fix:** Add to **`WhatsAppSharedSchema`** so it flows into both via `.extend()`.

**Prevention:** For any new WhatsApp config key valid at both levels, add to `WhatsAppSharedSchema`.

---

## Habitica

### B2. Habitica tool missing in CLI (but present in gateway)

**Symptom:** `openclaw agent --local` never saw the `habitica` tool.

**Root cause:** Plugin only registered the tool if `HABITICA_USER_ID` was set at registration time. CLI process doesn't inherit systemd env vars.

**Fix:** Always register; resolve credentials lazily at execution time (`resolveAuth()`).

### B3. Agent used `~/bin/habitica` instead of native `habitica` tool

**Root cause:** `tools.alsoAllow` contained tool names flagged as "unknown". `TOOLS.md` said to use `~/bin/habitica`.

**Fix:** Change to `["group:plugins"]`. Rewrite TOOLS.md to name native tools.

### B-P3-1. `habitica dashboard` — `KeyError: 'maxHealth'`

**Symptom:** Python KeyError when calling `habitica dashboard`.

**Root cause:** Habitica API removed the `maxHealth` field from user stats.

**Fix:** Hardcode max HP to `50`: `print(f'HP: {round(stats["hp"])}/50 | ...')`

### B-P3-2. `habitica` script — `unbound variable` in non-login shells

**Symptom:** `HABITICA_USER_ID: unbound variable` when called from cron or SSH.

**Root cause:** `set -euo pipefail` + `~/.profile` not sourced in non-login sessions.

**Fix:** Added `.profile` sourcing fallback:
```bash
if [ -z "${HABITICA_USER_ID:-}" ] && [ -f "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi
```

---

## SparkyFitness API

### B-SF1. All SparkyFitness routes were wrong

**Symptom:** Every `sparky_fitness` tool call returned 404.

**Root cause:** MCP server built using TypeScript schema field names, not actual API endpoint paths.

**Fix:** Discovered correct routes by reading server route files inside Docker container and testing with curl. See [features.md](features.md) Feature 6 for the correct route table.

### B-SF2. PostgreSQL 18+ volume conflict

**Symptom:** `sparkyfitness-db` container kept restarting.

**Root cause:** PostgreSQL 18 changed the data directory path. Old volume from initial failed run was incompatible.

**Fix:** Pin to `postgres:16-alpine` via `docker-compose.override.yml`. Remove old volumes: `docker volume prune` + `rm -rf ~/sparky/postgresql`.

### B-SF3. Wrong `Authorization` header

**Symptom:** "Authentication required" with correct token.

**Root cause:** Used `Authorization: Bearer` instead of `x-api-key`.

**Fix:** Use `x-api-key: TOKEN` header directly.

### B-SF4. Food creation: nested `default_variant` structure

**Symptom:** HTTP 500 — "null value in column `serving_size`".

**Root cause:** Sent `{ "default_variant": { "serving_size": 100 } }` but API reads `foodData.serving_size` (flat).

**Fix:** Flatten: `{ "name": "...", "serving_size": 100, "calories": 165, ... }`

### B-SF5. Wrong meal type and missing `variant_id`

**Symptom:** "Invalid meal type: snack".

**Root cause:** SparkyFitness uses `snacks` (plural). Also missing `variant_id` in food entry.

**Fix:** Map `snack` → `snacks`. Return `default_variant.id` from food creation step and pass as `variant_id`.

### B-SF6. Auth header broken in SSH one-liner (PowerShell)

**Symptom:** SSH commands with quotes failed.

**Root cause:** PowerShell mangles quotes inside `ssh host "..."`.

**Fix:** SCP a bash script to `/tmp/` and execute it remotely.

### B-P3-3. `sparky_fitness log_water` exit 22 (wrong API schema)

**Symptom:** `curl` returned HTTP 400.

**Root cause:** Script sent `{"date":"...","amount_ml":1200}` but API expects `{"entry_date":"...","change_drinks":N,"container_id":null}`.

**Fix:** Convert ml to drinks (250ml/drink) and use correct field names.

**Discovery:** Read the MCP server code which had the correct implementation.

### B-P3-4. `sparky_fitness summary` showed 0ml water

**Symptom:** Water always showed 0.

**Root cause:** `/dashboard/stats` doesn't include water. Water is at `/measurements/water-intake/{date}`.

**Fix:** Added separate API call for water in the summary action.

### B-P3-5. `sparky_fitness log_food` exit 22 (wrong field names)

**Symptom:** HTTP 400 on food logging.

**Root cause:** Used `calories_per_100g` instead of `calories`, `amount_grams` instead of `quantity`.

**Fix:** Aligned with MCP server's working implementation.

---

## WhatsApp

### B-P3-6. `wa_archive` UTC date bug

**Symptom:** After midnight UTC but before midnight SAST, `wa_archive today` returned no messages.

**Root cause:** `new Date().toISOString()` returns UTC. Between 22:00-00:00 UTC the "today" date was wrong for SAST.

**Fix:** Added SAST offset: `new Date(Date.now() + 2 * 3600 * 1000).toISOString().slice(0, 10)`

### B-P3-7. Phantom tool references across docs and crons

**Symptom:** Docs/crons referenced `whatsapp_archive`, `whatsapp_send`, `gateway_health` — tools that don't exist.

**Fix:** Replaced with actual tools (`wa_archive`, `message`, `openclaw health`) across all files.

### B-WA1. `openclaw message send` CLI fails in SSH

**Symptom:** "gateway timeout after 10000ms".

**Root cause:** CLI WebSocket connection is unstable in non-interactive SSH sessions.

**Fix:** Use HTTP API directly: `curl -X POST http://localhost:18789/tools/invoke -H "Authorization: Bearer $GW_TOKEN" ...`

---

## Cron

### B-CRON1. `openclaw cron add --job "$json"` syntax error

**Symptom:** "required option '--name' not specified".

**Root cause:** CLI uses named flags, not a `--job` JSON blob.

**Fix:** Use `--name`, `--cron`, `--tz`, `--message`, etc.

### B-CRON2. SSH PATH missing `openclaw` binary

**Fix:** Use full path in scripts: `$HOME/.npm-global/bin/openclaw`.

### B-P3-8. Cron jobs with wrong pronouns, hardcoded numbers

**Fix:** Corrected pronouns (Kealyn: "her" not "his"), replaced hardcoded numbers with `contacts.env`.

---

## Docker / System

### B-DOCKER1. Ubuntu 20.04 EOL + docker-model-plugin missing

**Root cause:** Convenience script installs `docker-model-plugin` which has no focal package.

**Fix:** Install directly: `sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin`

### B-DOCKER2. `newgrp docker` failed in SSH session

**Root cause:** `usermod -aG` takes effect on next login, not current session.

**Fix:** Disconnect and reconnect SSH.

---

## Node.js / Build

### B10. MCP `node:sqlite` warning breaks JSON-RPC framing

**Fix:** `node --no-warnings tools/openclaw-mcp-server.mjs`

### B11. `z.record(z.unknown())` breaks MCP tool listing

**Symptom:** Cursor shows "No tools, prompts or resources".

**Fix:** Use `z.record(z.string(), z.any())`.

### B12. `openclaw channels status` takes ~28 seconds

**Root cause:** Scans for Ollama models (not running → timeout).

**Fix:** Bypass CLI. Read auth state directly from credential files.

---

## Testing

### B14. Habitica test expected `jsonResult` but tool threw

**Fix:** Use `await expect(...).rejects.toThrow(...)` instead of checking return value.

### B-P3-9. Food logged with zero macros

**Root cause:** SparkyFitness has no food database. AI was not told to estimate macros.

**Fix:** Added Macro Estimation Protocol to health-coach skill. See [agent-intelligence.md](agent-intelligence.md).

---

## SSH / PATH

### B6. SSH PATH missing `~/.npm-global/bin`

**Fix (deployment):** Always `source ~/.profile` or prefix with `export PATH="$HOME/.npm-global/bin:...PATH"`.

**Fix (MCP server):** Explicitly construct PATH in `env` passed to `child_process.spawn`.

### B7. `sudo npm i -g .` installs to wrong prefix

**Fix:** `npm i -g .` without `sudo`. The user prefix (`~/.npm-global`) is writable.

### B8. `systemctl restart openclaw-gateway` — "Unit not found"

**Fix:** Always `systemctl --user restart openclaw-gateway`.

---

## Agent Behavior

### B9. Memory Synthesis cron overwrote TOOLS.md

**Fix:** Add "IMPORTANT: Do NOT edit TOOLS.md" to all synthesis cron prompts.

---

*~250 lines. All bugs from Phases 1-3 organized by category.*
