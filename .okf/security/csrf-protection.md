---
type: Security Control
title: CSRF protection on the JSON API
description: Every mutating engine endpoint verifies the CSRF token (no skip_forgery_protection anywhere); the SPA sends X-CSRF-Token on every non-GET call, so a cross-site form POST cannot trigger /api/run or write files.
tags: [security, ssrf, frontend]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T15:00:00Z
sources:
  - id: app-controller
    title: app/controllers/rails_http_lab/application_controller.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/controllers/rails_http_lab/application_controller.rb
  - id: frontend
    title: app/assets/javascripts/rails_http_lab/application.js
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/assets/javascripts/rails_http_lab/application.js
  - id: csrf-spec
    title: spec/requests/csrf_spec.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/spec/requests/csrf_spec.rb
---

# Threat

The [environment gate](/security/environment-gate.md) lets through any request to a local dev server, and dev setups rarely configure an `authenticator`. Rails also parses form-encoded POST bodies into `params`. Without CSRF verification, any page the developer visits could auto-submit a cross-site `<form method=post>` to `http://localhost:3000/rails/http-lab/api/run` with a `source=` request definition. The Rails server would then send that request into the developer's network. The same trick could create or overwrite `.bru` files through `POST /api/requests`. The attacker never reads the response, but the side effects still happen. Until 0.1.1, every mutating controller action called `skip_forgery_protection`, so this attack worked.

# Control

* `ApplicationController` declares `protect_from_forgery with: :exception`, and **no engine controller skips it**.[^app-controller] Do not add `skip_forgery_protection` to a subclass. A new endpoint that changes state is covered automatically.
* **Callback order:** `guard_environment!` runs first, then CSRF verification. A disabled engine therefore still answers a token-less POST with a plain 404 instead of revealing itself with a 422.[^app-controller] The `prepend: true` that used to sit on `protect_from_forgery` was removed for this reason.
* A missing or wrong token raises `ActionController::InvalidAuthenticityToken`. The controller rescues it as **422** `{ "error": "invalid or missing CSRF token — reload the page" }`. This is the same in every Rails version, independent of `show_exceptions`. See [error mapping](/engine/error-mapping.md).

# Frontend contract

The layout renders `csrf_meta_tags`. The `api()` helper reads the `csrf-token` meta and sends it as `X-CSRF-Token` on **every non-GET/HEAD call, with or without a body**.[^frontend] Before the fix, the header was set only when a body was present. That would have broken the two body-less `DELETE` calls (deleting a folder or a request) as soon as verification was turned on. Any new write path must go through `api()`. Do not call `fetch` directly.

The token lives in the host app's session, so the host must have cookie/session middleware. Any non-`api_only` Rails app does, and the SPA cannot work without it anyway.

# Tests

`spec/requests/csrf_spec.rb` derives the list of mutating routes from `RailsHttpLab::Engine.routes`, so a new route is checked without editing the spec. It asserts that each one returns 422 without a token. It also checks that a cross-site form POST to `/api/run` sends no outbound request, that a forged `POST /api/requests` writes no file, that a wrong token is rejected, that a body-less `DELETE` with the header succeeds, and that a disabled engine stays a 404.[^csrf-spec] All request specs run with forgery protection forced on and get a real token from the `csrf_headers` helper (see [testing conventions](/testing/corpus-fixtures.md)).
