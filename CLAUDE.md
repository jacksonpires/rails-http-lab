# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`rails-http-lab` is a Rails Engine gem (not an application). It mounts a Bruno-like HTTP request lab inside a host Rails app at `/rails/http-lab`, persisting collections as `.bru` files under `docs/http-lab/`. The defining constraint is **byte-stable round-trip with the Bruno desktop format** — files written by Bruno must parse and re-emit identically (see `spec/bruno/round_trip_spec.rb`). The reference fixture corpus lives under `spec/fixtures/bruno_corpus/` and is **gitignored** — drop a Bruno collection there locally to exercise the round-trip suite; CI/clean checkouts have the spec auto-skip.

Ruby `>= 3.1` required (`mise.toml` pins 3.4.7). Rails `>= 7.0`.

## Commands

```bash
bundle install                                 # install deps
bundle exec rspec                              # full suite (uses spec/dummy as host app)
bundle exec rspec spec/bruno/round_trip_spec.rb  # the round-trip property tests
bundle exec rspec spec/path/to_spec.rb:42      # single example by line number
```

There is no lint task and no build step beyond `gem build rails-http-lab.gemspec`. The engine is exercised via `spec/dummy/`, a minimal Rails app booted by `spec/rails_helper.rb`.

## Architecture

Four layers, each in its own subdirectory under `lib/rails_http_lab/`:

1. **`bruno/`** — Parser + Serializer for the `.bru` format.
   - `Parser` recognizes two block modes: `:kv` (`key: value` lines, 2-space indent) and `:raw` (opaque body, verbatim). Raw blocks are listed in `Parser::RAW_BLOCK_NAMES` — adding a new raw-block type (e.g. a new `body:*` variant) means updating that constant.
   - `Serializer` emits each block as `name {\n ... \n}` separated by a single blank line. Whitespace details — `leading_blank_lines`, `trailing_newline`, exact 2-space indent — are load-bearing for round-trip stability. Don't "tidy" them.
   - `Document` holds an ordered list of `Block`s. KV blocks preserve key order and allow duplicates (stored as `pairs` array, not a hash).

2. **`storage/`** — Filesystem CRUD rooted at `config.storage_path` (default `Rails.root/docs/http-lab`).
   - `Filesystem#safe_path` rejects absolute paths, `..` segments, and any resolved path escaping the root. All write APIs (`write_bru`, `create_folder`, `rename`, `delete`) go through it — preserve that when adding new methods. `rename` refuses to overwrite an existing destination.
   - `Tree` produces the nested folder/request structure consumed by the sidebar; the `environments/` folder at the root is treated specially (excluded from the main tree, surfaced separately).
   - **Top-level entries (collections) are sorted alphabetically, case-insensitive.** Nested entries still respect Bruno's `meta.seq` (so users can hand-order requests inside a folder). Don't unify these into a single sort key — the asymmetry is intentional.

3. **`execution/`** — HTTP runner that executes a parsed `Document`.
   - `Runner#run` resolves `{{vars}}` (via `VariableResolver`), merges `params:query`, applies `auth:bearer|basic|apikey`, dispatches via `Net::HTTP` with `executor_timeout` and `executor_max_body` limits, returns a `Response`.
   - **`Response#request`** carries the resolved request (`method`, `url`, `headers`, `body`) — populated by `summarize_request` after all interpolation/auth/body application, before dispatch. The frontend's cURL tab depends on this. Preserve it in both the success path and the rescue clauses (timeouts/generic errors); only `URI::InvalidURIError` legitimately returns `request: nil`.
   - **Bruno `script` and `tests` blocks are persisted but never executed** — this is a deliberate security boundary (confused-deputy / RCE risk). Do not add a JS runtime to evaluate them; users run scripts in Bruno desktop. The frontend renders those tabs as read-only with an explainer banner.

4. **`engine.rb` + `app/`** — The Rails Engine. Routes in `config/routes.rb` expose a JSON API under `/api` plus the SPA at root (`ui#index`):
   - `collections#tree`, `collections#create`
   - `folders#create`, `folders#rename` (POST), `folders#destroy` (DELETE)
   - `requests#show|update|create|destroy`, `requests#rename` (POST)
   - `environments#index|show|update`
   - `runs#create`
   - Vanilla-JS frontend in `app/assets/javascripts/rails_http_lab/application.js` talks to that API. Sidebar maintains `state.expandedFolders` (a Set of open folder paths) and preserves scroll across re-renders, so `loadTree()` after a save/create doesn't reset the user's place.

### Security model (do not weaken without discussion)

- `ApplicationController#guard_environment!` returns 404 unless `Rails.env` is in `config.enabled_envs` (default `[:development]`).
- `Engine`'s `after_initialize` **refuses to boot** if `:production` is in `enabled_envs` without a configured `authenticator` callable. Don't add fallbacks that bypass this.
- The runner makes requests from the Rails server — it can reach internal services. That's the point, but it's also why the auth gate matters.
- `ApplicationController` rescues `RailsHttpLab::Error` (base class) → 422. Subclass-specific rescues (`NotFoundError`, `OutsideStorageError`, `ParseError`) come first and take priority — don't reorder.

### Boot ordering gotcha

The engine class **must be defined before `Rails.application.initialize!`** so Rails picks it up while collecting railties — otherwise the engine's own `config/routes.rb` is never loaded and the host-side `mount` silently produces an empty route table (the mount point appears in `/rails/info/routes` but the engine section says "You don't have any routes defined!").

The install generator's `initializer.rb.tt` starts with `require "rails_http_lab"` for exactly this reason — it makes the engine survive a consumer that sets `require: false` on the gemfile entry. Don't drop that line. If a user reports `/rails/http-lab` returning 404 with an empty engine route table, this is almost always the cause.

## Test conventions

- `spec/spec_helper.rb` loads the library standalone (no Rails) — used by `bruno/`, `storage/`, `execution/` unit specs.
- `spec/rails_helper.rb` boots `spec/dummy/` and is required by `type: :request` and `type: :system` specs. It rewrites `config.storage_path` to a per-example tmpdir and adds `:test` to `enabled_envs` — call `RailsHttpLab.reset_configuration!` if a spec needs to override further.
- Corpus-dependent specs (`spec/bruno/round_trip_spec.rb`, the "Bruno corpus fixture" context in `spec/storage/tree_spec.rb`) `skip` cleanly when `spec/fixtures/bruno_corpus/` is empty. On a clean checkout you'll see ~4 pending; that's expected. To run them locally, populate the dir with a Bruno collection — any `.bru` files will be picked up automatically. If a fixture fails round-trip, the parser/serializer is wrong; fix it there, don't edit the fixture.
- `webmock` is loaded; outbound HTTP in tests must be stubbed.

## Conventions worth knowing

- KV pairs whose key starts with `~` are treated as disabled (skipped by the runner when applying headers, query params, form fields). Preserve them through parse/serialize.
- Bruno multi-line values use either unbalanced braces (e.g. URLs with embedded JSON) or `'''...'''` triple-quoted strings. `Parser#consume_multiline_value` handles both — touch with care and re-run the round-trip suite.
- `meta` block's `seq` integer drives sidebar ordering **inside folders**; top-level collections are sorted by name regardless of `seq`. `Filesystem#create_folder` writes a `seq` automatically for nested folders.
- The install generator only emits the empty `docs/http-lab/` directory and the initializer. `bruno.json` and `environments/` are created lazily by `Filesystem#ensure_root!` and `Filesystem#write_bru` (via `mkdir -p`) on first use — don't reintroduce them in the generator.
