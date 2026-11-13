---
type: Decision
title: Error mapping and rescue order
description: RailsHttpLab::Error subclasses map to 404/403/422, with specific rescues declared before the base class; 422 is numeric for Rack 2/3 compatibility.
tags: [api, compatibility]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T15:00:00Z
sources:
  - id: app-controller
    title: app/controllers/rails_http_lab/application_controller.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/controllers/rails_http_lab/application_controller.rb
  - id: ci-commit
    title: "Commit 9fb4c6e — Add Ruby x Rails CI matrix and compatibility table"
    resource: https://github.com/jacksonpires/rails-http-lab/commit/9fb4c6e
---

# Schema

| Error | Status |
|-------|--------|
| `NotFoundError` | 404 |
| `OutsideStorageError` | 403 |
| `ParseError` | 422 |
| `Error` (base) | 422 |
| `ActionController::InvalidAuthenticityToken` | 422, with a fixed "invalid or missing CSRF token — reload the page" message ([CSRF protection](/security/csrf-protection.md)) |

JSON requests get `{ "error": message }`. Other formats get a bare status.[^app-controller]

# Decisions

* **Rescue order matters.** The specific subclasses are declared before the base `RailsHttpLab::Error`. The CSRF rescue is outside that hierarchy, so its position doesn't matter. Don't reorder them, or a path-traversal attempt would come back as 422 instead of 403.
* **Numeric `422`, not a symbol.** `:unprocessable_entity` is deprecated in recent Rack, and `:unprocessable_content` does not exist in Rack 2, which Rails 7.0 uses. Only the integer works across the whole [compatibility matrix](/testing/compatibility-matrix.md).[^ci-commit]
