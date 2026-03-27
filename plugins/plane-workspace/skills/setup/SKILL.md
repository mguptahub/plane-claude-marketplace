---
name: setup
description: Initial setup wizard — configure your identity, connect to Plane, map projects to repos, and generate your personal agent. Re-run to add projects or reset.
user-invocable: true
argument-hint: "[--reset]"
allowed-tools: ["Bash(grep *)", "Bash(ls *)", "Bash(cat *)", "Bash(mkdir *)", "Bash(curl *)", "Bash(python3 *)", "Bash(find *)", "Write", "Read", "Skill(update-config)"]
---

# /setup — Plane Workspace Setup Wizard

## Pre-check: Detect Install Scope

The installer wrote config to the project dir for local/project scope, or to the user's Claude home for user scope. Check which:

```bash
grep -rq "plane-claude-mcp\|mguptahub-plane-claude-marketplace\|plane-workspace" \
  "$(pwd)/.claude/" "$(pwd)/.mcp.json" 2>/dev/null \
  && echo "LOCAL: $(pwd)/.claude" \
  || echo "USER"
```

Determine `BASE_PATH`:
- Output starts with `LOCAL:` → **local/project scope** → `BASE_PATH = $(pwd)/.claude`
- Output is `USER` → **user scope** → find Claude home:

```bash
# Find the user's Claude home (has a plugins/ directory)
for dir in "$HOME/.claude-plane" "$HOME/.claude"; do
  [ -d "$dir/plugins" ] && echo $dir && break
done
```

→ `BASE_PATH = <found dir>`

Show the user: *"Detected scope: [local|user] — all files will be written to `BASE_PATH`"*

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

**Configure MCP credentials** — the installer already created `.mcp.json`. Update it with credentials using `Skill(update-config)`:

```json
{
  "mcpServers": {
    "plane-claude-mcp": {
      "env": {
        "PLANE_API_TOKEN": "<token>",
        "PLANE_BASE_URL": "<api_base>",
        "PLANE_WORKSPACE_SLUG": "<slug>"
      }
    }
  }
}
```

Also add permissions via `Skill(update-config)`: `"mcp__plane-claude-mcp__*"`

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

Find the templates directory from the plugin installation:
```bash
find "$HOME" "$(pwd)" -name "frontend.md" -path "*/plane-workspace/templates/*" 2>/dev/null | head -1
```

Derive `TEMPLATES_DIR` from the result (parent directory of the found file).

Read the role template:
```bash
cat "<TEMPLATES_DIR>/<role>.md"
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
