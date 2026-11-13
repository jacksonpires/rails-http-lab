---
type: Security Control
title: Production boot guard
description: The engine's after_initialize raises — refusing to boot the host app — if :production is in enabled_envs without an authenticator.
tags: [security, configuration]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: engine
    title: lib/rails_http_lab/engine.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/engine.rb
  - id: readme
    title: README.md — Security
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/README.md#security
---

# Overview

In `config.after_initialize`, the engine checks for three things: `:production` is in `enabled_envs`, the app is running in production, and `authenticator` is `nil`. If all three hold, it **raises and the host app does not boot**.[^engine]

# Why fail closed

An unauthenticated server-side HTTP client in production is an open SSRF proxy into the internal network. It can also write files into the deployed app. A loud boot failure is far cheaper than finding out from an incident.[^readme] Don't add fallbacks, such as warning and continuing, or a default authenticator, that bypass this.
