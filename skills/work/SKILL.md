---
name: work
description: Universal work router — route to your personal agent or a named helper based on context. Reads your plane-workspace.json to understand available agents.
user-invocable: true
argument-hint: "[HelperName|WorkItemId] [instructions]  e.g. 'WEB-123' or 'gaurav create a work item for X' or 'shreya'"
---

# /work — Universal Work Router

Load context:

```bash
cat "$CLAUDE_PLUGIN_ROOT/user/plane-workspace.json"
ls "$CLAUDE_PLUGIN_ROOT/user/agents/" 2>/dev/null || echo "no-helpers"
```

This gives you:
- The user's identity and projects
- The list of available helper agents

---

## Routing Rules

### Step 1: Check for explicit agent name

Is the **first word** of `$ARGUMENTS` (case-insensitive) a name matching:
1. A file in `$CLAUDE_PLUGIN_ROOT/user/agents/` (e.g., `gaurav.md` → `gaurav`)
2. `me` → routes to `$CLAUDE_PLUGIN_ROOT/user/me.md`

If matched → the **remaining text** becomes the instruction for that agent. Go to Step 3.

### Step 2: Auto-route if no name matched

Use the full `$ARGUMENTS` text and infer the best destination:

| Signal | Route to |
|:--------|:---------|
| Work item identifier (e.g., `WEB-*`, `INFRA-*`, or any `<PROJECT>-<number>`) | **me** |
| Keywords: `implement`, `branch`, `PR`, `deploy`, `helm`, `terraform`, `frontend`, `backend` | **me** |
| Keywords: `email`, `gmail`, `slack`, `inbox`, `briefing`, `catch me up`, `messages` | **ea helper** (if installed) |
| Keywords: `create work item`, `backlog`, `scope`, `plan`, `triage`, `epic`, `requirements`, `feature` | **pm helper** (if installed) |
| Helper type inferred but not installed | Suggest: *"No [type] helper configured. Run `/helpers add [type]` to set one up."* |
| Ambiguous | Ask: *"Should I handle this as you (me) or route to a helper? Available: [list]"* |

### Step 3: Launch the agent

Use the Agent tool to launch the matched agent file:
- For `me`: use `$CLAUDE_PLUGIN_ROOT/user/me.md`
- For a helper: use `$CLAUDE_PLUGIN_ROOT/user/agents/<name>.md`

Pass the instruction text as the task prompt.
The agent reads its own file for persona and workflow instructions.

---

## Examples

| Command | Routes to | Instruction |
|:--------|:----------|:------------|
| `/work WEB-42` | me | `WEB-42` |
| `/work INFRA-99` | me | `INFRA-99` |
| `/work gaurav create ticket for Redis monitoring` | gaurav helper | `create ticket for Redis monitoring` |
| `/work shreya` | shreya helper | *(briefing)* |
| `/work check my emails` | ea helper (auto) | `check my emails` |
| `/work scope out new onboarding flow` | pm helper (auto) | `scope out new onboarding flow` |
| `/work me what's in my queue` | me | `what's in my queue` |
