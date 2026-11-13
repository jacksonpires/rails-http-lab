# Engine

Rails integration: how the engine boots, what it exposes, and how errors map to HTTP.

* [Boot ordering gotcha](boot-ordering.md) - The engine must be defined before `initialize!`, or its routes silently vanish.
* [JSON API](json-api.md) - The `/api` routes the SPA uses.
* [Error mapping](error-mapping.md) - Error subclasses → 404/403/422, in a deliberate rescue order.
