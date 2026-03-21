#!/usr/bin/env node
/**
 * OpenClaw unified MCP server — runs ON the VM.
 *
 * Cursor connects via SSH stdio tunnel:
 *   .cursor/mcp.json command: "ssh"
 *   args: ["-i","~/.ssh/id_rsa","henzard@192.168.122.82","node ~/.openclaw/mcp-server.mjs"]
 *
 * Exposes 13 tools:
 *   WhatsApp       (6): whatsapp_status, whatsapp_contacts, whatsapp_send,
 *                       whatsapp_poll, whatsapp_react, whatsapp_archive
 *   Habitica       (1): habitica (dashboard/dailies/habits/todos/stats/complete)
 *   Todoist        (4): todoist_tasks, todoist_projects, todoist_labels, todoist_sections
 *   Cron           (1): cron (list/add/update/remove/run)
 *   Health         (1): gateway_health
 */

import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { readFileSync, existsSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// ── Config ────────────────────────────────────────────────────────────────────

const HOME                      = homedir();
const CONFIG_PATH               = `${HOME}/.openclaw/openclaw.json`;
const GATEWAY_URL               = "http://localhost:18789";
const OPENCLAW                  = `${HOME}/.npm-global/bin/openclaw`;
const ARCHIVE_DB                = `${HOME}/.openclaw/whatsapp/archive.sqlite`;
const TODOIST_TOKEN_PATH        = `${HOME}/.openclaw/secrets/todoist-token`;
const TODOIST_GROCERY_CFG_PATH  = `${HOME}/.openclaw/workspace/config/todoist-groceries.json`;
const TODOIST_API               = "https://api.todoist.com/api/v1";

/** Read gateway auth token from the openclaw config file. */
function getToken() {
  try {
    const cfg = JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
    return cfg?.gateway?.auth?.token ?? "";
  } catch {
    return "";
  }
}

/** Default WhatsApp account from env (set in SSH command or fallback). */
const getAccount = () => process.env.OPENCLAW_WHATSAPP_ACCOUNT ?? "default";

// ── CLI helper ────────────────────────────────────────────────────────────────

/**
 * Run an openclaw CLI command locally. Automatically appends --json.
 * Returns { ok, data?, raw?, error? }.
 */
function runCLI(args, timeoutMs = 15_000) {
  return new Promise((resolve) => {
    const env = {
      ...process.env,
      PATH: `${HOME}/.npm-global/bin:${HOME}/.local/bin:${process.env.PATH}`,
    };
    const child = spawn(OPENCLAW, [...args, "--json"], {
      env,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => { stdout += d.toString(); });
    child.stderr.on("data", (d) => { stderr += d.toString(); });

    const timer = setTimeout(() => {
      child.kill();
      resolve({ ok: false, error: `openclaw ${args[0]} timed out after ${timeoutMs}ms` });
    }, timeoutMs);

    child.on("close", (code) => {
      clearTimeout(timer);
      const text = stdout.trim();
      if (code !== 0 && !text) {
        resolve({ ok: false, error: stderr.trim() || `openclaw exited ${code}` });
        return;
      }
      try {
        resolve({ ok: true, data: JSON.parse(text) });
      } catch {
        resolve({ ok: true, raw: text || stderr.trim() });
      }
    });

    child.on("error", (err) => {
      clearTimeout(timer);
      resolve({ ok: false, error: String(err.message) });
    });
  });
}

// ── HTTP helper ───────────────────────────────────────────────────────────────

async function fetchWithTimeout(url, options, timeoutMs) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(id);
    return res;
  } catch (err) {
    clearTimeout(id);
    throw err;
  }
}

async function invokeGatewayTool(tool, args) {
  const token = getToken();
  if (!token) {
    return { ok: false, error: `No gateway token found in ${CONFIG_PATH}` };
  }
  let res;
  try {
    res = await fetchWithTimeout(
      `${GATEWAY_URL}/tools/invoke`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ tool, args }),
      },
      30_000,
    );
  } catch (err) {
    return { ok: false, error: `Gateway unreachable at ${GATEWAY_URL}: ${err.message}` };
  }
  const body = await res.text();
  if (!res.ok) {
    return { ok: false, error: `Gateway error ${res.status}: ${body}` };
  }
  try {
    return { ok: true, data: JSON.parse(body) };
  } catch {
    return { ok: true, raw: body };
  }
}

function toContent(result) {
  if (!result.ok) {
    return { content: [{ type: "text", text: result.error }], isError: true };
  }
  const text =
    result.data !== undefined
      ? JSON.stringify(result.data, null, 2)
      : (result.raw ?? "");
  return { content: [{ type: "text", text }] };
}

// ── SQLite archive helper ─────────────────────────────────────────────────────

function queryArchive(params) {
  let db;
  try {
    db = new DatabaseSync(ARCHIVE_DB);
  } catch (e) {
    return { ok: false, error: `Cannot open archive DB at ${ARCHIVE_DB}: ${e.message}` };
  }

  const action = params.action ?? "recent";
  const limit  = Math.min(Number(params.limit) || 50, 200);
  const COLS   =
    "message_id,direction,sender,recipient,body,media_type,is_group,group_id,group_subject,timestamp";

  try {
    let rows = [];
    if (action === "recent") {
      rows = db
        .prepare(`SELECT ${COLS} FROM whatsapp_messages ORDER BY timestamp DESC LIMIT ?`)
        .all(limit);
    } else if (action === "search") {
      const conds = [];
      const vals  = [];
      if (params.date_from) { conds.push("timestamp>=?"); vals.push(new Date(params.date_from).getTime()); }
      if (params.date_to)   { conds.push("timestamp<=?"); vals.push(new Date(params.date_to).getTime()); }
      if (params.sender)    { conds.push("(sender LIKE ? OR recipient LIKE ?)"); vals.push(`%${params.sender}%`, `%${params.sender}%`); }
      if (params.group)     { conds.push("(group_id LIKE ? OR group_subject LIKE ?)"); vals.push(`%${params.group}%`, `%${params.group}%`); }
      if (params.query)     { conds.push("body LIKE ?"); vals.push(`%${params.query}%`); }
      const where = conds.length ? `WHERE ${conds.join(" AND ")}` : "";
      rows = db
        .prepare(`SELECT ${COLS} FROM whatsapp_messages ${where} ORDER BY timestamp DESC LIMIT ?`)
        .all(...vals, limit);
    } else if (action === "summary") {
      rows = db
        .prepare(
          "SELECT sender,COUNT(*) AS message_count,MAX(timestamp) AS last_seen," +
          "is_group,group_id,group_subject FROM whatsapp_messages " +
          "GROUP BY COALESCE(group_id,sender) ORDER BY last_seen DESC LIMIT ?",
        )
        .all(limit);
    }

    const enriched = rows.map((m) => ({
      ...m,
      is_voice_note: typeof m.media_type === "string" && m.media_type.startsWith("audio/"),
    }));

    return { ok: true, data: { count: enriched.length, messages: enriched } };
  } catch (e) {
    return { ok: false, error: e.message };
  } finally {
    try { db.close(); } catch { /* ignore */ }
  }
}

// ── Server ────────────────────────────────────────────────────────────────────

const server = new McpServer(
  { name: "openclaw", version: "1.0.0" },
  { capabilities: { tools: {} } },
);

// ── WhatsApp tools ────────────────────────────────────────────────────────────

server.tool(
  "whatsapp_status",
  "Check the WhatsApp session authentication state and gateway liveness.",
  {},
  async () => {
    const account = getAccount();
    const credsPath = `${HOME}/.openclaw/credentials/whatsapp/${account}/creds.json`;

    // Read WhatsApp auth creds
    let waStatus;
    if (existsSync(credsPath)) {
      try {
        const creds = JSON.parse(readFileSync(credsPath, "utf8"));
        waStatus = {
          account,
          status: "authenticated",
          phone: creds.me?.id?.replace(/:.*/, "") ?? "unknown",
          name: creds.me?.name ?? "unknown",
          platform: creds.platform ?? "unknown",
        };
      } catch (e) {
        waStatus = { account, status: "creds_unreadable", error: e.message };
      }
    } else {
      waStatus = { account, status: "not_authenticated", credsPath };
    }

    // Check gateway liveness
    let gwStatus;
    try {
      const token = getToken();
      const res = await fetchWithTimeout(
        `${GATEWAY_URL}/health`,
        token ? { headers: { Authorization: `Bearer ${token}` } } : {},
        5_000,
      );
      const body = await res.text();
      gwStatus = JSON.parse(body);
    } catch (e) {
      gwStatus = { ok: false, error: e.message };
    }

    const output = { whatsapp: waStatus, gateway: gwStatus };
    return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }] };
  },
);

server.tool(
  "whatsapp_contacts",
  "List known WhatsApp contacts (peers) and groups for the configured account.",
  {
    kind: z
      .enum(["peers", "groups", "all"])
      .optional()
      .default("all")
      .describe('"peers" (DM contacts), "groups", or "all".'),
  },
  async ({ kind }) => {
    if (kind === "peers") {
      return toContent(
        await runCLI(["directory", "peers", "list", "--channel", "whatsapp", "--account", getAccount()], 25_000),
      );
    }
    if (kind === "groups") {
      return toContent(
        await runCLI(["directory", "groups", "list", "--channel", "whatsapp", "--account", getAccount()], 25_000),
      );
    }
    // all
    const [peers, groups] = await Promise.all([
      runCLI(["directory", "peers", "list", "--channel", "whatsapp", "--account", getAccount()], 25_000),
      runCLI(["directory", "groups", "list", "--channel", "whatsapp", "--account", getAccount()], 25_000),
    ]);
    if (!peers.ok) return toContent(peers);
    if (!groups.ok) return toContent(groups);
    return {
      content: [{
        type: "text",
        text: JSON.stringify({ peers: peers.data ?? peers.raw, groups: groups.data ?? groups.raw }, null, 2),
      }],
    };
  },
);

server.tool(
  "whatsapp_send",
  [
    "Send a WhatsApp message. The 'target' must be an E.164 phone number (e.g. +15551234567)",
    "or a group JID (e.g. 1234567890-1234567890@g.us). For media, pass a public HTTPS URL.",
  ].join(" "),
  {
    target:       z.string().describe("E.164 phone number or group JID."),
    message:      z.string().describe("Text body of the message."),
    media:        z.string().optional().describe("Optional media: public HTTPS URL."),
    gif_playback: z.boolean().optional().describe("Send video as a looping GIF."),
  },
  async ({ target, message, media, gif_playback }) => {
    const result = await invokeGatewayTool("message", {
      action: "send",
      channel: "whatsapp",
      to: target,
      message,
      ...(media        ? { mediaUrl: media }       : {}),
      ...(gif_playback ? { gifPlayback: true }      : {}),
    });
    return toContent(result);
  },
);

server.tool(
  "whatsapp_poll",
  "Create a WhatsApp poll message.",
  {
    target:   z.string().describe("E.164 phone number or group JID."),
    question: z.string().describe("The poll question."),
    options:  z.array(z.string()).min(2).describe("Poll answer options (minimum 2)."),
    multi:    z.boolean().optional().describe("Allow multiple selections."),
  },
  async ({ target, question, options, multi }) => {
    const result = await invokeGatewayTool("message", {
      action: "poll",
      channel: "whatsapp",
      to: target,
      pollQuestion: question,
      pollOption: options,
      ...(multi ? { pollMulti: true } : {}),
    });
    return toContent(result);
  },
);

server.tool(
  "whatsapp_react",
  "React to a WhatsApp message with an emoji.",
  {
    target:     z.string().describe("E.164 phone number or group JID."),
    message_id: z.string().describe("Message ID to react to."),
    emoji:      z.string().describe("Emoji to react with (e.g. '👍')."),
    remove:     z.boolean().optional().describe("Remove the reaction instead of setting it."),
  },
  async ({ target, message_id, emoji, remove }) => {
    const result = await invokeGatewayTool("message", {
      action: "react",
      channel: "whatsapp",
      to: target,
      messageId: message_id,
      emoji,
      ...(remove ? { remove: true } : {}),
    });
    return toContent(result);
  },
);

server.tool(
  "whatsapp_archive",
  [
    "Query the local WhatsApp SQLite message archive.",
    "Results include is_voice_note=true for audio messages so you can say",
    '"John left a voice note saying..." vs "John typed...".',
  ].join(" "),
  {
    action:    z.enum(["search", "summary", "recent"]).describe('"search" filters; "summary" per-contact stats; "recent" newest messages.'),
    date_from: z.string().optional().describe("ISO 8601 start date (e.g. 2025-01-01)."),
    date_to:   z.string().optional().describe("ISO 8601 end date."),
    sender:    z.string().optional().describe("Filter by sender E.164 or JID."),
    group:     z.string().optional().describe("Filter by group JID or subject."),
    query:     z.string().optional().describe("Full-text search (for action=search)."),
    limit:     z.number().int().positive().max(200).optional().default(50).describe("Max results (default 50, max 200)."),
  },
  async (params) => {
    return toContent(queryArchive(params));
  },
);

// ── Habitica tool ─────────────────────────────────────────────────────────────
server.tool(
  "habitica",
  "Manage Habitica tasks and stats. Actions: dashboard, dailies, habits, todos, stats, complete.",
  {
    action:  z.enum(["dashboard", "dailies", "habits", "todos", "stats", "complete"]).describe("Action to perform."),
    task_id: z.string().optional().describe("Task ID (required for action=complete)."),
  },
  async ({ action, task_id }) => {
    if (action === "complete" && !task_id) {
      return { content: [{ type: "text", text: "task_id is required for action=complete." }], isError: true };
    }
    return toContent(await invokeGatewayTool("habitica", { action, ...(task_id ? { task_id } : {}) }));
  },
);

// ── Todoist helpers ───────────────────────────────────────────────────────────

function getTodoistToken() {
  try {
    return readFileSync(TODOIST_TOKEN_PATH, "utf8").trim();
  } catch {
    return null;
  }
}

function getTodoistGroceryConfig() {
  try {
    return JSON.parse(readFileSync(TODOIST_GROCERY_CFG_PATH, "utf8"));
  } catch {
    return null;
  }
}

async function todoistRequest(method, path, body) {
  const token = getTodoistToken();
  if (!token) {
    return { ok: false, error: `No Todoist token found at ${TODOIST_TOKEN_PATH}` };
  }
  const headers = {
    Authorization: `Bearer ${token}`,
    "X-Request-Id": crypto.randomUUID(),
  };
  if (body) headers["Content-Type"] = "application/json";
  try {
    const res = await fetchWithTimeout(
      `${TODOIST_API}${path}`,
      { method, headers, ...(body ? { body: JSON.stringify(body) } : {}) },
      15_000,
    );
    const text = await res.text();
    if (!res.ok) {
      return { ok: false, error: `Todoist API ${res.status}: ${text}` };
    }
    try {
      return { ok: true, data: text ? JSON.parse(text) : { ok: true } };
    } catch {
      return { ok: true, raw: text };
    }
  } catch (err) {
    return { ok: false, error: `Todoist request failed: ${err.message}` };
  }
}

// ── todoist_tasks ─────────────────────────────────────────────────────────────

server.tool(
  "todoist_tasks",
  [
    "Full task CRUD + grocery shortcut. Actions:",
    "list (all or filtered), get (single task), create, grocery (store-aware create),",
    "update, delete, close (mark done), reopen, move (to project/section/parent).",
  ].join(" "),
  {
    action:      z.enum(["list","get","create","grocery","update","delete","close","reopen","move"])
                  .describe("Action to perform."),
    task_id:     z.string().optional().describe("Task ID — required for get, update, delete, close, reopen, move."),
    // list params
    filter:      z.string().optional().describe("Todoist filter query for list (e.g. 'today', 'p1', '#Shopping', 'overdue')."),
    project_id:  z.string().optional().describe("Filter list by project ID, or assign project on create/update."),
    section_id:  z.string().optional().describe("Filter list by section ID, or assign section on create/update."),
    label:       z.string().optional().describe("Filter list by label name."),
    cursor:      z.string().optional().describe("Pagination cursor from previous list response."),
    limit:       z.number().int().min(1).max(200).optional().describe("Max tasks to return in list (default 50)."),
    // create / update params
    content:     z.string().optional().describe("Task title — required for create and grocery."),
    description: z.string().optional().describe("Task notes/description."),
    parent_id:   z.string().optional().describe("Parent task ID (create sub-task)."),
    labels:      z.array(z.string()).optional().describe("Label names to apply."),
    priority:    z.number().int().min(1).max(4).optional().describe("Priority: 1=p1 (urgent) … 4=natural."),
    due_string:  z.string().optional().describe("Natural language due date, e.g. 'tomorrow at 10am', 'every Mon'."),
    due_date:    z.string().optional().describe("Due date in YYYY-MM-DD format."),
    assignee_id: z.string().optional().describe("User ID to assign task to (shared projects)."),
    // grocery shortcut
    store:       z.string().optional().describe(
      "Store key for grocery action: checkers, pnp, woolies, dischem, takealot, faithfultonature, djvleis, builders, pharmacy. Auto-detected from content if omitted.",
    ),
    // move params
    move_to_project_id: z.string().optional().describe("Destination project ID for move action."),
    move_to_section_id: z.string().optional().describe("Destination section ID for move action."),
    move_to_parent_id:  z.string().optional().describe("Destination parent task ID for move action."),
  },
  async ({ action, task_id, filter, project_id, section_id, label, cursor, limit,
           content, description, parent_id, labels, priority, due_string, due_date, assignee_id,
           store, move_to_project_id, move_to_section_id, move_to_parent_id }) => {

    const needsId = ["get","update","delete","close","reopen","move"];
    if (needsId.includes(action) && !task_id) {
      return { content: [{ type: "text", text: `task_id is required for action=${action}.` }], isError: true };
    }

    if (action === "list") {
      const p = new URLSearchParams();
      if (filter)     p.set("filter",     filter);
      if (project_id) p.set("project_id", project_id);
      if (section_id) p.set("section_id", section_id);
      if (label)      p.set("label",      label);
      if (cursor)     p.set("cursor",     cursor);
      if (limit)      p.set("limit",      String(limit));
      return toContent(await todoistRequest("GET", `/tasks${p.toString() ? `?${p}` : ""}`));
    }

    if (action === "get") {
      return toContent(await todoistRequest("GET", `/tasks/${task_id}`));
    }

    if (action === "create") {
      if (!content) return { content: [{ type: "text", text: "content is required for create." }], isError: true };
      const body = { content };
      if (project_id)  body.project_id  = project_id;
      if (section_id)  body.section_id  = section_id;
      if (parent_id)   body.parent_id   = parent_id;
      if (description) body.description = description;
      if (labels)      body.labels      = labels;
      if (priority)    body.priority    = priority;
      if (due_string)  body.due_string  = due_string;
      if (due_date)    body.due_date    = due_date;
      if (assignee_id) body.assignee_id = assignee_id;
      return toContent(await todoistRequest("POST", "/tasks", body));
    }

    if (action === "grocery") {
      if (!content) return { content: [{ type: "text", text: "content is required for grocery." }], isError: true };
      const config = getTodoistGroceryConfig();
      if (!config) {
        return { content: [{ type: "text", text: `Cannot read grocery config from ${TODOIST_GROCERY_CFG_PATH}` }], isError: true };
      }
      const detectStore = (text) => {
        const lower = text.toLowerCase();
        for (const [key, meta] of Object.entries(config.stores)) {
          for (const alias of (meta.aliases ?? [])) {
            if (lower.includes(alias)) return key;
          }
        }
        return null;
      };
      const storeKey = store?.toLowerCase() ?? detectStore(content) ?? config.default_store;
      const storeConfig = config.stores[storeKey];
      if (!storeConfig) {
        return {
          content: [{ type: "text", text: `Unknown store: "${storeKey}". Valid: ${Object.keys(config.stores).join(", ")}` }],
          isError: true,
        };
      }
      const body = { content, project_id: config.project.id };
      if (storeConfig.section_id) body.section_id = storeConfig.section_id;
      const result = await todoistRequest("POST", "/tasks", body);
      if (!result.ok) return toContent(result);
      return {
        content: [{
          type: "text",
          text: JSON.stringify({ ok: true, store: storeConfig.section_name, project: config.project.name, task: result.data }, null, 2),
        }],
      };
    }

    if (action === "update") {
      const body = {};
      if (content)     body.content     = content;
      if (description !== undefined) body.description = description;
      if (project_id)  body.project_id  = project_id;
      if (section_id)  body.section_id  = section_id;
      if (labels)      body.labels      = labels;
      if (priority)    body.priority    = priority;
      if (due_string)  body.due_string  = due_string;
      if (due_date)    body.due_date    = due_date;
      if (assignee_id) body.assignee_id = assignee_id;
      if (Object.keys(body).length === 0) {
        return { content: [{ type: "text", text: "Provide at least one field to update." }], isError: true };
      }
      return toContent(await todoistRequest("POST", `/tasks/${task_id}`, body));
    }

    if (action === "delete") {
      return toContent(await todoistRequest("DELETE", `/tasks/${task_id}`));
    }

    if (action === "close") {
      return toContent(await todoistRequest("POST", `/tasks/${task_id}/close`));
    }

    if (action === "reopen") {
      return toContent(await todoistRequest("POST", `/tasks/${task_id}/reopen`));
    }

    if (action === "move") {
      const body = {};
      if (move_to_project_id) body.project_id = move_to_project_id;
      if (move_to_section_id) body.section_id = move_to_section_id;
      if (move_to_parent_id)  body.parent_id  = move_to_parent_id;
      if (Object.keys(body).length === 0) {
        return { content: [{ type: "text", text: "Provide move_to_project_id, move_to_section_id, or move_to_parent_id." }], isError: true };
      }
      return toContent(await todoistRequest("POST", `/tasks/${task_id}/move`, body));
    }

    return { content: [{ type: "text", text: `Unknown action: ${action}` }], isError: true };
  },
);

// ── todoist_projects ──────────────────────────────────────────────────────────

server.tool(
  "todoist_projects",
  "CRUD for Todoist projects (lists). Actions: list, get, create, update, delete, archive, unarchive.",
  {
    action:      z.enum(["list","get","create","update","delete","archive","unarchive"])
                  .describe("Action to perform."),
    project_id:  z.string().optional().describe("Project ID — required for get, update, delete, archive, unarchive."),
    name:        z.string().optional().describe("Project name — required for create."),
    color:       z.string().optional().describe("Project color name, e.g. 'berry_red', 'lime_green', 'sky_blue'."),
    parent_id:   z.string().optional().describe("Parent project ID (create a sub-project)."),
    is_favorite: z.boolean().optional().describe("Mark project as favourite."),
    view_style:  z.enum(["list","board"]).optional().describe("View style: list or board."),
  },
  async ({ action, project_id, name, color, parent_id, is_favorite, view_style }) => {
    const needsId = ["get","update","delete","archive","unarchive"];
    if (needsId.includes(action) && !project_id) {
      return { content: [{ type: "text", text: `project_id is required for action=${action}.` }], isError: true };
    }

    if (action === "list") {
      return toContent(await todoistRequest("GET", "/projects"));
    }

    if (action === "get") {
      return toContent(await todoistRequest("GET", `/projects/${project_id}`));
    }

    if (action === "create") {
      if (!name) return { content: [{ type: "text", text: "name is required for create." }], isError: true };
      const body = { name };
      if (color)       body.color       = color;
      if (parent_id)   body.parent_id   = parent_id;
      if (is_favorite !== undefined) body.is_favorite = is_favorite;
      if (view_style)  body.view_style  = view_style;
      return toContent(await todoistRequest("POST", "/projects", body));
    }

    if (action === "update") {
      const body = {};
      if (name)        body.name        = name;
      if (color)       body.color       = color;
      if (is_favorite !== undefined) body.is_favorite = is_favorite;
      if (view_style)  body.view_style  = view_style;
      if (Object.keys(body).length === 0) {
        return { content: [{ type: "text", text: "Provide at least one field to update." }], isError: true };
      }
      return toContent(await todoistRequest("POST", `/projects/${project_id}`, body));
    }

    if (action === "delete") {
      return toContent(await todoistRequest("DELETE", `/projects/${project_id}`));
    }

    if (action === "archive") {
      return toContent(await todoistRequest("POST", `/projects/${project_id}/archive`));
    }

    if (action === "unarchive") {
      return toContent(await todoistRequest("POST", `/projects/${project_id}/unarchive`));
    }

    return { content: [{ type: "text", text: `Unknown action: ${action}` }], isError: true };
  },
);

// ── todoist_labels ────────────────────────────────────────────────────────────

server.tool(
  "todoist_labels",
  "CRUD for Todoist labels (categories/tags). Actions: list, get, create, update, delete.",
  {
    action:      z.enum(["list","get","create","update","delete"])
                  .describe("Action to perform."),
    label_id:    z.string().optional().describe("Label ID — required for get, update, delete."),
    name:        z.string().optional().describe("Label name — required for create, used in update."),
    color:       z.string().optional().describe("Label color name, e.g. 'berry_red', 'lime_green', 'sky_blue'."),
    order:       z.number().int().optional().describe("Sort order among labels."),
    is_favorite: z.boolean().optional().describe("Mark label as favourite."),
  },
  async ({ action, label_id, name, color, order, is_favorite }) => {
    const needsId = ["get","update","delete"];
    if (needsId.includes(action) && !label_id) {
      return { content: [{ type: "text", text: `label_id is required for action=${action}.` }], isError: true };
    }

    if (action === "list") {
      return toContent(await todoistRequest("GET", "/labels"));
    }

    if (action === "get") {
      return toContent(await todoistRequest("GET", `/labels/${label_id}`));
    }

    if (action === "create") {
      if (!name) return { content: [{ type: "text", text: "name is required for create." }], isError: true };
      const body = { name };
      if (color)       body.color       = color;
      if (order !== undefined) body.order = order;
      if (is_favorite !== undefined) body.is_favorite = is_favorite;
      return toContent(await todoistRequest("POST", "/labels", body));
    }

    if (action === "update") {
      const body = {};
      if (name)        body.name        = name;
      if (color)       body.color       = color;
      if (order !== undefined) body.order = order;
      if (is_favorite !== undefined) body.is_favorite = is_favorite;
      if (Object.keys(body).length === 0) {
        return { content: [{ type: "text", text: "Provide at least one field to update." }], isError: true };
      }
      return toContent(await todoistRequest("POST", `/labels/${label_id}`, body));
    }

    if (action === "delete") {
      return toContent(await todoistRequest("DELETE", `/labels/${label_id}`));
    }

    return { content: [{ type: "text", text: `Unknown action: ${action}` }], isError: true };
  },
);

// ── todoist_sections ──────────────────────────────────────────────────────────

server.tool(
  "todoist_sections",
  "CRUD for Todoist sections (columns/sub-lists within a project). Actions: list, get, create, update, delete, archive, unarchive.",
  {
    action:     z.enum(["list","get","create","update","delete","archive","unarchive"])
                 .describe("Action to perform."),
    section_id: z.string().optional().describe("Section ID — required for get, update, delete, archive, unarchive."),
    project_id: z.string().optional().describe("Filter list by project ID, or assign project on create."),
    name:       z.string().optional().describe("Section name — required for create."),
    order:      z.number().int().optional().describe("Section sort order within the project."),
  },
  async ({ action, section_id, project_id, name, order }) => {
    const needsId = ["get","update","delete","archive","unarchive"];
    if (needsId.includes(action) && !section_id) {
      return { content: [{ type: "text", text: `section_id is required for action=${action}.` }], isError: true };
    }

    if (action === "list") {
      const p = new URLSearchParams();
      if (project_id) p.set("project_id", project_id);
      return toContent(await todoistRequest("GET", `/sections${p.toString() ? `?${p}` : ""}`));
    }

    if (action === "get") {
      return toContent(await todoistRequest("GET", `/sections/${section_id}`));
    }

    if (action === "create") {
      if (!name)       return { content: [{ type: "text", text: "name is required for create." }], isError: true };
      if (!project_id) return { content: [{ type: "text", text: "project_id is required for create." }], isError: true };
      const body = { name, project_id };
      if (order !== undefined) body.order = order;
      return toContent(await todoistRequest("POST", "/sections", body));
    }

    if (action === "update") {
      const body = {};
      if (name)  body.name  = name;
      if (order !== undefined) body.order = order;
      if (Object.keys(body).length === 0) {
        return { content: [{ type: "text", text: "Provide name or order to update." }], isError: true };
      }
      return toContent(await todoistRequest("POST", `/sections/${section_id}`, body));
    }

    if (action === "delete") {
      return toContent(await todoistRequest("DELETE", `/sections/${section_id}`));
    }

    if (action === "archive") {
      return toContent(await todoistRequest("POST", `/sections/${section_id}/archive`));
    }

    if (action === "unarchive") {
      return toContent(await todoistRequest("POST", `/sections/${section_id}/unarchive`));
    }

    return { content: [{ type: "text", text: `Unknown action: ${action}` }], isError: true };
  },
);

// ── Cron tool ─────────────────────────────────────────────────────────────────
server.tool(
  "cron",
  "Manage OpenClaw scheduled tasks. Actions: list, add, update, remove, run. Use list first to see job IDs.",
  {
    action:          z.enum(["list", "add", "update", "remove", "run"]).describe("Action to perform."),
    id:              z.string().optional().describe("Job ID (required for update, remove, run)."),
    job:             z.record(z.string(), z.any()).optional().describe("Full job object (for action=add)."),
    patch:           z.record(z.string(), z.any()).optional().describe("Partial update fields (for action=update)."),
    includeDisabled: z.boolean().optional().describe("Include disabled jobs in list output."),
    runMode:         z.enum(["due", "force"]).optional().describe('"due" runs only if due; "force" runs unconditionally.'),
  },
  async ({ action, id, job, patch, includeDisabled, runMode }) => {
    if (action === "list") {
      const args = ["cron", "list"];
      if (includeDisabled) args.push("--include-disabled");
      return toContent(await runCLI(args));
    }
    if (action === "remove") {
      if (!id) return { content: [{ type: "text", text: "id is required for action=remove." }], isError: true };
      return toContent(await runCLI(["cron", "rm", id]));
    }
    if (action === "run") {
      if (!id) return { content: [{ type: "text", text: "id is required for action=run." }], isError: true };
      const args = ["cron", "run", id];
      if (runMode === "force") args.push("--force");
      return toContent(await runCLI(args));
    }
    if (action === "add") {
      if (!job) return { content: [{ type: "text", text: "job object is required for action=add." }], isError: true };
      return toContent(await runCLI(["cron", "add", "--job", JSON.stringify(job)]));
    }
    if (action === "update") {
      if (!id)    return { content: [{ type: "text", text: "id is required for action=update." }], isError: true };
      if (!patch) return { content: [{ type: "text", text: "patch is required for action=update." }], isError: true };
      return toContent(await runCLI(["cron", "edit", id, "--patch", JSON.stringify(patch)]));
    }
    return { content: [{ type: "text", text: `Unknown cron action: ${action}` }], isError: true };
  },
);

// ── Gateway health tool ───────────────────────────────────────────────────────

server.tool(
  "gateway_health",
  "Check the OpenClaw gateway status: uptime, channel states, and active cron count.",
  {},
  async () => {
    const token = getToken();
    let res;
    try {
      res = await fetchWithTimeout(
        `${GATEWAY_URL}/health`,
        token ? { headers: { Authorization: `Bearer ${token}` } } : {},
        10_000,
      );
    } catch (err) {
      return { content: [{ type: "text", text: `Gateway unreachable at ${GATEWAY_URL}: ${err.message}` }], isError: true };
    }
    const body = await res.text();
    let data;
    try { data = JSON.parse(body); } catch { data = body; }
    return {
      content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
      ...(res.ok ? {} : { isError: true }),
    };
  },
);

// ── Start ─────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
