# Storage

Filesystem CRUD rooted at `config.storage_path` (default `Rails.root/docs/http-lab`).

* [Path safety](path-safety.md) - Every write goes through `safe_path`, which confines it to the storage root.
* [Sidebar ordering](sidebar-ordering.md) - Top level is alphabetical; inside folders, Bruno's `meta.seq` wins.
* [Lazy scaffolding](lazy-scaffolding.md) - `bruno.json` and `environments/` are created on first use, not by the generator.
