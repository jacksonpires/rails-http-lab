---
type: Decision
title: Lazy scaffolding of bruno.json and environments/
description: The install generator only creates the empty storage dir and the initializer; bruno.json and environments/ are created on first use.
tags: [install, bruno-interop]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: fs
    title: lib/rails_http_lab/storage/filesystem.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/storage/filesystem.rb
  - id: generator
    title: lib/generators/rails_http_lab/install/install_generator.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/generators/rails_http_lab/install/install_generator.rb
---

# Decision

`bin/rails g rails_http_lab:install` emits only the empty `docs/http-lab/` directory and `config/initializers/rails_http_lab.rb`.[^generator] The rest of the collection is created when first needed:

* `Filesystem#ensure_root!` creates the root and a default `bruno.json` (`name: "My APIs"`, `type: "collection"`). The `GET /api/tree` and `POST /api/collections` endpoints call it.[^fs]
* `environments/` appears when the first environment is saved, because `write_bru` runs `mkdir -p` on the parent directory.[^fs]

# Why

A user may point `storage_path` at an existing Bruno collection, which already has its own `bruno.json`. A single code path that creates files only when they are missing works in both cases. Don't reintroduce these files in the generator.
