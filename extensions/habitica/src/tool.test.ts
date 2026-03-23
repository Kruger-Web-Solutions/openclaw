import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("./api.js", () => ({
  fetchDashboard: vi.fn(),
  fetchTasks: vi.fn(),
  fetchUserStats: vi.fn(),
  scoreTask: vi.fn(),
  createTask: vi.fn(),
  scoreHabit: vi.fn(),
}));

import type { HabiticaAuth } from "./api.js";
import { createTask, fetchDashboard, fetchTasks, fetchUserStats, scoreHabit, scoreTask } from "./api.js";
import { createHabiticaTool } from "./tool.js";

describe("habitica tool", () => {
  const auth: HabiticaAuth = { userId: "test-user", apiKey: "test-key" };

  beforeEach(() => {
    vi.mocked(fetchDashboard).mockResolvedValue({
      stats: { hp: "50/50", mp: "30/60", exp: "100/200", level: 10, gold: 42, class: "warrior" },
      overdueDailies: [],
      incompleteTodos: [],
      habits: [],
      summary: {
        totalDailies: 0,
        completedDailies: 0,
        overdueDailies: 0,
        totalTodos: 0,
        incompleteTodos: 0,
        totalHabits: 0,
      },
    });
    vi.mocked(fetchTasks).mockResolvedValue([]);
    vi.mocked(fetchUserStats).mockResolvedValue({
      hp: 50,
      maxHealth: 50,
      mp: 30,
      maxMP: 60,
      exp: 100,
      toNextLevel: 200,
      lvl: 10,
      gp: 42,
      class: "warrior",
    });
    vi.mocked(scoreTask).mockResolvedValue({ success: true });
    vi.mocked(createTask).mockResolvedValue({ id: "new-task-id", text: "Test", type: "todo" } as never);
    vi.mocked(scoreHabit).mockResolvedValue({ success: true });
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("has correct tool metadata", () => {
    const tool = createHabiticaTool(auth);
    expect(tool.name).toBe("habitica");
    expect(tool.ownerOnly).toBe(true);
  });

  it("handles dashboard action", async () => {
    const tool = createHabiticaTool(auth);
    const result = await tool.execute("call-1", { action: "dashboard" });

    expect(fetchDashboard).toHaveBeenCalledWith(auth);
    expect(result).toHaveProperty("content");
  });

  it("handles dailies action", async () => {
    vi.mocked(fetchTasks).mockResolvedValue([
      { id: "d1", text: "Run", type: "daily", isDue: true, completed: false, streak: 5 },
    ]);
    const tool = createHabiticaTool(auth);
    const result = await tool.execute("call-2", { action: "dailies" });

    expect(fetchTasks).toHaveBeenCalledWith(auth, "dailys");
    expect(result).toHaveProperty("content");
  });

  it("handles habits action", async () => {
    const tool = createHabiticaTool(auth);
    await tool.execute("call-3", { action: "habits" });

    expect(fetchTasks).toHaveBeenCalledWith(auth, "habits");
  });

  it("handles todos action", async () => {
    const tool = createHabiticaTool(auth);
    await tool.execute("call-4", { action: "todos" });

    expect(fetchTasks).toHaveBeenCalledWith(auth, "todos");
  });

  it("handles stats action", async () => {
    const tool = createHabiticaTool(auth);
    await tool.execute("call-5", { action: "stats" });

    expect(fetchUserStats).toHaveBeenCalledWith(auth);
  });

  it("handles complete action", async () => {
    const tool = createHabiticaTool(auth);
    await tool.execute("call-6", { action: "complete", task_id: "task-abc" });

    expect(scoreTask).toHaveBeenCalledWith(auth, "task-abc");
  });

  it("returns error for complete without task_id", async () => {
    const tool = createHabiticaTool(auth);
    await expect(tool.execute("call-7", { action: "complete" })).rejects.toThrow(
      "task_id required",
    );
  });

  it("handles create_todo action (todo type)", async () => {
    const tool = createHabiticaTool(auth);
    await tool.execute("call-ct-1", { action: "create_todo", title: "Fix the UI bug", task_type: "todo", priority: 2 });

    expect(createTask).toHaveBeenCalledWith(auth, {
      type: "todo",
      text: "Fix the UI bug",
      notes: undefined,
      priority: 2,
    });
  });

  it("handles create_todo action (daily type)", async () => {
    const tool = createHabiticaTool(auth);
    await tool.execute("call-ct-2", { action: "create_todo", title: "Morning walk", task_type: "daily" });

    expect(createTask).toHaveBeenCalledWith(auth, {
      type: "daily",
      text: "Morning walk",
      notes: undefined,
      priority: undefined,
    });
  });

  it("handles create_todo action defaults task_type to todo", async () => {
    const tool = createHabiticaTool(auth);
    await tool.execute("call-ct-3", { action: "create_todo", title: "Some task" });

    expect(createTask).toHaveBeenCalledWith(auth, expect.objectContaining({ type: "todo" }));
  });

  it("returns error for create_todo without title", async () => {
    const tool = createHabiticaTool(auth);
    await expect(tool.execute("call-ct-4", { action: "create_todo" })).rejects.toThrow(
      "title required",
    );
  });

  it("handles score_habit action up", async () => {
    const tool = createHabiticaTool(auth);
    await tool.execute("call-sh-1", { action: "score_habit", task_id: "habit-abc", direction: "up" });

    expect(scoreHabit).toHaveBeenCalledWith(auth, "habit-abc", "up");
  });

  it("handles score_habit action down", async () => {
    const tool = createHabiticaTool(auth);
    await tool.execute("call-sh-2", { action: "score_habit", task_id: "habit-abc", direction: "down" });

    expect(scoreHabit).toHaveBeenCalledWith(auth, "habit-abc", "down");
  });

  it("returns error for score_habit without task_id", async () => {
    const tool = createHabiticaTool(auth);
    await expect(tool.execute("call-sh-3", { action: "score_habit" })).rejects.toThrow(
      "task_id required",
    );
  });

  it("returns error for unknown action", async () => {
    const tool = createHabiticaTool(auth);
    const result = await tool.execute("call-8", { action: "invalid" });

    const block = result.content[0]!;
    const parsed = JSON.parse(block.type === "text" ? block.text : "");
    expect(parsed.error).toContain("Unknown action");
  });

  it("throws when env vars are missing and no auth override", async () => {
    delete process.env.HABITICA_USER_ID;
    delete process.env.HABITICA_API_KEY;
    const tool = createHabiticaTool();
    await expect(tool.execute("call-9", { action: "dashboard" })).rejects.toThrow(
      "Habitica credentials not configured",
    );
  });

  it("resolves auth from env vars when no override provided", async () => {
    process.env.HABITICA_USER_ID = "env-user";
    process.env.HABITICA_API_KEY = "env-key";
    const tool = createHabiticaTool();
    await tool.execute("call-10", { action: "dashboard" });
    expect(fetchDashboard).toHaveBeenCalledWith({ userId: "env-user", apiKey: "env-key" });
    delete process.env.HABITICA_USER_ID;
    delete process.env.HABITICA_API_KEY;
  });
});
