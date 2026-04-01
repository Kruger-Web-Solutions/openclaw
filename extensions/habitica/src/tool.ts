import { Type } from "@sinclair/typebox";
import { jsonResult, readStringParam } from "openclaw/plugin-sdk/agent-runtime";
import type { HabiticaAuth } from "./api.js";
import { createTask, fetchDashboard, fetchTasks, fetchUserStats, reorderTask, scoreHabit, scoreTask, updateTask } from "./api.js";

const HabiticaToolSchema = Type.Object(
  {
    action: Type.Unsafe<
      "dashboard" | "dailies" | "habits" | "todos" | "stats" | "complete" | "create_todo" | "update_task" | "reorder" | "score_habit"
    >({
      type: "string",
      enum: ["dashboard", "dailies", "habits", "todos", "stats", "complete", "create_todo", "update_task", "reorder", "score_habit"],
      description:
        "Action to perform: 'dashboard' for full overview, 'dailies'/'habits'/'todos' for specific lists, 'stats' for user stats, 'complete' to mark a task done by title (preferred) or task_id, 'create_todo' to create a new task (todo/daily/habit), 'update_task' to modify an existing task, 'reorder' to move a task to a position (0-based), 'score_habit' to score a habit up or down.",
    }),
    task_id: Type.Optional(
      Type.String({ description: "Task ID — only needed for 'complete'/'score_habit' when you already have the ID. Prefer 'title' for 'complete' instead." }),
    ),
    title: Type.Optional(
      Type.String({ description: "Task name/title — required for 'create_todo'; also accepted by 'complete' to find and complete a task by name (case-insensitive substring match)." }),
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
    repeat: Type.Optional(
      Type.Object({
        m: Type.Optional(Type.Boolean()),
        t: Type.Optional(Type.Boolean()),
        w: Type.Optional(Type.Boolean()),
        th: Type.Optional(Type.Boolean()),
        f: Type.Optional(Type.Boolean()),
        s: Type.Optional(Type.Boolean()),
        su: Type.Optional(Type.Boolean()),
      }, { description: "Day-of-week repeat for dailies: m=Mon, t=Tue, w=Wed, th=Thu, f=Fri, s=Sat, su=Sun. Omitted days default to false." }),
    ),
    frequency: Type.Optional(
      Type.Unsafe<"weekly" | "daily" | "monthly" | "yearly">({
        type: "string",
        enum: ["weekly", "daily", "monthly", "yearly"],
        description: "Repeat frequency for dailies (default: weekly)",
      }),
    ),
    position: Type.Optional(
      Type.Number({ description: "0-based position to move a task to (required for reorder action)." }),
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
            notes: t.notes || undefined,
          })),
        });
      }

      if (action === "habits") {
        const tasks = await fetchTasks(auth, "habits");
        return jsonResult({
          total: tasks.length,
          habits: tasks.map((t) => ({
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
            text: t.text,
            priority: t.priority,
            due: t.date || undefined,
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
        let taskId = readStringParam(rawParams, "task_id");
        const titleParam = readStringParam(rawParams, "title");

        // If no task_id but title given, look up the task by name (case-insensitive substring)
        if (!taskId && titleParam) {
          const allTasks = [
            ...(await fetchTasks(auth, "todos")),
            ...(await fetchTasks(auth, "dailys")),
          ];
          const match = allTasks.find(
            (t) => !t.completed && t.text.toLowerCase().includes(titleParam.toLowerCase()),
          );
          if (!match) {
            return jsonResult({ error: `No incomplete task found matching: "${titleParam}"` });
          }
          taskId = match.id;
        }

        if (!taskId) {
          return jsonResult({ error: "Provide 'title' (task name) or 'task_id' for the complete action." });
        }
        const result = await scoreTask(auth, taskId);
        return jsonResult({ success: true, result });
      }

      if (action === "create_todo") {
        const title = readStringParam(rawParams, "title", { required: true });
        if (!title) {
          return jsonResult({ error: "title is required for the 'create_todo' action" });
        }
        const taskType = (readStringParam(rawParams, "task_type") ?? "todo") as "todo" | "habit" | "daily";
        const notes = readStringParam(rawParams, "notes") ?? undefined;
        const priority = typeof rawParams.priority === "number" ? rawParams.priority : undefined;
        const repeat = rawParams.repeat as Record<string, boolean> | undefined;
        const frequency = readStringParam(rawParams, "frequency") as "weekly" | "daily" | "monthly" | "yearly" | undefined;
        const result = await createTask(auth, { type: taskType, text: title, notes, priority, repeat, frequency });
        return jsonResult({ success: true, task: result });
      }

      if (action === "update_task") {
        const taskId = readStringParam(rawParams, "task_id");
        if (!taskId) {
          return jsonResult({ error: "task_id is required for the 'update_task' action" });
        }
        const fields: Record<string, unknown> = {};
        const title = readStringParam(rawParams, "title");
        if (title) fields.text = title;
        const notes = readStringParam(rawParams, "notes");
        if (notes !== undefined) fields.notes = notes;
        if (typeof rawParams.priority === "number") fields.priority = rawParams.priority;
        if (rawParams.repeat) fields.repeat = rawParams.repeat;
        const frequency = readStringParam(rawParams, "frequency");
        if (frequency) fields.frequency = frequency;
        if (Object.keys(fields).length === 0) {
          return jsonResult({ error: "Provide at least one field to update (title, notes, priority, repeat, frequency)." });
        }
        const result = await updateTask(auth, taskId, fields as Parameters<typeof updateTask>[2]);
        return jsonResult({ success: true, task: result });
      }

      if (action === "reorder") {
        const taskId = readStringParam(rawParams, "task_id");
        if (!taskId) {
          return jsonResult({ error: "task_id is required for the 'reorder' action" });
        }
        const position = typeof rawParams.position === "number" ? rawParams.position : undefined;
        if (position === undefined) {
          return jsonResult({ error: "position (0-based integer) is required for the 'reorder' action" });
        }
        const result = await reorderTask(auth, taskId, position);
        return jsonResult({ success: true, newOrder: result });
      }

      if (action === "score_habit") {
        let taskId = readStringParam(rawParams, "task_id");
        const titleParam = readStringParam(rawParams, "title");

        if (!taskId && titleParam) {
          const habits = await fetchTasks(auth, "habits");
          const match = habits.find((t) => t.text.toLowerCase().includes(titleParam.toLowerCase()));
          if (!match) {
            return jsonResult({ error: `No habit found matching: "${titleParam}"` });
          }
          taskId = match.id;
        }

        if (!taskId) {
          return jsonResult({ error: "Provide 'title' (habit name) or 'task_id' for the score_habit action." });
        }
        const direction = (readStringParam(rawParams, "direction") ?? "up") as "up" | "down";
        const result = await scoreHabit(auth, taskId, direction);
        return jsonResult({ success: true, direction, result });
      }

      return jsonResult({ error: `Unknown action: ${action}` });
    },
  };
}
