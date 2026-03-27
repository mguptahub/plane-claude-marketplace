---
name: setup
description: Initial setup wizard — configure your identity, connect to Plane, map projects to repos, and generate your personal agent. Re-run to add projects or reset.
user-invocable: true
argument-hint: "[--reset]"
allowed-tools: ["Bash(grep *)", "Bash(ls *)", "Bash(cat *)", "Bash(mkdir *)", "Bash(curl *)", "Bash(python3 *)", "Bash(find *)", "Write", "Read", "Skill(update-config)"]
---

# /setup — Plane Workspace Setup Wizard

> **IMPORTANT**: Do NOT use any session memory, prior context, or remembered values to pre-fill or skip any step. Every question must be asked explicitly and answered by the user in this session. Never assume you know the user's name, email, role, token, or any other value.

## Pre-check: Detect Install Scope & Paths

First, find the plugin's own installed file — this gives us the Claude home and templates dir without any hardcoding:

```bash
SKILL_FILE=$(find "$HOME" -maxdepth 8 -name "SKILL.md" \
  -path "*/plane-workspace/skills/setup/*" 2>/dev/null | head -1)

# Claude home = everything before /plugins/
CLAUDE_HOME=$(echo "$SKILL_FILE" | sed 's|/plugins/.*||')

# Templates dir = sibling of skills/
TEMPLATES_DIR=$(echo "$SKILL_FILE" | sed 's|/skills/setup/SKILL.md|/templates|')

echo "Claude home: $CLAUDE_HOME"
echo "Templates: $TEMPLATES_DIR"
```

This works regardless of how the user named their Claude home (`~/.claude`, `~/.claude-plane`, or anything else).

Now detect scope — the installer writes a reference into the project dir for local/project scope:

```bash
grep -rq "plane-claude-mcp\|plane-claude-marketplace\|plane-workspace" \
  "$(pwd)/.claude/" "$(pwd)/.mcp.json" 2>/dev/null \
  && echo "LOCAL" || echo "USER"
```

Determine `BASE_PATH`:
- `LOCAL` → **local/project scope** → `BASE_PATH = $(pwd)/.claude`
- `USER` → **user scope** → `BASE_PATH = $CLAUDE_HOME`

Show the user: *"Detected: [local|user] scope — writing to `<BASE_PATH>`"*

Check for existing config:
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
4. **Agent name** — *"What should your agent be called?"* (e.g., `manish`, `akshat`, `priya`) — this becomes `<name>.md` in the agents folder
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

**Configure MCP credentials** — the installer already created `.mcp.json` in the right place. Find and update it:

```bash
# For local/project scope — update the project's .mcp.json
cat "$(pwd)/.mcp.json" 2>/dev/null

# For user scope — update the Claude home .mcp.json
cat "$CLAUDE_HOME/.mcp.json" 2>/dev/null
```

Use the file that exists (based on detected scope). Update the `plane-claude-mcp` server entry with the API credentials. Do NOT create a new `.mcp.json` in any other location.

Also add `"mcp__plane-claude-mcp__*"` to allowed permissions using `Skill(update-config)` scoped to the same level (project settings for local/project scope, user settings for user scope).

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
    "base_path": "<BASE_PATH>"
  },
  "user": {
    "name": "<name>",
    "email": "<email>",
    "role": "<role>",
    "role_description": "<custom or null>",
    "agent_name": "<chosen agent name>",
    "plane_user_id": "<id>",
    "writes_code": <true|false>
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

Use `TEMPLATES_DIR` derived in the Pre-check step. Read the role template:

```bash
cat "$TEMPLATES_DIR/<role>.md"
```

Replace all placeholders:

| Placeholder | Value |
|:------------|:------|
| `{{AGENT_NAME}}` | Chosen agent name |
| `{{AGENT_CONTEXT}}` | "You are acting as **[name]**, a [role title]." |
| `{{AGENT_ROLE_TITLE}}` | Role display name (e.g., "DevOps Engineer") |
| `{{PLANE_USER_ID}}` | Plane user ID |
| `{{OWNER_NAME}}` | Same as agent name (self context) |
| `{{CUSTOM_NOTES}}` | Remove this line entirely |

Write to:
```bash
mkdir -p "$BASE_PATH/agents"
```

Write to `$BASE_PATH/agents/<agent-name>.md`

---

## Step 6 — Confirm

```
✅ Plane workspace setup complete!

  You:      <name> (<role>) — <email>
  Agent:    $BASE_PATH/agents/<agent-name>.md ✓
  Plane:    <workspace_slug> (User ID: <plane_user_id>)
  MCP:      plane-claude-mcp ✓
  Projects: <count> mapped
  Scope:    <user|local|project>

Next steps:
  /helpers add devops    → Add a DevOps helper
  /helpers add pm        → Add a PM helper
  /helpers add ea        → Add an EA for briefings
```
