---
name: helpers
description: Manage your helper agents — list, add, modify, or delete agents like PM, EA, developer, or recruiter.
user-invocable: true
argument-hint: "[list|add|modify|delete] [agent-name-or-type]"
---

# /helpers — Manage Helper Agents

Add, modify, or remove helper agents that work alongside your personal `me.md` agent.

Helper agents live in: `$CLAUDE_PLUGIN_ROOT/user/agents/`

---

## Parse $ARGUMENTS

| Input | Action |
|:------|:-------|
| `list` or no arguments | List installed helpers |
| `add [type]` | Add a helper from template |
| `modify <name>` | Edit an existing helper |
| `delete <name>` | Remove a helper |

---

## list

```bash
ls "$CLAUDE_PLUGIN_ROOT/user/agents/" 2>/dev/null
```

For each `.md` file found, read the first few lines to extract `name` and `description` from frontmatter. Display as a table.

If no helpers installed:
> "No helpers installed yet. Run `/helpers add` to get started."

---

## add

Show available templates:

```bash
ls "$CLAUDE_PLUGIN_ROOT/templates/helpers/"
```

Available templates:
| Type | What it does |
|:-----|:-------------|
| `pm` | Product Manager — scopes work, creates Plane tickets, manages backlog |
| `ea` | Executive Assistant — monitors email/Slack, briefings |
| `developer` | Developer colleague — picks up work items, implements |
| `recruiter` | Recruiter — LinkedIn search, candidate shortlisting |

If a type was specified in `$ARGUMENTS`, use it. Otherwise ask which template.

Ask:
1. **Name for this helper** — what you'll call them (e.g., "gaurav", "priya", "alex")
2. **Any customisation?** — optional special instructions or focus areas

Load workspace config:
```bash
cat "$CLAUDE_PLUGIN_ROOT/user/plane-workspace.json"
```

Read the template:
```bash
cat "$CLAUDE_PLUGIN_ROOT/templates/helpers/<type>.md"
```

Replace all placeholders:

| Placeholder | Value |
|:------------|:------|
| `{{HELPER_NAME}}` | Chosen name |
| `{{OWNER_NAME}}` | User's name from workspace config |
| `{{OWNER_PLANE_USER_ID}}` | User's Plane user ID |
| `{{WORKSPACE_SLUG}}` | Workspace slug |
| `{{CUSTOM_NOTES}}` | Custom instructions provided, or remove the line |

```bash
mkdir -p "$CLAUDE_PLUGIN_ROOT/user/agents"
```

Write to `$CLAUDE_PLUGIN_ROOT/user/agents/<name>.md`.

Confirm:
> "✅ Helper `<name>` added. Use `/work <name> <task>` to route tasks to them."

---

## modify

```bash
cat "$CLAUDE_PLUGIN_ROOT/user/agents/<name>.md"
```

Show the current content and ask what to change.
Apply edits and write back to the same file.

---

## delete

First confirm:
> "Are you sure you want to delete the `<name>` helper? This cannot be undone."

On confirmation:
```bash
rm "$CLAUDE_PLUGIN_ROOT/user/agents/<name>.md"
```

Confirm deletion.
