# Feed reservations and acknowledged-history protocol

Status: implementation design, **not implemented or approved for rollout**.
Identity prerequisite implemented locally: shared validated random feed_session_id
used by homepage/random/similar and initialized for recipient impressions. Preserved
through successful email/signup/validated OAuth session rotation; cleared on logout.
Reservation/acknowledgement changes below remain unimplemented. Legacy histories
are not migrated, so upgrade can reset recent-selection continuity once. Initial
parallel requests before session persistence and session-store races remain open.
Builds on ANTI_REPEAT_EXECUTION_PLAN.md Phase 2. Existing anti-repeat selection
remains active; do not remove selection marking until all migrated paths are tested.

Active-reservation primitive is now implemented locally as FeedReservationService,
but unused by app routes. Atomic acquire/release uses Redis server time, 120-second
expiry, 20-active cap, hashed content/session key namespace, and token ownership.
It does not write viewed history, validate impression/acknowledgement tokens or
atomically recheck viewed-history eligibility. Those integration steps remain open.
Returned token is stored as owner metadata in Redis (not hashed there); no raw media
payloads are stored. Two keys share a hash tag; real Cluster deployment not tested.

Nine real-Redis examples cover ownership, capacity, expiry/successor protection,
session isolation, unchanged history, key TTLs, invalid input, errors/unavailability
and two independent connections racing on one content identity. Full backend:
1070 examples, zero failures, seven pending, 62.26s; 74.28% (4623/6224), gates pass,
exit 0; 121 frontend tests pass. Initial error-stub teardown failure was corrected;
final full run is green. No live route behavior change or rollout approval.

## Code anchors and current semantics

Active lease validation now atomically checks server-time expiry and exact session/
content/token ownership without renewal. Status distinguishes active, invalid and
unavailable. It is unused by routes and must NOT substitute for the proposed
30-minute acknowledgement token: an expired 120-second lease does not prove that
a late otherwise-valid displayed impression is invalid. Durable ACK metadata and
history reconciliation remain unimplemented.

Three validation regressions cover association, no renewal, expiry, successors and
unavailability. Full backend: 1073 examples, zero failures, seven pending, 62.12s;
74.35% (4635/6234), gates pass, exit 0; 121 frontend tests pass; 12 targeted lease
tests pass (partial coverage exit 2); syntax/whitespace pass. No live behavior switch.

- SimpleMemeSelector.select marks selection in ViewingHistoryService; random/similar
  routes also mark it. Homepage now uses the selector. A prefetch therefore counts
  as selected, though not necessarily displayed.
- RandomMeme#issue_impression creates a 30-minute session-bound ID with pending
  URL metadata, bounded to 20 entries. Concurrent session writes can overwrite this
  pending map; it must not become the authoritative multi-tab reservation store.
- POST /api/impressions commits an idempotent PostgreSQL impression and view/exposure
  counters. Client qualification requires loaded media, visibility and one second.
- PostgreSQL and Redis cannot be committed atomically by the present architecture.
  This protocol must document recovery, not claim exactly-once distributed state.

## Proposed bounded constants (require capacity/privacy review)

| Concern | Proposed starting bound | Rationale/limit |
| --- | --- | --- |
| Reservation TTL | 120 seconds | Short speculative protection; slow/abandoned prefetch eventually eligible |
| Active reservations/session | 20 | Same order as existing pending map; cap checked atomically |
| Commit retries/server request | 1 Redis attempt | Client already retries acknowledgements; avoid nested retry storms |
| Selection conflict retries | 3 local attempts | No HTTP refetch; fail honestly if contention prevents reservation |
| Acknowledgement validity | Existing 30 minutes | Reservation expiry is not permission to reject an otherwise valid displayed impression |
| Acknowledged history | 5,000 entries / seven-day age window | Current local policy; memory approval still required |

Do not treat these starting values as measured production thresholds. Reservation
expiry can permit the same content in two tabs if one displays it late; explicitly
accept that bound rather than promise permanent uniqueness.

## Session identity and keys

Create an opaque random feed-session identity in the server session, shared by
homepage, /random, /random.json, /similar.json and exact recipient impressions.
Never fall back to IP identity. Do not key guest history to user_id or introduce
cross-device tracking. Decide guest → authenticated continuity in the existing
session-rotation helper: allowlist only this opaque identity when appropriate;
logout must not silently carry private account state into a new guest identity.
Define/test rotation and retention explicitly before enabling this migration.

Redis owns authoritative reservations and token metadata with per-session keys:
active token sorted set by expiry, content-to-token lookup and token metadata.
Opaque tokens bind session, content URL/identity and expiry. Hash tokens for key
names where practical; never log tokens, raw session identities or content URLs.
Keys must share a deliberate hash tag if Redis Cluster support is introduced;
current deployment compatibility must be checked, not assumed.

## Selection/reservation transaction

1. Fetch the bounded current candidate pool without changing supply scheduling.
2. Read/prune recent acknowledged history and active reservations. Rank eligible
   unseen candidates using existing selection policy; reserve only the chosen item.
3. Lua/atomic Redis operation rechecks candidate eligibility, prunes expired entries,
   enforces the active limit and installs session-bound token + expiry together.
   On conflict choose another candidate within three local attempts.
4. Return reserved content and opaque token with its impression ID. Prefetch creates
   a reservation only. No selection-time acknowledged-history write remains in a
   migrated path. Remove duplicate route marks in the same implementation slice.
5. Exhaustion distinguishes **temporarily reserved** from **all recently viewed**:
   do not replay an active reservation merely because unseen candidates are reserved.
   Offer retry shortly for temporary contention; replay least-recent acknowledged
   content only under the explicit exhausted/replay policy and with the same reserve
   rules. Single-item supply keeps the current meme and shows honest guidance.

Avoid token leakage into canonical/share URLs or persisted meme snapshots. Saved
and catalog identities must remain unchanged. Do not hold a Redis connection while
fetching Reddit/media, and do not create unbounded scripts proportional to inventory.

## Acknowledgement and partial failure

1. Validate token/session/content association and the existing valid impression ID.
   Redis token metadata replaces reliance on a race-prone session pending map for
   migrated requests; provide a bounded transition policy for older open pages.
2. Commit existing PostgreSQL impression/view/exposure transaction idempotently.
3. Atomically write/prune acknowledged Redis history and remove the matching active
   reservation. A retry must perform this reconciliation even when DB insertion is
   already deduplicated; `recorded: false` must not skip Redis repair.
4. If DB fails, return retryable 503; do not claim a recorded impression. Reservation
   stays until retry/expiry. If DB succeeds and Redis commit fails, return a retryable
   outcome without pretending DB rolled back. Retry uses the same ID/token and must
   not increment DB counters again. If retries are exhausted, history may lag; log
   aggregate stage failures and use expiry, not permanent exclusion.
5. Late valid acknowledgement may mark history after reservation expiry, but must
   never delete a successor token's reservation. Ownership compare-and-delete is
   mandatory. Repeated acknowledged tokens must not refresh history forever; history
   timestamp derives from the recorded acknowledgement, not retry arrival time.

No client URL field alone may create history entries or acknowledge arbitrary media.
Session/token mismatch is terminal; infrastructure failures are retryable. Keep
response bodies free of secret details and private/no-store.

## Abandonment, history navigation and outages

- Navigation away needs no guaranteed unload mutation: TTL handles abandoned
  reservations. Optional explicit release must be session/token-owned and idempotent.
- Failed media does not become viewed. Deliberately advancing may release its owned
  reservation, but does not declare the meme unsafe or disliked.
- Back/Forward/Recently viewed can restore the exact content independent of feed
  eligibility. Do not issue an unrelated selection or count duplicate acknowledgements.
- Redis unavailable: define a separate degraded response, not a global IP bucket or
  implicit “unseen” guarantee. Prefer retained current media with retry/Search. If a
  fallback is allowed, label repeat protection unavailable and bound its traffic.
- Cap evictions do not erase acknowledged history; old tokens expire. Sessions with
  20 active reservations must receive an honest retry response, not silently reset.

## Implementation tickets and acceptance

Identity validation: six new helper/auth regressions plus updated homepage tests;
19 targeted identity/auth/home cases pass (partial coverage exit 2). Full backend
1061 examples, zero failures, seven pending, 61.83s; 74.22% coverage (4595/6191),
gates pass, exit 0; 121 frontend tests pass. Provider auth mocked, no actual OAuth
acceptance or concurrency guarantee. No history marks removed or rollout enabled.

1. **Identity contract:** tests for all selection/recipient entry points, login/signup/
   OAuth rotation, logout, two tabs and old-page transition. No behavior switch yet.
2. **Reservation service:** atomic tests with two independent Redis connections,
   collisions, limits, expiry, ownership and malformed input; deterministic clock.
3. **Acknowledgement reconciliation:** DB failure, Redis-after-DB failure, lost response,
   duplicate/late ACK and successor ownership. No duplicate view/exposure counters.
4. **Route migration:** selector plus all route marks change together behind a reviewed
   rollout switch. Test prefetch abandonment and newly arrived content; retain current
   algorithm until route coverage is complete. Do not mix old/new history semantics
   without namespacing/versioned transition and rollback rules.
5. **Browser/operational acceptance:** two tabs, slow/offline/reconnected network,
   gallery/video failures, Back/Forward, Save/auth return and exhausted UI. Measure
   Redis memory, script latency, conflict/expiry rates and acknowledgement repair.

Exit: abandoned prefetch is not acknowledged history; healthy concurrent requests
reserve distinct eligible items within the lease; late retries cannot delete successor
state; existing share/Saved behavior and PostgreSQL dedupe remain intact. Rollout
still requires security remediation, exact-SHA CI, privacy/capacity approval and
explicit deployment authorization. No claim of unique artwork or new content supply.