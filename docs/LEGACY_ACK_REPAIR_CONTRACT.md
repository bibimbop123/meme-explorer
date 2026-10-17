# Legacy ACK lost-update repair: bounded integration contract

Status: implementation committed as 650a4a7; user reports production deployment;
deployed fresh-process flag check returned false. NOT approved for enablement.
The real-route regression covers disabled legacy loss
and enabled two-ACK success. Full acceptance matrix below remains incomplete.

## Current acceptance status

This section is authoritative for current status; numbered run results and
follow-up notes below are historical checkpoints, not additional outstanding work.

Latest backend: 1,282 examples, zero failures, seven pending; 76.73% coverage,
exit 0. Latest frontend: 143 passing. Runtime code is committed; subsequent browser
evidence/documentation updates remain uncommitted. feed.legacy_pending_store is
explicitly false. Deployment is operator-reported, not full backend-SHA verified.
Subsequent local uncommitted runtime changes add an external-issuance failure
warning and replace raw ACK exception messages with class names; tests pass.
These diagnostics do not supply aggregate rollout metrics.

Local uncommitted aggregate telemetry now records fixed-label daily handler counts
in Redis with two-day key TTL: legacy/external/unavailable issuance and recorded,
duplicate, invalid, unavailable, bad-JSON ACKs. Admin-only GET
/api/admin/legacy-impression-metrics returns counts with no-store, or 503 with
counts:null when unavailable. Date buckets explicitly use UTC. No identifier or
content labels. Writes fail soft; Redis outages can lose telemetry, and failures
before route handling are excluded. This is not a complete HTTP error denominator
or latency dashboard; old local performance results predate the added Redis write
per issuance/ACK and must not be used as current overhead evidence.
Telemetry-inclusive follow-up now measures four local on/off/off/on passes with
100 post-warmup cycles each: enabled p95 issuance 4.08–5.22 ms, ACK 4.41–5.17 ms,
retry 3.21–4.34 ms. Direct Redis totals match all 110 cycles per pass including
warmup. Fixture-only sequential loopback evidence, not deployed budget approval
or isolated measurement of telemetry overhead; see ledger for raw log path.

| Area | Current evidence | Remaining limitation |
| --- | --- | --- |
| Lost-update regression | Eight real-route Redis-session overlap cases: both save orders twice per flag state; enabled both ACKs/retries pass | Threads in one serving process, not multi-process HTTP |
| Independent store concurrency | Four fresh interpreters, independent Redis clients, 32 issues/20 retained | Test transport adapter, not production pool |
| Authorization | Route/middleware coverage plus local Chrome login form and native POST logout | No deployed staging acceptance |
| Rollback compatibility | Mixed IDs and local Chrome surviving single-process restart with issuance off | Multi-process config propagation/drain not exercised |
| Failure handling | Route tests; Chrome disconnect and post-commit response loss; actual local Redis stop/restart | Total Redis outage returns 500 via session middleware; recovery preserves Redis data and uses manual retry; same-count corruption not audited |
| Capacity/expiry | Approved independent 20+20 transition caps; expiry pruning, earliest deadline/ID-tie eviction, no retry renewal | Capacity eviction can invalidate older IDs; not unlimited retention |
| User accounting | Exactly-once impressions/views/activity and exposure increments over selection baseline | Selection-time history intentionally unchanged |
| Default/initialization | Actual YAML default off; sequential unbound legacy then bound external issuance | Concurrent unbound requests explicitly unresolved |
| Frontend nil ID | Actual module with DOM/observer doubles: no ACK, unchanged media | Not interactive browser evidence |
| Browser | Local fixture image dwell/Next/Back, shared-cookie tab fetches, two-slide gallery smoke | Not all tab ACKs dwell-driven; AJAX gallery replacement untested |
| Operations | Local 100-cycle per-state latency/memory sample; disable/drain procedure | Representative deployment measurements, approved budgets and separate canary approval outstanding |

Do not keep adding local tests as a substitute for the outstanding staging gate.
Staging requires operator-approved environment, budgets and enablement; production
enablement and committing further documentation changes require explicit approval.

## Proposed operational gates (NOT approved or executed)

These are discussion thresholds, not claims derived from the local sample.

- Before enablement, capture comparable deployed baseline and enabled samples
  for issuance and ACK p95, 5xx rates, Redis used_memory/evictions and nil-ID
  issuance. Agree on sampling window and traffic volume; no production fault tests.
- Proposed latency stop threshold: sustained p95 increase greater than both 20%
  and 25 ms relative to baseline. Compare equivalent routes and traffic; do not
  substitute the loopback fixture timings for deployed baseline.
- Stop immediately on unauthorized acceptance, repeat-count increments, new Redis
  evictions/OOM, or verified loss of a newly issued stable-binding credential
  within its deadline/capacity. Diagnose expected expiry/eviction separately.
- Proposed availability threshold: investigate/disable issuance on sustained
  ACK/issuance 5xx increase of 0.5 percentage points over baseline. A missing
  denominator or low traffic cannot establish a passing error rate.
- Reserve Redis headroom based on active binding count and measured payload
  distribution. Local 6,275-byte fixture key usage is not a worst-case allocation:
  payloads allow 16 KiB each and independent session keys also consume memory.
- Current YAML flag is global per process, not a percentage/cohort canary. Do not
  call an all-process flag flip a limited canary. Define routing/cohort scope or
  explicitly approve a monitored full enablement before proceeding.
- Confirm aggregate metrics can actually be observed before accepting these gates.
  Current implementation does not provide a complete nil-ID/ACK metrics dashboard.
  Missing observability is an enablement blocker, not an assumed zero-error result.
- Disable by setting issuance false in every serving process while retaining
  external lookup and Redis state for the original credential drain window.

## Runtime behavior and historical validation checkpoints

Implemented: shared issuance uses LegacyImpressionStore for existing valid session
bindings when feed.legacy_pending_store is true (config default false). Atomic
Redis issuance stores bounded context under hashed session/user keys, with 30-minute
per-entry deadlines and 20-entry external-store cap. At capacity it evicts an
earliest-expiring ID (ties by ID), not necessarily session insertion order. Lookup
does not renew expiry. New credentials are not added to the session map. First
unbound requests remain legacy; login/logout clears the ACK binding via existing
session rotation. ACK lookup remains active independently of issuance flag; a
store outage returns 503 when external lookup is needed, and failed issuance
returns no impression ID. Existing session-backed entries keep legacy behavior.

Approved transition policy: retain independent caps of 20 session-backed and 20
external credentials per stable session/user binding (up to 40 combined). This
explicitly replaces the proposed single combined 20-entry cap; it does not renew
credentials or promise unlimited retention. Rollback may issue legacy IDs while
external IDs remain valid until their original expiry or capacity eviction.
Open before enablement: staging interactive browser, multi-tab and operational
acceptance. No production enablement is authorized by passing tests.

Nil-ID frontend unit acceptance: observeImpression with an explicit null credential
stops previous observation, leaves current media unchanged and neither submits an
ACK nor marks it qualified/recent. Full frontend run: 143 passing. This tests the
actual module with DOM/observer doubles, not an interactive browser.

Corruption/provenance follow-up: store rejects invalid JSON, non-object payloads,
missing/mismatched user context, unsafe media URLs, invalid metadata types and
oversized payloads without renewing deadlines. Duplicate issuance cannot replace
context or renew expiry. Route tests reject conflicting existing DB URL or session
provenance without adding views. Full backend: 1,260 examples, zero failures,
seven pending, 76.60% coverage, exit 0; frontend: 142 passing.

Real Redis middleware auth follow-up now passes: actual password login renews
the session cookie and clears the ACK binding; old anonymous credentials reject.
Authenticated credentials ACK once, then reject after actual POST logout; new
anonymous credentials work under a different binding. Test-only state endpoint
seeds/reads CSRF and binding, not production code. Full backend rerun: 1,261
examples, zero failures, seven pending, 76.58% coverage, exit 0. Initial test-client
cookie parsing failure was fixed to handle Rack's multiple Set-Cookie headers.
This is HTTP/middleware acceptance, not interactive browser or staging evidence.

Follow-up route coverage now passes: issuance persistence failure returns usable
media with nil ID and no session pending fallback; lookup outage returns 503 with
no DB mutation and later retry succeeds; failed DB view update rolls back dedupe
then permits the same-ID retry; user change with unchanged binding, replacement
session and expired external entry reject. This is not yet a real login/logout
browser test. Full run: 1,255 examples, zero failures, seven pending, 76.53% coverage.
Do not implement “wait until legacy map empties” as a capacity fix: continued
legacy issuance renews that map, and flag rollback/re-enable can mix stores again.

## Decision

Separate pending credential persistence from whole-session snapshots without
changing selection/history semantics. Do not partially wire the existing v2
acknowledgment service: it also reconciles acknowledged history and requires a
different credential/client protocol. The coordinated v2 migration remains governed
by [its contract](FEED_MIGRATION_CONTRACT.md).

## Required runtime boundary

- Default-off flag applies to issuance at the shared issue_impression helper,
  covering homepage, random HTML/JSON, similar and exact recipient paths.
- Store server-created ID/content/context independently and atomically in Redis,
  not as an uncoordinated read/replace map. No client URL/title/user authorizes ACK.
- Bind to an existing server-owned session secret and authenticated identity;
  never IP, raw client parameters or feed continuity alone. Define login/logout
  rotation explicitly. Preserve current denial after session replacement.
- Initial concurrent requests before any binding persists are a separate unresolved
  case. Do not claim this repair fixes them. Require a stable existing binding for
  the first enabled slice, with an honest legacy path for uninitialized sessions.
- Preserve original 30-minute credential deadline, independent 20-entry caps for
  session and external credentials, bounded metadata and atomic external capacity/pruning rules. Specify eviction
  behavior explicitly rather than silently changing it. Reads/retries do not renew
  deadlines. Redis outages must not create credentials that were never persisted.
- Keep DB transaction/idempotency behavior; verify persisted ID/content/session
  provenance before treating a duplicate as an authorized retry. Do not count twice.
- ACK dispatch must remain able to accept both pre-rollout session-backed IDs and
  new externally stored IDs through their original lifetime after rollback. Do not
  use Redis unavailability as permission to trust client content or fail open.
- Define distinct issuance failure/capacity and ACK unavailable/invalid outcomes.
  Keep feed usable where safe, but never claim recorded:true without a commit.
- No telemetry identifiers, secrets, raw content or account data in diagnostic logs.

## Acceptance matrix before enabling

Authenticated accounting follow-up: two external IDs for the same user/media
each ACK then retry; exactly two impressions/views and two attributed view-activity
rows result. Exposure increases by two above the captured selection-time baseline,
so this does not remove or redefine existing selection accounting. Full backend:
1,273 examples, zero failures, seven pending, 76.61% coverage, exit 0.

Default/first-request acceptance: route test reloads the actual shipped YAML and
requires the flag false, no external issuance and a usable legacy ACK. Another
test starts without a binding, verifies first issuance is legacy, then subsequent
issuance is external under the established binding; both IDs ACK successfully.
This is sequential initialization, not a fix for concurrent unbound requests.
Full backend: 1,272 examples, zero failures, seven pending, 76.61% coverage, exit 0.

Expiry/capacity follow-up: issuance now refuses mismatched expiry/payload counts
before mutation, preventing partial structure loss from silently accumulating
unaccounted payloads. Tests verify refusal after either key is lost, expired hash
payload removal, earliest-deadline eviction and lexicographic ID tie ordering,
without changing surviving deadlines. This count check is not a complete integrity
audit of arbitrary same-cardinality corruption. Full backend: 1,270 examples,
zero failures, seven pending, 76.55% coverage, exit 0. Flag remains false.

Process-boundary store acceptance now passes: four fresh Ruby interpreters open
independent Redis connections, synchronize before issuance and issue 32 IDs against
one binding. Exactly 20 entries remain in both expiry/payload structures and every
retained ID is readable by the parent. Children run real store validation/Lua with
a test transport adapter, not the production connection pool or HTTP routes.
Full backend: 1,268 examples, zero failures, seven pending, 76.58% coverage, exit 0.
This is not multi-process HTTP or interactive staging-browser acceptance.

Repeated schedule follow-up: real middleware overlap now runs both response-save
orders twice for each flag state (eight examples). Each request is held after its
route response; joining the released worker includes its Redis session save before
the other is released. All enabled schedules ACK both IDs and retry without extra
views; disabled schedules retain the lost-update reproduction. Full backend:
1,267 examples, zero failures, seven pending, 76.58% coverage, exit 0. This
supersedes the single-schedule limitation below; process-boundary and staging
browser coverage remain outstanding.

Latest real-route overlap assertion retries every successful issued ID (both with
repair enabled), requires recorded:true on each first ACK and recorded:false on
each retry, and checks exactly two total impressions/views. Full rerun: 1,261
examples, zero failures, seven pending, 76.55% coverage, exit 0; frontend 143 passing.
This remains one forced overlap schedule per flag state, not process-boundary or
staging browser evidence.

1. Actual Redis-session feed-route barrier: both distinct issued IDs ACK once;
   then retry both, with two total impressions/views and no additional increments.
2. Wrong cookie, logout, expired ID, forged ID, mismatched user and malformed body
   remain rejected. Client URL/title substitution has no authority.
3. Concurrent issuance at capacity preserves the documented bound and eviction
   policy; expiry cleanup and wrong Redis key types fail safely.
4. Redis unavailable during issue/lookup and DB failure during ACK are tested;
   valid retries preserve original deadline and transaction rollback.
5. Mixed old/new credentials, disabled issuance after enablement, and rollback
   retain handler compatibility without renewing credentials.
6. Repeated deterministic overlap schedules, independent Redis connections and
   full frontend/backend gates pass. Add process-boundary coverage if feasible.
7. Staging browser multi-tab/Next/Back/auth journeys pass with privacy-safe
   rejection counts, latency/resource budgets and a documented disable procedure.

Do not deploy a new store as another disconnected helper. Deliver store, shared
issuance, legacy/new dispatch and real-route regressions together, flag off.
Operator approval is required separately for canary enablement. No selection-time
history marks are removed in this slice, and no v2 history is silently mixed in.

## Staging acceptance and disable procedure (not executed)

1. Obtain approval and use an isolated staging database/Redis environment. Record
   baseline request latency, Redis memory and eviction/error counters. Agree on
   acceptable budgets before enabling; none have been measured by this repair.
2. Set features.feed.legacy_pending_store true in staging config/features.yml.
   FeatureFlags caches YAML per process and has no environment override here:
   restart every serving process (or explicitly reload each process). Do not change
   production config. Verify active config in every process, not only the file.
3. Establish a normal stable session before opening two tabs with the same cookie.
   Exercise overlapping Next, Back, galleries and exact recipient links. Observe
   that visible usable media ACKs once, prefetch alone does not ACK and retries do
   not add views. Avoid collecting tokens, IDs, URLs or account identifiers in logs.
4. Exercise login, POST logout and new anonymous browsing. Old credentials must
   reject after identity rotation; newly issued credentials must work. Exercise a
   separate browser/session to verify it cannot ACK another session's credential.
5. In staging only, simulate external issuance/lookup failures without disrupting
   unrelated workloads. Media must remain usable with no credential on failed
   issuance; lookup failure must not add a view and must allow bounded retry.
6. Disable issuance by setting the flag false and restarting/reloading every
   serving process. Keep the new lookup code, Redis keys and original TTLs intact:
   outstanding external IDs must still ACK; newly selected items use the legacy
   path. Verify mixed old/new IDs and duplicate retries across this transition.
7. Do not roll back the code to a version without external lookup during the
   outstanding credential window. Stop external issuance everywhere, allow at
   least 30 minutes after the final external issuance, and verify the drain before
   removing compatibility code. Never bulk-delete credentials as routine rollback.

Record actual browser outcomes, approved budgets and observations in the ledger.
Initial unbound-session races remain excluded; production canary approval remains
a separate operator decision even after staging passes.