---
type: Component
title: Sessions and sidebar state
description: One session per request path holds the working doc, last response and tabs, mirrored to localStorage (LRU 30); expandedFolders and scroll survive tree reloads.
tags: [frontend]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: frontend
    title: app/assets/javascripts/rails_http_lab/application.js
    resource: https://github.com/jacksonpires/rails-http-lab/blob/main/app/assets/javascripts/rails_http_lab/application.js
---

# Schema

Each request path the user opens gets a session:[^frontend]

| Field | Description |
|-------|-------------|
| `doc` | Working copy, including unsaved edits |
| `savedDoc` | Last on-disk version, used for dirty detection and [persistable doc](/frontend/persistable-doc.md) |
| `activeTab` / `responseTab` | UI state |
| `response` | Last `/run` result |
| `touched` | Timestamp for the LRU |

# Persistence

Sessions are mirrored to `localStorage` under `rhl:<mount path>:sessions`. That keeps unsaved edits and the last response alive across navigation and reloads. Two caps apply: **30 sessions** (LRU) and **200 KiB per response body**.[^frontend] Response bodies, and the [resolved request](/execution/resolved-request.md) with its auth headers, therefore end up in the browser's localStorage.

# Sidebar

`state.expandedFolders` is a Set of open folder paths. Re-rendering the tree after a save or create (`loadTree()`) keeps both the expanded set and the scroll position, so the user's place is not lost. Restoring the last request after a reload also expands its parent folders.[^frontend]
