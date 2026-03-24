# Lessons Learned

> Every hard-won lesson from all three phases, organized by topic. Read this before making changes to avoid repeating our mistakes.

---

## Architecture

- **Config schema: use the shared schema for shared fields.** Any WhatsApp config key valid at top-level AND per-account must go in `WhatsAppSharedSchema`. Putting it only in the account schema causes "Unrecognized key" and gateway abort.
- **Plugin registration must be unconditional.** Never gate `api.registerTool()` on env var presence. Register always; validate credentials at call time.
- **`tools.alsoAllow: ["group:plugins"]`** is the correct way to allow plugin tools. Named entries produce warnings.
- **Run the MCP server on the VM.** The CLI only exists on the VM. Tunneling from a local server adds failure modes.
- **HTTP for gateway tools, CLI for non-HTTP.** The CLI's WebSocket connection is unreliable in non-interactive SSH sessions. `/tools/invoke` is rock-solid.
- **One tool per resource type.** 4-6 focused tools with 5-9 actions each beats a single tool with 20 actions.

---

## Operations

- **Env vars in TWO places:** systemd service (gateway process) AND `~/.bashrc`/`~/.profile` (CLI and cron). They are different processes.
- **`systemctl --user`** — never `sudo systemctl`. Gateway is a user service.
- **`systemctl --user daemon-reload`** required after every `.service` file edit.
- **`npm i -g .` without `sudo`** when prefix is user-owned (`~/.npm-global`).
- **SCP temp scripts to the VM** rather than inlining complex commands in `ssh host "..."` from PowerShell.
- **SSH sessions don't inherit `~/.bashrc`.** Always `source ~/.profile` or construct PATH explicitly.
- **Shell scripts need `.profile` sourcing.** Add a fallback at the top of every `~/bin/` script for env vars.

---

## Agent Behavior

- **Keep TOOLS.md accurate.** The agent reads it at boot. If it says to use a shell script, the agent uses the shell script.
- **Cron prompts must name actual tools.** "Run: wa_archive today Weighsoft" > "run the archive script".
- **High-frequency agent crons are expensive.** Every agent turn calls the model. Daily/task-based schedules are cost-effective.
- **Memory Synthesis can overwrite workspace files.** Always add "Do NOT edit TOOLS.md" to its prompt.
- **Never expose internal IDs to the user.** Always use task names. No UUIDs, no fallback to IDs.

---

## SparkyFitness API

- **Never trust schema files for route discovery.** Read the actual `app.use()` registrations and test with curl.
- **Auth: use `x-api-key`** not `Authorization: Bearer`.
- **Meal types are plural.** `snacks` not `snack`.
- **Two-step food logging.** Create food → get IDs → create food entry. No single-call endpoint.
- **Water is container-based.** POST `change_drinks` + `container_id`, not `amount_ml`.
- **Flat food body.** `serving_size` at top level, not inside `default_variant`.
- **`postgres:16-alpine` for stability.** postgres:18+ changed data directory structure.
- **SparkyFitness has NO food database.** The AI must estimate macros. Never log 0/0/0/0.

---

## Testing

- **Static audits catch reference errors.** They cannot catch API schema mismatches.
- **Functional testing catches runtime failures.** Every script action must be tested against the live API at least once.
- **The E2E test (`e2e-test.sh`) tests the MCP server, not the shell scripts.** Both have their own code paths and can drift.
- **When you fix a bug in one tool (MCP), check the equivalent shell script too.** They duplicate logic.
- **Clean up after every test.** Create → verify → delete. The test harness restores all state.

---

## Cross-Service Intelligence

- **One input, many outputs is the key UX upgrade.** "Morning meds done" triggering both response + Habitica completion saves the user a step.
- **Time-of-day inference eliminates unnecessary questions.** "Meds done" at 7am is obviously morning meds.
- **Progress snapshots create constant awareness.** The user always knows where they stand.
- **Silent crons prevent notification fatigue.** Only message when there's a gap. On-track = silence.

---

## Coaching vs. Dispatching

- **Dispatchers repeat reminders. Coaches adapt.** Missed 3 days? Suggest smaller target, don't repeat the same reminder.
- **Numbers without interpretation are noise.** "1200/2710 cal" is a fact. "You're at 44%. Protein-heavy lunch would help." is coaching.
- **Questions are more powerful than instructions.** "What got in the way?" creates reflection. "Do your dailies." creates resistance.
- **The AI as food database works.** Consistent reference tables for common foods prevent wild estimation swings.

---

## Docker on EOL Systems

- **`docker-model-plugin` doesn't exist on Ubuntu 20.04.** Use apt repository directly, not the convenience script.
- **Group membership requires session restart.** `usermod -aG docker $USER` takes effect on next login.

---

## Node.js / Tooling

- **`node:sqlite` needs `--no-warnings`** in Node < 26.
- **`z.record(z.string(), z.any())`** not `z.record(z.unknown())` — the latter breaks MCP schema generation.
- **`.mjs` extension** for standalone ES modules without `type: "module"` in `package.json`.
- **`crypto.randomUUID()` is a global** in Node >= 19.
- **Line number references in plans are approximate.** Upstream changes shift them. Always verify.

---

## Security

- **Never commit tokens, phone numbers, or API keys.** Use `~/.openclaw/secrets/` and `contacts.env`.
- **Passwordless sudo: add for deployment, remove immediately after.** Document the removal step.

---

*~150 lines. All lessons organized by topic for quick reference.*
