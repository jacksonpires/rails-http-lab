---
type: Component
title: Block modes (kv, raw, list)
description: The parser classifies every .bru block as kv, raw or list; raw needs an allowlist entry, list is detected by its `[` opener.
tags: [round-trip, extension-point]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: parser
    title: lib/rails_http_lab/bruno/parser.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/bruno/parser.rb
  - id: block
    title: lib/rails_http_lab/bruno/block.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/bruno/block.rb
---

# Schema

| Mode | Opener | Body | Examples |
|------|--------|------|----------|
| `:kv` | `name {` | `  key: value` lines, stored as an ordered `pairs` array | `meta`, `get`, `headers`, `params:query`, `auth:bearer`, `vars` |
| `:raw` | `name {` | Opaque, verbatim; the close is found by brace counting | `body:json`, `body:text`, `body:xml`, `body:sparql`, `body:graphql`, `body:graphql:vars`, `script:pre-request`, `script:post-response`, `tests`, `docs` |
| `:list` | `name [` | Verbatim until a line that is exactly `]`; `Block#items` gives the names | `vars:secret` in environment files |

# How the parser decides

* A `{` opener is **raw only if its name is in `Parser::RAW_BLOCK_NAMES`**. Otherwise it is kv.[^parser] Adding support for a new raw block type, such as a new `body:*` variant, means adding it to that constant. If you forget, its contents get parsed as `key: value` lines and the parser raises.
* A `[` opener is always a list. There is no allowlist.[^parser]
* Any line outside a block raises `ParseError`. The parser is strict on purpose, so callers learn their file is malformed instead of losing data silently.[^parser]

# Raw block closing

Raw bodies can contain braces (JSON, JS), so the parser counts `{` and `}` per line. The block closes on a line that is exactly `}` and brings depth to 0. There is a defensive branch for a closing brace that shares a line with content. Real Bruno files don't hit it.[^parser]

`Block#items` splits a list body on newlines and strips trailing commas, because Bruno separates list items with `,\n`.[^block]
