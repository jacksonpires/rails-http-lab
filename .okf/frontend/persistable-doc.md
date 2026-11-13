---
type: Decision
title: Persistable doc — don't write tab-injected empty blocks
description: The UI lazily injects empty blocks when a tab is viewed; persistableDoc drops them on save/send unless the block was already on disk.
tags: [round-trip, frontend]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: frontend
    title: app/assets/javascripts/rails_http_lab/application.js
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/assets/javascripts/rails_http_lab/application.js
  - id: interop-fix
    title: "Commit c48b32a — Fix Bruno interop bugs"
    resource: https://github.com/jacksonpires/rails-http-lab/commit/c48b32a
---

# Context

Opening a tab such as Params or Headers makes sure the matching block exists, so the editor has something to bind to. It injects for example an empty `params:query {}`. Before the interop fix, simply viewing a tab and saving wrote those empty blocks to the `.bru` file. The result was diff noise, and the file no longer matched Bruno's output.[^interop-fix]

# Decision

`persistableDoc(session)` filters the working doc before any write or send. It drops a block that is empty (a raw or list body that is only whitespace, or a kv block whose pairs are all blank) **unless** a block with that name was in the last on-disk version (`session.savedDoc`).[^frontend] Empty blocks that came from disk are kept, for [round-trip stability](/bruno-format/round-trip-stability.md).

Dirty detection compares *normalized* sources (empty blocks and blank rows stripped). As a result, viewing a tab or leaving a blank "+ Add row" does not mark the request as unsaved.[^frontend]

# Rule

Any new write path from the UI must go through `persistableDoc`.
