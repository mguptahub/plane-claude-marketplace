---
name: ui-test
description: Run browser-based UI tests using Playwright or agent-browser. Supports E2E flows, visual regression, and accessibility checks against a running web app.
user-invocable: true
argument-hint: "[test-file or flow description or base-url]  e.g. 'http://localhost:3000' or 'tests/e2e/issues.spec.ts' or 'test the issue creation flow'"
---

# UI Test

Run browser-based UI tests using Playwright or agent-browser automation.

## Workflow

### 1. Determine Mode

| Input | Mode |
|:------|:-----|
| `.spec.ts` / `.spec.js` file path | **Playwright** — run that spec |
| `tests/e2e/` directory | **Playwright** — run full E2E suite |
| Natural language flow (e.g., "test the issue creation flow") | **Agent-browser** — execute described flow |
| URL only | **Agent-browser** — smoke test |
| No arguments | Ask: which mode and target? |

### 2. Check App is Running

Verify the web app is accessible at the target URL before starting.
Default local URL: `http://localhost:3000`

If not running, ask the user to start it. Do not start it automatically.

### 3a. Playwright Mode

Detect config: `playwright.config.ts` or `playwright.config.js`

```bash
npx playwright test [test-file-or-dir] --reporter=list
```

For visual regression (only when explicitly asked):
```bash
npx playwright test --update-snapshots
```

### 3b. Agent-Browser Mode

Use the browser agent tool to:
1. Open the target URL
2. Execute the described flow step by step (click, fill, submit, assert)
3. Take screenshots at key checkpoints
4. Report what passed and what broke

Be explicit about each step so failures are easy to diagnose.

### 4. Accessibility Check (optional)

If asked or if the work item has a UX/UI label:
```bash
npx playwright test --grep @a11y
```

### 5. Report

```
UI Tests: ✓ PASSED  (12 tests, 3 flows, 0 failures)
```

or:

```
UI Tests: ✗ FAILED  (10 passed, 2 failed)

Failed:
- Issue creation flow — "Submit button not found" (selector: [data-testid="submit-issue"])
- Cycle board — visual regression diff detected
```

Surface failures with screenshots where possible. Do not auto-fix. Ask how to proceed.

### 6. Re-run on Fix

After a fix, re-run the affected spec to confirm.
