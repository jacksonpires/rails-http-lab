---
type: Interface
title: JSON API
description: Routes under /api (JSON by default) for the tree, collections, folders, requests, environments and runs; the SPA is served at the engine root.
resource: https://github.com/jacksonpires/rails-http-lab/blob/main/config/routes.rb
tags: [api, frontend]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T15:00:00Z
sources:
  - id: routes
    title: config/routes.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/config/routes.rb
  - id: requests-controller
    title: app/controllers/rails_http_lab/requests_controller.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/controllers/rails_http_lab/requests_controller.rb
---

# Schema

The SPA is `ui#index` at the engine root. Everything else lives under `/api`, with `format: :json` as the default.[^routes]

| Verb | Path | Action | Notes |
|------|------|--------|-------|
| GET | `/api/tree` | `collections#tree` | Calls `ensure_root!` first ([lazy scaffolding](/storage/lazy-scaffolding.md)) |
| POST | `/api/collections` | `collections#create` | Sets the `bruno.json` name only if it is empty |
| POST | `/api/folders` | `folders#create` | |
| POST | `/api/folders/rename` | `folders#rename` | Also updates `folder.bru` `meta.name` |
| DELETE | `/api/folders/*path` | `folders#destroy` | Recursive |
| GET/PUT/DELETE | `/api/requests/*path` | `requests#show/update/destroy` | `*path` keeps slashes and `.bru` |
| POST | `/api/requests` | `requests#create` | |
| POST | `/api/requests/rename` | `requests#rename` | Also updates `meta.name` |
| GET | `/api/environments` | `environments#index` | |
| GET/PUT | `/api/environments/:name` | `environments#show/update` | PUT replaces only `vars` |
| POST | `/api/run` | `runs#create` | See [runner](/execution/runner-pipeline.md) |

# Notes

* Rename is a **POST** with `{path, name}` rather than a PATCH. The new name may not contain `/` or `\`, and a trailing `.bru` is stripped.[^requests-controller]
* `POST /api/requests/rename` is declared **before** the `*path` glob routes, so it is not swallowed as a request path.[^routes]
* Requests are written either from raw `source` or from a `blocks` array of `{name, mode, pairs|raw}`. The server rebuilds `.bru` text from `blocks` and **re-parses** it, so everything written to disk passes through the [parser](/bruno-format/block-modes.md).[^requests-controller]
* Every non-GET route requires an `X-CSRF-Token` header carrying the token from the SPA's `csrf-token` meta. Without it the response is 422. See [CSRF protection](/security/csrf-protection.md).
