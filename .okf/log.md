# Update Log

## 2026-11-13
* **Creation**: Initial bundle produced from the v0.1.1 codebase — overview in [rails-http-lab](/project.md), plus the Bruno format, storage, execution, security, engine, frontend and testing areas.
* **Security**: All mutating API endpoints now verify the CSRF token. Previously every one called `skip_forgery_protection`, so a cross-site form POST could trigger `/api/run` or write `.bru` files. The SPA now sends `X-CSRF-Token` on body-less `DELETE`s too — [CSRF protection on the JSON API](/security/csrf-protection.md).
