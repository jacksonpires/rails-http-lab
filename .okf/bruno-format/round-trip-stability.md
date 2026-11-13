---
type: Principle
title: Byte-stable round-trip
description: Serializer.dump(Parser.parse(s)) must equal s for any file Bruno desktop writes; this is the gem's defining constraint.
tags: [round-trip, bruno-interop]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: parser
    title: lib/rails_http_lab/bruno/parser.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/bruno/parser.rb
  - id: serializer
    title: lib/rails_http_lab/bruno/serializer.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/bruno/serializer.rb
  - id: interop-fix
    title: "Commit c48b32a — Fix Bruno interop bugs found while recording the README demo GIF"
    resource: https://github.com/jacksonpires/rails-http-lab/commit/c48b32a
---

# Overview

The gem promises that a collection can move freely between this UI and Bruno desktop. The test of that promise is a round-trip property: `Serializer.dump(Parser.parse(s)) == s` for every file Bruno itself wrote.[^parser] If saving a request rewrites unrelated whitespace, every save shows up as noise in PR diffs, and the "files in the repo" pitch falls apart.

# What carries the guarantee

* **`Document` keeps whitespace metadata.** It stores `leading_blank_lines` and `trailing_newline`, and the serializer restores both exactly.[^serializer] These fields are load-bearing, so don't "tidy" them.
* **Exact layout.** Blocks are emitted as `name {` … `}` with a single blank line between them. KV lines use an exact 2-space indent.[^serializer]
* **KV blocks are ordered pair arrays, not hashes.** Key order and duplicate keys both survive.
* **Raw and list bodies are kept verbatim.** See [block modes](/bruno-format/block-modes.md).
* **Empty blocks already on disk are kept.** The frontend drops only empty blocks it injected itself. See [persistable doc](/frontend/persistable-doc.md).

# When it breaks

The rule is: **fix the parser or serializer, never the fixture.** The proof is the [corpus round-trip suite](/testing/corpus-fixtures.md). Real-world breakage has happened before. Environments that contain a `vars:secret [ ... ]` list made every run fail with a `ParseError` until list blocks were supported.[^interop-fix]
