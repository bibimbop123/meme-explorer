# First-party browser visitors — default-off candidate

Definition: distinct opted-in browser identifiers observed on a visible eligible
page within rolling 24h/7d/30d UTC windows. Not people, registered accounts, pageviews
or proof of attention. No IP fingerprinting or cross-device/account stitching.

Apply `db/migrations/add_browser_visitors.sql` through approved migration process
before considering `ENABLE_VISITOR_METRICS=true`. No production migration/enablement
performed. Cookie is opaque, HttpOnly, SameSite=Lax, Secure on HTTPS, 30-day rolling
expiry. Database stores SHA-256 key and latest observation only, not page history.
Each successful observation refreshes last-seen; duplicates do not inflate counts.

Existing explicit accepted cookie choice required globally; GPC/DNT suppress
collection. Unknown/rejected/storage-blocked choices produce no client event.
CSRF protection applies. Initial visible eligible page produces at most one client
event, not each AJAX Next. Login/logout do not explicitly clear analytics cookie.
Known automation can still call the endpoint; counts are not certified human traffic.

Cleanup worker deletes at most 10,000 expired rows per run while flag enabled;
schedule/monitor it and arrange cleanup when disabling. Database physical removal
can lag the 30-day counting window; do not promise exact deletion timing. Collection
start is first accepted observation, not historical backfill; gaps/outages aren't
tracked, so partial-window labels indicate elapsed time only, not source completeness.

Before enabling: privacy notice and persistent withdrawal control, appropriate
consent review, browser collection/withdrawal tests, bot/rate-limit review, hosted
migration and cleanup acceptance. Existing consent UI has regional/mobile gaps;
this candidate does not repair it or infer permission when choice is missing.
Service reports disabled/unavailable rather than fabricated zero on failures.