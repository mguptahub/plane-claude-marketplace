---
name: api-test
description: Run API/integration tests against a running service or test environment. Supports REST endpoint testing, contract validation, and integration test suites.
user-invocable: true
argument-hint: "[repo-path or test pattern or base-url]  e.g. 'http://localhost:8000' or 'tests/api/'"
---

# API Test

Run API and integration tests for the given repo or endpoint.

## Workflow

### 1. Determine Scope

Check `$ARGUMENTS`:
- If a URL is given (starts with `http`): use it as the base URL.
- If a path is given: scope tests to that directory.
- If no arguments: check the repo for an API test suite and ask for the target environment.

### 2. Detect Test Suite

| Signal | Tool | Command |
|:-------|:-----|:--------|
| `tests/api/` or `test_api_*.py` | Pytest | `pytest tests/api/ -v` |
| `*.test.ts` with supertest/axios imports | Jest/Vitest | `npx jest tests/api` |
| `*.http` files | httpyac | `npx httpyac run <file>` |
| `postman_collection.json` | Newman | `npx newman run <collection>` |
| `openapi.yaml` / `swagger.json` | Schemathesis | `schemathesis run <spec> --base-url <url>` |

If no suite found, ask the user what to test.

### 3. Check Service is Running

Verify the target service is reachable before running tests.
If not running, ask the user to start it. Do not start services automatically.

### 4. Run Tests

Execute the detected command.

### 5. Report

```
API Tests: ✓ PASSED  (38 endpoints tested, 0 failures)
```

or:

```
API Tests: ✗ FAILED  (36 passed, 2 failed)

Failed:
- POST /api/v1/issues — expected 201, got 422 (validation error: missing project_id)
- GET /api/v1/cycles — expected 200, got 500 (internal server error)
```

Surface failures to the calling agent/user. Do not auto-fix. Ask how to proceed.
