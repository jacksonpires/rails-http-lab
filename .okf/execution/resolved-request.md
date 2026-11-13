---
type: Interface
title: Resolved request summary (Response#request)
description: Response#request carries the fully resolved method/url/headers/body actually sent; the frontend's cURL tab is built from it.
tags: [frontend]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: runner
    title: lib/rails_http_lab/execution/runner.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/execution/runner.rb
  - id: response
    title: lib/rails_http_lab/execution/response.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/execution/response.rb
---

# Schema

The `request` member of the `Response` struct[^response] is filled by `Runner#summarize_request`, which runs **after** variable interpolation, query merging, auth and body have all been applied, and **before** dispatch:[^runner]

| Field | Type | Description |
|-------|------|-------------|
| `method` | String | Upper-case verb |
| `url` | String | Final URL, query included |
| `headers` | Hash | Every header on the `Net::HTTP` request, auth included |
| `body` | String or nil | Serialized body |

# Contract

* The frontend's cURL tab (`buildCurl` in `application.js`) is built from this summary. It shows what was actually sent, not the template.
* It must be present in the success path **and** in the timeout and generic-error rescue clauses, so a failed request can still be copied as cURL.[^runner]
* Only an invalid URL legitimately returns `request: nil`, because there is nothing to summarize yet.

Note that the summary includes resolved secrets such as bearer tokens and basic-auth headers. The `/run` JSON response returns them to the browser.
