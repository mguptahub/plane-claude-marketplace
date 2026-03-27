---
name: setup
description: Initial setup wizard — configure your identity, connect to Plane, map projects to repos, and generate your personal agent. Re-run to add projects or reset.
user-invocable: true
argument-hint: "[--reset]"
allowed-tools: ["Bash(echo *)", "Bash(ls *)", "Bash(cat *)", "Bash(mkdir *)", "Bash(curl *)", "Bash(python3 *)", "Write", "Read"]
---

# /setup — Plane Workspace Setup Wizard

## Pre-check: Detect Install Scope

Run this bash command to get the actual plugin root:

```bash
echo $CLAUDE_PLUGIN_ROOT
```

From the output, derive `BASE_PATH` — the Claude home directory where all output files will go:

- Extract the portion of the path up to and including the first `.claude*` directory segment.
  - Example: `/Users/manish/.claude-plane/plugins/marketplaces/...` → `BASE_PATH = /Users/manish/.claude-plane`
  - Example: `/Volumes/Work/project/.claude/plugins/...` → `BASE_PATH = /Volumes/Work/project/.claude`

Scope interpretation:
- `BASE_PATH` is inside the user's home directory at top level (e.g., `~/.claude-plane`, `~/.claude`) → **user scope**
- `BASE_PATH` is inside a project directory → **local or project scope**

All output files (`plane-workspace.json`, `agents/<name>.md`) go to `BASE_PATH`. Never hardcode `~/.claude` — always derive from `$CLAUDE_PLUGIN_ROOT`.

Check if config already exists:
```bash
cat "$BASE_PATH/plane-workspace.json" 2>/dev/null || echo "NOT_FOUND"
```

If found and `$ARGUMENTS` does not contain `--reset`, ask:
> "Config found. Do you want to: (a) Add a project mapping (b) Full reset (c) Cancel"

---

## Step 1 — Your Identity

Ask:
1. **Full name**
2. **Work email**
3. **Role** — select from:
   - `frontend` — Frontend Engineer
   - `backend` — Backend Engineer
   - `fullstack` — Full-Stack Engineer
   - `devops` — DevOps Engineer
   - `qa` — QA / Tester
   - `pm` — Product Manager
   - `ea` — Executive Assistant
   - `designer` — Designer
   - `recruiter` — Recruiter
   - `other` — (prompt: "Describe your role in a few words")
4. **Agent name** — *"What should your agent be called?"* (e.g., `manish`, `akshat`, `priya`) — this becomes `<name>.md`
5. **Do you write code?** — auto-yes for frontend/backend/fullstack/devops/qa. Ask for pm/ea/designer/recruiter/other.

---

## Step 2 — Plane Connection

Ask:
1. **Workspace slug** — part after `app.plane.so/` in their URL
2. **API token** — from Plane Settings → API Tokens
3. **API base URL** — default `https://api.plane.so` (change for self-hosted)

Validate token:
```bash
curl -s -H "X-Api-Key: <token>" "<api_base>/api/v1/users/me/"
```

- Success → confirm: *"Connected as [display_name] — User ID: [id]"*
- Failure → show error, ask to retry. Do not proceed until validated.

Store `plane_user_id` from the `id` field.

Set up MCP server — write to `<cwd>/.mcp.json` (project/local scope) or `~/.claude/.mcp.json` (user scope):

```json
{
  "mcpServers": {
    "plane-claude-mcp": {
      "command": "uvx",
      "args": ["plane-mcp"],
      "env": {
        "PLANE_API_TOKEN": "<token>",
        "PLANE_BASE_URL": "<api_base>",
        "PLANE_WORKSPACE_SLUG": "<slug>"
      }
    }
  }
}
```

Also add permissions via `Skill(update-config)`:
```json
"mcp__plane-claude-mcp__*"
```

---

## Step 3 — Project Mapping

Fetch projects:
```bash
curl -s -H "X-Api-Key: <token>" "<api_base>/api/v1/workspaces/<slug>/projects/"
```

Display the list. For each project:
- **Repo folder(s)?** — comma-separated local paths, or "none"
  - Skip if user does not write code

Fetch metadata for each project in parallel (states, labels, members):
```bash
curl -s -H "X-Api-Key: <token>" "<api_base>/api/v1/workspaces/<slug>/projects/<id>/states/"
curl -s -H "X-Api-Key: <token>" "<api_base>/api/v1/workspaces/<slug>/projects/<id>/labels/"
curl -s -H "X-Api-Key: <token>" "<api_base>/api/v1/workspaces/<slug>/projects/<id>/members/"
```

---

## Step 4 — Write plane-workspace.json

```bash
mkdir -p "$BASE_PATH"
```

Write to `$BASE_PATH/plane-workspace.json`:

```json
{
  "_meta": {
    "setup_date": "<YYYY-MM-DD>",
    "scope": "<user|project|local>",
    "plugin_root": "<CLAUDE_PLUGIN_ROOT>"
  },
  "user": {
    "name": "<name>",
    "email": "<email>",
    "role": "<role>",
    "role_description": "<custom or null>",
    "agent_name": "<chosen agent name>",
    "plane_user_id": "<id>",
    "writes_code": "<true|false>"
  },
  "plane": {
    "workspace_slug": "<slug>",
    "api_base": "<api_base>",
    "mcp_server": "plane-claude-mcp"
  },
  "projects": [
    {
      "identifier": "<ID>",
      "id": "<project_id>",
      "name": "<name>",
      "repos": ["<path1>"],
      "states": [{"name": "...", "id": "...", "group": "..."}],
      "labels": [{"name": "...", "id": "...", "color": "..."}],
      "members": [{"name": "...", "id": "...", "email": "..."}]
    }
  ]
}
```

---

## Step 5 — Generate Agent File

Read the role template:
```bash
cat "$CLAUDE_PLUGIN_ROOT/templates/<role>.md"
```

Replace placeholders:

| Placeholder | Value |
|:------------|:------|
| `{{AGENT_NAME}}` | Chosen agent name |
| `{{AGENT_CONTEXT}}` | "You are acting as **[name]**, a [role title]." |
| `{{AGENT_ROLE_TITLE}}` | Role display name (e.g., "DevOps Engineer") |
| `{{PLANE_USER_ID}}` | Plane user ID |
| `{{OWNER_NAME}}` | Same as agent name (self context) |
| `{{CUSTOM_NOTES}}` | Remove the line |

Write to:
```bash
mkdir -p "$BASE_PATH/agents"
# write to $BASE_PATH/agents/<agent-name>.md
```

---

## Step 6 — Confirm

```
✅ Plane workspace setup complete!

  You:      <name> (<role>) — <email>
  Agent:    <agent-name>.md ✓
  Plane:    <workspace_slug> (User ID: <plane_user_id>)
  MCP:      plane-claude-mcp ✓
  Projects: <count> mapped
  Scope:    <user|project|local>

Next steps:
  /helpers add devops    → Add a DevOps helper
  /helpers add pm        → Add a PM helper
  /helpers add ea        → Add an EA for briefings
```
