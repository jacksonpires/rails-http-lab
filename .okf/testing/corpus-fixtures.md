---
type: Runbook
title: Corpus round-trip fixtures
description: spec/fixtures/bruno_corpus/ is gitignored; drop any Bruno collection there to run the round-trip suite, which otherwise skips.
tags: [round-trip]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T15:00:00Z
sources:
  - id: round-trip-spec
    title: spec/bruno/round_trip_spec.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/spec/bruno/round_trip_spec.rb
  - id: tree-spec
    title: spec/storage/tree_spec.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/spec/storage/tree_spec.rb
---

# Procedure

1. Copy a Bruno collection (any tree of `.bru` files) into `spec/fixtures/bruno_corpus/`. The directory is gitignored, so it never gets committed.
2. Run `bundle exec rspec spec/bruno/round_trip_spec.rb`. Every `.bru` file is picked up automatically.[^round-trip-spec]
3. The "Bruno corpus fixture" context in `spec/storage/tree_spec.rb` uses the same directory.[^tree-spec]

On a clean checkout, and in CI, these examples **skip**. About 4 pending examples is expected, not a failure.

# When a fixture fails

The parser or serializer is wrong. Fix it there and **never edit the fixture**. See [round-trip stability](/bruno-format/round-trip-stability.md). [Multi-line values](/bruno-format/multiline-values.md) and new [raw block types](/bruno-format/block-modes.md) are the usual suspects.

# Other test conventions

* `spec/spec_helper.rb` loads the library without Rails, for the `bruno/`, `storage/` and `execution/` unit specs.
* `spec/rails_helper.rb` boots `spec/dummy/`, points `storage_path` at a tmpdir for each example, and enables `:test`.
* Request specs run with `ActionController::Base.allow_forgery_protection` forced on, whatever env the dummy app boots in. Every POST/PUT/DELETE must pass `headers: csrf_headers`. That helper loads the SPA shell and returns its real `csrf-token` meta, exactly as the frontend does. See [CSRF protection](/security/csrf-protection.md).
* `webmock` is loaded, so all outbound HTTP in specs must be stubbed.
