---
name: setup
description: Initial setup — configure your identity and generate your personal agent. Re-run to reset.
user-invocable: true
argument-hint: "[--reset]"
allowed-tools: ["Bash(find *)", "Bash(*/plane-workspace/scripts/setup.sh *)", "Write", "Read", "Skill(update-config)"]
---

# /setup — Plane Workspace Setup

> **IMPORTANT**: Do NOT use any session memory, prior context, or remembered values to pre-fill or skip any step. Every question must be asked explicitly and answered by the user in this session. Never assume any value.

## 0. Find the setup script

```bash
find "$HOME" -maxdepth 10 -name "setup.sh" \
  -path "*/plane-workspace/scripts/*" 2>/dev/null | head -1
```

Store as `SETUP_SCRIPT`. If not found, tell the user the plugin may not be installed correctly and stop.

## 1. Detect scope

```bash
"$SETUP_SCRIPT" init "$(pwd)"
```

Parse `scope` and `base_path` from the JSON output. Store both.

## 2. Collect Identity

Use `AskUserQuestion` to collect all identity fields in **one prompt**:

- **Full name**
- **Work email**
- **Role** — select one: `frontend` / `backend` / `fullstack` / `devops` / `qa` / `pm` / `ea` / `designer` / `recruiter` / `other`
  - If "other": also ask for a short role description (e.g. "Data Analyst")
- **Agent name** — what should your agent be called? (e.g. `manish`, `priya`) — this becomes `<name>.md` in your agents folder
- **Do you write code?** — auto-yes for `frontend`, `backend`, `fullstack`, `devops`, `qa`. Only ask for `pm`, `ea`, `designer`, `recruiter`, `other`.

## 3. Run Setup

Build a config JSON and write it to `/tmp/plane-setup-config.json`:

```json
{
  "base_path": "<from init output>",
  "scope": "<from init output>",
  "user": {
    "name": "<name>",
    "email": "<email>",
    "role": "<role>",
    "role_description": "<custom description, or null>",
    "agent_name": "<agent_name>",
    "writes_code": <true|false>
  }
}
```

Then run:

```bash
"$SETUP_SCRIPT" run /tmp/plane-setup-config.json
```

This writes `plane-workspace.json` (identity only) and generates your personal agent file from the matching role template.

Also run `Skill(update-config)` to register your agent in Claude Code settings.

## 4. Confirm

Show the script's output to the user. Then display:

```
✅ Setup complete! Your personal agent is ready.

Next steps:
  /connect-plane          → Connect to your Plane workspace (work items, MCP)
  /helpers add devops     → Add a DevOps helper agent
  /helpers add pm         → Add a PM helper
  /helpers add ea         → Add an EA for email/Slack briefings
```
