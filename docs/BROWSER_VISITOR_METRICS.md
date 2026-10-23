# First-party browser visitors — default-off candidate

Final pre-review verification: **1,388 backend examples, zero failures, seven
pending**, 78.25% coverage, exit 0; **180 frontend tests pass**, build/artifact/
diff checks pass. Temporary Redis stopped. Candidate remains uncommitted and
default-off pending review, hosted CI, migrations and privacy/operational sign-off.

Re-opt-in status follow-up: a 409 observation response now explains that the
browser identity was withdrawn and a reload is needed to start a new identity,
rather than reporting generic unavailability. **180 frontend tests pass**,
rebuilt bundle, JS syntax/diff pass. No backend changes in this step.

Privacy page disclosure: `/privacy` now describes the optional `meme_visitor`
cookie, SHA-256 key, last-visit timestamp, non-linkage to accounts/history,
independence from advertising consent, GPC/DNT, withdrawal suppression marker and
30-day scheduled cleanup eligibility. Route regression added; **1,388 backend
examples, zero failures, seven pending**, 78.18% coverage, exit 0; syntax/diff
pass. This is product disclosure accuracy, not legal sign-off; operator/legal
review remains required before enablement. Temporary Redis stopped.

CSV export parity: export now includes visitor status, collection-start UTC,
24h/7d/30d counts and partial flags, with empty values instead of zeroes when
disabled/unavailable. Initial run caught misplaced local variable in HTML route;
moved into export route and reran. **1,387 backend examples, zero failures,
seven pending**, 78.20% coverage, exit 0; syntax/diff pass. Temporary Redis
stopped; candidate uncommitted/default-off.

Dashboard diagnosis: visitor cards distinguish disabled collection from query
unavailability; available empty data says no observations yet with partial-window
labels. Safe operational hints, no raw database errors. Real rendered route tests
cover all three states. **1,387 backend examples, zero failures, seven pending**,
78.22% coverage, exit 0; syntax/diff pass. No Chrome rerun for wording change.
Candidate remains uncommitted/default-off; temporary Redis stopped.

Rolling-edge acceptance: fixed-time real DB regression includes observations
exactly at 24h/7d/30d lower boundaries, excludes just-older/future/revoked rows,
and verifies elapsed coverage labels and captured generation time. **1,386 backend
examples, zero failures, seven pending**, 78.16% coverage, exit 0; syntax/diff pass.
Tests/docs-only change; no production traffic or historical backfill. Temporary
Redis stopped, candidate uncommitted/default-off.

Snapshot consistency correction: 24h/7d/30d counts and collection-start metadata
now use one PostgreSQL statement/MVCC snapshot, not four independently observed
queries. Fixed cutoff preserved, revoked/future rows excluded. Regression checks
single statement and available empty-window result. **1,385 backend examples,
zero failures, seven pending**, 78.11% coverage; syntax/diff pass. No production
load/benchmark claim, browser not rerun for service-only change. Redis stopped.

Real two-tab acceptance: `tests/browser_visitor_tabs.mjs` passes **five checks
twice** with external requests blocked: shared established identity, cross-tab
withdrawal storage event, shared cookie removal, and no observation on later
visibility. Complements real DB concurrency test; does not hold/delay a response
or cover parallel no-cookie first visits, cookie response ordering, physical
devices or privacy review. JS syntax/diff pass. Temporary app/Chrome/Redis stopped.

Abuse-control follow-up: Rack::Attack observation-only throttle 60 POST/min/IP;
withdrawal excluded from this narrower limit, existing general API limit still
applies. Uses existing production Redis/memory-test store and local safelist.
Real middleware regression checks 61st request 429/Retry-After, other-client and
withdrawal independence. **1,384 backend examples, zero failures, seven pending**,
78.15% coverage; syntax/diff pass. Not distributed-bot prevention or proxy/IP
configuration acceptance; shared-NAT impact needs monitoring. Redis stopped.

## Current release decision

**Keep collection default-off pending review.** The dated-by-sequence notes below
are historical evidence, not separate release approvals. Latest backend: 1,388
examples / zero failures / seven pending, 78.25% coverage. Fresh frontend: 180
passing; build/artifact/diff checks pass. Latest Chrome: 210 passing checks after
revocation. No production migration/flag verification performed in this work.

### Before enablement

- [ ] Review and commit this candidate; run hosted CI on the exact revision.
- [ ] Review privacy wording, retention and independent consent/withdrawal behavior.
- [x] Run established-identity two-tab withdrawal: five checks pass twice.
- [ ] Accept or resolve parallel first-no-cookie and delayed response-cookie
  ordering limits; the two-tab test does not delay network responses.
- [x] Add observation-specific rate limit and middleware regression.
- [ ] Verify proxy/IP configuration, shared-NAT impact and internal/bot traffic.
- [ ] Apply base migration then revocation migration via approved staging process;
  repeat collection/count/withdrawal checks before production migration.
- [ ] Verify scheduled cleanup with collection on AND off; monitor backlog/failures.
- [ ] Record deployed revision, previous revision and rollback owner; only then
  explicitly enable `ENABLE_VISITOR_METRICS=true` through approved operations.

### Known boundary requiring a release decision

Revocation protects an established hashed cookie key. It cannot identify a request
that began without a cookie and independently minted a new key before withdrawal.
Also, a response that successfully recorded before withdrawal can arrive afterward
and restore the old cookie header: subsequent observations with that key are
rejected, but cookie removal is not a guaranteed network-wide atomic operation.
Do not describe this candidate as guaranteed deletion across every in-flight
request. Consent rejection suppresses ordinary future client collection. A stronger
guarantee needs a server-held consent-generation protocol and its own acceptance,
not a longer sleep or a client-only broadcast.

Current recommendation: review this bounded contract and privacy wording before
committing/enabling; do not silently mark the remaining gates complete. Additional
fixture counts alone will not settle that product/privacy decision.

### Operational smoke check

On an isolated fresh browser: no choice means no observation; Allow records one
browser, reload retains its identity; verify 24h/7d/30d counts and partial labels.
Decline/withdraw clears last-seen/cookie, leaves disclosed suppression key, and
removes that browser from counts. Replay old identity must return 409. Other browser
records must remain. Do not click Allow for other people or manufacture production
traffic to demonstrate growth.

Disable collection by setting the flag false and restarting web processes. This
does not itself remove stored rows; scheduled cleanup continues when schema exists.
Do not roll back by dropping analytics tables or revocation markers while old
requests/processes may still be using them. No historical visitor backfill.

## Historical implementation evidence

Retention cleanup correction: bounded worker cleanup now runs whenever migrated
visitor schema exists, even with collection disabled. Real DB worker regression
removes expired last-seen/revocation rows and preserves recent rows. **1,383 backend
examples, zero failures, seven pending**, 78.25% coverage, exit 0; syntax/diff pass.
Scheduling/backlog monitoring still operator-owned; no exact physical deletion SLA.
Temporary Redis stopped; candidate uncommitted/default-off.

Concurrent established-key store regression: six barrier-released real DB calls
(five observations plus one withdrawal) finish with revoked marker, null last-seen,
zero window counts and rejected subsequent observation. **1,382 backend examples,
zero failures, seven pending**, 78.21% coverage, exit 0; syntax/diff pass.
Concurrent scheduling is nondeterministic; one test run does not prove all network
or browser orderings. No-cookie first visits and real two-tab acceptance remain
open. Tests/docs-only follow-up; default-off, uncommitted. Redis stopped.

Post-revocation Chrome rerun: base plus revocation migrations applied only to
isolated browser database. Enabled fixture passes **210 checks, exit 0**, including
Allow, cookie continuity, independent advertising choice, withdrawal and rejection
after reload. No uncaught exceptions. This supersedes Chrome-not-rerun caveats for
current revocation implementation, not real two-tab/no-cookie acceptance or privacy
review. No runtime changes in this step; temporary app/Chrome/Redis stopped.

Old-cookie route acceptance: observation with an established cookie, withdrawal,
then replay of that old cookie yields **409**, no refreshed analytics cookie and
zero counts in all windows. Suppression row retained as disclosed. Full backend
**1,381 examples, zero failures, seven pending**, 78.16% coverage, exit 0.
Syntax/diff pass. This is ordered HTTP replay, not concurrent/two-tab browser
acceptance; no-cookie and response-order boundaries remain. Tests/docs-only
follow-up, candidate uncommitted/default-off; temporary Redis stopped.

Server revocation update: apply `add_browser_visitor_revocation.sql` after the base
migration. Withdrawal atomically clears last-seen and retains hashed key/revoked
timestamp; observations conflict on that row and cannot overwrite revocation.
Revoked identities return 409, never count or refresh cookie. Repeated withdrawal
does not extend marker age. Marker eligible for scheduled cleanup after 30 days;
frontend disclosure updated rather than claiming complete record deletion.
This protects established-cookie identity only: parallel first observations without
cookies and response cookie ordering remain boundaries. No production migration.
Historical deletion/no-revocation descriptions below are superseded by this entry.
Validation: **1,380 backend examples, zero failures, seven pending**, 78.19%
coverage; **179 frontend tests pass**, build/syntax/diff pass. Regression verifies
late write rejected, last-seen cleared and repeated withdrawal marker unchanged.
Caught/fixed transaction wrapper returning COMMIT rather than block result. No
Chrome rerun after revocation change. Candidate uncommitted/default-off; Redis stopped.

Cross-tab client status follow-up: relevant consent storage changes invalidate
pending observation status; unrelated storage events cannot hide an observation
failure. Withdrawal suppresses new requests while rejection remains stored, even
if prior response arrives late. Two new simulated cross-tab regressions; **179
frontend tests pass**, build/syntax/diff pass. No server revocation implemented:
already in-flight writes can still recreate deleted records. Real two-tab Chrome
and privacy review remain gates, default-off unchanged. Follow-up uncommitted.

Saved-choice disclosure: footer status initializes from visitor-only choice and
updates on storage events. Missing choice remains off; rejection does not imply
record deletion succeeded; GPC/DNT/storage failures explained. **177 frontend tests
pass**, rebuilt bundle, JS syntax/diff pass. No backend changes or Chrome rerun in
this slice. Cross-tab in-flight revocation remains unresolved; default-off.

Server withdrawal failure regression: failed deletion returns 503 without cookie
expiration or an unsupported claim that browser collection stopped. Record remains
for retry; retry succeeds. Withdrawal works with collection flag off. Full backend
**1,379 examples, zero failures, seven pending**, 78.17% coverage, exit 0. Initial
run exposed wall-clock same-UTC-day test failure; fixed test to midday UTC, no
retention behavior change. Syntax/diff pass; no Chrome rerun. Redis stopped.

Observation-status correction: consent saved is distinct from server recording.
Failed HTTP/network response reports unavailable with explicit reload retry; no
automatic retry loop. Pending observation protected from duplicate Allow sends;
same-page withdrawal invalidates late observation status and waits before deletion.
Two new regression cases; **176 frontend tests pass**, build/syntax/diff pass.
No backend changes or Chrome rerun in this slice. Cross-tab revocation and privacy
review still open; tracking default-off, follow-up uncommitted.

Frontend privacy/failure regression: executable isolated module tests cover no
consent/rejection, disabled flag, hidden/excluded pages, GPC/DNT, blocked storage,
single-send behavior and failed withdrawal messaging without success claims.
**174 frontend tests pass**, JS syntax/diff pass. These are simulated browser
globals, not real privacy-browser/device certification. Tests/docs-only slice;
backend not rerun. Cross-tab revocation and privacy review still required.

Browser gate follow-up: replaced immediate post-touch assertion with bounded wait
for expected slide, retaining same-feed assertion. No product gesture change.
Reset only fixture-origin storage at suite start to avoid old withdrawal choice
contaminating reruns. Two standalone completed runs pass **210 checks each**;
an intervening combined run exceeded tool timeout and is not counted as pass.
Trace instrumentation removed. These runs supersede earlier flaky-gate status for
this reproduction, not a physical-device guarantee. Cross-tab withdrawal/privacy
review remain open. Temporary app/Chrome/Redis stopped; syntax/diff pass.

Gallery-gate investigation follow-up: one instrumented full run passed **210
checks**, including seven reusable visitor-control checks. Subsequent runs again
failed at dynamic-gallery horizontal touch. Diagnostic hit-test in passing run
landed on expected active image; delay/instant-scroll experiments did not reliably
resolve and were reverted. No product gesture change or reliable full-suite pass
claimed. Focused six-check visitor result remains valid; gallery flakiness remains
an open gate. Temporary app/Chrome/Redis stopped; syntax/diff pass.

Browser follow-up: focused isolated Chrome check passes six assertions: no cookie
before Allow, HttpOnly cookie, unchanged advertising choice, stable identity on
reload, deletion and persisted withdrawal. Final isolated DB visitor-row count
zero. Full suite attempted twice and stopped earlier at dynamic-gallery horizontal
touch assertion; NOT a full-browser pass. Visitor checks added to reusable suite
but not reached there. Cross-tab races, privacy signals/failure paths and formal
privacy review remain gates. Temporary app/Chrome/Redis stopped; uncommitted.

Definition: distinct opted-in browser identifiers observed on a visible eligible
page within rolling 24h/7d/30d UTC windows. Not people, registered accounts, pageviews
or proof of attention. No IP fingerprinting or cross-device/account stitching.

Apply `db/migrations/add_browser_visitors.sql` through approved migration process
before considering `ENABLE_VISITOR_METRICS=true`. No production migration/enablement
performed. Cookie is opaque, HttpOnly, SameSite=Lax, Secure on HTTPS, 30-day rolling
expiry. Database stores SHA-256 key and latest observation only, not page history.
Each successful observation refreshes last-seen; duplicates do not inflate counts.

Separate explicit accepted visitor choice required globally; GPC/DNT suppress
collection. Unknown/rejected/storage-blocked choices produce no client event.
CSRF protection applies. Initial visible eligible page produces at most one client
event, not each AJAX Next. Login/logout do not explicitly clear analytics cookie.
Known automation can still call the endpoint; counts are not certified human traffic.

Cleanup worker deletes at most 10,000 expired rows per run when the migrated
table exists, including with collection disabled; schedule/monitor it. Physical removal
can lag the 30-day counting window; do not promise exact deletion timing. Collection
start is first accepted observation, not historical backfill; gaps/outages aren't
tracked, so partial-window labels indicate elapsed time only, not source completeness.

Footer controls now permit analytics Allow or Decline/withdraw independently of
advertising choice. Withdrawal stops this page, stores rejection, waits for its
pending observation, deletes this browser record and expires the analytics cookie.
Server withdrawal remains callable with collection disabled. Deletion failure is
reported for retry, not silently claimed successful. Cross-tab in-flight writes
can still recreate state; no global revocation guarantee. Privacy choice applies
only to this visitor pipeline, not existing ads/other analytics.

Validation: 1,377 backend examples, zero failures, seven pending; 170 frontend
tests pass; rebuilt bundle, syntax/diff pass. Actual consent UI/browser tests not
yet run. Migration/production flag unchanged, candidate uncommitted.

Before enabling: reviewed privacy notice and persistent withdrawal control, appropriate
consent review, browser collection/withdrawal tests, bot/rate-limit review, hosted
migration and cleanup acceptance. Existing consent UI has regional/mobile gaps;
this candidate does not repair it or infer permission when choice is missing.
Service reports disabled/unavailable rather than fabricated zero on failures.