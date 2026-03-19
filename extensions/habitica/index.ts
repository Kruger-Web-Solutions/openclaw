import { definePluginEntry, type AnyAgentTool } from "openclaw/plugin-sdk/core";
import { createHabiticaTool } from "./src/tool.js";

export default definePluginEntry({
  id: "habitica",
  name: "Habitica Plugin",
  description: "Habitica dashboard and task management agent tool",
  register(api) {
    api.registerTool(createHabiticaTool() as AnyAgentTool);
  },
});
