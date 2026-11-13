---
type: Decision
title: No script execution
description: Bruno `script:*` and `tests` blocks are persisted and shown read-only but never executed — a deliberate security boundary against RCE.
tags: [security, bruno-interop, frontend]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: readme
    title: README.md — Security
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/README.md#security
  - id: frontend
    title: app/assets/javascripts/rails_http_lab/application.js
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/assets/javascripts/rails_http_lab/application.js
---

# Decision

`script:pre-request`, `script:post-response` and `tests` are parsed as [raw blocks](/bruno-format/block-modes.md) and round-trip byte-for-byte. The [runner](/execution/runner-pipeline.md) never evaluates them.[^readme] The UI shows those tabs read-only, with an explainer banner (`rhl-readonly-banner`).[^frontend]

# Why

Running Bruno scripts would mean embedding a JS runtime in the Rails server and running code from `.bru` files. Those files can arrive through a PR, a copied collection, or the `source` parameter of `/api/run`. That is remote code execution with the server's privileges, a confused-deputy problem layered on top of the SSRF reach the runner already has. Users who need scripts run them in Bruno desktop.

Do not add a JS runtime to evaluate these blocks.

# Consequence

Requests that depend on scripts, for example a pre-request script that sets a token variable, behave differently here than in Bruno. That is accepted.
