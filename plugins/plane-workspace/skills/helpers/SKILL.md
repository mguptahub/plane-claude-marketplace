---
name: helpers
description: Manage your helper agents — list, add, edit, or delete helpers like devops, pm, ea, designer, and more.
user-invocable: true
argument-hint: "[list|add|edit|delete] [template-or-name]"
---

# /helpers — Manage Helper Agents

Helpers are subagent instruction files spawned by your main agent for parallel or delegated work.

They live in: `$CLAUDE_PLUGIN_ROOT/user/helpers/`

Load workspace config first:
```bash
cat "$CLAUDE_PLUGIN_ROOT/user/plane-workspace.json" 2>/dev/null || \
  cat "$(pwd)/.claude/plane-workspace.json" 2>/dev/null || \
  cat ~/.claude/plane-workspace.json 2>/dev/null
```

---

## Parse $ARGUMENTS

| Input | Action |
|:------|:-------|
| `list` or no args | List installed helpers |
| `add [template]` | Add a helper from a role template |
| `edit <name>` | Edit an existing helper |
| `delete <name>` | Remove a helper |

---

## list

```bash
ls "$CLAUDE_PLUGIN_ROOT/user/helpers/" 2>/dev/null || echo "No helpers installed yet."
```

For each `.md` file found, read its frontmatter and display:
- **Name** — from filename (without `.md`)
- **Description** — from the `description` field in frontmatter

If no helpers exist, suggest: `Try /helpers add devops` or `/helpers add ea`.

---

## add

Available role templates:

| Template | Best for |
|:---------|:---------|
| `frontend` | UI/React work |
| `backend` | APIs and services |
| `fullstack` | Full-stack tasks |
| `devops` | Helm, Terraform, infra |
| `qa` | Testing and bug filing |
| `pm` | Work item management, scoping |
| `ea` | Email/Slack briefings |
| `designer` | Wireframes, Figma, Pencil |
| `recruiter` | LinkedIn search |
| `other` | Custom role |

If a template name was provided in `$ARGUMENTS` (e.g. `/helpers add devops`), skip the selection prompt.

Otherwise use `AskUserQuestion` to ask:
1. **Which template?** (from the list above)
2. **Name for this helper** — e.g. `akshat`, `goutham`, `design-bot`. Used to invoke them.
3. **Any custom focus or constraints?** (optional — e.g. "focus on INFRA only", "no git push without confirmation")

Read the template:
```bash
cat "$CLAUDE_PLUGIN_ROOT/templates/<template>.md"
```

Replace all placeholders:

| Placeholder | Value |
|:------------|:------|
| `{{AGENT_NAME}}` | Chosen helper name |
| `{{AGENT_CONTEXT}}` | `"You are acting as **[name]**, a [role title] helping **[owner_name]**."` |
| `{{AGENT_ROLE_TITLE}}` | Role display name (e.g. "DevOps Engineer") |
| `{{PLANE_USER_ID}}` | Owner's `plane_user_id` from workspace config |
| `{{OWNER_NAME}}` | Owner's `user.name` from workspace config |
| `{{CUSTOM_NOTES}}` | Custom instructions provided, or remove the line |

```bash
mkdir -p "$CLAUDE_PLUGIN_ROOT/user/helpers"
```

Write to `$CLAUDE_PLUGIN_ROOT/user/helpers/<name>.md`.

Confirm:
> ✅ Helper `<name>` added. Your agent can now spawn them using the Agent tool with `run_in_background: true` for parallel tasks.

---

## edit

```bash
cat "$CLAUDE_PLUGIN_ROOT/user/helpers/<name>.md"
```

Show the current content. Use `AskUserQuestion` to ask what to change (instructions, focus, constraints, etc.). Apply changes and write back.

Confirm:
> ✅ Helper `<name>` updated.

---

## delete

Confirm first:
> Are you sure you want to delete helper `<name>`? This cannot be undone.

Then:
```bash
rm "$CLAUDE_PLUGIN_ROOT/user/helpers/<name>.md"
```

Confirm:
> ✅ Helper `<name>` deleted.
