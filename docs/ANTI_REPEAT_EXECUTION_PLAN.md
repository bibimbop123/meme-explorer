# Anti-repeat feed execution plan

Status: proposed execution order, not deployment approval. Builds on
[code audit](RANDOM_FEED_AUDIT_2026_10_16.md), [feed audit](FEED_EXPERIENCE_AUDIT.md)
and [release gates](CONTROLLED_RELEASE_2026_10_16.md).

## Outcome and scope

Make Next feel like progress: prioritize eligible unseen content, preserve the
ability to recover favorites, and admit when supply is exhausted. A replay must not
be presented as fresh. Do not promise unique artwork from distinct URL counts.

Optimize worthwhile discoveries and voluntary sharing, not session length or raw
ingestion volume. Use iFunny's public freshness/topic positioning as product
inspiration only; no proprietary algorithm/library access or integration assumed.

Owners below are roles to assign, not commitments by named people. Execute in
dependency order; do not estimate calendar dates before scope/owners are agreed.

## Phase 1 — Validate and isolate the existing anti-repeat fix

**Owner:** engineering + QA. **Status:** code implemented locally; acceptance open.

Execution update: homepage/session integration tests added; basic history membership
uses a Set. Reads/writes now prune entries older than seven days, in addition to the
5,000-entry cap and sliding key TTL. Idle keys expire; pruning of individual entries
on active keys occurs on reads/writes, not a scheduled deletion timer.

Local single-session exhausted-pool benchmark (5,000 entries, 100 selections):
p50 8.65ms, p95 9.68ms, Redis MEMORY USAGE 613,480 bytes for one synthetic history
key. Not a concurrency/production baseline; identifier lengths and allocator vary.
Capacity/privacy approval remains open. Artifact: /tmp/meme-novelty-benchmark.json.

Chrome three-item guest/Save-Data pass: all items before replay, initial exhaustion
notice, next-oldest AJAX replay and Back restore PASS; no runtime exceptions captured.
Artifact: /tmp/meme-novelty-browser-results.json. Account/prefetch-enabled/multi-tab,
single-item and full size-matrix browser acceptance remain open.

Follow-up: single-item guest Chrome with prefetch enabled now passes three assertions:
one initial random.json prefetch, no additional requests on Next, retained current
media plus visible exhaustion and specific no-different-content message. Fixed the
prior generic-error/two-retry behavior for explicitly exhausted identical responses.
Artifact: /tmp/meme-single-browser-results.json; no captured runtime exceptions.
This covers single-item prefetch, not the full account/multi-item/multi-tab matrix.
Latest final-build suite: 1049 backend examples, zero failures, seven pending,
74.14% coverage (4582/6180), gates pass, exit 0; 121 frontend tests and build pass.

Automated matrix follow-up: five real-Redis selector cases at 1/2/20/200/5,000
eligible URLs verify last-unseen priority and oldest-first replay without history
reset. Signed-in homepage route continuity also passes. These seed prior history;
they do not simulate every preceding browser view or parallel tabs. Latest full
backend: 1055 examples, zero failures, seven pending, 60.47s; 74.14% (4582/6180),
gates pass, exit 0; 121 frontend tests pass. Browser size/account matrix remains open.

- Review homepage selector use, URL/file deduplication, no shared-record mutation,
  no history reset and oldest-selected exhaustion replay.
- Make retention a conscious decision: 5,000 selections/seven-day age window plus
  sliding key TTL is implemented locally, not approved production policy. Verify
  pruning and memory behavior under realistic active/idle traffic before rollout.
- Benchmark Redis memory/key growth and selection p50/p95 at realistic concurrency;
  full-pool filtering and 5,000-member history reads have a cost. Set rollout budgets
  from a baseline, not an invented performance guarantee.
- Run real Chrome guest/account checks with 1, 2, 20, 200 and 5,000 eligible items,
  reload/home, Back/Forward, prefetch enabled/disabled and history clear/expiry.
- Verify exhaustion notice on initial HTML and AJAX, including restored history;
  explicitly test a one-item pool where no different Next can exist.
- Add route-level tests that repeated homepage requests share the same recent-
  selection identity and do not bypass unseen filtering. Existing selector tests
  alone do not prove browser/session continuity.

**Exit:** deterministic tests plus browser evidence; within a stable single-session
fixture, each eligible URL is selected before replay, exhausted cycles avoid recent
items when alternatives exist, and newly added eligible URLs take priority. These
are scoped contracts, not guarantees during Redis loss, session reset or concurrency.

## Phase 2 — Separate selection reservations from acknowledged views

Implementation contract: [reservation protocol](FEED_RESERVATION_PROTOCOL.md).
Design prepared only; constants, identity transition and failure semantics require
review before changing selection-time history writes.

**Owner:** engineering. **Status:** design required before implementation.

Current history records selection/prefetch, not actual viewing. Define one shared
session identity for homepage, random, similar and recipient flows; preserve privacy
and guest/auth continuity without IP-only identity or new cross-device tracking.

State machine:

1. **Eligible:** not excluded by recent acknowledged history or active reservation.
2. **Reserved:** server atomically reserves selected URL for a bounded interval and
   issues an opaque session-bound selection token. Prefetch is reserved, not viewed.
3. **Acknowledged:** existing valid impression acknowledgement idempotently commits
   viewed history and releases reservation. Validate URL/session/token association.
4. **Expired/released:** abandoned prefetch/failure becomes eligible after a bounded
   lease; do not create permanent exclusion or treat failed media as a dislike.

Decide exact reservation expiry, maximum outstanding count, history retention,
gallery qualification and navigation-away behavior before coding. Use Redis atomic
operations and ownership checks; do not use an unprotected read-then-write selection
as the multi-tab guarantee. Do not hold DB/Redis connections across network fetches.

**Required tests:** two tabs selecting concurrently; duplicate/late acknowledgements;
prefetch abandonment; failed media; history restoration; logout/login; malformed or
cross-session tokens; reservation expiry; Redis failure; server restart. Preserve
existing impression and Saved/share identities. Define degraded behavior explicitly.

**Exit:** unused prefetch does not count as viewed; concurrent requests do not
reserve the same URL while alternatives exist under healthy Redis; bounded leases
cannot erase history or lock a session out. No extra Reddit fetches to satisfy retries.

## Phase 3 — Prove and improve supply, in parallel with observation

**Owner:** operator + product/design. **Status:** production evidence/user audit open.

- Verify scheduled worker execution, OAuth success and intended shared Redis across
  three normal maintenance cycles; compare observed retained inventory to candidate
  additions and publication outcomes. Do not purge pools or force refresh storms.
- Audit consecutive real feed selections using FEED_AUDIT_CAPTURE.csv; observe
  5–8 consenting target users discovering/sending, recovering/saving and steering.
- Measure selected versus acknowledged versus usable content separately. Count
  repeated URL, identical artwork and reused templates with different punchlines
  separately; mark uncertain comparisons rather than silently merging identities.
- If source overlap is confirmed, try one bounded hot/new/top/time-window rotation
  with page/request/cursor budgets and cooldowns. Preserve quality gates and working
  pools on failure. Do not scrape/import an iFunny library or add unbounded sources.

**Exit:** dated source/filter/overlap breakdown and a selected experiment. If supply
is genuinely exhausted, keep honest replay/Search/return-later choices; a new
algorithm cannot manufacture new eligible memes.

## Phase 4 — Address visual repetition only if the audit warrants it

**Owner:** engineering + content/product reviewer. **Status:** deferred pending data.

Evaluate perceptual matching offline on a permitted, representative sample. Review
false positives for caption edits, crops and common templates. Keep original URLs
and canonical Saved/share identities; visual clusters are eligibility hints, not
destructive identity merges. Review storage/rights, deletion and privacy policies.
No unrestricted server downloads: allowlisted hosts/redirect handling, time/size
bounds and SSRF protections must precede any fetching. Adopt a new library only
after explicit compatibility/security review; none selected by this plan.

**Exit:** documented matching precision/false-positive tradeoff and a reversible
session-level experiment—not a claim of perfect visual deduplication.

## Phase 5 — Small user controls, not a ranking rebuild

**Owner:** product + engineering. **Status:** choose based on findings.

Offer explicit replay choice at exhaustion, Search/community discovery and possibly
a small supported topic selector. “Not my thing” needs Undo/reset and honest
session/account scope. Next remains navigation, not negative feedback. Keep source
diversity/exploration; do not amplify views/likes blindly or claim learned tastes
without evidence. Defer collections, mandatory onboarding and elaborate ranking.

## Measurement and rollout

- Baseline and compare the same audience/session/window definitions: repeat URL and
  visual-art rates per acknowledged selection, usable/attempted media, eligible unseen
  inventory, time to usable content, source mix and voluntary would-send ratings.
- Report raw denominators and guest/account, cold/warm and device breakdowns. Small
  qualitative sessions identify failures; they do not establish causal retention lift.
- Require fresh hosted test/security success on the final exact SHA, dependency
  remediation, schema/config review and explicit release approval. Fix production
  PUBLIC_ORIGIN/social metadata separately; do not weaken Host validation.
- Canary only after approval, with predeclared Redis memory/eviction, p95 latency,
  error and repeat-rate budgets. Stop on wrong-content actions, favorite loss,
  privacy exposure or sustained budget breach. No positive quality-score adjustment
  solely for passing tests, larger URL counts or code completion.
- Rollback code coherently; retain catalog/Saved identities and compatible history
  data. Do not flush Redis or clear everyone's history as the rollback shortcut.

## Next implementation ticket

**Phase 1 acceptance and retention/performance review** before extending the code:
add homepage/session integration tests; exercise small/exhausted/newly-grown pools
in Chrome; measure 5,000-history memory/selection cost; decide seven-day per-key
versus per-entry retention. Then checkpoint anti-repeat work independently from
security updates and design Phase 2's reservation protocol.