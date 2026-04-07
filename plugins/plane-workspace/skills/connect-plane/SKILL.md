---
name: connect-plane
description: Connect Claude Code to your Plane workspace — configure the MCP server, fetch project metadata, and update your workspace config. Run after /setup.
user-invocable: true
argument-hint: "[--reset]"
allowed-tools: ["Bash(find *)", "Bash(curl *)", "Bash(cat *)", "Bash(*/plane-workspace/scripts/setup.sh *)", "Read", "Write", "Skill(update-config)"]
---

# /connect-plane — Connect to Plane Workspace

Configures the Plane MCP server and fetches project context for your agent. Run this after `/setup`.

> **IMPORTANT**: Do NOT pre-fill any values from memory or prior context. Ask every question explicitly.

## 0. Verify setup exists

Find the setup script:
```bash
find "$HOME" -maxdepth 10 -name "setup.sh" \
  -path "*/plane-workspace/scripts/*" 2>/dev/null | head -1
```

Store as `SETUP_SCRIPT`. If not found, stop and tell the user to reinstall the plugin.

Load existing workspace config to get `base_path`:
```bash
cat "$CLAUDE_PLUGIN_ROOT/user/plane-workspace.json" 2>/dev/null || \
  cat "$(pwd)/.claude/plane-workspace.json" 2>/dev/null || \
  cat ~/.claude/plane-workspace.json 2>/dev/null
```

If no config found, stop and tell the user to run `/setup` first.

## 1. Collect Plane Connection Details

Use `AskUserQuestion` to collect in **one prompt**:

- **Workspace slug** — the part after `app.plane.so/` (e.g. `my-team`)
- **API token** — from Plane Settings → API Tokens
- **API base URL** — default: `https://api.plane.so` (only change if self-hosted)

## 2. Validate & Fetch Projects

```bash
"$SETUP_SCRIPT" connect <api_base> <api_token> <slug>
```

- If output contains `{"error": ...}` → show the error, ask the user to recheck token/slug, go back to step 1.
- If success → show: *"Connected as [display_name]."* and list projects as `IDENTIFIER — Name`.

## 3. Select Projects & Repo Paths

Use `AskUserQuestion` to ask:

- **Which projects do you work on?** (enter identifiers, e.g. `INFRA, WEB` — or `all` for everything)
- For each selected project (if user `writes_code` is true in config): **Repo folder(s)?** (comma-separated absolute paths, or leave blank if none)

## 4. Save Connection

Build a connect config JSON and write to `/tmp/plane-connect-config.json`:

```json
{
  "base_path": "<from plane-workspace.json _meta.base_path>",
  "scope": "<from plane-workspace.json _meta.scope>",
  "api_base": "<api_base>",
  "api_token": "<api_token>",
  "workspace_slug": "<slug>",
  "plane_user_id": "<from connect output>",
  "selected_projects": [
    {
      "identifier": "INFRA",
      "id": "<from connect output>",
      "name": "<from connect output>",
      "repos": ["/path/to/repo1", "/path/to/repo2"]
    }
  ]
}
```

Then run:

```bash
"$SETUP_SCRIPT" connect-save /tmp/plane-connect-config.json
```

This fetches states, labels, and members for each selected project, updates `plane-workspace.json` with the plane section and project metadata, and writes `.mcp.json` from the template.

Also run `Skill(update-config)` to add `"mcp__plane-claude-mcp__*"` to allowed permissions.

Update the user's agent file (`$base_path/agents/<agent_name>.md`) to set their `Plane User ID` field from `plane_user_id` in the connect output.

## 5. Confirm

Show the script's output. Then display:

```
✅ Connected to Plane!
   Workspace: <slug>
   Projects:  <list of identifiers>
   MCP:       plane-claude-mcp

Your agent can now manage work items, projects, and more.

To add helper agents:
  /helpers add devops   → DevOps helper
  /helpers add pm       → PM helper
  /helpers add ea       → EA for briefings
```
