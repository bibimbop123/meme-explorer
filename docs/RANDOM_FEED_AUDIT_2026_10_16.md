# Random feed: repetition audit and corrective plan

Trigger: user repeatedly sees the same memes. Code audit, not a confirmed diagnosis
of the current production instance. No production configuration/deployment changed.

Detailed next-step plan: [anti-repeat execution](ANTI_REPEAT_EXECUTION_PLAN.md).

## Findings, ordered by user harm

1. Homepage selected via pool.sample instead of the live unseen-aware selector.
   Reload/home visits therefore ignored selection history.
2. SimpleMemeSelector cleared all history on exhaustion. This erased recent memory
   and allowed immediate replays from the whole weighted pool; popular content could
   recur quickly. Same-second scores also made “recent” order ambiguous.
3. History retained 200 selections for two hours, below the 5,000 URL inventory
   target. Longer sessions/returns could repeat without full-pool coverage.
4. Prefetch and selection mark history before actual acknowledged display; routes
   also mark selections again. Unseen means not recently selected, not not viewed.
   Homepage now participates, but exact-recipient visits still need a shared policy.
5. Candidate supply repeatedly starts at top/week pages, with only two bounded
   pages. Larger targets cannot invent new content. Current production inventory,
   scheduler/OAuth outcomes and retained growth are still unverified.
6. URL identity misses same artwork at different URLs; template reuse is not always
   a duplicate. Global engagement weights can concentrate exposure. Neither can be
   repaired by silently resetting history or blindly increasing ingestion volume.
7. Redis failure/eviction, session changes, parallel requests and identical visual
   reposts remain repeat risks. There is no atomic per-viewer selection reservation.

## Implemented locally

- Homepage uses the same selector as random feed.
- URL/file identity deduplication before selection; selected metadata is copied,
  not written into shared pool records.
- Exhaustion retains history and selects the least-recently-selected eligible item;
  no wholesale history reset. New URLs remain preferred over replay.
- History bounded at 5,000 entries with seven-day sliding TTL; fractional timestamps
  reduce same-second ordering ties. This is a deliberate retention/memory increase,
  not cross-device tracking; explicit clear_history still works. Review privacy,
  Redis memory/eviction and key counts before rollout. Exact timestamp ties and
  concurrent selections are still possible.
- Exhaustion is exposed in JSON and a visible viewer notice; stale browser operations
  cannot overwrite it. Single-item pools cannot provide a different next meme.
  Replays are least-recently selected, not claimed genuinely fresh.

## iFunny comparison: product principles, not proprietary code

Public [iFunny App Store listing](https://apps.apple.com/us/app/ifunny-funny-videos-memes-gifs/id429610587)
describes fresh featured content and topical categories (animals, games/anime,
wholesome, etc.). That supports comparing freshness and explicit topical choice,
not asserting its inventory size, ranking implementation or no-repeat guarantees.
iFunny's web FAQ returned 401 during this audit. No internal library/source/API
was accessed and no scraping/import integration is proposed.

| Product principle | Meme Explorer response |
| --- | --- |
| A reason to return for new content | Measure retained new eligible URLs/source age across normal jobs; do not relabel replays fresh |
| Discoverable topical choice | Improve existing Search/community discovery before elaborate personalized ranking |
| Feed should feel like progress | Unseen-first, stable replay order, honest exhausted notice; then bounded acknowledged-view reservations |
| Worth sending beats time spent | Audit readability, visual repeats and voluntary would-send value; avoid forced endless engagement |

## Revised priorities

1. Validate and review this anti-repeat change; test real guest/account sessions with
   small and grown pools, reloads, prefetch, history and Redis outages. Deploy only
   after security remediation/CI and separate approval; existing security gate fails.
2. Verify live supply and production sharing-origin blocker. Track actual eligible
   unique URLs/replay frequency and visual repeats separately. No pool purge.
3. Separate short-lived speculative reservations from acknowledged-view history;
   define release/expiry/failed-media behavior and multi-tab concurrency, with tests.
4. Audit consecutive real feed and observe users. If identical artwork dominates,
   evaluate perceptual matching offline with caption-edit safeguards; do not change
   share/Saved identities or fetch arbitrary URLs server-side without SSRF defenses.
5. Only then test bounded source rotation/source-concentration or optional topic
   controls, one reversible experiment with baseline/guardrails. No ranking rebuild,
   collections or cosmetic redesign as a substitute for fixing repetition.

## Validation

Phase 1 follow-up: Set membership avoids repeated linear scans; seven-day entry
pruning added on history reads/writes. Two homepage/session integration cases and
one active-key age-pruning regression added. Full post-build backend **1049 examples,
zero failures, seven pending**, 58.87s, **74.14% (4582/6180)**, gates pass, exit 0.
120 frontend tests and build pass. Four guest/Save-Data Chrome three-item assertions
pass; account/prefetch-enabled and broader matrix remain open. See execution plan
for local latency/memory measurements and remaining capacity/privacy approval.

24 targeted selector/history examples pass (partial coverage exit 2). Full backend
under the current local security-patch bundle, rerun after final build: **1046
examples, zero failures, seven pending**, 57.77s; **74.12% coverage (4577/6175)**,
gates pass, exit 0. **120 frontend tests pass**, Vite build, Ruby syntax and whitespace
pass. No real-device/browser pass of this change yet. Scores unchanged.