---
name: setup
description: Initial setup wizard — configure your identity, connect to Plane, map projects to repos, and generate your personal agent. Re-run to add projects or reset config.
user-invocable: true
argument-hint: "[--reset]"
---

# /setup — Plane Workspace Setup Wizard

Set up or reconfigure your Plane workspace plugin. Guides you through identity, Plane API connection, project mapping, and personal agent generation.

---

## Pre-check

```bash
cat "$CLAUDE_PLUGIN_ROOT/user/plane-workspace.json" 2>/dev/null || echo "NOT_FOUND"
```

If config exists and `$ARGUMENTS` does not contain `--reset`, ask:
> "You already have a workspace configured. Do you want to:
> (a) Add a new project mapping
> (b) Full reconfigure (reset everything)
> (c) Cancel"

If (a) → skip to Step 3, reusing existing user/plane data.
If (b) → proceed from Step 1.
If (c) → exit.

---

## Step 1 — Your Identity

Ask the user:

1. **Full name** — your name as it should appear in agents and comments
2. **Work email** — your official email address
3. **Role** — select from:
   - `frontend` — Frontend Engineer
   - `backend` — Backend Engineer
   - `fullstack` — Full-Stack Engineer
   - `qa` — QA / Tester
   - `other` — (prompt for a custom role description)
4. **Do you write code?**
   - Auto-yes for: frontend, backend, fullstack
   - Ask explicitly for: qa, other

---

## Step 2 — Plane Connection

Ask for:

1. **Workspace slug** — the part after `app.plane.so/` in their Plane URL (e.g., `my-company`)
2. **API token** — from Plane Settings → API Tokens
3. **API base URL** — default `https://api.plane.so` (change for self-hosted instances)

**Validate the token immediately:**

```bash
curl -s \
  -H "X-Api-Key: <token>" \
  "<api_base>/api/v1/users/me/"
```

Parse the response:
- On success: confirm *"Connected as [display_name] ([email]) — User ID: [id]"*
- On failure: show the error, ask to retry. Do not proceed until validated.

Store:
- `plane_user_id` — from `id` field in response
- `display_name` and `email` for confirmation

**Set up MCP server:**

Invoke `Skill(update-config)` to add to project `.mcp.json`:

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

Also add `"mcp__plane-claude-mcp__*"` to allowed permissions via `Skill(update-config)`.

---

## Step 3 — Project Mapping

Fetch all projects from the workspace:

```bash
curl -s \
  -H "X-Api-Key: <token>" \
  "<api_base>/api/v1/workspaces/<slug>/projects/"
```

Display the list of projects (identifier + name).

For each project, ask:
- **Which local repo folder(s) map to this project?**
  - Accept comma-separated paths or "none"
  - Skip entirely if user does not write code (qa + writes_code=false)
  - Multiple repos → multiple paths (e.g., `/home/user/plane, /home/user/plane-ee`)

Fetch metadata for each project (run in parallel):

```bash
# States
curl -s -H "X-Api-Key: <token>" "<api_base>/api/v1/workspaces/<slug>/projects/<project_id>/states/"

# Labels
curl -s -H "X-Api-Key: <token>" "<api_base>/api/v1/workspaces/<slug>/projects/<project_id>/labels/"

# Members
curl -s -H "X-Api-Key: <token>" "<api_base>/api/v1/workspaces/<slug>/projects/<project_id>/members/"
```

---

## Step 4 — Write plane-workspace.json

```bash
mkdir -p "$CLAUDE_PLUGIN_ROOT/user"
```

Write to `$CLAUDE_PLUGIN_ROOT/user/plane-workspace.json`:

```json
{
  "_meta": {
    "setup_date": "<YYYY-MM-DD>",
    "plugin_version": "1.0.0"
  },
  "user": {
    "name": "<name>",
    "email": "<email>",
    "role": "<role>",
    "role_description": "<custom description or null>",
    "plane_user_id": "<id from /me>",
    "writes_code": true
  },
  "plane": {
    "workspace_slug": "<slug>",
    "api_base": "<api_base>",
    "mcp_server": "plane-claude-mcp"
  },
  "projects": [
    {
      "identifier": "<IDENTIFIER>",
      "id": "<project_id>",
      "name": "<project name>",
      "repos": ["<path1>", "<path2>"],
      "states": [
        {"name": "In Progress", "id": "...", "group": "started"}
      ],
      "labels": [
        {"name": "Bug", "id": "...", "color": "#eb144c"}
      ],
      "members": [
        {"name": "...", "id": "...", "email": "..."}
      ]
    }
  ]
}
```

---

## Step 5 — Generate me.md

Read the matching role template:

```bash
cat "$CLAUDE_PLUGIN_ROOT/templates/roles/<role>.md"
```

Replace all placeholders with actual values:

| Placeholder | Value |
|:------------|:------|
| `{{USER_NAME}}` | User's full name |
| `{{USER_EMAIL}}` | User's email |
| `{{PLANE_USER_ID}}` | Plane user ID from Step 2 |
| `{{USER_ROLE}}` | Role label (e.g., "Full-Stack Engineer") |
| `{{USER_ROLE_DESCRIPTION}}` | Custom notes if role = "other", else remove line |
| `{{WORKSPACE_SLUG}}` | Workspace slug |
| `{{WRITES_CODE}}` | true or false |
| `{{PROJECTS_SUMMARY}}` | Markdown table: Identifier \| Project Name \| Repos |

Write the result to `$CLAUDE_PLUGIN_ROOT/user/me.md`.

---

## Step 6 — Confirm Setup

Show a completion summary:

```
✅ Plane workspace setup complete!

  You:      <name> (<role>) — <email>
  Plane:    <workspace_slug> (User ID: <plane_user_id>)
  MCP:      plane-claude-mcp ✓
  Projects: <count> mapped
  Agent:    user/me.md ✓

Next steps:
  /helpers add pm        → Add a PM helper
  /helpers add ea        → Add an EA for briefings
  /work <TICKET-123>     → Start working on a ticket
```
