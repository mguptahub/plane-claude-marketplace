---
name: setup
description: Initial setup wizard — configure your identity, connect to Plane, map projects to repos, and generate your personal agent. Re-run to add projects or reset.
user-invocable: true
argument-hint: "[--reset]"
allowed-tools: ["Bash(find *)", "Bash(*/plane-workspace/scripts/setup.sh *)", "Write", "Read", "Skill(update-config)"]
---

# /setup — Plane Workspace Setup Wizard

> **IMPORTANT**: Do NOT use any session memory, prior context, or remembered values to pre-fill or skip any step. Every question must be asked explicitly and answered by the user in this session. Never assume any value.

## 0. Find the setup script

```bash
find "$HOME" -maxdepth 10 -name "setup.sh" \
  -path "*/plane-workspace/scripts/*" 2>/dev/null | head -1
```

Store as `SETUP_SCRIPT`. If not found, tell the user the plugin may not be installed correctly.

## 1. Collect Identity

Use `AskUserQuestion` to collect all identity fields in one prompt:
- Full name
- Work email
- Role (select: frontend / backend / fullstack / devops / qa / pm / ea / designer / recruiter / other)
- If "other": ask for a short role description
- Agent name — what should your agent be called? (e.g. `manish`, `priya`) — becomes `<name>.md`
- Do you write code? (auto-yes for frontend/backend/fullstack/devops/qa — only ask for pm/ea/designer/recruiter/other)

## 2. Collect Plane Connection

Use `AskUserQuestion` to collect in one prompt:
- Workspace slug (the part after `app.plane.so/`) — leave blank to skip
- API token (from Plane Settings → API Tokens) — leave blank to skip Plane/MCP setup
- API base URL (default: `https://api.plane.so` — only needed if self-hosted)

If both slug and token are blank, Plane MCP connection will be skipped. The user can re-run `/setup` later to connect.

## 3. Validate & Fetch Projects

Pass `-` for token/slug if the user left them blank:

```bash
"$SETUP_SCRIPT" init <api_base> <api_token_or_-> <slug_or_-> "$(pwd)"
```

This always detects the install scope. If a token was provided, it also validates it and returns the project list.

- If it returns `{"error": ...}` → show the error, ask the user to re-check token/slug, go back to step 2.
- If result has `"no_token": true` → note: *"No Plane connection configured. You can add it later by re-running /setup."* Skip straight to step 5 (no project selection; `selected_projects` will be `[]`).
- If successful with token → show: *"Connected as [display_name]. Detected [scope] scope."*

Parse and display the project list as `IDENTIFIER — Name`.

## 4. Select Projects & Repo Paths

*(Skip this step entirely if no token was provided — go to step 5.)*

Use `AskUserQuestion` to ask:
- **Which projects do you work on?** (enter identifiers, e.g. `INFRA, WEB`)
- For each selected project (if user writes code): **Repo folder(s)?** (comma-separated paths, or "none")

## 5. Run Full Setup

Build a config JSON and write it to `/tmp/plane-setup-config.json`:

```json
{
  "base_path": "<from init output>",
  "scope": "<from init output>",
  "user": {
    "name": "<name>",
    "email": "<email>",
    "role": "<role>",
    "role_description": "<custom or null>",
    "agent_name": "<agent_name>",
    "plane_user_id": "<from init output, or empty string if no token>",
    "writes_code": <true|false>
  },
  "plane": {
    "workspace_slug": "<slug or empty>",
    "api_base": "<api_base>",
    "api_token": "<token or empty — omit key if no token>"
  },
  "selected_projects": [
    {
      "identifier": "INFRA",
      "id": "<from init output>",
      "name": "<from init output>",
      "repos": ["/path/to/repo1", "/path/to/repo2"]
    }
  ]
}
```

Then run:

```bash
"$SETUP_SCRIPT" run /tmp/plane-setup-config.json
```

This writes `plane-workspace.json`, generates the agent file, and (if token present) fetches metadata + updates `.mcp.json`.

Also run `Skill(update-config)` to add `"mcp__plane-claude-mcp__*"` to allowed permissions.

## 6. Confirm

Show the script's output to the user. Then add:

```
Next steps:
  /helpers add devops    → Add a DevOps helper
  /helpers add pm        → Add a PM helper
  /helpers add ea        → Add an EA for briefings
```

If Plane was not connected, also show:
```
  /setup                 → Re-run to add your Plane API token
```
