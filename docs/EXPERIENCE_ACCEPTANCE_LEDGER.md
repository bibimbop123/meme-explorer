# Experience acceptance and baseline ledger

## Execution state

### Signed-in browser like continuity — 2026-10-17

Opt-in random disposable account adds six checks: browser-fetch signup with real
CSRF/session, DOM Like confirmation/count, liked media on profile after full-page
navigation, unlike baseline restoration, logout and protected profile redirect.
**138 total browser checks pass**; default account-free run remains 132. Signup
fetch is not real form submission; image presence is not exact-meme reload state.
Fixture guards existing accounts and deletes only designated random user/activity
at exit. Independent query after shutdown reports zero matching fixture users.

153 frontend tests, syntax/diff checks pass. Test/harness/docs-only; no backend
rerun or product defect/implementation change. No account credentials logged in
reports, production mutation, commit/push/deploy/feed changes or score increase.
Temporary Chrome/server/Redis stopped. Physical pointer, concurrent tabs, exact
reload state, real user/content evidence and manual/platform gates remain open.

### Guest browser like retry/late-response acceptance — 2026-10-17

Complete Chrome fixture suite **132 passing checks**. Six new checks use DOM
Like-button listeners with real guest HTTP/CSRF/Redis persistence and test-only
fetch wrapper dropping/holding successful responses after server completion.
Lost success → visible rollback → retry desired true with one count increment;
explicit unlike restores count. Held success after Next leaves other meme UI
unchanged; Previous restores confirmed original like. Final unlike restores delta.
No new app defect/implementation change or physical click claim. 153 frontend tests,
JS syntax/diff pass. Backend not rerun; latest 1,313/zero failures/seven pending.
No signed-in browser or guest multi-tab race claim. Fixture services stopped;
no production/flag/commit/push/deploy changes, no score increase.

### Like HTTP retry and partial-write rollback acceptance — 2026-10-17

Extended actual-app config.ru/HTTP test to 19 checks: missing like CSRF rejected;
desired states true/true/false/false/true preserve intended state and counts;
nonboolean intent rejected. Real Redis session/auth/CSRF stack; no browser click
claim. Added random like fixture identity and at-exit metadata/activity cleanup.
Independent DB query confirms zero fixture users/stats/activity afterward.

New backend regression injects swallowed missing-table SQL after membership/count/
preference writes start; all three roll back and service reports failure. Full
backend **1,313 examples / zero failures / seven pending, 77.61% coverage
(5,303/6,833), exit 0**, 72.29s. **153 frontend tests pass**, Ruby syntax/diff
checks pass. Product implementation unchanged this slice; tests/docs only. No
browser rerun, concurrency HTTP guarantee, guest-session race fix, deployment,
commit/push/feed change or score increase. Disposable Redis stopped afterward.

### Desired-state and atomic signed-in likes — 2026-10-17, local validation

`/like` accepts optional boolean liked; invalid shapes/states/URL types rejected.
Bundled client sends intent, not toggle-only. Missing state retains old toggle
compatibility. Signed-in set_like locks media stats row within DB transaction,
serializes membership/count/preference transition, returns unchanged for repeated
desired state and rolls back critical failure with safe 503. Explicit outcome retained
because repository transaction wrapper returns COMMIT result. Optional legacy
leaderboard isolated by savepoint: rescued missing-table SQL otherwise poisons
PostgreSQL transaction. Final SELECT verifies transaction has not silently aborted.

Initial full runs failed for transaction return semantics and optional leaderboard
SQL; fixed, not bypassed. One bundle-fingerprint failure came from rebuilding during
tests; final run used fixed artifacts. Final **1,312 examples / zero failures /
seven pending, 77.54% coverage (5,298/6,833), exit 0**, 71.19s. **153 frontend tests
pass**, including explicit-state client payload; build/syntax/diff pass. New tests:
route retries/validation, unchanged-state counts/preferences, rollback and four
concurrent same-state requests over real pooled DB connections. Existing real Redis
session toggle compatibility passes. Browser interaction mutation not newly run.

Guest desired states use session and remain vulnerable to concurrent session writes;
legacy clients still toggle on retry. Conflicting signed-in intents serialize by DB
arrival, not client sequence/version. Direct track_like callers outside route remain
outside lock boundary. No schema/ranking/flag/historical score repair or production
changes. No commit/push/deploy/score bump. Disposable Redis stopped after checks.

### Sequential like preference integrity — 2026-10-17, local regression

Inspection confirmed track_like bumped preferences on every positive toggle while
liked_at history survives unlike. Preference bump now consults prior liked_at so
sequential re-likes of one user/media do not repeatedly strengthen community taste.
New real-route regression exercises first like, three unlike/re-like cycles and a
different meme in the same community: global counts alternate 0/1; preference stays
1.0/times_liked=1 until second distinct meme then becomes 1.2/2.

Full backend **1,308 examples / zero failures / seven pending, 77.51% coverage
(5,274/6,804), exit 0**, 71.16s. **152 frontend tests pass**; syntax/diff checks pass.
No ranking formula/feed flag/schema change, no historical score repair. This retains
historical-positive evidence rather than decrementing on unlike. Not a retry-safe
desired-state API or concurrency fix; authenticated route still toggles and its
multiple persistence writes are not atomic. Missing legacy liked_at can count once
again; preference-write failure handling remains existing best-effort behavior.
No recommendation quality/retention lift claimed. Browser not rerun for backend
slice. Disposable test Redis stopped; no commit/push/deploy or score increase.

### Content baseline collection checks — 2026-10-17, offline tooling

Extended existing bounded offline summary without changing its private input schema:
four joint guest/returning × mobile/desktop cell counts, unknown judgment counts,
missing-coverage warnings and explicit manual-review requirements. Detects complete
marginal mixes masking empty joint cells. Unviewed requests excluded; no quality
score, auto acceptance, fetching, ranking changes or real observations invented.
Runbook/worksheet explain empty warnings are not quality or research approval.

Three new regression examples cover joint gaps, fully judged balanced fixtures still
requiring manual review and invisible-request exclusion. Full backend: **1,307
examples, zero failures, seven pending, 77.45% coverage (5,268/6,802), exit 0**,
70.43s. **152 frontend tests pass**; direct offline empty-report smoke, Ruby syntax
and diff checks pass. Test fixtures are synthetic validation, not content evidence.
No app/browser behavior change; browser suite not rerun. Disposable Redis stopped.
Real audit/user research, manual accessibility and platform acceptance remain open.
No commit/push/deploy, feed changes or score increase.

### Action-group keyboard visibility — 2026-10-17, local fixture acceptance

Browser suite now **126 passing checks**: 48 new focus/viewport/center-hit assertions
for Like/Save/Share/Download at 320/375/1280px in both themes. Entry is programmatic
Like focus, then native Tab through Save→Share→Download. No action mutations,
no reproduced app defect and no product code changed. 152 Node tests, JS syntax
and diff checks pass. Backend not rerun for test/docs-only additions; latest remains
1,304 examples / zero failures / seven pending / 77.38% coverage.

Fixture image checks do not cover all scroll/media/overlay/error/zoom/contrast
states or whole-page Tab order. Center-hit is narrower than full unobscuration.
No screen-reader/physical-device acceptance or real-content evidence added. Test
services stopped; no commit/push/deploy/flag changes or score increase. Prioritize
real baseline and manual/platform gates over further count-only fixture expansion.

### Skip-to-content keyboard continuity — 2026-10-17, reproduced/fixed

Skip activation did not focus main. Adding tabindex alone was insufficient:
fragment navigation reached viewer popstate content-history logic. Added main
tabindex=-1 and a skip click handler preventing fragment history while focusing/
scrolling main. Native anchor remains without JS. Browser at 320/375/1280 confirms
visible focused skip, main focus, unchanged meme/URL and next Tab into viewer
navigation. Menu test waits after focus-induced scrolling before opening; scroll
intentionally closes disclosure. No general history semantics change.

Final validation: **78 browser checks**, **152 frontend tests**, build/syntax/diff
pass. Final-code full backend: **1,304 examples, zero failures, seven pending,
77.38% coverage (5,253/6,789), exit 0**, 69.22s. Bundle rebuilt. Two new Node
regressions cover landmark markup and handler focus/scroll/preventDefault behavior.
Action-focus/sticky coverage remains incomplete; true zoom, screen-reader listening,
physical devices, ads, content study and Render termination remain open. No score
increase, commit/push/deploy or feed/config changes. Temporary services stopped.

### Gallery accessibility — 2026-10-17, reproduced/fixed

Chrome AX tree exposed inactive server slides: reproduced before fix. Server slides
now hidden semantically; labeled native indicator buttons expose selected state;
counter is polite/atomic live status. Added focus-visible styling and reduced-motion
gallery transition suppression. Browser indicator Enter activation required correct
CDP input metadata (test fix, not product bug). Route contract verifies initial
semantics; Node gallery mocks reflect native style/attribute updates.

Final validation: **66 browser checks**, **150 frontend tests**, build/syntax/diff
pass. Full backend **1,304 examples, zero failures, seven pending, 77.40% coverage
(5,255/6,789), exit 0**, 70.36s. Accessibility tree confirms one current image;
keyboard activation, selected state, visible outline and zero reduced-motion
transition verified. No actual screen-reader listening or desktop 200% zoom;
viewport/text enlargement not relabeled as zoom. Physical devices, contrast across
all states, ads/real content and platform termination remain open. No score bump,
commit/push/deploy or feed flag changes. Temporary fixture services stopped.

### Valid playback and dynamic galleries — 2026-10-17, local fixture acceptance

Browser script now passes **60 checks**. Added original in-memory canvas→VP8/WebM
fixture and CDP byte-range responses. Normal dynamic renderer now has browser
evidence for decoded gallery, button/vertical/horizontal touch ownership and exact
slide recovery after Next→Previous. Synthetic silent video decodes, plays, seeks
paused/muted to 0.8s and restores position after Next→Previous. Initial failures
were test global-variable scoping and missing byte ranges, not confirmed app bugs.

150 frontend tests, JS syntax and diff checks pass. No product code changed or
backend suite rerun this slice; latest backend remains 1,304 / zero failures /
seven pending. No binary fixture or new dependency; recording is generated locally
in Chrome memory. One WebM codec is not cross-browser MP4/audio/streaming coverage.
True zoom, screen reader, physical devices, ads, real content research and platform
termination remain open. No score increase/commit/push/deploy or feed changes.
Services stopped after validation. See [browser report](BROWSER_UX_ACCEPTANCE_2026_10_17.md).

### Gallery gestures and video recovery — 2026-10-17, reproduced/fixed

Extended browser fixture with request-local gallery and invalid-video modes.
Browser regression reproduced vertical-dominant touch changing a server gallery
slide, and nested video `<source>` error failing to create recovery actions.
Fixed both server/dynamic gallery gesture state for direction, pinch/multitouch,
cancellation and interactive exclusions. Recovery now maps SOURCE errors to parent
VIDEO. Two new executable Node gallery tests plus nested-source assertion; updated
existing touch mocks with native touchend shape. Rebuilt committed bundle.

Final validation: **50 browser checks pass**, **150 frontend tests pass**, build
passes, full backend **1,304 examples / zero failures / seven pending, 77.40%
coverage (5,255/6,789), exit 0**, 69.97s. Syntax/diff checks pass. Browser confirms
gallery button/keyboard ownership, vertical gesture preserving slide/feed identity,
video controls/muted state, explicit retry retaining identity and next escape to
decoded local image. Existing 132-byte MP4s are invalid; no successful playback,
seeking or codec acceptance claimed. Server gallery has browser evidence; dynamic
gesture changes have executable Node coverage, not equivalent browser acceptance.

True zoom, physical devices, screen reader, ads-enabled layouts, valid playback,
live content study and production/platform termination remain open. No feed flags,
production changes, commit/push/deploy or score increase. Local fixture services
stopped after checks. See [browser report](BROWSER_UX_ACCEPTANCE_2026_10_17.md).

### Browser image-viewer UX — 2026-10-17, local fixture acceptance

Added guarded actual-stack browser fixture and dependency-free Node/CDP script.
42 checks pass in headless Chrome: 320/375/1280px layout, decoded-image bounds,
theme states, menu viewport/Escape/focus, shortcuts focus trap/dismissal,
Space→Next→Previous identity, doubled root text, reduced-motion query delivery,
emulated vertical/horizontal touch, About swipe non-navigation and no uncaught
Runtime exceptions. Ruby HTTP blocked, Sidekiq faked, page external requests
intercepted, ads disabled, local test DB/disposable Redis. No feed override.

No defect reproduced or product-code edits this slice. No actual 200% zoom,
screen reader, physical-device pinch, video/gallery/ad-enabled or real content
acceptance claimed; text enlargement and touch emulation are narrower checks.
See [browser report](BROWSER_UX_ACCEPTANCE_2026_10_17.md). Scripts remain opt-in;
no new browser dependency. No full backend rerun for these harness/docs additions.
No commit/push/deploy or score increase. Fixture server/Chrome/disposable Redis
stopped after validation. Research observations and production state untouched.

### Actual-app middleware and shutdown — 2026-10-17, local acceptance

Added guarded opt-in `tests/app_server_test.rb`: actual config.ru evaluated inside
an isolated wrapper, explicit local test PostgreSQL/disposable Redis 16379,
allowlisted child environment, dotenv bypass, Ruby HTTP blocked, fake Sidekiq and
local media supply. No feed override. Twelve checks pass through actual Redis
sessions, SessionValidator, authorization, compression and app: login/CSRF/session
rotation, profile, repaired routes, viewer markup, old-token rejection, logout and
post-logout protection. A gated health request completes after direct-Puma TERM;
analytics shutdown completes before process reap. This is not Render Rackup or
production-environment acceptance, nor actual provider OAuth/browser media testing.

Transport suite extended to 19 checks with explicit in-flight response drain.
Both suites pass; fixture-account cleanup independently verified (zero matching
rows). Nonlocal DB guard rejects before app boot. Frontend 148 pass; Ruby syntax
and diff checks pass. Full backend's latest run remains the preceding Puma batch
(1,304 / zero failures / seven pending); not rerun for these test/docs-only changes.
See [acceptance detail](PUMA_7_ACCEPTANCE.md). No production/start-command/config
changes, commit/push/deploy or score increase. Browser/physical-device/accessibility
and real content review remain open. Local disposable Redis stopped after tests.

### Puma security remediation — 2026-10-17, local validation

Puma upgraded 6.6.1→7.2.1 with matching `~>7.2.1` constraint; native extension
loads on isolated Ruby 3.2.1. Config hook renamed to `before_worker_boot`; cluster
behavior not accepted. Fresh standalone advisory scan against fa229525 reports
**zero known vulnerabilities, exit 0**. No advisory ignores or relaxed gates.

Added standalone `tests/puma_http_test.rb` and CI step: **17 passing** checks
using real subprocesses/loopback sockets for Rackup and repository Puma config,
cookie/CSRF/body continuity over persistent HTTP, malformed Content-Length,
isolated PROXY v1 initial/repeated/oversized lines and shutdown. Full backend:
**1,304 examples, zero failures, seven pending, 77.43% coverage (5,257/6,789),
exit 0**, 71.3s. Frontend 148 passed; build/native diagnostics/bundle check and
diff/syntax checks passed. No actual provider OAuth or new full-browser acceptance.

Important discovery: Rackup fixture SIGTERM does not gracefully shut down through
its handler; SIGINT does. Direct Puma CLI logs graceful stop on TERM, then normally
re-raises the signal. Tests reflect those distinct contracts, not a hidden success
claim. Render still uses Rackup; platform TERM/in-flight request drain and actual
app staging acceptance remain deployment blockers. See [Puma acceptance](PUMA_7_ACCEPTANCE.md).
Tests use fixture Rack apps, not actual config.ru, to avoid dotenv/provider/startup
job side effects. Hosted Linux CI remains unrun locally. No commit/push/deploy,
start-command changes, production mutations or feed enablement. Score unchanged.

### Product roadmap phase 1 — 2026-10-17, local validation

Started the [66→90 roadmap](PRODUCT_IMPROVEMENT_ROADMAP.md); no score increase
claimed. Authenticated `/saved` now redirects to implemented `/profile` favorites;
unsupported `/taste-evolution` returns an explicit 410 with useful alternatives,
not a missing-service exception or fabricated insights. Six new route examples
cover browser/JSON authentication, exact favorites continuity and retirement state.
Replaced obsolete taste template; corrected README's stale Render build claim.
Added private baseline worksheet for 100 visible selections, double review,
5–8 user tasks and three ordinary supply cycles; no observations fabricated.

Scoped isolated dependency updates: ActiveSupport 7.2.4, Faraday 2.14.4,
HTTParty 0.24.3, JSON 2.21.2, JWT 3.3.0, OAuth2 2.0.25 plus required transitive
changes; separate development-only SQLite update to 2.10.0. Gemfile constraints
unchanged. SQLite native in-memory round trip passed. Final backend run against
local test PostgreSQL and disposable Redis 16379: **1,304 examples, zero failures,
seven pending, 77.36% coverage (5,252/6,789), exit 0**, 70.3s. Frontend 148 passed;
Vite build, isolated native diagnostics, CSRF contract, syntax, documentation links
and diff checks passed. Seven pending tests predate this slice.

Fresh standalone Ruby audit still exits 1 for two Puma 6.6.1 PROXY protocol
advisories only. Security gate remains blocked; no ignores or bypass. Major server
upgrade/boot/shutdown/HTTP acceptance is next. No real provider OAuth, fresh browser
acceptance, hosted Linux CI, credential rotation, live content research, commit,
push, deployment or feed flag enablement performed. Existing earlier mobile-swipe
changes retained. Temporary reports under `/tmp/meme-roadmap-*` are local evidence,
not durable production metrics. Scores remain 66/100 pending outcome validation.

### ACK concurrency investigation: real middleware reproduction

Uncommitted telemetry review: date buckets now explicitly UTC to avoid cross-host
timezone splits. Tests cover UTC/local midnight difference and corrupt numeric
counter reporting unavailable, not zero. Initial cached test-date helper assertion
fixed; final full backend: 1,282 examples, zero failures, seven pending, 76.73%
coverage, exit 0. Production untouched; no commit/deploy/enablement this pass.

Telemetry-inclusive local benchmark passed four sequential passes in on/off/off/on
order using temporary /tmp/meme-ack-telemetry-latency.mjs. Only disposable Redis
19379 is cleared between passes; dedicated local DB and fixture HTTP wrapper,
production untouched. Each pass: ten warmups plus 100 measured issuance/ACK/retry
cycles. Redis counters independently asserted 110 recorded ACKs and 110 duplicates;
on passes 110 external + one initial legacy issuance, off passes 111 legacy.
Counts verified directly in Redis, not via HTTP admin endpoint (endpoint access
and response covered in backend tests). Enabled p95 ms ranges: issue 4.08–5.22,
ACK 4.41–5.17, retry 3.21–4.34; disabled ranges 4.29–4.53, 4.22–4.46,
2.97–3.69 respectively. External key memory 6,275 bytes per enabled fixture binding
(excludes telemetry/session/global overhead). Raw results:
/tmp/meme-ack-telemetry-latency.log. No pre/post telemetry causal overhead claim:
earlier run differs in cache/order/time; no load or deployed network simulation.
Temporary services stopped. Representative deployed budget remains unapproved.

Local uncommitted aggregate telemetry integrated: fixed event labels, daily Redis
hash/two-day retention, transactional increment+expiry, no credential/content/user
labels. Shared issuance and ACK dispatch record outcomes; admin-only no-store
endpoint /api/admin/legacy-impression-metrics returns available/counts or 503/null.
Concurrent counter, failure/empty distinction, admin access and route event tests
pass. Initial cleanup-stub failure fixed. Full backend rerun: 1,280 examples,
zero failures, seven pending, 76.70% coverage, exit 0. Redis outages can lose writes;
pre-handler failures excluded; no latency dashboard. Added per-outcome Redis write
requires new overhead measurement before rollout; previous local timings predate
telemetry. No production changes, deployment, commit or flag enablement.

Local uncommitted diagnostics hardening: failed external persistence warns with
storage:external only; ACK DB failures log exception class rather than raw message
that could contain database values. Route tests assert warning shape and simulate
a sensitive exception message while requiring only PG::Error in ACK error context.
Full backend rerun: 1,273 examples, zero failures, seven pending, 76.59% coverage,
exit 0. These are failure diagnostics, not aggregate success/error denominators or
latency metrics; observability rollout blocker remains. Production untouched.

Current release status: runtime repair committed as 650a4a7, production deployment
operator-reported, fresh deployed Ruby process confirmed flag false. Later local
Chrome evidence and this documentation are uncommitted. Local browser smoke, tab
fetches, login/logout, single-process rollback, transport/lost-response retries and
preserving Redis restart have passed with the limitations recorded below. Local
latency sample is not a production budget. Contract current-status table updated;
proposed operational thresholds are explicitly unapproved. Global YAML flag has
no built-in cohort rollout, and aggregate nil-ID/ACK observability is incomplete.
Production enablement remains blocked pending scope, observability and budget
agreement. No new runtime changes, production requests or enablement this pass.

Local operational sample completed (temporary script /tmp/meme-ack-latency.mjs,
results /tmp/meme-ack-latency.log): isolated fixture HTTP app and dedicated local
DB/Redis, sequential loopback requests, flag off then on. Each pass discards ten
warm-up cycles and measures 100 issue/ACK/retry cycles, asserting first ACK
recorded:true and retry recorded:false. Off p50/p95 ms: issuance 4.02/8.00,
ACK 4.08/7.50, retry 2.66/3.94. On p50/p95 ms: issuance 3.25/3.95,
ACK 3.48/4.90, retry 2.73/3.40. Enabled external store has two keys using
6,275 bytes total via Redis MEMORY USAGE after capacity saturation. This excludes
session keys, allocator/global overhead, other bindings and worst-case metadata.
Single sequential run with off first/on second has warm-cache/order bias; do not
claim production speedup, load capacity or approved operational budget. Production
untouched; local Redis stopped afterward. Operational thresholds still require
operator agreement and representative deployment measurements.

Actual isolated Redis stop/restart browser check passed with important limitation:
stable-binding external ID selected via browser fetch, disposable Redis shutdown
SAVE, browser ACK returns HTTP 500 and DB impression count for that ID remains 0.
Redis restarted from local snapshot (sessions and credentials preserved); after
32 seconds for availability cache expiry, explicit browser retry returns
200/recorded:true, next retry recorded:false, one impression total. Total Redis
outage can fail at session middleware with 500 rather than route-specific 503.
This is manual retry after recovery, not guaranteed automatic recovery after the
frontend retry budget; Redis data loss is not covered. Production untouched.
Temporary services stopped; operational latency/resource budgets remain unmeasured.

Local Chrome lost-response-after-commit acceptance passed: stable-binding external
credential, actual visible-dwell ACK, DevTools interception at RESPONSE stage.
First server response is 200/recorded:true and a separate local DB query confirms
the impression committed BEFORE response is failed as ConnectionReset. Actual
frontend automatically retries same ID; second server response is
200/recorded:false, exactly one DB impression remains, further explicit retry also
deduplicates. Artificial browser response loss, not infrastructure outage. Local
fixtures/isolated DB and Redis only; production/default flag untouched. Temporary
services stopped. Operational budgets and live Redis outage recovery remain open.

Local Chrome transport-recovery check passed: reload under persisted binding for
external issuance, intercept first visible-dwell ACK with DevTools Fetch and fail
it as InternetDisconnected, then allow the actual frontend's automatic retry.
Exactly two intercepted attempts carry the same ID; local DB contains exactly one
impression for that ID, and a subsequent explicit browser retry returns
200/recorded:false. Real module/dwell/retry path, artificial transport failure;
not a Redis outage or lost-response-after-commit simulation. Production untouched.
Live infrastructure outage recovery and operational budgets remain open. Temporary
services stopped; no runtime code change, committed issuance flag still false.

Local Chrome gallery smoke passed with two local-image slides in the isolated
fixture wrapper. Both active slides decode; gallery Next/Previous changes active
slide while preserving the page's impression ID. After visible dwell and slide
changes, explicit same-ID ACK returns 200/recorded:false (already recorded by
browser observation). This initial-page gallery check does not exercise AJAX
gallery replacement or prove external-store issuance: a fresh unbound page may
use legacy issuance. Prior stable-binding route tests cover external issuance.
Browser outage recovery and operational budgets remain open. Production/default
flag untouched; temporary services stopped. No runtime code changes.

Local Chrome rollback acceptance passed: issue an external credential in isolated
fixture app, stop/restart that app with local-only issuance override false while
preserving its Redis session and session secret, then ACK old credential (200,
recorded:true), retry (recorded:false), select/ACK new legacy credential (200,
recorded:true). Requests originate in existing browser tab through real CSRF fetch
wrapper. Local override is temporary harness code, not a new runtime env flag.
Production and committed config untouched. Single local process restart only;
multi-process rollout/drain remains untested. Galleries, browser outage recovery
and operational budgets still NOT RUN. Temporary services stopped afterward.

Local Chrome follow-up (same isolated fixture Rack wrapper/database/Redis): two
tabs with shared session concurrently fetch random.json; distinct non-nil IDs
both ACK recorded:true, then both retry recorded:false. ACK requests are explicit
browser fetch calls, not independent dwell observations in each tab, and this
schedule is not a deterministic middleware barrier. Actual browser login form
submission redirects to profile; old anonymous ID rejects after login. A new
authenticated ID succeeds, native CSRF-protected POST logout completes, that ID
rejects afterward and a fresh anonymous ID succeeds. All assertions passed via
Chrome DevTools Protocol. Local-only fixture account; no production changes.
Galleries, browser outage/rollback and operational budgets remain NOT RUN.
Temporary services stopped; committed issuance flag remains false.

Local browser acceptance (partial, after 650a4a7): actual headless Google Chrome
against loopback Rack/Puma with real Redis sessions, dedicated local database
meme_explorer_ack_browser_test and disposable Redis port 19379. Temporary wrapper
enables repair only in that process, supplies local image fixtures, skips dotenv
loading and blocks outbound Ruby HTTP; Chrome blocks external HTTP(S). Committed
flag and production remain unchanged. Fixture image decoded; after scrolling media
into view, visible dwell plus Next/Previous produced two HTTP 200 ACK responses
and exactly two local DB impressions/views. Screenshot: /tmp/meme-ack-browser.png.
No ACK during initial viewport sample. This is a limited browser smoke check,
not full acceptance: multi-tab, galleries, browser auth, outages/rollback and
operational budgets remain NOT RUN. Temporary services stopped afterward.

**Historical pre-browser status (superseded by release status above):** local uncommitted
default-off repair; latest backend 1,273 examples / zero failures / seven pending,
76.61% coverage, exit 0; frontend 143 passing. Eight real-route overlap schedules,
both-ID retries, independent-process store capacity, real middleware login/logout,
mixed rollback credentials, failure/corruption handling and authenticated counters
have local coverage. Interactive staging browser and operational acceptance are
NOT complete. See [current acceptance table](LEGACY_ACK_REPAIR_CONTRACT.md#current-acceptance-status)
for precise limitations. No commit, push, deployment or enablement authorized.

The paragraphs below preserve chronological investigation checkpoints (newest
first). Earlier counts and “remaining” notes are historical, not current blockers.

Authenticated external-ACK accounting acceptance passes: two issued IDs, each
retried, produce exactly two impressions/views and two user/session-attributed view
activity rows; exposure increases exactly twice above selection-time baseline.
Selection-time behavior remains unchanged. Full backend 1,273 examples, zero
failures, seven pending, 76.61% coverage, exit 0. Flag off; staging acceptance open.

Actual shipped configuration default-off coverage now passes without flag stubs:
legacy issuance/ACK works and external issue is not called. Sequential first-request
coverage verifies legacy issuance before binding stabilization, then external
issuance with both IDs accepted. Concurrent unbound initialization remains excluded.
Full backend: 1,272 examples, zero failures, seven pending, 76.61% coverage, exit 0.
Staging browser/operational acceptance remains outstanding; flag remains false.

Expiry/capacity corruption follow-up: issuance rejects mismatched expiry/payload
counts before mutation (including partial key loss). New tests verify expired
payload pruning and earliest-deadline/ID-tie eviction without renewing survivors.
Not a full audit of equal-cardinality corruption. Full backend 1,270 examples,
zero failures, seven pending, 76.55% coverage, exit 0. Flag off; staging still open.

Store process-boundary acceptance passes four fresh interpreters with independent
Redis clients and synchronized issuance (32 issued, exactly 20 retained and
readable). Real store/Lua, test transport adapter; not multi-process HTTP/pool
coverage. Full backend: 1,268 examples, zero failures, seven pending, 76.58%
coverage, exit 0. Interactive staging/operational acceptance remains open. Flag off.

Repeated overlap coverage now passes both deterministic response/session-save
orders twice per flag state: eight real middleware examples, enabled two-ACK
success with both retries idempotent and disabled legacy loss retained. Full
backend 1,267 examples, zero failures, seven pending, 76.58% coverage, exit 0.
Process-boundary/staging browser evidence remains open. Flag off; no deployment.

Overlap regression strengthened to retry BOTH externally issued IDs (previously
only one successful ID was retried). First ACKs must report recorded:true; every
retry recorded:false; enabled total remains two impressions/views. Full backend
rerun: 1,261 examples, zero failures, seven pending, 76.55% coverage, exit 0;
frontend 143 passing. Still no repeated/process-boundary or staging browser claim.
Flag off; no commit/push/deployment.

Nil-ID frontend regression now tests actual navigation module with observer/DOM
doubles: previous observation stops, media stays unchanged, no ACK or qualification
is created. Frontend 143 passing. No runtime frontend change. Repair contract now
includes an unexecuted staging checklist and per-process flag-disable/drain
procedure. Staging browser evidence and operational budgets remain outstanding;
no staging or production enablement performed. Latest backend remains 1,261
examples, zero failures, seven pending (not rerun for frontend/docs-only changes).

Real Redis middleware authentication acceptance now passes actual password login,
cookie renewal, ACK-binding replacement and POST logout. Pre-login IDs reject
after login, authenticated IDs reject after logout, and newly bound anonymous IDs
work. Full backend: 1,261 examples, zero failures, seven pending, 76.58% coverage,
exit 0. Initial harness failure handling multiple Set-Cookie headers corrected.
Supersedes older middleware-auth gap notes below; browser/staging acceptance still
open. No application behavior changed in this follow-up. Flag remains off.

Corruption/provenance acceptance added: malformed/oversized context and metadata
fail closed, duplicate issuance cannot renew or replace context, and conflicting
DB URL/session provenance returns unavailable without view mutation. Full backend
1,260 examples, zero failures, seven pending, 76.60% coverage, exit 0; frontend
142 passing. Real middleware login/logout rotation and staging/browser acceptance
remain open. Flag off; no commit, deployment or enablement.

Transition policy explicitly revised with user approval: independent 20-entry
legacy-session and external-store caps (up to 40 combined), no credential renewal.
New route acceptance fills both stores, disables issuance, verifies legacy eviction
and unchanged surviving legacy deadlines, then ACKs all 40 retained credentials
twice with exactly 40 impressions/views. Full isolated backend run: 1,256 examples,
zero failures, seven pending, 76.48% coverage, exit 0. This supersedes earlier
single-capacity blocker notes below. Real auth/browser journeys and remaining
corruption/provenance coverage still gate enablement; flag remains false.

Repair failure/auth route acceptance now passes six additional cases: no ID on
failed persistence, lookup outage/retry, DB rollback/retry, changed user binding,
replaced session and expired external entry. Full isolated run: 1,255 examples,
zero failures, seven pending; 76.53% coverage, exit 0. Capacity remains unresolved:
waiting for a session map to empty is insufficient with ongoing issuance and
flag rollback. Flag stays false; no rollout, commit or deployment performed.

Initial local runtime repair is now integrated, flag feed.legacy_pending_store
default false. Shared issuance stores new IDs outside whole-session snapshots for
existing valid ACK bindings; lookup remains compatible with issuance disabled.
Real Redis-session route test passes both ACKs with repair enabled, retains the
legacy lost-update reproduction when off, rejects foreign sessions and deduplicates
retry. Store tests cover user/session isolation, expiry, concurrent external-store
cap and malformed/wrong-type/unavailable failure. Full run: 1,249 examples, zero
failures, seven pending, 76.53% coverage, exit 0. Uncommitted/undeployed.
Not rollout-ready: combined legacy/external capacity, route outages, auth rotation,
nil-ID client handling and staging acceptance remain open; see repair contract.
Selection-time history and v2 integration remain unchanged.

Repair design now documented in [legacy ACK repair contract](LEGACY_ACK_REPAIR_CONTRACT.md):
default-off coordinated issuance/storage/dispatch slice, no v2 history-policy
change or whole-auth-session merging. Real-route reproduction additionally proves
foreign-session rejection and surviving-ID idempotent retry without extra views.
Latest full isolated run: 1,245 examples, zero failures, seven pending, 76.36%
coverage, exit 0. This remains reproduction/design, not a runtime repair.

Follow-up now runs actual random.json and api/impressions routes inside the real
Redis session middleware. A seeded existing guest session has stable feed/ACK
binding and CSRF state. Two feed responses are held before either session commit;
both issue distinct IDs, but later ACKs produce one 200 and one 404 and exactly
one DB impression/view. This confirms a real route-level legitimate-ACK loss for
the forced overlap schedule. No client-content fallback or security bypass used.
Full run: 1,245 examples, zero failures, seven pending, 76.42% coverage, exit 0.
The test intentionally expects today's bug; no runtime fix/migration is enabled.

Local integration test now overlaps two requests through the actual
Rack::Session::Redis middleware against isolated Redis. A queue barrier ensures
both load the same existing session before either persists its copied pending
map. Both responses contain their own issued entry, but a subsequent request
reads only one entry: last whole-session write overwrites the other addition.
The test uses a small fixture endpoint with issue_impression's read/copy/write
shape; it does not yet reproduce concurrent full feed routes or a real ACK POST.
Its one-entry assertion documents today's bug, not desired acceptance behavior.

Full isolated validation: 1,244 backend examples, zero failures, seven pending,
76.39% coverage, exit 0. Unique session namespace and 60-second expiry bound test
state; disposable Redis stopped. No production calls, route changes, authorization
changes or migration enablement. Test and evidence update remain uncommitted.

Next bounded design decision: retain server-issued pending credentials outside
whole-session snapshots with explicit session/auth binding, original expiry,
capacity limits and failure semantics, or use the coordinated default-off v2
integration. Do not repair by trusting client URL/title/user fields, globally
merging authentication sessions, renewing expired credentials, or removing ACK
authorization. Require real-route concurrency and wrong-session/retry tests before
claiming the failure fixed. Prefetch selection-time history remains a separate
coordinated migration problem.

Roadmap: [remaining-work execution](REMAINING_WORK_EXECUTION_ROADMAP.md).
Stage 0 is in progress; stage 1 collection is prepared, not completed.
UX candidate `72a8fe4` and metadata follow-up `120b70a` were committed and
operator-reported deployed, followed by measured timing/pipeline slices through
`10795b4`. Public markers support specific features, not independently verified
full web/worker SHAs. Current documentation updates remain local/uncommitted.

Use this ledger for results, not inferred completion. For each new observation
record UTC time, environment, actual revision (or unknown), browser/OS, method,
result, limitation and next action. Never include credentials or account emails.

## Stage 0: acceptance record

| Check | Evidence/result | Status / next action |
| --- | --- | --- |
| Candidate frontend served | Public HTML markers; bundle, viewer CSS and keyboard JS byte-matched `72a8fe4` | Observed; full server SHA unknown |
| Web/worker revision and environment alignment | No operator SHA/config attestation recorded | Operator verifies privately |
| Local build and test gates | Latest full backend run: 1,234 examples, 0 failures, 7 pending; 76.33% coverage; latest frontend 141 tests/build passed | Local evidence, not hosted CI |
| Guest Next/Previous and help focus | Real local Rack app in Chrome; exact return image and focus restoration passed | Local scripted acceptance |
| Save -> email login/signup | Actual local forms and full-page exact-meme redirects passed | Local scripted acceptance; disposable users removed |
| Narrow layout | Chrome fixtures at 320/375px: sticky navigation and menu positioning passed | Fixture, not physical-device acceptance |
| Enlarged text | Doubled root font fixture exposed/fixed Previous overflow | True browser zoom still pending |
| Dark navigation | Scoped Chrome computed colors passed | Full-app theme check pending |
| Screen reader | No manual evidence | Pending operator/manual review |
| Real Reddit OAuth | Mocked/server tests only | Pending approved callback and operator-owned account |
| Exact share recipient preview | No current platform-preview evidence recorded here | Pending operator preview check |
| Credential rotation / hosted CI | Not verified | Operator confirms privately / records exact-SHA CI result |

Do not pass stage 0 while a critical wrong-content, authentication, false-save,
hidden-focus or inaccessible-navigation failure remains. See
[release checklist](UX_RELEASE_CANDIDATE.md) for task details and rollback rules.

## Stage 1A: three ordinary supply cycles

### Configuration repair and recovery checkpoint

Operator configuration edits initially left an incomplete REDIS_URL and caused
startup URI parsing failure. Do not copy credential-bearing exceptions into this
ledger. Operator was instructed to restore the complete intended Internal URL
and rotate exposed credentials privately; credential rotation remains unverified.

Subsequent operator read-back: 3,660 unique payload URLs/records, 1,659,064 bytes,
zero structural invalid/duplicate records, refresh age 49 seconds; age buckets
442 under one day, 3,125 one-to-seven days, 93 over seven days, zero unknown.
Lease TTL 7,178 seconds is consistent with recent acquisition, not proof of job
progress. Sample UTC/SHA were not supplied; this is not a matched cycle outcome.

After the repair, one public random.json response returned 200, no-store/private,
expected identity fields and integer likes. Timings (ms): route_total 38.50,
selection_pipeline 31.69, pool_lookup 25.71, selection_work 5.28,
response_prepare 4.61, history_write 0.73, likes_lookup 3.50/database_fallback,
impression_issue 1.99, serialization 0.02. Earlier warm PINGs were roughly 57ms;
post-repair PINGs and exact routing/configuration are not independently verified.
This is consistent with improved Redis connectivity, not a controlled benchmark,
field p95, or proof of cause. Pause speculative cache/telemetry optimization.

Next acceptance: verify worker uses the intended complete connection privately;
observe ordinary maintenance completion and match its logs to a read-back; confirm
credential rotation; resume content/user audits and manual accessibility checks.

One historical production completion is known: 990 fetched/validated candidates,
981 unique candidates, 162 previous unique URLs, 885 candidate new unique URLs,
1,047 published records, publication succeeded, 278.385 seconds job duration.
This is not the required three-cycle observation and is not current inventory.

### Operator-provided inventory read-back

Sample UTC time and deployed SHA were not supplied. The read-only diagnostic
reported 3,640 metadata records and 3,640 unique payload URLs, zero invalid records
under its structural checks, zero duplicate URLs, and refresh age 26 seconds.
Source-age buckets: 441 under one day (12.1%), 3,124 one-to-seven days (85.8%),
75 over seven days (2.1%), zero unknown. No cooldown or maintenance lease existed
at sampling time. Random list count matched 3,640; derived pools overlap and must
not be added together. Fresh-list membership (2,013) is not the under-one-day
source-age count. The report is non-atomic and does not establish media health,
visual uniqueness, humor quality or scheduler consistency. Compared with the
earlier 1,047-record publication, the sampled count is 2,593 higher; this is not
a measured single-cycle yield. Await matching maintenance logs before assigning
this read-back to one of the three observed ordinary cycles.

### Operator collection procedure

1. In the intended worker's logs, observe the next three **ordinary scheduled**
   maintenance attempts. Do not enqueue extra work or run direct maintenance.
2. For each attempt, retain sanitized Starting, Inventory batch outcome,
   Maintenance finished/Success or skip/error lines, and terminal job duration.
3. After each completed attempt, run the existing read-only diagnostic in the
   matching environment:

   ```sh
   bundle exec ruby scripts/check_pool_inventory.rb --content-summary
   ```

   This opt-in reads bounded inventory payload and emits aggregates. It does not
   validate media availability, humor or visual uniqueness. Record its UTC sample
   time and non-atomic nature. Do not share connection URLs or payloads.
4. Record cumulative provider counters as snapshots per fetcher, never sum them.
   If a cycle skips, record why; do not bypass the lease/cooldown to force success.
5. If worker logs stop, use the earlier read-only Sidekiq process/queue check.
   A lease alone does not prove an active job. Preserve inventory and evidence.

| Cycle | UTC / worker SHA | Outcome and duration | Fetched / validated / candidate new unique | Published / read-back count | Source-age buckets / invalid / duplicates | Skip/error/provider explanation |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Completed 2026-10-17 08:54:26 UTC; SHA unknown; enqueue origin not shown | Published, job done; 265.746s | 1,155 / 1,155; 1,134 unique; 0 candidate new unique | 3,660 stored; matching post-job read-back pending | Pending | 212 requests, 209 successful listings, 1 auth failure, 2 other HTTP failures, no 429s; cumulative snapshot |
| 2 | Started 2026-10-17 08:55:00 UTC via scheduler; SHA unknown | Began tier 1, then deployment banner; terminal outcome unknown | Nominal request 1,340; results pending | Pending | Pending | Deployment may interrupt work; no completion inferred |
| 3 | Pending | Pending | Pending | Pending | Pending | Pending |

Exit: all three attempts accounted for, publication/read-back distinguished from
fetch success, and unexplained losses/no-ops assigned a concrete investigation.

Cycle 1 basic filtering rejected zero candidates; optional pipeline was disabled.
All 1,134 unique fetched URLs overlapped existing inventory: successful fetching
and republishing did not replenish unseen supply. No humor/moderation quality
acceptance is implied by “passed quality filter.” Do not sum successive provider
snapshots or attribute zero yield solely to the three HTTP failures.

Repository supply-policy review: OAuth/static listings both use weekly top;
pagination restarts with no cursor each fetch and is capped at two pages per
community. Maintenance samples up to 25 unique configured communities per tier.
This bounds work but can repeatedly cover existing URLs. One zero-yield cycle
supports overlap diagnosis, not a claim that the whole provider is exhausted.
A duplicate-only regression now verifies zero new unique yield, successful
republishing distinguished from growth, and no retirement of retained inventory.

Proposed experiment, NOT enabled: after the next two ordinary attempts are
accounted for and source/content review passes, allocate a small explicit share
(initial candidate: 10%) of the existing listing-request budget to newest posts,
replacing rather than adding requests. Keep provider/page caps, throttle, auth,
429 early-stop, cooldown, media/structural checks, publication conflict handling
and source timestamps unchanged. No extra providers or subreddit expansion.
Use a default-off configuration with weekly-top-only rollback. Before enabling,
test OAuth/static URL construction, page cursors, invalid configuration, request
budget, rate-limit stop and original age preservation; review newest-post media
availability/readability since recency is not quality. Compare candidate-new
unique yield and retained publication plus source/topic balance and content audit
results over a pre-agreed observation window. Stop on quality, request-budget,
provider-error or publication regressions. Operator approval is required to roll
out; do not widen the budget to compensate for low yield.

At 08:54:49 UTC the worker reported RTTs 56,912/60,145/56,760/60,573/56,733
microseconds (~57–61ms). Worker connectivity exists, but low-latency routing is
not confirmed; web improvement does not establish worker environment parity.
The 08:55 attempt requests more inventory normally but has no terminal result in
the excerpt. Observe shutdown/new-worker logs before interpreting its lease or
re-enqueueing anything. Private worker URL/region/credential checks remain open.

## Stage 1B: 100-selection content audit

### First operator observations and clipping fix

Follow-up screenshot confirms bottom-caption clipping on Chrome/Mac for a supplied
exact single-image permalink. Source is 500x524 with a complete bottom caption.
Static reproduction of that page with current styles showed full aspect at desktop
and 375/744px frames; exact user-browser cause remains unverified. Public viewer
CSS bytes still match `8da55b8`. No gallery fix is implied. Found a separate cache
invalidation gap: viewer CSS used an unversioned URL while the bundle is hashed.
Local follow-up fingerprints viewer CSS bytes in its stylesheet URL using the
existing bundle-helper pattern. This makes new CSS URLs change with content;
does not prove stale CSS caused the screenshot or resolve it without retest.
142 frontend tests and 1,243 backend examples passed, zero failures, seven pending,
76.39% coverage, exit 0; whitespace passed. Uncommitted/undeployed. Next: approved
rollout then inspect original Chrome rendered styles or retest with cache disabled
if clipping persists; do not mark the original defect fixed on fixture evidence.

User reports four consecutive desktop/returning observations: all loaded;
items 1–3 were reported readable; item 4 was clipped with no scroll recovery.
Items 2–4 did not repeat earlier artwork in the batch. URL repetition/source age
were not verified. Item 3 was subjectively unfunny/confusing; item 4 worthwhile
despite clipping. These are user-reported observations, not independent image
reviews. Do not generalize humor quality or repetition from four items.

Local Chrome reproduction found AJAX .meme-image-container inherited a square,
overflow-hidden wrapper and absolutely positioned image from legacy CLS CSS.
Natural-height viewer overrides left a 1,800px image inside a 600px clipping
wrapper. Scoped fix restores normal-flow image positioning and natural wrapper
height/overflow. After fix desktop fixture image/wrapper heights both 1,800px;
fluid 320/375px frame fixtures both expanded wrapper to full rendered image
height, no clipping. Original item 4 was not available to reproduce directly;
gallery/video and already-cropped source files are not established fixed.

142 frontend tests passed including the new wrapper regression; whitespace
checks passed. No JS/build artifact change or backend code change. Local and
uncommitted; production and the original reported meme still require retesting.

Collect ordinary browsing with consent where appropriate, not a scripted fetch
storm. Keep content examples private if needed; do not export session histories.
Use local audit row numbers, not user identifiers. A requested/prefetched meme
must not be counted as visibly viewed.

Record per selection: audit number, guest/returning condition, device class,
visible yes/no, readable yes/no, media available yes/no, source age known/unknown,
age bucket, repeated URL yes/no, repeated artwork yes/no, and broad topic/source
group. Do not assume different URLs mean different artwork or unseen means fresh.

Report aggregates with denominators: visible/requested, readable/visible,
available/visible, known-age/visible, repeated-URL/visible, repeated-artwork/visible,
and source/topic concentration. Keep subjective relevance/humor feedback separate.

Status: **0/100 audit selections recorded in this ledger**. Public startup smoke
checks are not a representative content audit.

## Stage 1C: 5–8 observed users

Recruit with consent; no account email exports. Use anonymous participant labels
and operator-owned staging accounts where account creation is not the task.

Tasks, without coaching:

1. Find a meme worth keeping; describe why.
2. Advance, then recover the previous meme.
3. Save, authenticate if needed, and confirm the same meme is retained.
4. Recover it from favorites and share an exact link.
5. Find a different topic using Search.

Record task success, time/hesitation, errors, device, assistance and a short
consented quote. Distinguish study task completion from production retention.
Stop for privacy/accessibility distress or wrong-account/wrong-content actions.

Status: **0 participants observed in this ledger**; automated browser scripts
are not user research.

## Next intervention decision

### Selection pipeline follow-up

Operator inventory sample at 2026-10-17 08:34:16 UTC: 3,656 records/unique URLs,
1,657,625 payload bytes (~1.66 MB decimal), zero structurally invalid records or
duplicate URLs, refresh age 44 seconds. Source age: 439 under one day, 3,126
one-to-seven days, 91 over seven days, zero unknown. No maintenance lease or
cooldown existed at sampling time. Derived pools overlap. This is a non-atomic
inventory read-back, not a matched maintenance-cycle outcome or media audit.
The actual payload is similar in byte size to the earlier synthetic parse fixture,
but that does not establish production decoding time or network throughput.
Next evidence: privately verify Redis region/internal routing and resource metrics;
compare a few sequential PING RTTs from the same web shell without printing URLs.
Do not add a stale process cache or clear inventory on this evidence alone.

After operator-reported `c5cbd6f` rollout, one public response returned route_total
782.81ms, selection_pipeline 603.09ms, pool_lookup 426.04ms, selection_work
119.15ms, history_write 58.87ms and likes_lookup 117.57ms/database_fallback.
HTTP 200, no-store/private and expected fields passed. Parent-minus-children was
about 58ms versus the earlier roughly 173ms, consistent with fewer telemetry
flushes but not a controlled causal comparison. Nested stage boundaries changed.

Local diagnostic follow-up adds payload_bytes to successful opt-in content_summary
using the already-read bounded raw string's bytesize. No extra Redis command,
default metadata change or content identifiers. After approval/deployment, obtain
one operator read-back with --content-summary to pair payload size and record
count with pool latency. Inspect Redis region/internal routing and resource
metrics privately; do not infer network throughput from payload bytes alone.

Local telemetry-batching implementation: random.json opts into a bounded
fiber-local batch around the existing total measurement. Nested completed stage
samples retain their RPUSH/LTRIM ordering and flush in one pipeline on normal
completion or exception unwinding; standalone callers still record immediately.
At 64 pending samples a chunk flush bounds memory. Telemetry errors remain soft
and batch state clears before final flush. No cache/history/selection policy
change. Stage timings no longer include the former nested telemetry network waits,
so historical benchmark distributions straddle a measurement-boundary change.
selection_pipeline/route_total still include the final flush. Validate runtime
benefit after approval; the local experiment is not production acceptance.
Validation: 1,232 backend examples, zero failures, seven pending, 76.28% coverage,
gates passed, exit 0. Includes nested single-flush ordering, result preservation,
exception cleanup, soft telemetry failure, bounded buffering and simultaneous
thread isolation. No frontend changes; disposable test Redis stopped.
Route-level acceptance additionally confirms one flush containing exactly
pool_manager_lookup, pool_lookup, selection and total, retained Redis samples,
unchanged response state and cleared batch storage. Latest full isolated run:
1,233 examples, zero failures, seven pending; 76.36% coverage, exit 0. Still local,
uncommitted and undeployed.

Local decoding experiment: 5,000 synthetic records, 1,707,781 JSON bytes, three
warm-ups and 20 parses on isolated project Ruby produced min/median/max
2.07/2.62/4.94ms. Excludes real payload shape, network transfer, Redis, concurrent
load and production hardware. Does not establish production parsing cost, but
does not support blaming parsing alone for the observed 450.36ms pool lookup.

Static populated-route trace identifies four separate benchmark recording
pipeline flushes: pool_manager_lookup, pool_lookup, selection and total. Each
already batches its RPUSH/LTRIM pair but flushes independently. Candidate next
experiment: request-scoped batched recording with preserved stage samples,
standalone behavior, nested/exception cleanup and thread isolation. Do not add
an inventory process cache or remove telemetry on this evidence alone.

After operator-reported `4010046` deployment, one public response reported
route_total 923.26ms, selection_pipeline 743.36ms, pool_lookup 450.36ms and
selection_work 119.73ms. The roughly 173ms parent/children difference includes
outer benchmark recording and surrounding overhead; it is not pure telemetry.
The populated pool manager path performs one RedisService.get('meme_pool'),
which decodes the full payload, then returns without expansion. The enclosing
pool helper also records pool_manager_lookup. No redundant pool read was found
to remove. A regression now enforces one populated-pool read and no request-time
fetcher/maintenance lock/batch fetch. No runtime change or process cache added;
payload transfer/decoding and nested telemetry remain investigation candidates.

After operator-reported `1838106` deployment, one response returned route_total
824.18ms, selection_pipeline 654.54ms, response_prepare 167.17ms, history_write
55.05ms and likes_lookup 111.62ms/database_fallback. All expected fields and 200/
no-store checks passed. Lower than earlier individual samples, not a controlled
causal comparison or percentile.

Local timing follow-up exposes pool_lookup and selection_work inside the existing
benchmark blocks, excluding each block's own subsequent benchmark recording call.
Pool lookup still includes nested pool-manager instrumentation; selection_work
includes selector history/preference I/O, not just CPU. Parent-minus-children
contains outer recording calls and surrounding overhead, not exclusively telemetry.
No additional Redis writes or selection-policy changes; timings overlap parents.

After operator-reported `9b0311a` deployment, one public response reported
route_total 965.95ms, selection_pipeline 778.80ms, response_prepare 182.86ms,
history_write 59.06ms, likes_lookup 123.31ms and database_fallback; HTTP 200 and
expected fields. Selection was roughly 81% of handler duration in this sample,
not a field percentile or algorithm-only CPU cost.

Local review found history retrieval prunes then reads in two sequential Redis
calls. Follow-up pipelines those commands in order and returns the resolved read
result. It changes neither history TTL/bounds nor selection-time commit policy;
it is not a transaction or ACK/session concurrency fix. Existing duplicate route
marking and benchmark telemetry remain unchanged. Expected benefit is one fewer
sequential network wait per history read, not a measured production speedup.

History-read pipeline validation: 1,226 backend examples, zero failures, seven
pending; 76.23% coverage, gates passed, exit 0. Ordered/resolved-result and
failure-path tests passed alongside existing real-Redis pruning, recency,
deduplication, capacity and expiry coverage. Disposable Redis stopped; syntax and
whitespace checks passed. Three-file slice remains local and uncommitted.

### Pipeline rollout and likes-cache follow-up

After operator-reported `28b8c6e` deployment, five sequential public random.json
requests in one guest cookie session, spaced two seconds apart, all returned 200,
expected identity fields and database_fallback. Sample ranges/medians (ms):

| Measurement | Min | Median | Max |
| --- | ---: | ---: | ---: |
| Client request elapsed | 1253.38 | 1394.64 | 1416.74 |
| response_prepare | 169.11 | 171.11 | 177.49 |
| history_write | 55.68 | 56.40 | 58.36 |
| likes_lookup | 112.31 | 112.98 | 120.08 |
| impression_issue | 1.92 | 2.47 | 9.21 |

No warm hit occurred, so cache-hit versus fallback latency is unmeasured. Requests
selected content and issued pending impressions but did not ACK visible views;
this is not an ordinary-user content audit or media-ready measurement. Client
elapsed includes transport/client overhead; unmeasured time cannot all be assigned
to application code. Investigate existing pool/selection measurements and
session/middleware/network costs before prioritizing another likes optimization.
Five observations do not establish field p95 or controlled before/after benefit.

Local follow-up adds route_total (handler entry through JSON serialization) and
selection_pipeline (the existing benchmark call, including its Redis recording).
They add monotonic clock reads only. route_total excludes before/after filters,
outer middleware/session persistence and transport. selection_pipeline includes
pool lookup, selection, nested instrumentation and their telemetry writes, not
just algorithm CPU. Parent and child durations overlap; never sum all stages.
Use these to locate the remaining gap before proposing another optimization.

Operator reports deploying `5dd473a`. One public response returned history_write
57.54ms and response_prepare 175.00ms, versus earlier single samples of 235.43ms
and 355.88ms; likes_lookup was 116.94ms. This is encouraging, not a controlled
comparison or percentile. HTTP 200, no-store/private and expected fields passed.

Likes lookup already uses a 300-second cache: GET, database fallback on miss,
SETEX for a successful result. Cold versus warm status was not measured in that
production response. Added real-Redis tests confirming successful zero and
nonzero values survive a second read without another DB query and retain expiry.
No runtime/cache policy change. Full isolated run: 1,221 examples, zero failures,
seven pending, 76.13% coverage, exit 0. Production cold/warm attribution remains
open; do not lengthen TTL or cache outage fallbacks to chase a single sample.

Local attribution follow-up adds X-Likes-Lookup on successful random.json:
cache_hit, database_fallback, unavailable, not_requested or unknown (allowlisted).
The helper records whether its existing fallback ran; no extra cache read/write
or database query is introduced. database_fallback includes a cache miss or Redis
unavailability and does not distinguish them. The value is request-instance state,
captured immediately after lookup, and contains no URL, key or account identifier.
Pair it with likes_lookup duration during ordinary browsing after approved rollout;
do not interpret a slow cache_hit alone as database latency.

Attribution acceptance: consecutive real-Redis route requests report database
fallback then cache hit; a likes DB failure keeps HTTP 200/zero fallback with
unavailable attribution; replacement helpers without diagnostic state report
unknown. Final isolated run: 1,224 examples, zero failures, seven pending,
76.20% coverage, exit 0. No frontend changes in this slice. Still uncommitted and
not deployed; no new production sample collected.

### Operator-reported follow-up rollout and timing sample

Operator subsequently reports deploying `f796705`. One fresh public response
contained all sub-stages: response_prepare 355.88ms, history_write 235.43ms,
media_detect 0.03ms, likes_lookup 119.80ms, impression_issue 2.46ms,
serialization 0.02ms; HTTP 200, no-store/private and expected identity fields.
This is one observation, not p50/p95 or a measured before/after comparison.

Local follow-up pipelines the four history-write commands in existing order,
preserving pruning, deduplication, bounds and TTL with no reply dependencies.
Pipelining reduces sequential network waits; it is not a transaction and does not
fix ACK/session races or change selection-time history semantics. No production
improvement is claimed until ordinary-session timings are compared after approval.

Pipeline follow-up validation: 1,219 backend examples, zero failures, seven pending;
76.18% coverage, gates passed, exit 0. Added ordered-command/failure tests and a
real-Redis regression that directly reads the sorted set after mark_seen, proving
write-time expired-score pruning and renewal of a short TTL without allowing the
read helper's pruning to mask errors. Existing deduplication and capacity tests
also passed. Disposable Redis stopped. Implementation remains uncommitted.

Operator reports merging/deploying `120b70a`. A public random.json request returned
200, no-store/private, expected response identity fields, and timings:
response_prepare 347.03ms, impression_issue 2.62ms, serialization 0.02ms. A fresh
HTML response showed the searchable community; an earlier request still returned
old markup. Exact deployed revision/transition cause were not independently
verified. One sample is not a percentile or stable bottleneck estimate.

Local follow-up adds history_write, media_detect and likes_lookup sub-stages
inside response_prepare. They overlap the parent duration and must not be added
to it. No extra network telemetry, history-policy or caching changes are included.

Interpretation after rollout: history_write measures the route's legacy history
write (currently four sequential Redis commands), media_detect measures local
type detection, and likes_lookup measures the cache/DB fallback helper. Large
history time suggests investigating Redis round trips; large likes time suggests
cache misses/DB/network work. These are hypotheses until sampled. Do not remove
history writes or change ACK semantics as a performance shortcut. A controlled
delayed-lookup regression verifies attribution to likes_lookup and its parent;
it is not a production benchmark.

### Local post-selection measurement slice

`/random.json` now has local, uncommitted Server-Timing stages: response_prepare
(history/session field preparation, response building and initial likes lookup),
impression_issue (pending state, engagement lookup and catalog registration), and
serialization. These use monotonic clocks and add no Redis telemetry writes.
The existing SelectionBenchmark total still means pool/selection work, not the
entire HTTP request. New headers exclude session middleware persistence, network
delivery and media-ready/render time. No production timings collected yet.
After approved rollout, collect a bounded ordinary-session sample in browser
Network tools, record sample size and stage p50/p95, and compare with full request
and media-ready timing. Do not infer a bottleneck or improvement before measuring.

Code review also identified duplicate like-count lookups in each random/similar
JSON response: response building fetched the count, then impression issuance
fetched it again. Local follow-up reuses that server-built count within the same
response, preserving fallback lookup for callers without a supplied count and
coercing the output to integer. This proves one fewer helper lookup per tested
JSON response, not a measured production latency improvement.

Review checkpoint: zero-count reuse and missing-count helper fallback are covered.
An initial new HTML-route expectation failed because that route separately calls
engagement lookup twice; the test was corrected to exercise the helper fallback
directly, not to claim homepage deduplication. Final isolated full rerun passed:
1,215 examples, zero failures, seven pending, 76.10% coverage, exit 0. No homepage
deduplication, ACK migration, fetch-policy or production-setting change is included.

### Bounded release grouping

- Metadata quick wins: searchable initial community, unseen-not-fresh wording,
  related template/frontend tests and rebuilt bundle.
- Measurement/lookup slice: aggregate post-selection Server-Timing and one
  server like-count lookup per random/similar JSON response, with regressions.
- Documentation: roadmap, acceptance ledger and operator-reported release evidence.

All three groups remain local/uncommitted. Review and obtain explicit commit,
push and deployment approvals. After approved rollout, verify actual deployed
revision, guest and signed-in response state, no-store behavior and timing header.
Collect ordinary usage timings rather than generating a production benchmark
storm. Preserve the previous known-good revision and rollback if correctness or
request failures regress. None of this completes the three-cycle/user-study gates.

Not selected until evidence is available. Rank at most three findings by impact,
frequency, confidence, effort and dependencies; choose one reversible intervention.
If concurrency corrupts legitimate ACK/history state, prioritize reproduction and
correctness over ranking experiments. If latency dominates, measure server stages
and media-ready time separately before optimizing.

| Finding | Evidence / denominator | Impact / confidence | Proposed bounded fix | Success rule / rollback |
| --- | --- | --- | --- | --- |
| Awaiting baseline | Not yet collected | Unknown | Not selected | Define before implementation |