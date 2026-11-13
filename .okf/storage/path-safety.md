---
type: Security Control
title: Path safety (Filesystem#safe_path)
description: All storage APIs resolve user-supplied paths through safe_path, which rejects absolute paths, `..` segments and anything resolving outside the root.
tags: [security]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: fs
    title: lib/rails_http_lab/storage/filesystem.rb
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/lib/rails_http_lab/storage/filesystem.rb
---

# Overview

Paths come straight from the browser. Request paths, folder paths and environment names (which become `environments/<name>.bru`) all reach the filesystem. `Filesystem#safe_path` is the single choke point:[^fs]

| Rejected | Error |
|----------|-------|
| empty path | `OutsideStorageError` |
| starts with `/` | `OutsideStorageError` |
| any `..` segment | `OutsideStorageError` |
| cleaned path not equal to the root and not under `root/` | `OutsideStorageError` |

`OutsideStorageError` maps to HTTP 403 (see [error mapping](/engine/error-mapping.md)).

# Invariants to keep

* **Every** method that reads or writes a path goes through `safe_path`: `read_bru`, `write_bru`, `create_folder`, `rename` (both ends) and `delete`. New methods must do the same.[^fs]
* `rename` refuses to overwrite an existing destination.[^fs] Rename must never be a way to clobber a file.
* `delete` on a directory is `rm -rf`. The only thing confining it is `safe_path`.
