# plane-workspace — Claude Code Plugin

Connect Claude Code to your Plane workspace. Get work item context, role-based agents, and shared team workflows — all inside your editor.

## Quick Start

1. Install the plugin via the Claude Code plugin marketplace
2. Run `/setup` to configure your identity, connect Plane, and map your repos
3. Start working: just say `INFRA-123` or `WEB-456` and Claude picks it up

## Commands

| Command | What it does |
|:--------|:-------------|
| `/setup` | First-time setup wizard (re-run to add projects or reset) |
| `/helpers` | Manage helper agents (PM, EA, dev colleagues) |
| `/work [agent] [task]` | Route work to yourself or a helper |
| `/gm` | Activate start-of-day briefing (requires EA helper) |

## What Gets Configured

After `/setup`, the plugin creates:
- `user/plane-workspace.json` — your workspace config (API connection, projects, states, labels, members)
- `user/me.md` — your personal AI agent, tailored to your role
- `user/agents/` — any helpers you add via `/helpers`

These files are **gitignored** — personal to you, not shared with the repo.

## Adding Helper Agents

```
/helpers add pm        # Product Manager — scopes work, creates tickets
/helpers add ea        # Executive Assistant — email/Slack briefings
/helpers add developer # Developer colleague — picks up work items
/helpers add recruiter # Recruiter — LinkedIn search and shortlisting
```

## Refreshing Workspace Metadata

States, labels, and members can change. Re-run `/setup` to pull fresh metadata from Plane.

## Requirements

- Claude Code with plugin support
- A Plane account with API access (app.plane.so or self-hosted)
- API token from Plane Settings → API Tokens

## For Self-Hosted Plane

During `/setup`, you can change the API base URL from the default `https://api.plane.so` to your instance URL.
