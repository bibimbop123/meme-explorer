# Experience-first recovery: 163-item production pool

Status: prioritized proposal, not deployed fixes or confirmed production root cause.
Evidence: user-supplied excerpt, 2026-10-16 23:24:22–23:24:55 UTC. Deployed SHA,
worker status, Redis contents and provider responses have not been inspected.

## Evidence and explanation

- Requests explicitly use MemePoolManager's 163 records, not the small local fallback.
  "Tier-distributed" is a generic log label, not proof of source balance or quality.
- Twelve random.json responses return 200 in approximately 1126–1332ms; three home
  responses take 666–733ms. Short convenience sample, not field p95 or media-ready time.
- Eleven impression POSTs appear: eight 200, three 404. This is 3/11 in this excerpt,
  not a population error rate. A 200 does not establish recorded:true.
- Five vitals POSTs and one favicon GET return 404. Those vitals are not being
  collected by that endpoint. Favicon failure is polish, not the pool/latency cause.
- Generic/repeated titles do not prove repeated URLs or artwork. No humor, source
  age, readability or visual diversity judgment can be made from these logs alone.
- No maintenance appears in 33 seconds; its configured cadence is five minutes.
  This absence does NOT prove worker failure.

Confirmed repository behavior, pending deployed-version verification:

1. random.json logs the pool size before unseen selection: 163 source records,
   not 163 remaining unseen identities and not a 163 hard cap.
2. random_memes_pool immediately returns a successful nonempty manager pool.
   get_pool accepts any nonempty size. Browsing does not expand an undersized
   nonempty pool; doing provider work on every Next would create latency/rate pressure.
3. Bootstrap deliberately fetches small listings from 12 communities, not 5000.
   A small initial pool is plausible; this excerpt does not prove its provenance.
4. Growth depends on background maintenance. Below 1000, it requests a nominal
   1000-item batch; requested counts are not actual new usable additions. Repository
   declares Sidekiq worker/five-minute schedule, not proof they run in production.
5. Fetcher uses weekly top listings, at most two pages/community. Repeated batches
   can overlap; provider errors/429 cooldowns, structural/optional filters, URL dedup
   and publication conflicts reduce net additions. Reviewed code merges retained
   supply up to 5000, but deployed SHA is unknown. Raising target alone adds nothing.

### Diagnose, do not guess

| Hypothesis | Evidence needed | Action only if confirmed |
| --- | --- | --- |
| Worker/scheduler not running | worker SHA, queue consumption, three normal cycles | Restore intended scheduling, not request-time fetch loops |
| Different web/worker Redis/config | private config comparison and read-only samples from both | Approved shared-config correction |
| Provider auth/rate limit | redacted auth outcome, cooldown and batch rate_limited | Private credential repair; respect backoff/provider terms |
| Listing overlap/filter rejection | fetched_unique, validated_unique, candidate_new_unique, rejection counts | One measured source/listing change; retain safety gates |
| Publication/retention failure | publication outcome plus subsequent read-back counts | Fix writer/conflict/retention without purging working pool |
| Old deployed code | exact web/worker SHAs | Reviewed rollout after security/CI gates |

ACK 404 is a separate investigation: unknown/expired/session-mismatched IDs,
pending-map eviction, overlapping session writes, logout/old-page state are plausible.
Current pending IDs are session-map based; concurrent writes can overwrite entries.
Do not claim the exact cause from log timing/colors. Collect aggregate rejection
reasons without raw tokens, IDs, titles, URLs or user identity.

## Delivery order — supersedes more standalone infrastructure work

### P0: Diagnose supply and user friction in parallel

Owners: operator + backend + product/QA; assign named owners before execution.

- Verify deployed SHAs/config/worker; run existing read-only inventory checker in
  web/worker environments. Observe three ordinary maintenance cycles: requested →
  fetched unique → validated unique → new unique → published → retained. Include
  duration, 429/cooldown, filter losses and conflicts. No forced refresh/fetch storm.
- Audit 100 consecutive selections across guest/account and cold/warm contexts.
  Record load/readability, URL repeat versus same artwork versus same template,
  source mix and source age. Inspect all 163 if feasible/authorized; don't infer
  usability or unique artwork from record count. Use FEED_EXPERIENCE_AUDIT.md.
- Profile random endpoint stages: existing pool/selection timing plus response
  shaping, catalog registration, engagement queries, Redis round trips and session
  overhead. A nonempty pool means request-time provider fetching is not established
  as the delay. Measure browser time-to-usable separately.
- Reproduce ACK failures with rapid Next, prefetch, two tabs and auth return.
  Decide whether to implement privacy-bounded vitals collection or disable the
  unsupported sender; fix favicon references using an existing supported asset.

Exit: dated supply bottleneck and top experience bottleneck with denominators;
no production fix or growth claim until observed. Preserve working inventory.

### P1: Make the current pool worthwhile and navigation dependable

- Fix unreadable/cropped/broken media and wrong-content/favorite-loss defects first.
  Preserve current meme on failure; avoid jumping controls and retry storms.
- Complete reviewed coordinated unseen/reservation/ACK integration, not more
  disconnected helpers. Qualify displayed media rather than abandoned prefetch;
  preserve personalization, exact sharing/Saved recovery and old-page rollback.
- Keep honest exhaustion/replay messaging and no single-item refetch loop. Repeat
  protection cannot manufacture new supply, and visual variety can be below 163.
- Optimize measured hot-path costs before deepening prefetch. Proposed goals for
  review: warm random API p95 <500ms; median prefetched Next-to-usable <300ms on a
  declared device/network. Targets only, not current results, SLAs or hosting promises.

Exit: coordinated integration matrix and scoped real device/browser acceptance,
without regressions in identity, Save, safety, accessibility or ACK deduplication.

### P2: Grow usable novelty, not a vanity inventory counter

- Restore ordinary retained growth first if broken. Then test ONE bounded ingestion
  change: rotate community coverage OR mix approved fresh/rising/hot with weekly
  top. Respect API budgets, attribution and moderation; don't add every source/sort.
- Measure usable new URLs per cycle, visual repost proportion, source/topic balance,
  source-age distribution, broken/unreadable/unsafe rates and review effort. URL
  dedup is not art dedup; a different caption can be a worthwhile distinct meme.
- Human-sample readability and voluntary would-send judgments. "Validated" means
  structural/filter checks, not certified humor. Never relax safety to hit 1000/5000.
- Consider perceptual grouping only after a labeled sample and false-positive review;
  do not blindly discard every repeated template or store unnecessary media copies.

Exit: retained usable additions across three cycles and improved sampled novelty,
without worse safety/media/readability rates. No arbitrary count delays UX repair.

### P3: Observe users, then choose one reversible feed experiment

- Watch 5–8 target users discover something worth sending, recover/save a skipped
  item, and steer away from an unwanted topic. Obtain consent; use existing worksheet.
- Shortlist: temporary "less of this topic", explicit repeat/source controls,
  optional mood/topic entry, fresh-versus-classic choice, clearer gallery position,
  fit/zoom. Choose by observed task failure, not feature count.
- Prefer explicit reversible signals. Next is not dislike; popularity is not humor.
  Do not introduce opaque AI ranking without a baseline and evaluation.
- Primary outcomes: worthwhile discoveries per 20 usable views, voluntary would-send
  judgments, recover/save task success. Guardrails: repeats, unreadability, failures,
  latency, wrong-meme actions and unwanted content. Share-sheet opening is not delivery.

## First local execution slice

- SelectionBenchmark append/trim now uses one connection/pipeline per stage rather
  than two sequential round trips. Existing rolling-window behavior retained;
  this removes known instrumentation overhead, not proof of production latency gain.
- Unsupported /api/vitals submissions disabled; local observer diagnostics remain.
  No new browsing-path collection endpoint or privacy policy introduced. Legacy
  FID/CLS diagnostics are not a complete modern Core Web Vitals implementation.
- JS built before backend boot. Full backend 1189 examples, zero failures, seven
  pending; 75.51% (4946/6550), coverage gates pass, exit 0. Runtime 247.8s on this
  local run, not a product benchmark. All 123 frontend tests pass; 13 targeted
  timing cases pass (partial coverage exit 2); syntax/whitespace pass.
- Still open: 163-item supply diagnosis with operator, endpoint stage profiling,
  ACK 404 reproduction, favicon repair, coordinated feed integration, content/user
  audit. No production config, ingestion or feed-history semantics changed.

## Second local execution slice: missing icons

- Added lightweight original 192/512 PNG icons and 180 Apple touch PNG. Layout,
  manifest and OpenSearch dimensions now match served assets; existing favicon URL
  works. Static route regression fetches icons and verifies PNG dimensions.
- Full backend 1190 examples, zero failures, seven pending, 65.89s; 75.51%
  (4946/6550), coverage gates pass, exit 0; 123 frontend tests pass; 60 targeted SEO
  cases pass (partial coverage exit 2); syntax/whitespace pass. No JS change in this
  slice; preceding JS build remains current. No production rollout or pool growth.
- Next major work remains endpoint profiling, ACK rejection reproduction and operator
  evidence of replenishment. Icons are polish, not the feed-quality solution.

## Third local execution slice: source freshness

- Fetcher now retains valid Reddit created_utc as UTC created_at and bounded source
  post ID. Existing freshness boost can use real source age on new records; unknown
  legacy age remains unknown. No target increase, pool purge or listing-policy change.
  Replacement still prefers fetched_at when present; this does not alone fix stale
  turnover or prove improved production novelty/humor.
- Two provenance regressions, including malformed/future/nonfinite values. Full
  backend 1192 examples, zero failures, seven pending, 65.80s; 75.56% (4954/6556),
  gates pass, exit 0; 123 frontend tests pass; 10 targeted fetcher cases pass (partial
  coverage exit 2); syntax/whitespace pass. No JS changed in this slice.

## Fourth local execution slice: source-aware stale replacement

- Earlier experience fixes committed as da6a9db. Stale replacement now prioritizes
  valid source created_at, then valid fetched_at, with unknown age last. Re-fetching
  old weekly-top content no longer rejuvenates retirement priority. Existing
  non-destructive replacement safeguards retained; no inventory purged.
- This applies to target-capacity stale replacement, NOT the current undersized
  163-item expansion branch. No production replenishment/root-cause fix claimed.
- Full backend 1194 examples, zero failures, seven pending, 65.57s; 75.58%
  (4959/6561), gates pass, exit 0; 123 frontend tests pass; 10 targeted stale-refresh
  cases pass (partial coverage exit 2); syntax/whitespace pass. No JS changes.

## Fifth local execution slice: provider-yield diagnosis

- Numeric cumulative provider counters distinguish 2xx HTTP, 401/403, real 429,
  other HTTP and request/parse errors. Use per-instance deltas, not sum across tiers.
  Empty maintenance still uses protective cooldown but labels cause unconfirmed.
  No request-volume, policy, safety or provider-throttle changes; no growth claim.
- Full backend 1196 examples, zero failures, seven pending, 65.96s; 75.61%
  (4972/6576), gates pass, exit 0; 123 frontend tests pass; 22 targeted fetcher/stale
  cases pass (partial coverage exit 2); syntax/whitespace pass. Worker evidence
  remains necessary; no new diagnostics deployed yet.

## Sixth local execution slice: zero-yield distinctions

- Added missing-token call counter (no provider request); tested empty successful
  listing versus timeout. No changed listing policy, throttle or cooldown; missing
  token was already unable to fetch, blank tokens now fail early too.
- Full backend 1198 examples, zero failures, seven pending, 66.28s; 75.62%
  (4974/6578), gates pass, exit 0; 123 frontend tests pass; 14 targeted fetcher cases
  pass (partial coverage exit 2); syntax/whitespace pass. Production cause unverified.

## Seventh local execution slice: honest bootstrap diagnosis

- Empty bootstrap probes no longer assert 429 unless fetcher confirms rate limit.
  Both confirmed/unknown causes retain protective cooldown and early stop; no
  publication, fetch-volume increase or filter change. Two new regressions; an older
  test updated to explicitly simulate confirmed 429 after first full run caught it.
- Final full backend 1200 examples, zero failures, seven pending, 65.85s; 75.59%
  (4974/6580), gates pass, exit 0; 123 frontend tests pass; 11 targeted bootstrap
  cases pass (partial coverage exit 2); syntax/whitespace pass. Cause in production
  remains unconfirmed until operator maintenance/provider evidence is collected.

## Eighth local execution slice: opt-in pool freshness summary

- Read-only diagnostic adds explicit --content-summary, bounded fixed pool read,
  aggregate unique/duplicate/invalid counts and source-age buckets only. Metadata-only
  default unchanged; no URLs/titles/session histories exported. No production run.
- Full backend 1202 examples, zero failures, seven pending, 65.70s; 75.70%
  (5007/6614), gates pass, exit 0; 123 frontend tests pass; six targeted diagnostic
  cases pass (partial coverage exit 2); syntax/whitespace pass. Operator can use
  approved deployment environment to collect actual supply evidence next.

## Ninth local execution slice: mixed-record summary correctness

- Explicit per-record URL/age assignment avoids inherited state across malformed,
  missing-date or future-date records. Regression puts unknown dates immediately
  after fresh content. No production reads or inventory behavior changes.
- Full backend 1203 examples, zero failures, seven pending, 65.60s; 75.73%
  (5009/6614), gates pass, exit 0; 123 frontend tests pass; seven targeted diagnostic
  cases pass (partial coverage exit 2); syntax/whitespace pass.

## Tenth local execution slice: ACK rejection evidence

- Legacy ACK 404 now logs only malformed_id/expired_pending/missing_pending, not
  credentials/content/account data. Stale pending-map test models a lost session
  update and rejects client URL fallback; not a real multi-tab race reproduction.
  No ACK authorization/history migration or fix of session overwrites claimed.
- Initial logger expectations corrected for request-timer messages. Contaminated
  full rerun failed unrelated benchmark/auth cases; after stopping test processes
  and restarting disposable Redis, isolated full backend 1205 examples, zero
  failures, seven pending, 65.69s; 75.71% (5013/6621), gates pass, exit 0.
  Nine targeted ACK cases pass (partial coverage exit 2); 123 frontend tests pass;
  syntax/whitespace pass. No production logs collected or deployment performed.

## Guardrails

No pool purge, parallel fetch storms, disabled cooldowns, target-only increase,
blind filter relaxation, unreviewed provider expansion or private browsing telemetry.
Pause isolated helper/test expansion unless it directly resolves the measured
integration bottleneck. Security remediation, credential rotation, exact-SHA hosted
CI, capacity/privacy review and explicit deployment approval remain mandatory.
Keep provisional website 75/meme 45 scores: this excerpt warrants urgency, not a
score increase or a claim that the site was fixed. This plan changes no production state.