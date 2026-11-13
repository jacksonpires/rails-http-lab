---
type: Runbook
title: "Boot ordering gotcha: empty engine route table"
description: If /rails/http-lab 404s and the engine shows no routes, the engine class was defined after Rails.application.initialize! — the initializer's require fixes it.
tags: [troubleshooting, install]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: initializer
    title: lib/generators/rails_http_lab/install/templates/initializer.rb.tt
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/generators/rails_http_lab/install/templates/initializer.rb.tt
  - id: entry
    title: lib/rails_http_lab.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab.rb
---

# Symptom

`/rails/http-lab` returns 404. `/rails/info/routes` lists the mount point, but the engine's section says *"You don't have any routes defined!"*

# Cause

Rails collects railties while `Rails.application.initialize!` runs. If `RailsHttpLab::Engine` is not defined by then, the engine's `config/routes.rb` is never loaded. The host-side `mount` still succeeds, but it mounts an empty route table. The usual trigger is a Gemfile entry with `require: false`.

The engine file itself is required only `if defined?(Rails)`.[^entry]

# Fix

The generated initializer starts with `require "rails_http_lab"`.[^initializer] Initializers run inside `initialize!`, early enough to define the engine. **Never drop that line** from `initializer.rb.tt`. When helping a user who sees this symptom, check that their initializer still has it.
