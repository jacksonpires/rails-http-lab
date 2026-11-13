---
okf_version: "0.2"
---

# rails-http-lab

Knowledge bundle for the `rails-http-lab` gem — a Rails Engine that mounts a Bruno-compatible HTTP request lab inside a host app. Start with the [project overview](/project.md).

* [rails-http-lab](project.md) - What the gem is, its four layers, and the constraints that shape every change.

# Areas

* [Bruno format](bruno-format/) - Parsing and serializing `.bru` files with byte-stable round-trip.
* [Storage](storage/) - Filesystem CRUD for collections, path safety, sidebar ordering.
* [Execution](execution/) - The HTTP runner, variable resolution, and what it sends.
* [Security](security/) - The gates and boundaries that keep a server-side HTTP client safe.
* [Engine](engine/) - Rails integration: boot ordering, the JSON API, error mapping.
* [Frontend](frontend/) - The vanilla-JS SPA and how it keeps Bruno files clean.
* [Testing](testing/) - Corpus fixtures and the Ruby × Rails compatibility matrix.
