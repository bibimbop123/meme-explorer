# Meme Explorer: product and code audit

Date: 2026-10-15. Scope: repository inspection, targeted frontend execution,
production asset build, and attempted backend test execution. No production
traffic, visual browser testing, real-user interviews, or live performance
measurement was performed. Scores are engineering/product judgments, not
measured satisfaction or proof of production security.

## Verdict: 56 / 100 before this change

| Dimension | Earned / available | Assessment |
| --- | --- | --- |
| Core discovery and content | 13 / 20 | Real pool, anti-repeat selection, fallback media, personalization inputs; selection and impression semantics remain inconsistent. |
| Usability and accessibility | 10 / 20 | Responsive templates and shortcuts, but broken selector contracts, missing visible Next action, and error recovery that discards content. |
| Security and privacy | 7 / 20 | BCrypt, parameterized queries, middleware protections; unsafe interpolation, broad production CSP, tracked sensitive-file risk, and incomplete CSRF integration. |
| Reliability and architecture | 11 / 15 | Redis, workers, fallback paths and connection pooling; multiple overlapping paths and unsafe distributed-lock startup behavior. |
| Performance and delivery | 8 / 15 | Small JS bundle, prefetching, latency instruments; lazy-loaded hero, broad shared assets, recursive build output and no original frontend CI. |
| Quality and product measurement | 7 / 10 | Substantial RSpec inventory and retention service; local backend execution blocked and speculative requests counted as views. |
| **Total** | **56 / 100** | **Promising foundation; not yet an exceptional consumer product.** |

Do not award a higher production score just because this patch compiles.
Re-score after browser journeys and backend integration pass and engagement
data comes from genuine displayed content.

## Product thesis

Win one job: **“Give me something worth laughing at or sending to a friend,
immediately.”** The moat is a fresh, trustworthy corpus plus a learning loop
that improves a user's next recommendation—not more navigation items or
decorative motion. Optimize delight per minute, not time trapped in the app.

## Highest-severity findings

**Implementation correction:** inspection of the installed `rack-csrf` 0.1.0
source during Gate A found that it does not implement session tokens and ignores
the configured `raise`/`skip` options. It reads nonstandard Rack header keys.
The original token-contract diagnosis below was therefore incomplete. Gate A
replaces that configuration with explicit session-token middleware and client
integration. Standalone contract tests pass; full application/browser verification
remains blocked by the local native-gem environment.

### P0: release and trust

1. **Unsafe HTML interpolation.** The original AJAX escape helper only escaped
   text-node characters, not attribute quotes. Server-side random display and
   metadata templates also interpolated titles without escaping. Fixed the
   touched surfaces; audit all remaining templates and gallery helpers before
   declaring XSS eliminated. URL protocol validation is a separate requirement.
2. **CSRF client/server contract is incomplete.** `app.rb` enables Rack::CSRF;
   `public/js/modules/meme-interactions.js` and navigation's skip POST do not
   send a CSRF token. Verify the middleware's actual header/parameter contract,
   expose a token safely, and test signed-in like/save/skip with the full
   `config.ru` middleware stack. Do not solve this by disabling protection.
3. **Tracked sensitive-file risk.** Git tracks `.env.production` and
   `meme_explorer.db` despite ignore rules. Contents were not printed or
   classified in this audit. Owner should inspect privately, rotate any real
   credentials, untrack sensitive files, assess history exposure, and add
   secret scanning. Deleting the current copy does not revoke historical secrets.
4. **Local backend suite cannot boot.** BCrypt's installed extension links to
   Ruby 3.4 while the active interpreter is 3.2.1. `bundle check` succeeds but
   requiring BCrypt fails. Rebuild native gems under a single supported Ruby,
   configure an isolated test database, and rerun the complete suite. No test
   database was created and no production data was intentionally modified.

### P1: core loop correctness

5. **Like/save break after AJAX changes.** Interactions looked for `#meme-image`
   while new image markup omitted that ID; control updates used `.like-button`
   and `.save-button` while ERB rendered IDs. Fixed those contracts and added
   a canonical meme identifier on the display for video/gallery/CDN consistency.
6. **No visible Next control in the random controls partial.** Added an explicit
   Next meme button, usable without discovering a keyboard gesture.
7. **Duplicate browser history.** Both render and callers pushed entries. Removed
   caller pushes. Initial server-rendered state still needs seeding so Back
   restores the first meme without a reload; popstate must synchronize tracking.
8. **Speculative fetch is counted as consumption.** `prefetchNext()` calls
   `/random.json`; `routes/random_meme.rb` records view state/statistics during
   selection. Separate selection/prefetch from acknowledged visible impression.
   Use idempotent impression IDs and record visibility after media presentation.
9. **Startup deletes shared locks.** `config.ru` unconditionally deletes the pool
   bootstrap lock and fetch cooldown. A new process cannot assume another
   instance has no active work. Replace with owner-token leases, TTLs, and atomic
   compare-and-delete; test simultaneous deployment/worker starts.
10. **Content-destroying failures.** Navigation replaced the current meme with an
    error and forced a redirect after two seconds. Fixed to preserve content,
    announce an error, and let Next retry. Network requests still need explicit
    timeouts, cancellation and robust stale-prefetch handling.

### P1: trust, accessibility and discovery

11. **Overbroad production script trust.** `lib/middleware/security_headers.rb`
    intentionally permits `https:` and inline scripts for rotating ad domains.
    This materially weakens XSS containment. Migrate to nonce-based CSP and
    controlled ad integrations; stage in report-only mode rather than breaking
    the current application with an untested policy.
12. **Consent geography is guessed from timezone.** `public/js/cookie-consent.js`
    lists EU timezones and otherwise assumes non-EU. Timezone is not reliable
    jurisdiction/consent evidence. Prefer explicit non-essential opt-in, easy
    revocation, storage failure resilience and qualified legal review.
13. **Sharing has no strong content identity.** AJAX keeps URL `/random`; layout
    social metadata is largely generic and references an SVG preview. Build a
    stable per-meme permalink with matching title, raster preview, creator/source
    attribution and useful landing experience. Verify crawler responses.
14. **Motion and input conflicts.** Removed the full-screen pulse on each AJAX
    navigation, avoided forcing autoplay in new video markup, and guarded
    browser shortcuts/focused controls/duplicate key handling. Full keyboard
    dialog focus, reduced-motion behavior and screen-reader journeys still
    require browser validation. Existing standalone shortcut UI needs alignment.

### P2: delivery and maintainability

15. **Vite recursively copied the public root into its own child.** Build output
    overwrote unrelated tracked artifacts. Set `publicDir: false` and preserve
    other output files. Regenerated the deployed bundle and changed module
    mirrors. Existing redundant dist assets remain technical debt.
16. **Primary image loaded lazily.** Changed random-page image/GIF media to eager,
    high-priority loading. Next step: actual dimensions/aspect ratios, responsive
    sources and browser-measured LCP/CLS, not invented performance gains.
17. **Broad page-global initialization.** MemeApp initialized and prefetched on
    non-meme pages. Added a display guard. Layout still loads many independent
    scripts/styles; consolidate only after mapping ownership and dependencies.
18. **Documentation and commentary outweigh contracts.** Numerous files contain
    historical audits and unsupported impact predictions. Replace narrative
    “production grade” assertions with small modules, executable contracts and
    measurable acceptance criteria. Avoid a framework rewrite for its own sake.

## Improvements implemented in this audit

- Quote-safe AJAX escaping and targeted ERB escaping.
- Visible Next action; image/control selector and canonical identity repairs.
- Single history push per successful next/similar navigation.
- Non-destructive errors; loading `aria-busy`; stronger shortcut guards.
- Muted, non-forced-autoplay AJAX video; removal of per-navigation flash.
- Eager, high-priority primary image loading.
- No meme app initialization on unrelated pages.
- Safe Vite output configuration, regenerated assets, frontend CI test/build step.
- Seven dependency-free Node regression tests (`npm test`).

## Execution roadmap

### Gate 1 — trustworthy release

Repair Ruby/native gems, run backend tests against isolated PostgreSQL/Redis,
fix and test CSRF, assess tracked secrets, and finish output escaping/URL checks.
Browser acceptance: guest and signed-in user each browse 20 memes; like, save,
share, retry after disconnect, navigate Back/Forward, use keyboard and mobile
touch. No wrong-meme interactions, silent failures or duplicate requests.

### Gate 2 — exceptional discovery

Unify the home and next-meme selection path. Separate impressions from
prefetches. Canonicalize content IDs, deduplicate reposts, handle exhausted pools
honestly, and show useful recovery for unavailable media. Add explicit “more
like this / less like this” and source attribution before new game modes.
Keep anonymous browsing frictionless; ask for signup when saving has value.

### Gate 3 — a repeatable distribution loop

Ship stable share pages, native-share cancellation handling and collections
that are genuinely useful to revisit. Add search to discoverable navigation.
Remove empty ad placeholders unless real inventory exists. Evaluate revenue
per retained satisfied user, not revenue per intrusive impression.

### Gate 4 — measured learning

Track guest and signed-in cohorts separately, D1/D7 return, successful displayed
impressions, saves/shares per displayed meme, duplicate/unavailable-content
rates and negative feedback. Keep logged-in-only retention explicitly labeled.
Measure browser p75 LCP <= 2.5s, INP <= 200ms, CLS <= 0.1 and next-meme latency
by warm/cold cache and network class. These are targets, not observed results.
Run a controlled personalization experiment with guardrails for variety and
content safety; do not optimize only dwell time or assume every Next is dislike.

## Validation

- `npm test`: seven tests passed.
- `npm run build`: passed; existing Vite CJS API deprecation warning remains.
- Random ERB partial syntax compiled; layout requires compilation inside a
  method because its legitimate `yield` is invalid at Ruby top level.
- Backend RSpec attempt: zero examples executed; BCrypt native linkage error.
- No claim of browser-level accessibility, live speed, retention lift, full
  security clearance or complete backend coverage is made.