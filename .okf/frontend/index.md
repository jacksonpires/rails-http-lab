# Frontend

Vanilla-JS SPA in `app/assets/javascripts/rails_http_lab/application.js`, talking to the [JSON API](/engine/json-api.md).

* [Persistable doc](persistable-doc.md) - Empty blocks injected by viewing a tab are dropped on save/send; blocks already on disk are kept.
* [Query/URL sync](query-url-sync.md) - The URL query string and the `params:query` block mirror each other both ways.
* [Sessions and sidebar state](sessions.md) - Per-request working copies mirrored to localStorage; expanded folders and scroll survive re-renders.
