---
type: Decision
title: Query param merge — block keys replace URL keys
description: The runner lets params:query keys override the same keys in the URL query instead of appending duplicates, because Bruno mirrors them.
tags: [bruno-interop, ui-sync]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: runner
    title: lib/rails_http_lab/execution/runner.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/execution/runner.rb
  - id: interop-fix
    title: "Commit c48b32a — Fix Bruno interop bugs"
    resource: https://github.com/jacksonpires/rails-http-lab/commit/c48b32a
---

# Context

Bruno keeps the URL's query string and the `params:query` block mirrored, and Bruno desktop sends only the URL. A file written by Bruno therefore usually has every param in both places. The first runner appended the block to the URL, so every param was sent twice.[^interop-fix]

# Decision

`Runner#merge_query!` builds the extra params from enabled `params:query` pairs, plus the apikey with `placement: queryparams`. It then **removes any URL param whose key is being overridden** and appends the extras. URL params not named in the block are kept as-is.[^runner]

This applies to the runner only. On the editing side, the frontend keeps the URL and the block in sync both ways ([query/URL sync](/frontend/query-url-sync.md)). Keep both behaviours. Each one covers a case the other doesn't: a hand-edited or out-of-sync file on one side, a live edit on the other.

The apikey `queryparams` placement was silently ignored before the same fix.[^interop-fix]
