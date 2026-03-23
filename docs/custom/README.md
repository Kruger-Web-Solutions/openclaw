# docs/custom — index

This folder contains the complete knowledge base for this OpenClaw fork. Every decision, bug, lesson, and operational procedure is documented here so that any future Cursor session or developer can pick up without starting from scratch.

---

## Start here

| File | What it covers | Read first if... |
|---|---|---|
| **[implementation-guide.md](implementation-guide.md)** | Full story: every feature built, every bug, all lessons learned (Phase 1 + Phase 2) | You are new to this fork or starting a new development session |
| **[ssh-and-vm-operations.md](ssh-and-vm-operations.md)** | SSH setup, PowerShell gotchas, sudo, gateway ops, diagnostics, model switching | Something on the VM isn't working, or you need to deploy |
| **[mcp-implementation-guide.md](mcp-implementation-guide.md)** | Deep-dive on the MCP server (14 tools, transport decisions, Todoist + SparkyFitness integration) | You are adding or debugging MCP tools |
| **[personal-assistant-runbook.md](personal-assistant-runbook.md)** | Ongoing ops: IP change, token rotation, cron management, annual calendar refresh, goals session | Maintaining the live system after initial deployment |
| **[vm-deploy/](vm-deploy/)** | Ready-to-run deploy scripts: TOOLS.md, calendar-2026.json, cron setup, SparkyFitness, E2E tests, full orchestration | You are deploying the personal assistant system to the VM |

---

## Context documents (in `/docs/`)

| File | What it covers |
|---|---|
| [docs/openclaw-best-practices.md](../openclaw-best-practices.md) | Post-install optimization guide (for Cursor / operators) |
| [docs/contributing-fork-workflow.md](../contributing-fork-workflow.md) | Upstream sync, git remotes, deployment corrections |

---

## Quick answers

**I need to deploy a code change to the VM →** [ssh-and-vm-operations.md §7](ssh-and-vm-operations.md#7-deploying-changes)

**Gateway won't start / "Unrecognized key" error →** [ssh-and-vm-operations.md §9](ssh-and-vm-operations.md#9-diagnostics-and-log-reading) + [implementation-guide.md §12 B1](implementation-guide.md#b1-config-invalid-unrecognized-key-on-channelswhatsapparchive)

**PowerShell SSH command fails →** [ssh-and-vm-operations.md §5](ssh-and-vm-operations.md#5-powershell-ssh-gotchas)

**Agent uses wrong tool (exec instead of native) →** [implementation-guide.md §9](implementation-guide.md#9-agent-alignment-tools-cron-toolsmd) + [implementation-guide.md §12 B3](implementation-guide.md#b3-agent-used-binhabitica-instead-of-native-habitica-tool)

**MCP tools not showing in Cursor →** [mcp-implementation-guide.md §8.2](mcp-implementation-guide.md#82-zod-zrecordzunknown-breaks-mcp-schema-generation) + [mcp-implementation-guide.md §8.5](mcp-implementation-guide.md#85-nodesqlite-warning-breaks-mcp-stdio)

**WhatsApp send returns "Tool not available: message" →** [mcp-implementation-guide.md §8.11](mcp-implementation-guide.md#811-gateway-blocked-message-tool--tool-not-available-message)

**whatsapp_contacts returns empty array →** [mcp-implementation-guide.md §8.12](mcp-implementation-guide.md#812-whatsapp_contacts-returned---not-a-bug) — this is normal if the directory is empty

**Upstream merge conflicts →** [implementation-guide.md §11](implementation-guide.md#11-upstream-merge-workflow)

**Switch primary model →** [ssh-and-vm-operations.md §11](ssh-and-vm-operations.md#11-model-selection-and-switching)

**Add a new plugin tool →** [implementation-guide.md §14.1](implementation-guide.md#141-new-agent-plugin-tool)

**Add a new MCP tool →** [mcp-implementation-guide.md §10](mcp-implementation-guide.md#10-how-to-add-a-new-tool)

**Why does the MCP server run on the VM, not locally? →** [mcp-implementation-guide.md §2](mcp-implementation-guide.md#why-the-server-runs-on-the-vm-not-locally)

**SparkyFitness returns 404 / wrong route →** [implementation-guide.md §16](implementation-guide.md#16-feature-6-sparkyFitness-self-hosted-nutrition-tracker) + [mcp-implementation-guide.md §12](mcp-implementation-guide.md#12-sparkyFitness-tool--complete-reference)

**SparkyFitness "Invalid meal type: snack" →** [implementation-guide.md §20 B-SF5](implementation-guide.md#20-phase-2-bugs-and-fixes) — use `snacks` (plural)

**SparkyFitness food entry fails (serving_size null) →** [implementation-guide.md §20 B-SF4](implementation-guide.md#20-phase-2-bugs-and-fixes) — use flat payload, not nested `default_variant`

**SparkyFitness "Authentication required" with correct token →** [implementation-guide.md §20 B-SF3](implementation-guide.md#20-phase-2-bugs-and-fixes) — use `x-api-key` header not `Authorization: Bearer`

**`openclaw cron add` "required option --name not specified" →** [implementation-guide.md §20 B-CRON1](implementation-guide.md#20-phase-2-bugs-and-fixes) — use named flags, not `--job`

**How to verify the full system is working →** [implementation-guide.md §22](implementation-guide.md#22-e2e-test-harness) — run `e2e-test.sh`

**`sparky_fitness` not available to WhatsApp agent →** [implementation-guide.md §21](implementation-guide.md#21-phase-2-lessons-learned) — it's Cursor MCP only; build an extension for gateway access

**VM IP changed →** [personal-assistant-runbook.md §1](personal-assistant-runbook.md#1-vm-ip-changed)

**Rotate a token / credential →** [personal-assistant-runbook.md §2](personal-assistant-runbook.md#2-rotate-a-secret-token)

**Add or change a cron job →** [personal-assistant-runbook.md §4](personal-assistant-runbook.md#4-add-change-or-remove-a-cron-job)

**Update TOOLS.md (agent identity) →** [personal-assistant-runbook.md §5](personal-assistant-runbook.md#5-update-toolsmd)

**Annual calendar / feast date refresh →** [personal-assistant-runbook.md §6](personal-assistant-runbook.md#6-annual-calendar-refresh)

**Set up annual goals (MEMORY.md) →** [personal-assistant-runbook.md §7](personal-assistant-runbook.md#7-memorymd-and-annual-goals-session)
