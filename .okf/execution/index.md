# Execution

How a parsed `.bru` document becomes a real HTTP request sent from the Rails server.

* [Runner pipeline](runner-pipeline.md) - Steps from document to `Net::HTTP` dispatch, limits and error handling.
* [Variable resolution](variable-resolution.md) - `{{var}}` substitution from the selected environment, and its limits.
* [Query param merge](query-param-merge.md) - `params:query` keys replace the same keys in the URL instead of duplicating them.
* [Resolved request summary](resolved-request.md) - `Response#request` carries the exact request sent; the cURL tab depends on it.
