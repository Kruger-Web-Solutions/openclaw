# Fork workflow: use this repo, sync upstream, and add value

This guide is for **Cursor users and other contributors** who work on this OpenClaw fork. It explains how to use the repo, pull from upstream without breaking things, deploy safely, and add value for the community.

---

## What this repo is

- **This repository** is a **fork** of [openclaw/openclaw](https://github.com/openclaw/openclaw) with customizations (e.g. WhatsApp archive, Habitica plugin, faster-whisper, deployment to a team or production VM).
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
- **Follow [CONTRIBUTING.md](/CONTRIBUTING.md)**:
  - Run `pnpm build && pnpm check && pnpm test` (or the relevant subset: `pnpm test:extension whatsapp`, `pnpm test:extension habitica`, etc.).
  - Keep PRs focused; use American English in code and docs.
- **Config and schema**:
  - New config keys for channels (e.g. WhatsApp) must be added in **both** the TypeScript types and the **Zod schema**. For shared channel config (valid at top-level and per-account), add the key to the **shared** schema (e.g. `WhatsAppSharedSchema` in `src/config/zod-schema.providers-whatsapp.ts`) so it’s valid in both places. Adding it only in one place causes "Unrecognized key" and can block gateway startup.
- **Boot files** (`AGENTS.md`, `TOOLS.md`, `MEMORY.md`, etc. in the workspace) are loaded by the agent. The Memory Synthesis cron can overwrite some of these; avoid relying on it to edit `TOOLS.md` if you’ve customized it (and add "Do NOT edit TOOLS.md" to the synthesis prompt if that job exists).
- **Commit and push** to your fork, then open a PR to your fork’s `main` or to the shared org remote as your workflow requires.

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
- **channel.ts**: Upstream often refactors imports (e.g. from `openclaw/plugin-sdk/whatsapp` to local `./runtime-api.js`, `./directory-config.js`, `./group-policy.js`). **Keep upstream’s structure** and re-apply **only our custom blocks** (e.g. archive imports, `archiveDb`, archive logic in `startAccount`, `onRawMessage`). Do not keep our old import paths if upstream has moved them.
- **docs/tools/plugin.md**: Prefer upstream’s doc structure (e.g. "Model providers / Speech providers" sections) unless we have a deliberate fork-specific addition.
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

If the remote rejects (non–fast-forward), fetch and merge the remote’s `main` first to preserve their commits, then push again.

---

## 4. Deployment (don’t break production)

Use **[DEPLOY.md](/DEPLOY.md)** as the canonical deployment guide. Apply these **corrections** so deployments don’t break:

| Issue | Correction |
|-------|------------|
| **`sudo npm i -g .`** | Use **`npm i -g .`** (no sudo) when the npm global prefix is user-owned (e.g. `~/.npm-global`). |
| **systemctl restart** | Gateway often runs as a **user** service. Use **`systemctl --user restart openclaw-gateway`** (and **`systemctl --user daemon-reload`** after any service file edit). |
| **Env vars** | Set them in **both** (1) the **systemd service** (for the gateway process) and (2) **`~/.bashrc` / `~/.profile`** (for CLI-spawned processes like `openclaw agent --local`, cron, SSH). |
| **After editing the service file** | Run **`systemctl --user daemon-reload`** before restart. |

**VM deployment (short):**

```bash
ssh user@your-vm
source ~/.profile   # or export PATH="$HOME/.npm-global/bin:$PATH" if needed
cd ~/openclaw-custom
git pull origin main
pnpm install
pnpm build
npm i -g .
openclaw gateway restart
```

**PowerShell + SSH**: Multi-line or JSON-heavy commands over SSH from PowerShell often get mangled. Prefer writing a small script locally, SCP’ing it to the VM (e.g. `/tmp/script.sh`), running it there, then deleting it.

---

## 5. Pitfalls that break things (lessons learned)

- **Config schema**: Adding a key only under `accounts.<id>` or only at top-level in the wrong schema causes "Unrecognized key" and gateway abort. Add shared keys to the **shared** Zod schema (and matching TypeScript type) so both positions are valid.
- **Plugin registration**: If a plugin checks env vars at **registration** time, the tool can be missing when the agent runs in a different process (e.g. CLI) that doesn’t have those env vars. Prefer resolving secrets **at execution time** and always registering the tool.
- **Tool allowlists**: Use **`tools.alsoAllow: ["group:plugins"]`** (or the correct allowlist) so plugin tools (e.g. `habitica`, `whatsapp_archive`) are allowed; otherwise the agent may try to use `exec` or shell wrappers instead of the native tools.
- **Cron prompts**: Point cron jobs at **native tools** (e.g. "Use the native `whatsapp_archive` tool" / "Use the native `habitica` tool") instead of raw SQL, custom scripts, or `exec` so behavior stays consistent and maintainable.
- **High-frequency crons**: Avoid agent-turn crons every 1–5 minutes; they burn API credits and add little value. Prefer daily or task-based schedules.

---

## 6. Adding value for the community

- **Upstream first**: If a change is generic (no fork-specific secrets or org details), consider opening a PR to [openclaw/openclaw](https://github.com/openclaw/openclaw) so the whole community benefits. Follow [CONTRIBUTING.md](/CONTRIBUTING.md) and mark AI-assisted PRs as such.
- **Changelog**: For user-facing changes in this fork, add a fragment under `changelog/fragments/` and/or update [CHANGELOG.md](/CHANGELOG.md) as per project convention.
- **Docs**: Update [DEPLOY.md](/DEPLOY.md), [docs/](/docs/), or this guide when you change deployment steps or workflows so the next contributor or Cursor session doesn’t break things.
- **Security**: Don’t commit secrets. Use `.gitignore` for local config that contains tokens (e.g. `.cursor/mcp.json`); provide `.example` templates instead. See [SECURITY.md](/SECURITY.md).

---

## 7. Quick reference

| Task | Command / note |
|------|-----------------|
| Fetch latest upstream | `git fetch upstream` |
| See how far ahead upstream is | `git log --oneline main..upstream/main` |
| Merge upstream into a branch | `git checkout -b merge-upstream-main` then `git merge upstream/main` |
| Deploy on VM | See [DEPLOY.md](/DEPLOY.md) + corrections in §4 above |
| Restart gateway (user service) | `systemctl --user restart openclaw-gateway` |
| Run extension tests | `pnpm test:extension whatsapp` / `pnpm test:extension habitica` |
| Run doctor | `openclaw doctor` |

**See also:** [OpenClaw best practices](openclaw-best-practices.md) — optimize already-running OpenClaw after installing an updated build (tool policy, env, cron, config).

---

This document is part of the fork’s knowledge base so that Cursor and other contributors can use the repo, pull from upstream safely, and add value without breaking production or the community workflow.
