---
type: Security Control
title: Environment gate
description: ApplicationController#guard_environment! returns 404 unless Rails.env is in enabled_envs, then 403 if an authenticator is configured and rejects the request.
tags: [security, configuration]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T15:00:00Z
sources:
  - id: app-controller
    title: app/controllers/rails_http_lab/application_controller.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/controllers/rails_http_lab/application_controller.rb
  - id: config
    title: lib/rails_http_lab/configuration.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/configuration.rb
---

# Overview

Every engine request, both the SPA and the API, passes through `guard_environment!` as a `before_action`:[^app-controller]

1. If `Rails.env` is not in `config.enabled_envs` (default `[:development]`[^config]), the response is **404**. A disabled engine looks as if it doesn't exist instead of advertising itself.
2. If `config.authenticator` is set and `authenticator.call(request)` is falsy, the response is **403**.

The gate runs **before** CSRF verification. A disabled engine therefore answers even a token-less POST with 404 instead of a CSRF 422 that would reveal it. See [CSRF protection](/security/csrf-protection.md).

The authenticator is optional outside production. In production it becomes mandatory through the [boot guard](/security/production-boot-guard.md).

# Test setup

`spec/rails_helper.rb` adds `:test` to `enabled_envs`. Without that, the request specs would all get 404.
