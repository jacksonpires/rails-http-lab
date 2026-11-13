---
type: Decision
title: Disabled keys (`~` prefix)
description: KV pairs whose key starts with `~` are disabled; they persist through parse/serialize but the runner and URL sync skip them.
tags: [bruno-interop, ui-sync]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: runner
    title: lib/rails_http_lab/execution/runner.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/execution/runner.rb
  - id: frontend
    title: app/assets/javascripts/rails_http_lab/application.js
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/assets/javascripts/rails_http_lab/application.js
---

# Overview

Bruno marks a disabled row (header, query param, form field) by prefixing its key with `~`. The gem follows the same convention:

* **Storage:** the pair is an ordinary kv pair and round-trips untouched.
* **Runner:** `~` keys are skipped for headers, `params:query`, `body:form-urlencoded` and `body:multipart-form`.[^runner]
* **URL sync:** disabled params live only in the `params:query` block and never appear in the URL query string. When the URL is edited, they are kept at the end of the block.[^frontend] See [query/URL sync](/frontend/query-url-sync.md).

A `~key` in an environment's `vars` block is harmless. `{{…}}` names cannot contain `~` (see [variable resolution](/execution/variable-resolution.md)), so it never matches.
