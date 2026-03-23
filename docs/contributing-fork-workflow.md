# Fork workflow: use this repo, sync upstream, and add value

This guide is for **Cursor users and other contributors** who work on this OpenClaw fork. It explains how to use the repo, pull from upstream without breaking things, deploy safely, and add value for the community.

---

## What this repo is

- **This repository** is a **fork** of [openclaw/openclaw](https://github.com/openclaw/openclaw) with customizations (e.g. WhatsApp archive, Habitica plugin, faster-whisper, personal assistant system, SparkyFitness integration, deployment to a production VM).
- **Upstream** = [openclaw/openclaw](https://github.com/openclaw/openclaw) — the canonical OpenClaw project. We keep our fork in sync with upstream so we get fixes and features while keeping our custom code.
- **Your remotes** might include:
  - `origin` — your own fork or the primary fork you push to (e.g. henzard/openclaw or Kruger-Web-Solutions/openclaw).
  - `upstream` — openclaw/openclaw (required for syncing).
  - Optional: `kws` or another remote for a shared org fork (e.g. Kruger-Web-Solutions/openclaw).

---

## 1. Clone and set up remotes

```bash
git clone https://github.com/<your-org-or-you>/openclaw.git
cd openclaw
```

Add upstream if not already present:

```bash
git remote add upstream https://github.com/openclaw/openclaw.git
git fetch upstream
```

Verify:

```bash
git remote -v
# origin    https://github.com/<you>/openclaw.git (fetch)
# origin    https://github.com/<you>/openclaw.git (push)
# upstream  https://github.com/openclaw/openclaw.git (fetch)
# upstream  https://github.com/openclaw/openclaw.git (push)
```

---

## 2. Making code changes (daily workflow)

- **Branch from `main`** for features or fixes:
  ```bash
  git checkout main
  git pull origin main
  git checkout -b feat/my-change
  ```
- **CI is disabled on this fork.** GitHub Actions workflows have been set to `workflow_dispatch` only — they required upstream org secrets and burned minutes on every push. Run checks **locally** before pushing:
  ```bash
  pnpm check && pnpm test
  # For extension-scoped changes:
  pnpm test:extension whatsapp
  pnpm test:extension habitica
  # If touching build output, module boundaries, or published surfaces:
  pnpm build
  ```
- **Follow [CONTRIBUTING.md](/CONTRIBUTING.md)**: keep PRs focused; use American English in code and docs.
- **Config and schema**:
  - New config keys for channels (e.g. WhatsApp) must be added in **both** the TypeScript types and the **Zod schema**. For shared channel config (valid at top-level and per-account), add the key to the **shared** schema (e.g. `WhatsAppSharedSchema` in `src/config/zod-schema.providers-whatsapp.ts`) so it's valid in both places. Adding it only in one place causes "Unrecognized key" and can block gateway startup.
- **Boot files** (`AGENTS.md`, `TOOLS.md`, `MEMORY.md`, etc. in the workspace) are loaded by the agent. The Memory Synthesis cron can overwrite some of these; avoid relying on it to edit `TOOLS.md` if you've customized it (and add "Do NOT edit TOOLS.md" to the synthesis prompt if that job exists).
- **Secrets and phone numbers**: Never hardcode tokens, API keys, or phone numbers in scripts committed to the repo. Read tokens from `~/.openclaw/secrets/` at runtime; store phone numbers in `~/.openclaw/secrets/contacts.env` (sourced by scripts). Always commit `.example` templates, never real values. See §6 (Security) and [`docs/custom/vm-deploy/contacts.env.example`](custom/vm-deploy/contacts.env.example).
- **Commit and push** to your fork, then open a PR to your fork's `main` or to the shared org remote as your workflow requires.

---

## 3. Syncing from upstream (merge upstream/main)

Do this periodically so the fork gets upstream fixes and features without drifting too far.

### 3.1 Create a merge branch and merge

```bash
git checkout main
git pull origin main
git checkout -b merge-upstream-main
git fetch upstream
git merge upstream/main --no-edit
```

### 3.2 Resolve conflicts

- **Typical conflict files**: `extensions/whatsapp/src/channel.ts`, `docs/tools/plugin.md`, sometimes `pnpm-lock.yaml`.
- **channel.ts**: Upstream often refactors imports (e.g. from `openclaw/plugin-sdk/whatsapp` to local `./runtime-api.js`, `./directory-config.js`, `./group-policy.js`). **Keep upstream's structure** and re-apply **only our custom blocks** (e.g. archive imports, `archiveDb`, archive logic in `startAccount`, `onRawMessage`). Do not keep our old import paths if upstream has moved them.
- **docs/tools/plugin.md**: Prefer upstream's doc structure (e.g. "Model providers / Speech providers" sections) unless we have a deliberate fork-specific addition.
- **pnpm-lock.yaml**: If conflicted, take one side (e.g. `git checkout --theirs pnpm-lock.yaml`) then run `pnpm install` to regenerate.

After resolving:

```bash
git add <resolved-files>
git commit -m "Merge upstream/main: resolve <list conflicts>"
```

### 3.3 Merge into main and push

```bash
git checkout main
git merge merge-upstream-main -m "Merge branch 'merge-upstream-main'"
git push origin main
```

If you also push to a shared org remote (e.g. Kruger-Web-Solutions):

```bash
git push kws main
# or: git push <org-remote> main
```

If the remote rejects (non–fast-forward), fetch and merge the remote's `main` first to preserve their commits, then push again.

---

## 4. Deployment (don't break production)

Use **[DEPLOY.md](/DEPLOY.md)** as the canonical deployment guide. Apply these **corrections** so deployments don't break:

| Issue | Correction |
|-------|------------|
| **`sudo npm i -g .`** | Use **`npm i -g .`** (no sudo) when the npm global prefix is user-owned (e.g. `~/.npm-global`). |
| **systemctl restart** | Gateway often runs as a **user** service. Use **`systemctl --user restart openclaw-gateway`** (and **`systemctl --user daemon-reload`** after any service file edit). |
| **Env vars** | Set them in **both** (1) the **systemd service** (for the gateway process) and (2) **`~/.bashrc` / `~/.profile`** (for CLI-spawned processes like `openclaw agent --local`, cron, SSH). |
| **After editing the service file** | Run **`systemctl --user daemon-reload`** before restart. |
| **Docker on Ubuntu 20.04** | Never use `curl -fsSL https://get.docker.com \| sudo sh` — the `docker-model-plugin` package doesn't exist on focal and the script fails. Install via apt directly: `sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin`. |
| **PostgreSQL on Docker** | Pin to `postgres:16-alpine` via a `docker-compose.override.yml`. postgres 18+ changed the data directory structure and breaks existing volume mounts. |

**VM deployment — use the orchestration scripts** in `docs/custom/vm-deploy/`:

```powershell
# From Windows PowerShell in the repo root:
.\docs\custom\vm-deploy\deploy-all.ps1
```

Or manually for code-only changes:

```powershell
$sshKey = "C:\Users\henza\.ssh\id_rsa"
$vm = "henzard@192.168.122.82"
scp -i $sshKey docs\custom\vm-deploy\phase2-deploy-code.sh "${vm}:/tmp/oc-phase2.sh"
ssh -i $sshKey $vm "bash /tmp/oc-phase2.sh && rm /tmp/oc-phase2.sh"
```

For MCP server changes only (no build needed):

```powershell
scp -i $sshKey tools\openclaw-mcp-server.mjs "${vm}:~/openclaw-custom/tools/openclaw-mcp-server.mjs"
# Then: Ctrl+Shift+P → "MCP: Reconnect servers" in Cursor
```

**PowerShell + SSH**: Multi-line or JSON-heavy commands over SSH from PowerShell often get mangled. Prefer writing a small script locally, SCP'ing it to the VM (e.g. `/tmp/script.sh`), running it there, then deleting it.

**See also:** [`docs/custom/personal-assistant-runbook.md`](custom/personal-assistant-runbook.md) — covers post-deployment ops: IP change, token rotation, cron management, annual calendar refresh.

---

## 5. Pitfalls that break things (lessons learned)

- **Config schema**: Adding a key only under `accounts.<id>` or only at top-level in the wrong schema causes "Unrecognized key" and gateway abort. Add shared keys to the **shared** Zod schema (and matching TypeScript type) so both positions are valid.
- **Plugin registration**: If a plugin checks env vars at **registration** time, the tool can be missing when the agent runs in a different process (e.g. CLI) that doesn't have those env vars. Prefer resolving secrets **at execution time** and always registering the tool.
- **Tool allowlists**: Use **`tools.alsoAllow: ["group:plugins"]`** (or the correct allowlist) so plugin tools (e.g. `habitica`, `whatsapp_archive`) are allowed; otherwise the agent may try to use `exec` or shell wrappers instead of the native tools.
- **Cron prompts**: Point cron jobs at **native tools** (e.g. "Use the native `whatsapp_archive` tool" / "Use the native `habitica` tool") instead of raw SQL, custom scripts, or `exec` so behavior stays consistent and maintainable.
- **Cron CLI syntax**: `openclaw cron add` uses **named flags** (`--name`, `--cron`, `--tz`, `--message`, `--announce`). There is no `--job` JSON flag. Run `openclaw cron add --help` to verify before scripting.
- **High-frequency crons**: Avoid agent-turn crons every 1–5 minutes; they burn API credits and add little value. Prefer daily or task-based schedules.
- **MCP tool scope**: The Cursor MCP server (`tools/openclaw-mcp-server.mjs`) and the OpenClaw gateway plugin system are **separate registries**. A tool added to the MCP server is only accessible from Cursor, not from the WhatsApp agent. To expose a capability to the WhatsApp agent, build a proper OpenClaw extension (like `extensions/habitica`).
- **SparkyFitness API routes**: Routes do not match the TypeScript schema names. Discover them by reading the server's `app.use()` registrations, not the schema. Key corrections: `/food-entries?selectedDate=` not `/diary?date=`; meal type is `snacks` (plural) not `snack`; food creation uses a flat body, not nested `default_variant`; auth header is `x-api-key` not `Authorization: Bearer`. Full route table: [`docs/custom/mcp-implementation-guide.md §12`](custom/mcp-implementation-guide.md).
- **SSH PATH**: Non-interactive SSH sessions don't source `~/.bashrc`. Always use full paths (e.g. `$HOME/.npm-global/bin/openclaw`) or `source ~/.profile` at the top of scripts. Construct `PATH` explicitly in `child_process.spawn` env.

---

## 6. Adding value for the community

- **Upstream first**: If a change is generic (no fork-specific secrets or org details), consider opening a PR to [openclaw/openclaw](https://github.com/openclaw/openclaw) so the whole community benefits. Follow [CONTRIBUTING.md](/CONTRIBUTING.md) and mark AI-assisted PRs as such.
- **Changelog**: For user-facing changes in this fork, add a fragment under `changelog/fragments/` and/or update [CHANGELOG.md](/CHANGELOG.md) as per project convention.
- **Docs**: Update [DEPLOY.md](/DEPLOY.md), [docs/](/docs/), or this guide when you change deployment steps or workflows so the next contributor or Cursor session doesn't break things.
- **Security**: Don't commit secrets or phone numbers. Use `~/.openclaw/secrets/` for tokens and `~/.openclaw/secrets/contacts.env` for phone numbers (template: [`docs/custom/vm-deploy/contacts.env.example`](custom/vm-deploy/contacts.env.example)). Use `.gitignore` for local config that contains tokens (e.g. `.cursor/mcp.json`); provide `.example` templates instead. See [SECURITY.md](/SECURITY.md).

---

## 7. Quick reference

| Task | Command / note |
|------|-----------------|
| Fetch latest upstream | `git fetch upstream` |
| See how far ahead upstream is | `git log --oneline main..upstream/main` |
| Merge upstream into a branch | `git checkout -b merge-upstream-main` then `git merge upstream/main` |
| Deploy on VM (full) | `.\docs\custom\vm-deploy\deploy-all.ps1` (PowerShell from repo root) |
| Deploy on VM (code only) | SCP + run `phase2-deploy-code.sh` — see §4 above |
| Restart gateway (user service) | `systemctl --user restart openclaw-gateway` |
| Run extension tests | `pnpm test:extension whatsapp` / `pnpm test:extension habitica` |
| Run doctor | `openclaw doctor` |
| Verify full system | `bash /tmp/e2e-test.sh` (SCP from `docs/custom/vm-deploy/e2e-test.sh`) |
| Day-to-day VM ops | [docs/custom/personal-assistant-runbook.md](custom/personal-assistant-runbook.md) |
| All bugs and lessons | [docs/custom/implementation-guide.md](custom/implementation-guide.md) |

**See also:**
- [OpenClaw best practices](openclaw-best-practices.md) — optimize an already-running OpenClaw (tool policy, env, cron, config).
- [docs/custom/README.md](custom/README.md) — full index of the custom knowledge base.

---

This document is part of the fork's knowledge base so that Cursor and other contributors can use the repo, pull from upstream safely, and add value without breaking production or the community workflow.
