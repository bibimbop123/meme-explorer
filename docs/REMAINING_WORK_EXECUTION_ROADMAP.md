# Remaining work: evidence-led execution roadmap

## Purpose and status

This is the current delivery sequence for remaining work. It supersedes older
next-action ordering, not historical evidence, security requirements or protocol
contracts. Estimates are focused engineering days, not dates or commitments.
Operator approvals, participant recruitment and external services add elapsed time.

### Baseline

- UX implementation: `72a8fe4`; operator reports deployment. Public HTML markers
  and three frontend assets matched the candidate. Full deployed web/worker SHAs
  still require operator verification.
- Production evidence includes one completed maintenance batch: 162 -> 1,047
  retained records, 885 candidate new unique URLs, publication succeeded. This
  proves one completion, not sustained freshness, visual diversity or current size.
- Local uncommitted follow-up: searchable initial community and honest “unseen”
  inventory wording. Latest isolated validation: 1,210 backend examples, zero
  failures, seven pending, 75.80% coverage; 141 frontend tests; build passed.
- Legacy feed routes still mark selection-time history; reservation/ACK/traversal
  prerequisites exist but are not coordinated into the live feed path.
- Accounts are not active people. No validated retention or user-satisfaction
  baseline exists. Historical quality scores are not acceptance criteria.

## Delivery order

| Stage | Priority | Indicative effort | Result required before moving on |
| --- | --- | --- | --- |
| 0. Close release and security gates | P0 | 1–2 days | Known deployed revision, acceptance record, no critical journey failures |
| 1. Measure supply, content and user friction | P0, parallel with stage 0 | 2–4 days plus recruitment | Three ordinary cycles, 100-selection audit, 5–8 observed users |
| 2. Fix the highest-impact reliability/performance bottleneck | P1 | 2–4 days | Reproduced failure or measured bottleneck, small verified fix |
| 3. Integrate feed protocol behind a default-off flag | P1 | 5–8 days | End-to-end protocol invariants, rollback and controlled canary evidence |
| 4. Run one content-quality experiment | P1 | 2–4 days plus observation | Measured benefit without reliability or diversity regression |
| 5. Deliver secure account recovery | P1, can run in parallel after provider decision | 3–5 days | End-to-end reset delivery and abuse/security acceptance |

Do not serialize research behind infrastructure work. Stage 1 begins immediately;
its findings select stage 2's first fix. Stage 4 may precede stage 3 only if it does
not depend on ACK/view-history semantics and passes the same release gates.

## Stage 0 — Make the current release trustworthy

**Driver:** engineering; **operator:** deployment, credentials and environment.

1. Review and obtain commit approval for the local metadata quick wins. Keep the
   existing release-evidence documentation changes distinct from shipped claims.
2. Record actual deployed web/worker SHAs, intended Redis/database alignment,
   worker heartbeat and previous known-good web revision. Do not print URLs with
   credentials. Check region/internal Redis routing and resource metrics before
   changing timeouts or concurrency.
3. Execute the [release checklist](UX_RELEASE_CANDIDATE.md) with an operator-owned
   test account in isolated staging: mobile/desktop, true 200% zoom, screen reader,
   reduced motion, real images/video/galleries and consent/ad combinations.
4. Complete real Reddit OAuth through an approved callback; test cancelled/failed
   login and exact-meme save continuity. Verify exact-share metadata and an actual
   recipient/platform preview; do not assume asset matches prove backend behavior.
5. Verify credential rotation privately and hosted CI at the intended release SHA.

**Exit:** every check has SHA/environment/browser/result; no wrong-content action,
false save confirmation, hidden focus or blocked core control. Critical failures
block rollout. Deferred noncritical issues have an owner and explicit acceptance.
Redis eviction policy is a separate operational decision: assess shared cache/job
memory needs and isolation before changing policy; never blindly clear Redis.

## Stage 1 — Establish an experience baseline

**Supply lane (operator + engineering)**

- Observe three consecutive ordinary scheduled maintenance cycles without extra
  enqueue/direct runs. Record fetch, validation, unique additions, publication,
  retained read-back count, duration, cooldown/lease outcome and provider counters.
- Use bounded aggregate inventory summaries to distinguish source age, duplicates
  and malformed records. Cumulative provider snapshots must not be summed.
- Explain each no-op/error; only change fetch policy after the loss stage is known.

**Content lane (product/reviewer)**

- Audit 100 ordinary selections across guest/returning sessions, noting requested
  versus actually visible content. Mark readable, unavailable, source-age-known,
  repeated URL, repeated artwork and topic/source concentration separately.
- Record audit boundaries and limitations. Do not export raw session histories or
  account identifiers; keep any necessary content examples access-controlled.

**User lane (product + engineering)**

- Observe 5–8 target users without coaching: find something worthwhile, go back,
  save after signing in, recover a favorite, share and steer discovery with Search.
- Record completion, hesitation, errors, device and brief consented feedback.
  Small studies identify friction; they do not establish population growth.

**Exit:** one concise baseline report ranks the top three problems by observed
impact, confidence and effort, and chooses exactly one next intervention. A larger
pool or more accounts alone does not pass this gate.

## Stage 2 — Fix measured reliability and latency

1. Reproduce overlapping requests/multi-tab navigation using real session writes.
   Correlate privacy-safe ACK rejection reasons; distinguish malformed, expired and
   lost pending state. Existing synthetic lost-map tests are not race reproduction.
2. Profile random endpoint stages after selection: engagement lookup, catalog/
   impression work, Redis calls and serialization. Separately measure media-ready
   time in the browser; server response time is not readable-content time.
3. Apply the smallest fix to the dominant failure/latency source, with a regression
   that failed beforehand. Preserve exact-content actions, retries and auth checks.

**Acceptance:** controlled race scenarios no longer lose legitimate state or apply
actions to wrong content; unauthorized ACKs remain rejected. Record before/after
p50/p95 and errors under the same workload. Agree a numeric budget from the baseline
before optimization; do not invent field p95 from a handful of requests.

## Stage 3 — Coordinated feed migration, not more disconnected helpers

Use [migration contract](FEED_MIGRATION_CONTRACT.md) and
[reservation protocol](FEED_RESERVATION_PROTOCOL.md) as authoritative invariants.

1. Map routes, JSON builder/parser, selection/reservation, media snapshots,
   prefetch, navigation cancellation, history and ACK authorization end to end.
2. Add a default-off integration flag with the existing feed as the rollback path.
3. Prove contract behavior: selecting/prefetching alone is not a viewed commit;
   exact authorized ACK commits at most once; concurrent navigation preserves
   identity; expired/malformed credentials cannot change history; snapshot limits
   and traversal ordering remain bounded under churn and failure.
4. Test real Redis/session concurrency and old/new client behavior. Run full gates,
   staging journeys, fault injection and resource/privacy review.
5. Operator-approved small canary only after staging passes. Define sample window,
   error/latency budgets and stop thresholds before enabling; compare with baseline.

**Exit:** linked end-to-end evidence, not just helper tests; no wrong-content or
unauthorized mutations, acceptable duplicate/ACK/latency outcomes, and a verified
disable/redeploy procedure. If correctness regresses, disable the flag first and
preserve data/evidence. No broad rollout merely because unit tests pass.

## Stage 4 — One reversible quality experiment

Choose from the stage 1 report: source-age rotation, repeat-artwork handling,
source/topic controls, or media readability. Do not implement all at once.

- Write hypothesis, eligible audience, measurement window, baseline, success rule,
  safety limits and rollback flag before coding.
- Evaluate usable novelty, readability, concentration and explicit user feedback.
  Next is navigation, not dislike; views are exposure, not proof of humor.
- Ship only if the targeted outcome improves without material media, latency,
  privacy, diversity or exact-content recovery regressions. Repeat the audit and
  user tasks; retain or revert based on evidence.

## Stage 5 — Secure password recovery

**Dependency:** operator chooses/configures a supported transactional email provider
and verified sender; confirm development/staging delivery before adding UI promises.

- Persist only hashed, cryptographically random, expiring, single-use tokens.
- Rate-limit requests/redemption, use non-enumerating responses and redact logs.
- Require CSRF where applicable, validate the new password, consume tokens
  atomically, and invalidate relevant sessions after reset.
- Test missing/expired/replayed tokens, concurrent redemption, delivery failure,
  abuse limits, account enumeration and successful end-to-end email delivery.

**Exit:** operator-owned account can recover securely; failed delivery never claims
an email was delivered. Until then, do not restore the inert “Forgot?” link.

## Shared release discipline

- Each slice: reproduce/baseline -> bounded change -> regression tests -> frontend
  build before backend boot -> non-overlapping isolated full suites -> review ->
  explicit commit/push/deploy approvals -> smoke/observation -> retain or revert.
- No pool purge, lease deletion, fetch storms, blind filter relaxation or target-only
  increase. Preserve cooldowns, existing inventory and privacy-safe diagnostics.
- Never log passwords, OAuth codes, Redis credentials or user-email inventories.
- Keep a single evidence ledger with revision, environment, command/task, result,
  limitation and next action. Link historical plans rather than overwriting them.

## Start here: next three deliverables

Execution record and collection instructions:
[experience acceptance ledger](EXPERIENCE_ACCEPTANCE_LEDGER.md).

1. **Acceptance record:** operator confirms deployed SHAs and completes zoom,
   screen-reader, real OAuth and recipient-preview checks.
2. **Baseline report:** three maintenance cycles + 100-selection audit + scheduled
   5–8-user sessions, with one ranked intervention recommendation.
3. **Measured fix:** reproduce the highest-impact ACK/navigation failure or profile
   the dominant post-selection bottleneck, then deliver one regression-backed fix.

Defer social features, more gamification, more providers and major UI redesigns
until these deliverables show they address a real unmet need.