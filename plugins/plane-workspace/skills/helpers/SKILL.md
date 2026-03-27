---
name: helpers
description: Manage your helper agents — list, add, modify, or delete helpers like devops, pm, ea, designer, and more.
user-invocable: true
argument-hint: "[list|add|modify|delete] [template-or-name]"
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
| `add [template]` | Add a helper from template |
| `modify <name>` | Edit an existing helper |
| `delete <name>` | Remove a helper |

---

## list

```bash
ls "$CLAUDE_PLUGIN_ROOT/user/helpers/" 2>/dev/null || echo "No helpers installed."
```

Show each helper's name and description from frontmatter.

---

## add

Show available templates:

```bash
ls "$CLAUDE_PLUGIN_ROOT/templates/"
```

Available templates (same set used for your own agent):

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

Ask:
1. **Which template?**
2. **Name for this helper** — e.g., `akshat`, `goutham`, `design-bot`. This is what you'll use to invoke them.
3. **Any custom focus or constraints?** (optional)

Read template:
```bash
cat "$CLAUDE_PLUGIN_ROOT/templates/<template>.md"
```

Replace placeholders:

| Placeholder | Value |
|:------------|:------|
| `{{AGENT_NAME}}` | Chosen helper name |
| `{{AGENT_CONTEXT}}` | "You are acting as **[name]**, a [role] helping **[owner]**." |
| `{{AGENT_ROLE_TITLE}}` | Role display name |
| `{{PLANE_USER_ID}}` | Owner's Plane user ID from workspace config |
| `{{OWNER_NAME}}` | Owner's name from workspace config |
| `{{CUSTOM_NOTES}}` | Custom instructions, or remove the line |

```bash
mkdir -p "$CLAUDE_PLUGIN_ROOT/user/helpers"
```

Write to `$CLAUDE_PLUGIN_ROOT/user/helpers/<name>.md`.

Confirm:
> "✅ Helper `<name>` added. Spawn them with the Agent tool pointing to `$CLAUDE_PLUGIN_ROOT/user/helpers/<name>.md`. Use `run_in_background: true` for parallel tasks."

---

## modify

```bash
cat "$CLAUDE_PLUGIN_ROOT/user/helpers/<name>.md"
```

Show content, ask what to change. Write back.

---

## delete

Confirm first. Then:
```bash
rm "$CLAUDE_PLUGIN_ROOT/user/helpers/<name>.md"
```
