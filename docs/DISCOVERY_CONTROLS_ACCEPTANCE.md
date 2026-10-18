# Discovery controls: candidate acceptance

## Implemented contract

Atomic isolation regression: standalone real Redis session interleaving now has
**eight passing checks**, reproducing legacy session-field overwrite while proving
the separate store retains Hide and its revision after the late whole-session
commit. Established browsing identity only; not first-request initialization,
logout revocation or two-tab display acceptance. No runtime changes in this step.

Fresh-Next browser rerun: **203 Chrome checks pass, exit 0** against the rebuilt
client with speculative selection disabled on enabled-control pages. Navigation,
Hide/scarcity/Undo/Reset and responsive keyboard recovery pass. This supersedes
the fresh-Next browser-pending note below. It is not a two-tab consistency or
latency evaluation; remaining identity/in-flight/manual/research gates stay open.

Fresh-Next update: enabled-control pages suppress speculative prefetch and discard
any old prefetched result before Next requests current server selection. Disabled
pages retain prefetch; Previous/history unchanged. **170 frontend tests pass**, build
and diff checks pass. Chrome has not been rerun after this client change. This
removes speculative-result reuse, not preference/selection overlap already in
flight, identity initialization races or old tabs loaded before the change. Added
latency is an explicit tradeoff; no speed/relevance benefit claimed.

Latest browser validation: atomic-store route integration passes the **203-check
Chrome account-free suite**, exit 0, including native Hide/scarcity/Undo/Reset,
responsive recovery controls and keyboard focus. This supersedes browser-pending
notes below. It does not test two-tab races, first-request identity initialization
or in-flight logout writes; default-off release gates remain unchanged.

Logout cleanup update: POST logout now attempts preference deletion regardless of
rollout flag; store failure logs a generic warning and does not prevent session
destruction. Fixed TTL is fallback. This is best effort, not a revocation/tombstone
guarantee against an in-flight write after deletion. Two route regressions pass;
full backend **1,356 examples, zero failures, seven pending, 77.95% coverage**.
Chrome still pending for atomic-route integration. Earlier no-deletion notes below
describe superseded implementation stages.

Latest integration update: routes and Undo UI now use the separate atomic store,
keyed by existing opaque `feed_session_id`, not session preference fields. Login
already preserves this browsing identity; logout clears the session identity.
Old unreferenced records expire at fixed 30 days from first write; immediate
logout deletion is not implemented. Existing legacy session preference fields
are not migrated. Reads/writes fail closed with 503 on store unavailability.
Backend **1,354 examples / zero failures / seven pending**, 77.92% coverage;
frontend **168 pass**, syntax/diff pass. Chrome has not been rerun for this route
integration. Stale in-memory prefetch and identity initialization/session races
still need acceptance. Default-off remains required. Later historical notes below
describe earlier implementation stages, not completion of these remaining gates.

- Hide current community from future Random/home/Similar selections; max 20.
- Browser-session storage only, not account taste scores. Session may survive
  browser close; auth can clear it. Reset on shared devices.
- Visible hidden communities, individual Restore, Undo last actual hide, Reset.
- Native CSRF-protected form POST followed by full-page 303 redirect.
- Exclusions apply to selection and HTML fallback; no silent widening on exhaustion.
- Exhausted JSON returns classified 409; client preserves current media and offers
  restore/reset recovery. Empty source pool remains a supply error, not preference
  exhaustion. No claim that hiding a community understands broader topics.
- Search, exact links and prior viewing history are intentionally not restricted.

## Local evidence

Latest full backend: 1,348 examples, zero failures, seven pre-existing pending,
77.86% coverage. Frontend: 168 passing tests. Build passes.
Chrome account-free suite with the switch explicitly enabled: 203 passing checks, including native hide/exhaustion/
undo/reset, responsive recovery controls and focus at three widths/both themes.
The enabled browser journey passes after the switch change; disabled behavior is
covered by backend regression. These are local runs, not deployed approval or population evidence.

## Release blockers / known boundaries

**Multi-tab preference synchronization is not solved.** Another tab can render a
previously prefetched item. Concurrent session writes can lose preference changes.
UI discloses previously loaded content, but disclosure alone is not synchronization.
Do not claim an immediate cross-tab exclusion guarantee. Agree acceptable scope
and reproduce simultaneous writes before broad rollout; consider server-held state
with atomic updates if cross-tab persistence is a requirement.

### Consistency investigation

Production `config.ru` uses `Rack::Session::Redis` (redis-rack 3.0.0), not
cookie-contained preference data. Its `find_session` and `write_session` each use
a separate local mutex; `write_session` sets the entire session snapshot. There
is no request-wide transaction or compare-and-swap. A late overlapping selection
request can therefore write an old preference snapshot after a successful Hide,
not only two simultaneous preference POSTs. This is now reproduced by a
deterministic middleware-level interleaving, not merely inferred from source.

Run `REDIS_URL=redis://127.0.0.1:16379/0 ruby scripts/isolated_bundle.rb exec ruby
tests/discovery_session_race_test.rb` from the repository root with disposable
Redis running. Six checks confirm the old snapshot loads, Hide succeeds and is
visible, then the late request overwrites it. The script uses the installed real
session middleware, a unique namespace, a 60-second TTL and scoped cleanup; no
database/app boot or flush. Its passing exit means the **known bug reproduced**,
not that concurrent controls are safe. It is not a full application/two-tab test.

Client `prefetchNext` stores one response in memory; `loadNextMeme` consumes it
without revalidating preference state. `cache: 'no-store'` avoids HTTP cache reuse,
but does not invalidate this in-memory result. Previous/history remains an
intentional exception and must not be erased to fix fresh selection behavior.

Proposed next implementation boundary (not implemented or approved):

Foundation now implemented separately in `DiscoveryPreferencesStore`, but **not
wired into routes/auth/client**: atomic Redis Lua changes, 20-community cap,
Undo target, revisions and fixed 30-day expiry from first write (Reset preserves
remaining expiry); empty reads create no key, failures raise Unavailable. Five
service examples cover concurrent hides and core boundaries. Full backend run:
1,353 examples, zero failures, seven pending, 77.92% coverage, exit 0. This does
not yet repair live discovery controls; route integration/lifecycle/display
consistency remain next. No browser rerun for this unused service foundation.

1. Store bounded discovery state separately from whole-session writes, under an
   opaque session-scoped identifier. Define TTL, session rotation/logout cleanup,
   unavailable-store behavior and deletion before introducing a new store.
2. Atomically apply Hide/Restore/Undo/Reset with a monotonically increasing
   revision. Do not globally merge session hashes or change auth session locking.
3. Return revision with selections; invalidate old in-memory prefetch on change.
   A cross-tab broadcast is an optimization, not authoritative state or a
   guarantee for a selection already in flight. Define the commit/display boundary
   explicitly before claiming immediate exclusion.
4. Deterministically interleave two POSTs and a slow selection against the real
   Redis middleware; verify no lost controls, correct Undo and state after reload.
   Route specs use a shared fake session and cannot establish this guarantee.
5. Exercise real two-tab prefetch/recovery and failure paths, then decide whether
   the accepted consistency guarantee is sufficient to enable the default-off flag.

Do not patch the vendored session gem or add only a BroadcastChannel listener and
mark this gate resolved. A separate state store changes lifecycle/privacy behavior
and needs its own implementation and acceptance slice.

`ENABLE_DISCOVERY_CONTROLS=true` explicitly enables this candidate; unset or any
other value disables it. Disabled: panel absent, stored exclusions ignored, writes
return 404 without changing preference state (CSRF middleware still applies).
Stored preferences are retained and resume if re-enabled within the same session.
This is a process-wide operational switch, not a cohort canary or synchronization
fix. Restart processes consistently when changing it. Leave it off until remaining
gates are accepted. Do not change unrelated feed issuance flags to release this.

## Manual staging acceptance — NOT RUN

Record candidate/deployed revisions, browser/OS/device, result and evidence privately.
Use isolated staging services and ordinary fixture/community supply, not production
cache clearing or forced supply jobs.

1. Hide a real displayed community; confirm all new server selections respect it.
2. Next/Previous/gallery/video/exact-link journeys retain correct action targets.
3. Exhaust current supply by settings: restore/reset accessible, no blocked title
   or media in response, no irreversible loss of saved/history items.
4. Duplicate Hide, Undo, Restore last target, Reset, cap/error behavior.
5. Slow/offline form POST and lost response: explain actual state on reload.
6. Two tabs with pending prefetch, simultaneous hide/restore, login/logout and
   session expiry. Record limitations rather than silently passing races.
7. True 200% browser zoom, screen-reader announcements, mobile touch targets,
   dark/light themes and ads/consent overlays. CDP checks are not these tests.

## Product validation — NOT RUN

Observe 5–8 consented intended users changing topic/community without assistance,
undoing and explaining session/account scope. Record counts, failures and confusion.
Compare explicit relevance ratings and variety before changing weighting. Combine
with 100-selection content baseline and three ordinary supply cycles. No retention
lift, score increase or automatic experiment approval from test counts.

## Next action

Review/commit candidate, resolve required multi-tab/rollout contract, run hosted CI
and manual staging gates through approved operations. Do not start another ranking
or preference feature before observing this one. Roll back candidate code through
normal reviewed release if wrong-content/exclusion/security regressions occur;
existing session preference data is bounded and removable via Reset.