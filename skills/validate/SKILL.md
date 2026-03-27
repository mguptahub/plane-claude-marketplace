---
name: validate
description: Run tests, linting, and build checks on the current repo to verify changes work correctly
user-invocable: true
argument-hint: "[repo-path]"
---

# Validate

Run validation checks on the current or specified repository.

## Steps

### 1. Detect the repo

If `$ARGUMENTS` is provided, use it as the repo path. Otherwise use `git rev-parse --show-toplevel` from the current working directory.

### 2. Match repo to project

Load workspace config:
```bash
cat "$CLAUDE_PLUGIN_ROOT/user/plane-workspace.json"
```

Match the detected repo path against `projects[].repos[]` to find the project. Use the project identifier to determine repo type.

If the repo is not in the workspace config, fall back to path-based detection:

| Path contains | Type |
|:-------------|:-----|
| `plane-helm-charts` | Helm (public) |
| `helm-charts-private` | Helm (private) |
| `plane-mcp-server` | Python (MCP Server) |
| `plane-ee` | Web App (EE) |
| `plane` | Web App (OSS) |

### 3. Find what changed

```bash
git diff --name-only HEAD
```

If no HEAD yet: `git status --porcelain`.

### 4. Run checks by repo type

#### Helm Charts (public + private)
For each chart with modified files:
```bash
helm lint <chart-path>
helm template test-release <chart-path>
```
Both must pass with no errors.

#### Python (MCP Server / other Python repos)
```bash
ruff check . --select E,F,I,UP,B --line-length 120
ruff format --check .
```

#### Web App (OSS / EE)
Check `package.json` for available scripts:
- If `lint` script exists: `npx next lint` or `npm run lint`
- If `typecheck` or `type-check` script exists: run it
- If `build` script exists: `npm run build`

Report which checks ran and their results.

### 5. Report results

- List each check run with pass/fail status
- For failures: show relevant error output
- If all pass: confirm briefly
