---
type: Component
title: Multi-line kv values
description: A kv value continues onto following lines while its braces are unbalanced or a '''triple-quoted''' string is open.
tags: [round-trip, fragile]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: parser
    title: lib/rails_http_lab/bruno/parser.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/bruno/parser.rb
---

# Overview

Bruno lets a value in a [kv block](/bruno-format/block-modes.md) span several lines in two ways:

1. **Unbalanced braces.** A URL with embedded JSON such as `?filter={` keeps reading lines until the brace depth returns to 0.
2. **Triple-quoted strings.** `'''…'''` is Bruno's multi-line literal. Braces inside it are ignored for depth counting.

`Parser#consume_multiline_value` and `value_needs_continuation?` implement both. A value that is never closed raises `ParseError`.[^parser]

# Handle with care

This is the most fragile spot in the parser. Small changes can swallow the block's closing `}` or split a value in the wrong place. Re-run the [round-trip suite](/testing/corpus-fixtures.md) after touching it.

Key parsing also tolerates 0–4 leading spaces and splits on the **first** `:`. That way URLs and times inside values keep their colons.[^parser]
