---
name: unit-test
description: Run unit tests for the current project/repo. Detects the test framework and runs the appropriate commands. Reports pass/fail with a summary of failures.
user-invocable: true
argument-hint: "[repo-path or test file/pattern]"
---

# Unit Test

Run unit tests for the given repo or file path.

## Workflow

### 1. Determine Scope

Check `$ARGUMENTS`:
- If a repo path or file pattern is given, scope tests to that path.
- If no arguments, use the current working directory.

### 2. Detect Framework

| Signal | Framework | Command |
|:-------|:----------|:--------|
| `jest.config.*` or `"jest"` in `package.json` | Jest | `npx jest [pattern] --passWithNoTests` |
| `vitest.config.*` or `"vitest"` in `package.json` | Vitest | `npx vitest run [pattern]` |
| `pytest.ini` / `pyproject.toml` with pytest | Pytest | `pytest [path] -v` |
| `go.mod` present | Go test | `go test ./...` |

If ambiguous, check `package.json` scripts for a `test` entry and use that.

### 3. Run Tests

Execute the detected command. Capture output.

### 4. Report

```
Unit Tests: ✓ PASSED  (142 passed, 0 failed)
```

or:

```
Unit Tests: ✗ FAILED  (139 passed, 3 failed)

Failed:
- src/components/issues/IssueCard.test.tsx — "renders priority badge" (assertion error)
- ...
```

If tests fail:
- Show the failure output for each failed test.
- Do NOT auto-fix. Surface failures and ask how to proceed.

### 5. Re-run on Fix

If the calling agent fixes failing tests, re-run to confirm they pass.
