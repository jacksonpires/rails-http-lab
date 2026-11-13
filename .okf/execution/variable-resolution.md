---
type: Component
title: Variable resolution
description: VariableResolver substitutes {{name}} from the selected environment's `vars` block; unknown names are left in place, and secrets are not resolved.
tags: [bruno-interop, limitation]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: resolver
    title: lib/rails_http_lab/execution/variable_resolver.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/execution/variable_resolver.rb
  - id: runs-controller
    title: app/controllers/rails_http_lab/runs_controller.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/controllers/rails_http_lab/runs_controller.rb
  - id: env-controller
    title: app/controllers/rails_http_lab/environments_controller.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/controllers/rails_http_lab/environments_controller.rb
---

# Overview

The resolver is a flat `name → value` map built from the `vars` kv block of `environments/<name>.bru`. It replaces `{{ name }}`, with optional spaces, where `name` matches `[\w.-]+`. **Unknown names are left as-is** so the user can see what is missing.[^resolver] If the environment named in the request does not exist, the runner silently falls back to an empty resolver.[^runs-controller]

# Known limitations

* **`vars:secret` values are not resolved.** In Bruno, the secret list block holds only the variable *names*. Bruno desktop keeps the values outside the `.bru` file. The gem preserves the list but has no values to substitute, so a URL that depends on a secret fails with the "unresolved variable" error from the [runner](/execution/runner-pipeline.md).
* There is no collection-level, folder-level or runtime variable scope. Only the selected environment is used.
* There is no recursive resolution: a value that itself contains `{{other}}` is not expanded again.[^resolver]

# Editing environments

`PUT /api/environments/:name` replaces only the `vars` block. Every other block, notably `vars:secret`, is written back untouched. A new `vars` block is inserted first, because that is where Bruno writes it.[^env-controller] Before the interop fix, saving an environment silently dropped `vars:secret`.
