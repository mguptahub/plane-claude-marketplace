---
name: review
description: Review uncommitted changes (staged + unstaged) for bugs, logic errors, security issues, and code quality
user-invocable: true
argument-hint: "[path-filter]"
---

# Review Uncommitted Changes

Review all uncommitted changes in the current repository before committing.

## Steps

### 1. Detect the repo

Use `git rev-parse --show-toplevel` from the current working directory. If `$ARGUMENTS` contains a path, use that as the repo root instead.

### 2. Gather the diff

```bash
git diff HEAD
```

If no HEAD yet (fresh repo): `git diff --cached` and `git status`.

### 3. Identify changed files

List all modified/added files from the diff. Read full file contents for context — don't review the diff in isolation.

### 4. Review each change for

- **Bugs & logic errors**: Off-by-ones, null/undefined access, wrong variable, missing returns, race conditions
- **Security**: Injection, hardcoded secrets, unsafe deserialization, OWASP top 10
- **Error handling**: Missing or swallowed errors, broad catches, unhelpful messages
- **Naming & clarity**: Misleading names, confusing control flow, unnecessary complexity
- **Consistency**: Does the change follow existing patterns in the file/project?
- **Edge cases**: Empty inputs, boundary values, concurrent access, large inputs

### 5. Report findings grouped by severity

- **Critical**: Bugs, security vulnerabilities, data loss risks — must fix before commit
- **Warning**: Suspicious patterns, missing validation, potential issues — should fix
- **Suggestion**: Style, naming, minor improvements — nice to have

For each finding: file, line range, what's wrong, concrete fix.

If no issues found, say so briefly.

## Rules

- Only review what changed — don't audit entire files unless needed for context.
- Be specific. Show the exact issue and fix.
- Don't suggest adding comments, docstrings, or type annotations unless the change introduced a confusing pattern.
- Don't suggest refactoring beyond the scope of the change.
- If `$ARGUMENTS` contains a path filter, only review files matching that pattern.
