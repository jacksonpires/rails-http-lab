---
type: Decision
title: Query/URL two-way sync
description: Editing the URL query rewrites params:query and vice versa, mirroring Bruno; disabled (~) params live only in the block.
tags: [ui-sync, bruno-interop, frontend]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: frontend
    title: app/assets/javascripts/rails_http_lab/application.js
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/assets/javascripts/rails_http_lab/application.js
---

# Behaviour

The sync mirrors Bruno desktop:[^frontend]

* `syncUrlFromParams` rebuilds the URL query from the enabled `params:query` pairs.
* `syncParamsFromUrl` rebuilds the block from the URL query. [Disabled](/bruno-format/disabled-keys.md) `~` pairs stay at the end of the block, because they never appear in the URL.
* If the URL has no query and there is no block, no block is created.

Files saved from the UI therefore look the way Bruno would have written them. The runner still defends against files that are out of sync by [letting block keys replace URL keys](/execution/query-param-merge.md). Keep both mechanisms.
