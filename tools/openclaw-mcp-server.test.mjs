/**
 * Integration tests for openclaw-mcp-server.mjs
 *
 * Tests verify tool registration and handler logic by mocking child_process and fetch.
 */
import { beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

// ── Mock setup (must happen before server import) ────────────────────────────

// Capture registered tools
const registeredTools = new Map();

vi.mock("@modelcontextprotocol/sdk/server/mcp.js", () => ({
  McpServer: vi.fn(function () {
    this.tool = vi.fn((name, _desc, _schema, handler) => {
      registeredTools.set(name, { handler });
    });
    this.connect = vi.fn();
  }),
}));

vi.mock("@modelcontextprotocol/sdk/server/stdio.js", () => ({
  StdioServerTransport: vi.fn(function () {}),
}));

// Mock execFile at the module level -- actual implementation replaced per-test
const execFileMock = vi.fn();
vi.mock("node:child_process", () => ({
  execFile: (cmd, args, opts, cb) => {
    // Handle both (cmd, args, opts, cb) and (cmd, args, cb) signatures
    const callback = typeof opts === "function" ? opts : cb;
    execFileMock(cmd, args, (err, stdout, stderr) => {
      if (err) {
        const e = Object.assign(new Error(err.message ?? "Command failed"), {
          stderr: err.stderr ?? "",
          stdout: err.stdout ?? "",
          code: err.code ?? 1,
        });
        callback(e, { stdout: err.stdout ?? "", stderr: err.stderr ?? "" });
      } else {
        callback(null, { stdout: stdout ?? "", stderr: stderr ?? "" });
      }
    });
  },
}));

vi.mock("node:util", () => ({
  promisify: (fn) => {
    return (...args) =>
      new Promise((resolve, reject) => {
        fn(...args, (err, result) => {
          if (err) reject(err);
          else resolve(result);
        });
      });
  },
}));

// Mock global fetch -- re-stubbed in beforeEach because vitest's unstubGlobals:true
// restores globals after each test.
const mockFetch = vi.fn();

// Set env before importing the server
process.env.OPENCLAW_GATEWAY_TOKEN = "test-token";
process.env.OPENCLAW_GATEWAY_URL = "http://localhost:18789";
process.env.OPENCLAW_WHATSAPP_ACCOUNT = "default";

await import("./openclaw-mcp-server.mjs");

// Re-stub fetch before every test (undone by unstubGlobals:true between tests)
beforeEach(() => {
  vi.stubGlobal("fetch", mockFetch);
});

// ── Helper to call a registered tool handler ─────────────────────────────────

async function callTool(name, params = {}) {
  const entry = registeredTools.get(name);
  if (!entry) throw new Error(`Tool not registered: ${name}`);
  return entry.handler(params);
}

// ── Mock response helpers ─────────────────────────────────────────────────────

/** Queue a successful CLI response (JSON) */
function mockCli(data) {
  execFileMock.mockImplementationOnce((_cmd, _args, cb) =>
    cb(null, JSON.stringify(data), ""),
  );
}

/** Queue a failed CLI response */
function mockCliError(stderr) {
  execFileMock.mockImplementationOnce((_cmd, _args, cb) => {
    const err = Object.assign(new Error("Command failed"), {
      stderr,
      stdout: "",
      code: 1,
    });
    cb(err, "", stderr);
  });
}

/** Queue a successful HTTP response */
function mockGw(data) {
  mockFetch.mockResolvedValueOnce({
    ok: true,
    status: 200,
    text: async () => JSON.stringify(data),
  });
}

/** Queue a failed HTTP response */
function mockGwError(status, body = "error") {
  mockFetch.mockResolvedValueOnce({
    ok: false,
    status,
    text: async () => body,
  });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe("tool registration", () => {
  it("registers all 9 expected tools", () => {
    const expected = [
      "whatsapp_status",
      "whatsapp_contacts",
      "whatsapp_send",
      "whatsapp_poll",
      "whatsapp_react",
      "whatsapp_archive",
      "habitica",
      "cron",
      "gateway_health",
    ];
    for (const name of expected) {
      expect(registeredTools.has(name), `Missing tool: ${name}`).toBe(true);
    }
    expect(registeredTools.size).toBe(9);
  });
});

describe("whatsapp_status", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns CLI output on success", async () => {
    mockCli({ connected: true });
    const result = await callTool("whatsapp_status");
    expect(result.isError).toBeUndefined();
    expect(result.content[0].text).toContain("connected");
  });

  it("returns isError on CLI failure", async () => {
    mockCliError("WhatsApp not linked");
    const result = await callTool("whatsapp_status");
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("WhatsApp not linked");
  });
});

describe("whatsapp_contacts", () => {
  beforeEach(() => vi.clearAllMocks());

  it("fetches both peers and groups when kind=all", async () => {
    mockCli([{ jid: "1234@s.whatsapp.net", name: "Alice" }]);
    mockCli([{ jid: "group-1@g.us", name: "Family" }]);
    const result = await callTool("whatsapp_contacts", { kind: "all" });
    expect(result.isError).toBeUndefined();
    const data = JSON.parse(result.content[0].text);
    expect(data).toHaveProperty("peers");
    expect(data).toHaveProperty("groups");
  });

  it("fetches only peers when kind=peers", async () => {
    mockCli([{ jid: "1234@s.whatsapp.net", name: "Alice" }]);
    const result = await callTool("whatsapp_contacts", { kind: "peers" });
    expect(result.isError).toBeUndefined();
    expect(execFileMock).toHaveBeenCalledTimes(1);
  });

  it("fetches only groups when kind=groups", async () => {
    mockCli([{ jid: "group-1@g.us", name: "Family" }]);
    const result = await callTool("whatsapp_contacts", { kind: "groups" });
    expect(result.isError).toBeUndefined();
    expect(execFileMock).toHaveBeenCalledTimes(1);
  });
});

describe("whatsapp_send", () => {
  beforeEach(() => vi.clearAllMocks());

  it("sends a text message", async () => {
    mockCli({ messageId: "abc123" });
    const result = await callTool("whatsapp_send", {
      target: "+15551234567",
      message: "Hello!",
    });
    expect(result.isError).toBeUndefined();
    const [cmd, args] = execFileMock.mock.calls[0];
    expect(cmd).toBe("openclaw");
    expect(args).toContain("--target");
    expect(args).toContain("+15551234567");
    expect(args).toContain("--message");
    expect(args).toContain("Hello!");
  });

  it("includes --media when media is provided", async () => {
    mockCli({ messageId: "abc124" });
    await callTool("whatsapp_send", {
      target: "+15551234567",
      message: "See attached",
      media: "/tmp/chart.png",
    });
    const [, args] = execFileMock.mock.calls[0];
    expect(args).toContain("--media");
    expect(args).toContain("/tmp/chart.png");
  });

  it("includes --gif-playback flag when requested", async () => {
    mockCli({ messageId: "abc125" });
    await callTool("whatsapp_send", {
      target: "+15551234567",
      message: "Animated",
      media: "/tmp/anim.mp4",
      gif_playback: true,
    });
    const [, args] = execFileMock.mock.calls[0];
    expect(args).toContain("--gif-playback");
  });
});

describe("whatsapp_archive", () => {
  beforeEach(() => vi.clearAllMocks());

  it("calls gateway /tools/invoke with whatsapp_archive tool", async () => {
    mockGw({ count: 1, messages: [{ id: "m1", is_voice_note: false }] });
    const result = await callTool("whatsapp_archive", {
      action: "recent",
      limit: 10,
    });
    expect(result.isError).toBeUndefined();
    const [url, opts] = mockFetch.mock.calls[0];
    expect(url).toContain("/tools/invoke");
    const body = JSON.parse(opts.body);
    expect(body.tool).toBe("whatsapp_archive");
    expect(body.args.action).toBe("recent");
  });

  it("returns isError on gateway auth failure (401)", async () => {
    mockGwError(401, "Unauthorized");
    const result = await callTool("whatsapp_archive", { action: "recent" });
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("401");
  });

  it("returns isError when gateway token is not configured", async () => {
    const orig = process.env.OPENCLAW_GATEWAY_TOKEN;
    process.env.OPENCLAW_GATEWAY_TOKEN = "";
    try {
      const result = await callTool("whatsapp_archive", { action: "recent" });
      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("OPENCLAW_GATEWAY_TOKEN");
    } finally {
      process.env.OPENCLAW_GATEWAY_TOKEN = orig;
    }
  });
});

describe("habitica", () => {
  beforeEach(() => vi.clearAllMocks());

  it("forwards action to gateway", async () => {
    mockGw({ dailies: [{ text: "Morning routine", completed: false }] });
    const result = await callTool("habitica", { action: "dailies" });
    expect(result.isError).toBeUndefined();
    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body.tool).toBe("habitica");
    expect(body.args.action).toBe("dailies");
  });

  it("returns error when task_id is missing for complete action", async () => {
    const result = await callTool("habitica", { action: "complete" });
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("task_id is required");
  });

  it("sends task_id for complete action", async () => {
    mockGw({ success: true });
    await callTool("habitica", { action: "complete", task_id: "task-abc" });
    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body.args.task_id).toBe("task-abc");
  });
});

describe("cron", () => {
  beforeEach(() => vi.clearAllMocks());

  it("lists cron jobs", async () => {
    mockGw({ jobs: [{ id: "job-1", name: "Daily reminder" }] });
    const result = await callTool("cron", { action: "list" });
    expect(result.isError).toBeUndefined();
    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body.tool).toBe("cron");
    expect(body.args.action).toBe("list");
  });

  it("passes id and patch for update action", async () => {
    mockGw({ updated: true });
    await callTool("cron", {
      action: "update",
      id: "job-1",
      patch: { enabled: false },
    });
    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body.args.id).toBe("job-1");
    expect(body.args.patch).toEqual({ enabled: false });
  });
});

describe("gateway_health", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns health data on success", async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: async () => JSON.stringify({ status: "ok", uptime: 12345 }),
    });
    const result = await callTool("gateway_health");
    expect(result.isError).toBeUndefined();
    const data = JSON.parse(result.content[0].text);
    expect(data.status).toBe("ok");
    expect(data.uptime).toBe(12345);
  });

  it("falls back to CLI when gateway is unreachable", async () => {
    mockFetch.mockRejectedValueOnce(
      Object.assign(new Error("fetch failed: ECONNREFUSED"), {
        code: "ECONNREFUSED",
      }),
    );
    mockCli({ gateway: "offline" });
    const result = await callTool("gateway_health");
    // CLI fallback was attempted and returned a result
    expect(result.content[0].text).toBeTruthy();
  });

  it("returns isError on non-ok health response", async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      status: 503,
      text: async () => JSON.stringify({ error: "gateway overloaded" }),
    });
    const result = await callTool("gateway_health");
    expect(result.isError).toBe(true);
  });
});
