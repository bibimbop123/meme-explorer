# CSP report-only staging

Default: unchanged existing enforced CSP. Opt in on **staging first** with
`CSP_REPORT_ONLY=true`; restart the app. Do not remove the enforced CSP header.

The additional report-only policy permits same-origin scripts and request-nonced
layout scripts, reports inline event handlers and untrusted script origins, and
restricts objects/base URI. It does not block execution. Styles, media and other
directives are not yet migrated. No strict-dynamic trust is granted to ad scripts.

Requests receive a fresh nonce before rendering; layout script tags use it.
Other templates and dynamically generated inline handlers remain migration work.
When enabled, responses are private/no-store to prevent nonce replay. This can
reduce static caching too; evaluate performance before broad enablement.

No report collector is configured: inspect browser Console/DevTools violations
using docs/BROWSER_ACCEPTANCE.md. Do not submit URLs, cookies, tokens or script
samples to third-party collectors without privacy review. This is diagnostic
scaffolding, not a completed CSP audit or production security acceptance.

Before enforcement: inventory violations, migrate inline handlers/scripts, review
each third-party origin and ad trust boundary, test auth/viewer/Saved on devices,
and design a bounded/privacy-reviewed report endpoint if required. Never fix reports
by adding arbitrary https: or unsafe-inline to the candidate script policy.

Rollback: unset CSP_REPORT_ONLY and restart. Existing enforced policy remains.