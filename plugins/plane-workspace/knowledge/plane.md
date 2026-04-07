# Plane Workspace — Shared Knowledge

This file is loaded by all agents and skills in the plane-workspace plugin. It provides shared context for working with Plane via MCP.

## Spawning Helpers

When delegating work to a helper agent, **always use `run_in_background: true` by default**. Helpers are designed to work in parallel — the main agent should not block waiting for them unless it explicitly needs the result before continuing.

```
Agent tool:
  subagent_type: <helper-name>
  run_in_background: true   ← always, unless you need the result before proceeding
  prompt: <task description>
```

Only omit `run_in_background` (foreground) when the main agent cannot proceed without the helper's output — e.g. a PM helper scoping a task before implementation begins.

When a background helper completes, you will be notified automatically. Summarise the result to the user at that point.

## Memory System

Agents maintain memory across sessions using dated markdown files. This prevents losing context when a session ends mid-task.

### Memory File Path

```
$CLAUDE_PLUGIN_ROOT/user/memory/<agent-name>-<ddmmyyyy>-<seq>.md
```

- `<agent-name>` — your agent's name (e.g. `manish`)
- `<ddmmyyyy>` — today's date (e.g. `07042026`)
- `<seq>` — two-digit sequence for multiple tasks in the same day (`01`, `02`, `03` …)

### On Session Start

Always check for recent memory files first:
```bash
ls "$CLAUDE_PLUGIN_ROOT/user/memory/<agent-name>-"*.md 2>/dev/null | sort -r | head -5
```

Read the most recent file. If `status` is `in_progress` or `paused`, resume from where you left off. Tell the user: *"Resuming from memory: [task]."*

If no memory file exists, start fresh.

### Memory File Format

```markdown
---
agent: <agent-name>
date: <ddmmyyyy>
seq: <seq>
task: <WORK-ITEM-ID> — <short title>
status: in_progress | completed | paused
---

## Context
[What we're working on — work item summary, key requirements]

## Progress
- [x] Completed step
- [ ] Pending step

## Decisions
[Key decisions made — approach chosen, trade-offs]

## Next Steps
[Exactly what to do when resuming this task]

## Notes
[Anything important — blockers, observations, warnings]
```

### Writing Memory

Write or update the memory file at these checkpoints:
- After understanding the task (context captured)
- After branching (branch name recorded)
- After each major implementation step
- Before ending the session

```bash
mkdir -p "$CLAUDE_PLUGIN_ROOT/user/memory"
```

Use `Write` to create or overwrite the memory file.

### Closing Out

- Mark `status: completed` when the task is done and PR is up.
- Mark `status: paused` if interrupted mid-task.
- Never delete memory files — they serve as an audit trail.

## Workspace Config

Always load user context from `$CLAUDE_PLUGIN_ROOT/user/plane-workspace.json` at the start of any task. This file contains:
- `user.name`, `user.email`, `user.plane_user_id`, `user.role`
- `plane.workspace_slug`, `plane.mcp_server`
- `projects[]` — each with `identifier`, `id`, `repos[]`, `states[]`, `labels[]`, `members[]`

## MCP Server

The Plane MCP server is named **`plane-claude-mcp`**. Always use this name when calling MCP tools (e.g., `mcp__plane-claude-mcp__list_work_items`).

The workspace slug is in `plane.workspace_slug` from the config.

## User Identity

Always use `user.plane_user_id` from the workspace config when:
- Filtering work items by assignee
- Creating/updating work items with assignee field
- Any MCP operation that requires a user ID

Never hardcode user IDs in instructions.

## Common Operations

### Fetch work items assigned to me
```
list_work_items(project_id=<id>, assignee=<plane_user_id>)
```

### Update work item state
```
update_work_item(project_id=<id>, work_item_id=<id>, state=<state_id>)
```

### Add a comment
```
create_work_item_comment(project_id=<id>, work_item_id=<id>, comment_html=<content>)
```
See rich text rules below before writing comment content.

### Create a work item link
```
create_work_item_link(project_id=<id>, work_item_id=<id>, url=<url>, title=<title>)
```

### Look up a project's state ID
Read from `plane-workspace.json`:
```
project = config.projects.find(p => p.identifier === "WEB")
state = project.states.find(s => s.name === "In Progress")
state_id = state.id
```

## Rich Text Rules — CRITICAL

Plane uses a rich text editor (Tiptap/ProseMirror) for work item descriptions, comments, and pages.

**NEVER use literal `\n` (backslash-n) in any content written to Plane.**

If you do, the layout will break — `\n` will appear as raw text in the editor instead of a line break.

### For HTML content (`comment_html`, `description_html`):

Use proper HTML tags. Examples:

```html
<p>Fixed the login bug in the auth flow.</p>
<ul>
  <li>Updated token refresh logic</li>
  <li>Added error boundary for expired sessions</li>
</ul>
<p>All tests passing.</p>
```

| Need | Use |
|:-----|:----|
| Paragraph | `<p>text</p>` |
| Line break | `<br>` (sparingly) |
| Unordered list | `<ul><li>item</li></ul>` |
| Ordered list | `<ol><li>item</li></ol>` |
| Bold | `<strong>text</strong>` |
| Inline code | `<code>text</code>` |
| Code block | `<pre><code>block</code></pre>` |
| Heading | `<h2>text</h2>` |

### For pages (Markdown):
Use standard markdown with real newlines between sections. Never `\n`.

## Branch Naming Convention

- INFRA work items: `infra-{number}/{short-description}` from `master`
- WEB work items: `web-{number}/{short-description}` from `preview`

## PR Attribution

Always use in PR descriptions:
```
Co-authored with Plane-Ai <noreply@plane.so>
```

Never use "Generated with Claude Code" or "Co-authored with Claude".
