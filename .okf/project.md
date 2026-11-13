---
type: Project
title: rails-http-lab
description: Rails Engine gem that mounts a Bruno-compatible HTTP request lab at /rails/http-lab and stores collections as .bru files in the host repo.
resource: https://github.com/jacksonpires/rails-http-lab
tags: [bruno-interop]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T15:00:00Z
sources:
  - id: readme
    title: README.md
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/README.md
  - id: gemspec
    title: rails-http-lab.gemspec
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/rails-http-lab.gemspec
---

# Overview

`rails-http-lab` is a Rails **Engine gem**, not an application. It gives a host Rails app a Postman/Bruno-like UI for ad-hoc HTTP requests, and saves the requests as files in the host repo (default `docs/http-lab/`), so they can be reviewed in PRs.[^readme] Current version is 0.1.1. It needs Ruby `>= 3.1` and Rails `>= 7.0`.[^gemspec]

The value proposition rests on three choices:

1. **Requests are files in the repo.** No external workspace.
2. **The UI runs inside the Rails process.** There is no CORS, and it can reach internal services. That reach is also why the [security gates](/security/) exist.
3. **The files use the Bruno format.** The same collection opens in Bruno desktop, which is why [byte-stable round-trip](/bruno-format/round-trip-stability.md) is the defining constraint of the codebase.

# Architecture

Four layers live under `lib/rails_http_lab/`, each one depending only on the layers above it in this list:

| Layer | Role | Area |
|-------|------|------|
| `bruno/` | Parser + Serializer for `.bru` | [Bruno format](/bruno-format/) |
| `storage/` | Filesystem CRUD and the sidebar tree | [Storage](/storage/) |
| `execution/` | Runs a parsed document as an HTTP request | [Execution](/execution/) |
| `engine.rb` + `app/` | Rails Engine, JSON API and SPA | [Engine](/engine/), [Frontend](/frontend/) |

The `bruno/`, `storage/` and `execution/` layers load without Rails. The engine is required only when `Rails` is defined. That split is why the unit specs can run standalone (see [testing](/testing/)).

# Things that are deliberately *not* done

* Bruno `script` and `tests` blocks are never executed. See [no script execution](/security/no-script-execution.md).
* The install generator does not scaffold `bruno.json` or `environments/`. See [lazy scaffolding](/storage/lazy-scaffolding.md).

# Gotchas worth knowing up front

* If `/rails/http-lab` returns 404 and the engine shows no routes, see the [boot ordering gotcha](/engine/boot-ordering.md).
* The sidebar uses two sort keys on purpose: alphabetical at the top level, `meta.seq` inside folders. See [sidebar ordering](/storage/sidebar-ordering.md).
* Every mutating API endpoint verifies the CSRF token, and the SPA sends `X-CSRF-Token` on every non-GET call. See [CSRF protection](/security/csrf-protection.md).
