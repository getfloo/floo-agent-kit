---
name: security-review
description: Review a diff for security issues before shipping. Use when writing or reviewing code that handles authentication, database connections, secrets, environment variables, cookies, CORS, input validation, or any attack surface. Invoked directly or via the /security-review slash command.
user-invocable: true
---

# Security Review

> A checklist-based security review for a single diff. Run before shipping any change that touches an attack surface.

## When to invoke

- Authoring or reviewing auth/session/token code
- Authoring or reviewing middleware (rate limit, CORS, CSP, auth middleware)
- Adding or modifying routes that accept user input
- Changing database query code
- Changing anything that reads or writes secrets/env vars
- Changing security headers, cookie flags, or TLS configuration
- Changing serialization/deserialization of untrusted data
- Handling file upload, redirects, or third-party integrations

If you're uncertain whether a change is security-relevant, run this skill. The cost is low; the cost of missing a bug is not.

---

## The checklist

Run through every applicable section. For each item, state one of: **PASS** / **FAIL** / **N/A**. For every FAIL, state the fix inline — "add parameterized query", not "consider SQL injection risk."

### 1. Secrets and environment

- No hardcoded credentials, API keys, tokens, or connection strings in source.
- `.env` and equivalents are gitignored. No committed secrets in the diff.
- No secret values in log lines (log the key name, not the value).
- No secrets in error messages, stack traces, or API responses returned to clients.
- Secrets read from environment or a secret manager — never embedded in config committed to the repo.

### 2. Database and query safety

- Every query is parameterized. No string concatenation, f-strings, `.format()`, or template literals interpolating user input into SQL.
- Database errors are caught and returned as generic messages. The raw exception is logged server-side but never forwarded to the client.
- No superuser / admin credentials used for application queries.
- Multi-tenant code scopes every query to the current tenant/org/user. Reviewer can trace every data access back to a scope check.
- Direct object reference protected: IDs in the URL / body cannot be swapped to access another user's data.

### 3. Authentication and sessions

- Session cookies have `HttpOnly`, `Secure`, and `SameSite` flags set appropriately.
- Auth tokens are NOT stored in `localStorage` / `sessionStorage`. Use `HttpOnly` cookies.
- JWTs are verified server-side on every request — never trust client-side claims.
- Session expiration is set. No infinite sessions. Token rotation on elevation.
- Passwords hashed with `bcrypt` (cost ≥ 12), `argon2id`, or `scrypt`. Never MD5, SHA1, SHA256, plain hash, or plaintext.
- Rate limits on login, password reset, token-issuing endpoints.

### 4. Input validation and serialization

- Every new user-supplied input has validation: type, length, format, allowed values.
- Reject by default; accept known-good. Allowlists beat denylists.
- No deserialization of untrusted data into native objects without a schema (no `pickle.loads()`, no `yaml.load()`, no `eval()`).
- File uploads validate both extension and content type. Uploaded files stored outside the web root, served via a handler that sets correct headers.
- URL/redirect parameters are validated against an allowlist; open redirects are closed.

### 5. CORS, CSP, and security headers

- CORS `Access-Control-Allow-Origin` is a specific origin, never `*` in production.
- `X-Content-Type-Options: nosniff` set.
- `X-Frame-Options: DENY` (or `SAMEORIGIN` if iframing is a requirement).
- `Strict-Transport-Security` set for HTTPS enforcement.
- Content-Security-Policy set, with `'unsafe-inline'` / `'unsafe-eval'` avoided unless specifically justified and scoped.

### 6. Injection vectors beyond SQL

- Command injection: no `os.system`, `subprocess(..., shell=True)`, or equivalent with user input.
- Template injection: no user input passed to template engines with auto-escape off.
- Prompt injection (LLM calls): user-controlled strings quoted/escaped, system prompts and user prompts clearly separated.
- SSRF: outbound HTTP calls on URLs derived from user input — validated against an allowlist, never permit loopback / private IPs.
- XXE: XML parsers configured to disable DTDs and external entities.

### 7. Error handling and information disclosure

- No raw stack traces returned to clients.
- No internal paths, schema names, or secrets leaked in error responses.
- `DEBUG=True` / `NODE_ENV=development` cannot reach production.
- TLS verification not disabled (`verify=False`, `rejectUnauthorized: false`).
- `eval()` / `exec()` not called on user input.

### 8. Audit and observability

- Sensitive operations (login, password change, permission change, admin action, data export) emit an audit log.
- Log lines include enough context to reconstruct "who did what when" — actor, target, operation, timestamp.
- Failed auth attempts logged for detection.

---

## Output format

After running the checklist, produce a structured report:

```
## Security Review

**Diff scope:** [N files, which ones touch the attack surface]
**Risk level:** LOW / MEDIUM / HIGH / CRITICAL

### Findings

#### Critical (must fix before ship)
- [file:line] [one-sentence description] → [specific fix]

#### High (should fix before ship)
- [file:line] [description] → [fix]

#### Medium (should address)
- [file:line] [description] → [fix]

#### Passes
- [section: everything PASS, or specific items PASSed]

### Verdict
SHIP / SHIP WITH FIXES / DO NOT SHIP

[One paragraph plain-English summary — what's strong, what's weak, what's next.]
```

---

## After the review

If verdict is **SHIP**, record the attestation:

```bash
./mark_reviewed.sh --tier heavy
```

This writes the heavy-review sentinel that `pre-pr-check.sh` checks at `gh pr create` time. If verdict is **SHIP WITH FIXES** or **DO NOT SHIP**, fix the findings first, re-run this skill on the updated diff, and then mark.

Never write the sentinel when findings remain. The audit trail — "reviewed and approved" vs "reviewed and fixes outstanding" — is the trust boundary.
