---
type: Decision
title: Ruby × Rails compatibility matrix
description: CI runs every Ruby 3.1–4.0 × Rails 7.0–8.1 pair (minus Rails 8 on Ruby 3.1); the Gemfile pins rails from RAILS_VERSION and the README table mirrors the matrix.
resource: https://github.com/jacksonpires/rails-http-lab/blob/main/.github/workflows/ci.yml
tags: [compatibility]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: ci
    title: .github/workflows/ci.yml
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/.github/workflows/ci.yml
  - id: readme
    title: README.md — Compatibility
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/README.md#compatibility
---

# Decision

CI runs the full suite on Ruby `3.1, 3.2, 3.3, 3.4, 4.0` × Rails `7.0, 7.1, 7.2, 8.0, 8.1`. Rails 8.x is excluded on Ruby 3.1, because Rails 8 requires Ruby `>= 3.2`.[^ci] The workflow sets `RAILS_VERSION`, and the `Gemfile` reads it to pin `rails ~> X.Y.0`.

Run one series locally with:

```bash
RAILS_VERSION=7.2 bundle update rails && RAILS_VERSION=7.2 bundle exec rspec
```

# Rules

* The README compatibility table must stay in sync with the CI matrix.[^readme]
* Code must work on the oldest pair (Ruby 3.1 / Rails 7.0 / Rack 2). One example is the numeric 422 in [error mapping](/engine/error-mapping.md).
