import { Type } from "@sinclair/typebox";
import { jsonResult, readStringParam } from "openclaw/plugin-sdk/agent-runtime";
import type { HabiticaAuth } from "./api.js";
import { createTask, fetchDashboard, fetchTasks, fetchUserStats, scoreHabit, scoreTask } from "./api.js";

const HabiticaToolSchema = Type.Object(
  {
    action: Type.Unsafe<
      "dashboard" | "dailies" | "habits" | "todos" | "stats" | "complete" | "create_todo" | "score_habit"
    >({
      type: "string",
      enum: ["dashboard", "dailies", "habits", "todos", "stats", "complete", "create_todo", "score_habit"],
      description:
        "Action to perform: 'dashboard' for full overview, 'dailies'/'habits'/'todos' for specific lists, 'stats' for user stats, 'complete' to mark a task done, 'create_todo' to create a new task (todo/daily/habit), 'score_habit' to score a habit up or down.",
    }),
    task_id: Type.Optional(
      Type.String({ description: "Task ID (required for 'complete' and 'score_habit' actions)" }),
    ),
    title: Type.Optional(
      Type.String({ description: "Task title/text — required for 'create_todo'" }),
    ),
    task_type: Type.Optional(
      Type.Unsafe<"todo" | "habit" | "daily">({
        type: "string",
        enum: ["todo", "habit", "daily"],
        description: "Type of task to create — defaults to 'todo' if omitted",
      }),
    ),
    notes: Type.Optional(
      Type.String({ description: "Optional notes/description for the new task" }),
    ),
    priority: Type.Optional(
      Type.Number({ description: "Task priority: 0.1=trivial, 1=easy, 1.5=medium, 2=hard (default 1)" }),
    ),
    direction: Type.Optional(
      Type.Unsafe<"up" | "down">({
        type: "string",
        enum: ["up", "down"],
        description: "Direction to score a habit — 'up' for positive, 'down' for negative (required for 'score_habit')",
      }),
    ),
  },
  { additionalProperties: false },
);

function resolveAuth(authOverride?: HabiticaAuth): HabiticaAuth {
  if (authOverride) return authOverride;
  const userId = process.env.HABITICA_USER_ID?.trim();
  const apiKey = process.env.HABITICA_API_KEY?.trim();
  if (!userId || !apiKey) {
    throw new Error(
      "Habitica credentials not configured. Set HABITICA_USER_ID and HABITICA_API_KEY environment variables (Habitica Settings > API).",
    );
  }
  return { userId, apiKey };
}

/**
 * @param authOverride - When provided, credentials are used directly (useful for tests).
 *   When omitted, credentials are resolved from process.env at execute time.
 */
export function createHabiticaTool(authOverride?: HabiticaAuth) {
  return {
    name: "habitica",
    label: "Habitica",
    ownerOnly: true,
    description:
      "Interact with Habitica: fetch dashboard (dailies, habits, todos, stats), individual task lists, complete a task, create new todos/dailies/habits, or score a habit.",
    parameters: HabiticaToolSchema,
    execute: async (_toolCallId: string, rawParams: Record<string, unknown>) => {
      const auth = resolveAuth(authOverride);
      const action = readStringParam(rawParams, "action", { required: true }) ?? "dashboard";

      if (action === "dashboard") {
        const data = await fetchDashboard(auth);
        return jsonResult(data);
      }

      if (action === "dailies") {
        const tasks = await fetchTasks(auth, "dailys");
        const overdue = tasks.filter((t) => t.isDue && !t.completed);
        return jsonResult({
          total: tasks.length,
          overdue: overdue.length,
          dailies: tasks.map((t) => ({
            id: t.id,
            text: t.text,
            completed: t.completed,
            isDue: t.isDue,
            streak: t.streak,
          })),
        });
      }

      if (action === "habits") {
        const tasks = await fetchTasks(auth, "habits");
        return jsonResult({
          total: tasks.length,
          habits: tasks.map((t) => ({
            id: t.id,
            text: t.text,
            value: t.value,
          })),
        });
      }

      if (action === "todos") {
        const tasks = await fetchTasks(auth, "todos");
        const incomplete = tasks.filter((t) => !t.completed);
        return jsonResult({
          total: tasks.length,
          incomplete: incomplete.length,
          todos: incomplete.map((t) => ({
            id: t.id,
            text: t.text,
            priority: t.priority,
            date: t.date,
            notes: t.notes || undefined,
          })),
        });
      }

      if (action === "stats") {
        const stats = await fetchUserStats(auth);
        return jsonResult({
          hp: `${Math.round(stats.hp)}/${stats.maxHealth}`,
          mp: `${Math.round(stats.mp)}/${stats.maxMP}`,
          exp: `${stats.exp}/${stats.toNextLevel}`,
          level: stats.lvl,
          gold: Math.round(stats.gp * 100) / 100,
          class: stats.class,
        });
      }

      if (action === "complete") {
        const taskId = readStringParam(rawParams, "task_id", { required: true });
        if (!taskId) {
          return jsonResult({ error: "task_id is required for the 'complete' action" });
        }
        const result = await scoreTask(auth, taskId);
        return jsonResult({ success: true, taskId, result });
      }

      if (action === "create_todo") {
        const title = readStringParam(rawParams, "title", { required: true });
        if (!title) {
          return jsonResult({ error: "title is required for the 'create_todo' action" });
        }
        const taskType = (readStringParam(rawParams, "task_type") ?? "todo") as "todo" | "habit" | "daily";
        const notes = readStringParam(rawParams, "notes") ?? undefined;
        const priority = typeof rawParams.priority === "number" ? rawParams.priority : undefined;
        const result = await createTask(auth, { type: taskType, text: title, notes, priority });
        return jsonResult({ success: true, task: result });
      }

      if (action === "score_habit") {
        const taskId = readStringParam(rawParams, "task_id", { required: true });
        if (!taskId) {
          return jsonResult({ error: "task_id is required for the 'score_habit' action" });
        }
        const direction = (readStringParam(rawParams, "direction") ?? "up") as "up" | "down";
        const result = await scoreHabit(auth, taskId, direction);
        return jsonResult({ success: true, taskId, direction, result });
      }

      return jsonResult({ error: `Unknown action: ${action}` });
    },
  };
}
