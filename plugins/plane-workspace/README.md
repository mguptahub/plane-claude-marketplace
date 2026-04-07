# plane-workspace — Claude Code Plugin

Connect Claude Code to your Plane workspace. Get work item context, role-based agents, and shared team workflows — all inside your editor.

## Installing

```
/plugin marketplace add mguptahub/plane-claude-marketplace
/plugin install plane-workspace@plane-claude-marketplace
```

## Quick Start

```
/setup            → Configure your identity and generate your personal agent
/connect-plane    → Connect to Plane (API token, workspace, MCP server)
```

Once set up, just mention a work item like `INFRA-123` or `WEB-456` and your agent picks it up.

## Commands

| Command | Description |
|:--------|:------------|
| `/setup` | First-time identity setup — name, email, role, agent name. Re-run to reset. |
| `/connect-plane` | Connect to Plane — API token, workspace slug, project selection, MCP server config. |
| `/helpers [list\|add\|edit\|delete]` | Manage helper agents (pm, ea, devops, designer, recruiter, etc.) |
| `/gm` | Activate start-of-day email + Slack briefing (requires EA helper) |

## Quality Gate Skills

These skills run automatically as part of developer workflows, or can be invoked directly:

| Skill | Description |
|:------|:------------|
| `/review` | Review uncommitted changes for bugs, logic errors, and security issues |
| `/validate` | Run lint and build checks on the current repo |
| `/unit-test` | Run unit tests and report pass/fail with failure summary |
| `/api-test` | Run API/integration tests against a running service |
| `/ui-test` | Run browser-based E2E and visual regression tests via Playwright |

## Helper Agent Templates

When you run `/helpers add <template>`, the plugin creates a new agent from one of these role templates:

| Template | Role |
|:---------|:-----|
| `frontend` | Frontend Engineer — UI/React work |
| `backend` | Backend Engineer — APIs and services |
| `fullstack` | Full-Stack Engineer |
| `devops` | DevOps Engineer — Helm, Terraform, infra |
| `qa` | QA Engineer — testing and bug filing |
| `pm` | Product Manager — scoping and work item management |
| `ea` | Executive Assistant — email/Slack briefings |
| `designer` | Designer — wireframes, Figma, Pencil |
| `recruiter` | Recruiter — LinkedIn search and shortlisting |
| `other` | Custom role |

## What Gets Created

After `/setup` + `/connect-plane`:

| File | Description |
|:-----|:------------|
| `plane-workspace.json` | Your config: identity, Plane connection, project metadata (states, labels, members) |
| `agents/<name>.md` | Your personal AI agent, tailored to your role |
| `agents/<helpers>.md` | Helper agents added via `/helpers add` |
| `.mcp.json` | MCP server config for `plane-claude-mcp` (written at project or user scope) |

All files are **gitignored** — personal to you, not committed to the repo.

## Scope Detection

The plugin auto-detects where to write config:

- **Local scope** — if your current project already has Plane plugin references in `.claude/` or `.mcp.json`, config is written under `.claude/` in that project.
- **User scope** — otherwise, config is written globally under `~/.claude/`.

## Requirements

- Claude Code with plugin support
- A Plane account with API access (`app.plane.so` or self-hosted)
- API token from **Plane Settings → API Tokens**
- `uvx` available (for the MCP server — install via `pip install uv`)

## Self-Hosted Plane

During `/connect-plane`, change the API base URL from the default `https://api.plane.so` to your instance URL.
