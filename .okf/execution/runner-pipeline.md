---
type: Component
title: Runner pipeline
description: Execution::Runner turns a Bruno document into a Net::HTTP request — resolve vars, merge query, headers, auth, body, dispatch with limits.
resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/execution/runner.rb
tags: [ssrf, bruno-interop]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T15:00:00Z
sources:
  - id: runner
    title: lib/rails_http_lab/execution/runner.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/execution/runner.rb
  - id: runs-controller
    title: app/controllers/rails_http_lab/runs_controller.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/controllers/rails_http_lab/runs_controller.rb
  - id: config
    title: lib/rails_http_lab/configuration.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/configuration.rb
---

# Entry point

`POST /api/run` accepts either a stored `path` or an unsaved `source` (raw `.bru` text), plus an optional `environment` name.[^runs-controller] Because `source` is accepted, the UI can send a request with unsaved edits. It also means the endpoint will run arbitrary request definitions. That is why it sits behind the [environment gate](/security/environment-gate.md) and [CSRF protection](/security/csrf-protection.md).

# Pipeline

1. Find the verb block (`get`/`post`/`put`/`patch`/`delete`/`head`/`options`). If there is none, raise `Error`.
2. [Resolve variables](/execution/variable-resolution.md) in the URL. Any `{{var}}` still left in the URL raises an actionable "select an environment that defines it" error.[^runner]
3. [Merge the query](/execution/query-param-merge.md) from `params:query`, plus apikey auth when its placement is `queryparams`.
4. Apply `headers`, skipping [disabled keys](/bruno-format/disabled-keys.md).
5. Apply auth: `bearer`, `basic`, or `apikey` as a header.
6. Apply the body by kind: `json`, `text`, `xml`, form-urlencoded, multipart (**text fields only**), or `graphql` (query plus parsed vars). The body kind accepts both Bruno's camelCase names and the kebab-case names.[^runner]
7. [Summarize the resolved request](/execution/resolved-request.md), then dispatch.

# Limits

| Config | Default | Effect |
|--------|---------|--------|
| `executor_timeout` | 30 s | `open_timeout` and `read_timeout` |
| `executor_max_body` | 10 MiB | response body is truncated with a `[...truncated]` marker; `size_bytes` still reports the full size |

Defaults come from `Configuration`.[^config]

# Errors are values

The runner never raises to the controller. Invalid URLs, timeouts and any other `StandardError` come back as `Response(error: …)`, so the UI shows them in the response pane.[^runner]

# Not executed

`script:*` and `tests` blocks are ignored. See [no script execution](/security/no-script-execution.md).
