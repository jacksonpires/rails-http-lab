---
type: Decision
title: Sidebar ordering — alphabetical top level, seq inside folders
description: Top-level collections sort case-insensitively by name; nested entries sort by Bruno's meta.seq, then name — an intentional asymmetry.
tags: [bruno-interop]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: tree
    title: lib/rails_http_lab/storage/tree.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/storage/tree.rb
  - id: fs
    title: lib/rails_http_lab/storage/filesystem.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/storage/filesystem.rb
---

# Decision

`Storage::Tree` uses two sort keys on purpose:[^tree]

* **Top level (collections):** `name.downcase`, so the list is alphabetical and case-insensitive. Any `seq` is ignored.
* **Nested:** `[seq || 9999, name.downcase]`, so Bruno's hand-ordering is respected and entries without a `seq` go last.

# Why

At the top level, users scan for a collection by name, and folders created from different tools have unrelated `seq` values. Inside a folder, the order of requests is meaningful (for example a login → create → fetch flow), and Bruno desktop lets users drag to reorder. Do **not** unify these into one sort key.

# Related mechanics

* `Filesystem#create_folder` writes a `folder.bru` with `meta { name, seq }`, where `seq` is the max `seq` among sibling `.bru` files plus 1.[^fs]
* The root-level `environments/` directory is excluded from the tree and returned separately as `environments`.[^tree]
* `folder.bru` itself is never listed as a request.[^tree]
