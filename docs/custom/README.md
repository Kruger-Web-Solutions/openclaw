# docs/custom — index

This folder contains the complete knowledge base for this OpenClaw fork. Every decision, bug, lesson, and operational procedure is documented here so that any future Cursor session or developer can pick up without starting from scratch.

**All docs are 150-400 lines** — sized for AI consumption. No monoliths.

---

## Start here

| File | What it covers | Read first if... |
|---|---|---|
| **[architecture.md](architecture.md)** | System diagram, file maps, tool inventory, how to extend, upstream merge | You are new to this fork |
| **[features.md](features.md)** | All 8 features: archive, whisper, Habitica, rate limiter, MCP, SparkyFitness, crons, Todoist | You need to understand or change a feature |
| **[agent-intelligence.md](agent-intelligence.md)** | Cross-service chaining, coaching intelligence, macro estimation, proactive crons | You are working on agent behavior or skills |
| **[bugs-and-fixes.md](bugs-and-fixes.md)** | Every bug from all 3 phases, organized by category | You hit an error |
| **[lessons-learned.md](lessons-learned.md)** | Hard-won lessons organized by topic | You are about to make a change |
| **[deployment-journal.md](deployment-journal.md)** | Chronological record of all deployments, E2E test, VM reference | You need to deploy or reproduce the setup |
| **[ssh-and-vm-operations.md](ssh-and-vm-operations.md)** | SSH setup, PowerShell gotchas, sudo, gateway ops, diagnostics, model switching | Something on the VM isn't working |
| **[mcp-implementation-guide.md](mcp-implementation-guide.md)** | Deep-dive on the MCP server (14 tools, transport decisions) | You are adding or debugging MCP tools |
| **[personal-assistant-runbook.md](personal-assistant-runbook.md)** | IP change, token rotation, cron management, calendar refresh, goals session | Maintaining the live system |
| **[vm-deploy/](vm-deploy/)** | Deploy scripts, skills, TOOLS.md, HELP.md, cron scripts | You are deploying to the VM |

---

## Context documents (in `/docs/`)

| File | What it covers |
|---|---|
| [docs/openclaw-best-practices.md](../openclaw-best-practices.md) | Post-install optimization guide (for Cursor / operators) |
| [docs/contributing-fork-workflow.md](../contributing-fork-workflow.md) | Upstream sync, git remotes, deployment corrections |

---

## Quick answers

**What is cross-service chaining?** → [agent-intelligence.md](agent-intelligence.md) — One input triggers ALL related services

**Why does food log with zero macros?** → [agent-intelligence.md](agent-intelligence.md) — SparkyFitness has no food DB; AI must estimate

**How does coaching work?** → [agent-intelligence.md](agent-intelligence.md) — Micro-commitments, win celebration, questioning

**What are the proactive crons?** → [agent-intelligence.md](agent-intelligence.md) — 6 smart crons that push context before it's needed

**How does unplanned meal coaching work?** → [agent-intelligence.md](agent-intelligence.md) — Reflection protocol, MEMORY.md tracking, weekly warnings, escalation to Alicia + Rhyno

**`sparky_fitness log_water` exit 22** → [bugs-and-fixes.md](bugs-and-fixes.md) — Use `entry_date`/`change_drinks` not `date`/`amount_ml`

**`sparky_fitness log_food` exit 22** → [bugs-and-fixes.md](bugs-and-fixes.md) — Use flat payload with correct field names

**`habitica dashboard` KeyError** → [bugs-and-fixes.md](bugs-and-fixes.md) — Hardcode max HP to 50

**`habitica` unbound variable in cron** → [bugs-and-fixes.md](bugs-and-fixes.md) — Source `.profile` fallback

**Gateway won't start / "Unrecognized key"** → [bugs-and-fixes.md](bugs-and-fixes.md) B1 + [ssh-and-vm-operations.md](ssh-and-vm-operations.md)

**Agent uses wrong tool** → [lessons-learned.md](lessons-learned.md) — Keep TOOLS.md accurate, use `group:plugins`

**PowerShell SSH command fails** → [ssh-and-vm-operations.md](ssh-and-vm-operations.md) — SCP scripts, don't inline

**MCP tools not showing in Cursor** → [bugs-and-fixes.md](bugs-and-fixes.md) B10/B11 — `--no-warnings` + correct Zod types

**How to add a new feature** → [architecture.md](architecture.md) — Plugin tool, WhatsApp config, MCP tool, cron, shell script

**Deploy changes to VM** → [ssh-and-vm-operations.md](ssh-and-vm-operations.md) + [deployment-journal.md](deployment-journal.md)

**VM IP changed** → [personal-assistant-runbook.md](personal-assistant-runbook.md)

**Rotate a token** → [personal-assistant-runbook.md](personal-assistant-runbook.md)

**SparkyFitness API routes** → [features.md](features.md) Feature 6

**How to verify the full system** → [deployment-journal.md](deployment-journal.md) — run `e2e-test.sh`
