# Security

The runner is a server-side HTTP client that can reach internal services. That reach is the point of the gem and also its main risk. Do not weaken these controls without discussion.

* [Environment gate](environment-gate.md) - 404 unless `Rails.env` is in `enabled_envs`; optional `authenticator` → 403.
* [Production boot guard](production-boot-guard.md) - The engine refuses to boot with production enabled and no authenticator.
* [No script execution](no-script-execution.md) - Bruno `script`/`tests` blocks are persisted but never run.
* [Path safety](/storage/path-safety.md) - Storage writes are confined to the storage root.
* [CSRF protection on the JSON API](csrf-protection.md) - Every mutating endpoint verifies the CSRF token; the SPA sends it on every non-GET call.
