# Meme Explorer: product and code audit — 2026-10-17

## Verdict: 66 / 100

An increasingly reliable meme viewer, not yet a differentiated entertainment
product. The next breakthrough should be better content and user control, not
another feature layer. Product principle: **find something worth laughing at or
sending to a friend, immediately, and recover it easily later.**

This is an independent engineering/product judgment, not a measured satisfaction
score or a claim to know FunCorp's internal practices. Scope: code inspection,
current local tests, build, native dependency diagnostics and dependency audits.
No new live-browser, production, screen-reader, real-user or retention experiment
was performed. Historical browser evidence is recorded in the acceptance ledger;
it is not fresh acceptance of this change. The older 56/100 audit used a different
rubric, so the difference is not a measured ten-point improvement.

| Dimension | Score | Assessment |
| --- | ---: | --- |
| Content quality, freshness and discovery | 13/25 | Real supply pipeline and anti-repeat history, but no current reviewed visible-content baseline; URL uniqueness is not artwork uniqueness. |
| Core viewing UX and accessibility | 15/20 | Explicit navigation, history, media recovery, theme and keyboard support. Mobile gesture defects found; full zoom/screen-reader/device acceptance incomplete. |
| Relevance and user agency | 7/15 | Signed-in subreddit preferences influence ranking; limited guest learning and no visible less-like-this, mute-source or report control in the core controls. |
| Sharing, saving and return loop | 11/15 | Exact links, save/auth continuation and favorites detail are substantial strengths; dead secondary personalization routes undermine completeness. |
| Reliability, architecture and delivery | 13/15 | Broad passing tests, Redis leases, bounded supply work and accounting contracts; disabled repair rollout and fragmented scripts/styles need operational acceptance. |
| Security, privacy and measurement | 7/10 | CSRF, password hashing and security tests exist; fresh dependency advisories, permissive production CSP and limited outcome measurement prevent stronger confidence. |
| **Total** | **66/100** | **Good foundation; release gates and content-market fit remain open.** |

Do not increase this score merely because this patch passes tests. Re-score from
visible-content review, observed user tasks, deployed reliability and retention.

## What is working

- Root selection now uses the shared selector rather than trusting a stale local
  cache (`routes/home.rb`). Do not repeat the older audit's already-fixed diagnosis.
- Exact-meme identity is taken seriously across sharing, saving and recent history.
- Current media is preserved during navigation failures; recovery is preferable
  to destroying the content a person was about to save/share.
- Discovery works anonymously; save/auth continuation can preserve the exact meme.
- Signed-in likes/saves feed subreddit preferences into `SimpleMemeSelector`.
- Backend tests exercise concurrency, Redis failure, pool publication, auth,
  escaping and media recovery, not only happy paths.
- Current production JS bundle is 56.31 kB / 16.55 kB gzip. This is a build size,
  not total page weight or observed browser performance.

## Findings and required action

### P0 — address before treating this as release-ready

1. **Dependency audit fails.** A fresh standalone `bundler-audit check --update`
   reported 19 advisory entries across activesupport, faraday, httparty, json,
   jwt, oauth2, puma and sqlite3. Multiple entries can describe related issues;
   this is not 19 independently proven exploitable application vulnerabilities.
   SQLite is development-only. Review advisory conditions and compatible patch
   batches; Puma needs a separately reviewed major-version/server change under
   the current Gemfile constraint. Preserve security gates. See the dependency
   remediation document, not a blanket automatic upgrade.
2. **Production CSP is permissive.** `lib/middleware/security_headers.rb` allows
   HTTPS script origins and inline scripts. The nonce-based stricter policy is
   report-only, not enforced protection. Inventory actual ads/inline handlers,
   validate reports and stage enforcement; do not claim nonce markup alone
   fixes XSS. Treat third-party ad code as a trust/performance dependency.
3. **Sensitive artifacts remain tracked.** Git lists `.env.production` and
   `meme_explorer.db`. Presence alone does not prove active secret exposure;
   inspect privately, rotate any live credentials, remove unnecessary tracked
   artifacts and review history. No secret values were read or copied here.
4. **Impression repair is not rollout-approved by tests alone.** The committed
   `feed.legacy_pending_store` flag remains false. The acceptance ledger records
   local race/rollback work and operational limits. Validate representative
   deployment, concurrency, Redis budgets and rollback before enabling it.
   Selection history is not a reliable confirmed-display denominator.

### P1 — product defects and high-leverage gaps

5. **Site-wide swipes could hijack unrelated pages — fixed in this audit.**
   `mobile-swipe.js` attached document listeners without a viewer guard and
   fell back to `/random`. It used x=0 as “no touch,” lacked touchcancel handling,
   accepted unsafe multi-touch state, and could intercept diagonal scrolling,
   video controls and editable content. The change scopes gesture starts to
   the viewer, preserves native/interactive gestures, cancels safely, removes
   fallback redirects and makes setup/cleanup repeatable. Five VM-based
   regression tests cover the contract; physical-device acceptance remains open.
6. **Registered secondary routes reference missing code.**
   `routes/personalization.rb` calls `PersonalizationService` in `/taste-evolution`
   and `/saved`; no service definition exists in the inspected runtime source.
   `/saved` also renders absent `views/saved_memes.erb`. Authenticated execution
   reaches invalid dependencies. `/profile` and `/saved/:id` are the implemented
   favorites paths. Consolidate `/saved` onto `/profile`; explicitly retire or
   implement taste insights with route tests. Do not invent insights to fill UI.
7. **The content-quality baseline is still missing from this audit.** Historical
   inventory has thousands of URLs, but cannot establish humor, readability,
   novelty or available media. Review 100 actually displayed selections across
   time windows, guest/returning sessions and mobile/desktop. Double-review 20;
   distinguish source-post age from artwork age and exact from near duplicates.
8. **Freshness may be supply-limited rather than ranking-limited.** Existing
   content-quality notes record a maintenance batch with zero new unique URLs.
   Check ordinary maintenance novelty yield before adding more sources or more
   ranking complexity. Experiment with bounded fresh/hot supply separately from
   ranking, preserving budget, moderation and weekly-top rollback.
9. **Users cannot clearly teach the product what to avoid.** Core controls offer
   Like/Save/Share/Download, not an explicit negative preference or safety report.
   Put “Not my taste,” “Hide this source,” and “Report” in a compact More menu,
   with honest confirmation and undo. A report needs a real moderation queue,
   reason taxonomy, abuse controls and review workflow—not a cosmetic toast.
10. **Preference evidence is coarse and one-way.** Subreddit weighting is not
    demonstrated humor understanding. `EngagementService.track_like` adds a
    preference increment on a like without decrementing on unlike. Audit
    like/unlike cycles and write atomicity before treating that score as durable
    taste. Do not classify every Next as a dislike or every dwell as enjoyment.
11. **Return-rate measurement excludes guests.** `RetentionService` explicitly
    measures signed-in users; daily first-to-last activity is a duration proxy,
    not real sessions. Label both honestly. Any guest cohort identifier needs
    privacy/consent/retention review; do not introduce fingerprinting to get D7.

### P2 — simplify after core acceptance

12. **Fragmented frontend ownership.** The layout loads numerous standalone
    scripts/styles alongside Vite. Duplicate initialization has caused previous
    failures; keep an ownership map, page-scope features, consolidate only with
    regression coverage. The swipe change remains standalone and is not also
    imported into the bundle.
13. **Build configuration documentation was stale.** Follow-up inspection confirms
    the current Render web blueprint builds frontend assets with npm; the older
    README incorrectly said it did not. `public/dist` is still committed. Verify
    dashboard settings actually match the blueprint and check tracked artifact
    reproducibility in CI. Blueprint configuration alone does not prove deployment.
14. **Passing route tests do not establish good journeys.** Some existing
    assertions accept either success or redirect and merely nonempty content.
    Add authenticated secondary-route contracts and real-browser critical paths.
    Seven backend tests remain pending against a removed diversity service;
    replace them with current-selector acceptance rather than hiding the gap.
15. **Documentation is not operational evidence.** Historical predictions,
    repeated audit narratives and stale file comments obscure current behavior.
    Keep one current status index and executable gates. Avoid another rewrite,
    leaderboard layer or gamification system while core outcomes are unproven.

## FunCorp-style product direction

**Make the meme the product.** Preserve complete artwork, readable captions,
native zoom and playback controls. Navigation should be reachable by thumb,
keyboard and assistive technology without ads covering media or actions.

**Optimize for worthwhile discoveries, not trapped attention.** The outcome
metric should combine genuine displayed-content satisfaction, save/share intent
and return. A share-sheet opening is not a completed share; a canceled native
share is not success. Do not silently claim otherwise.

**Teach taste with minimal friction.** Keep immediate guest browsing. Offer an
optional topic chooser and session-only negative feedback first; clearly separate
temporary versus account-persistent preferences. Maintain an exploration budget
and measure source/topic variety so personalization does not collapse the feed.

**Build distribution around exact content.** Make a received link useful on its
own: readable meme, attribution, clear unavailable state, no forced signup and an
obvious next discovery. Validate real link previews and guest-to-save recovery.
Only add collections/digests once people demonstrably return to favorites.

**Earn monetization after delight.** Run with/without-ad journey checks. No
popunders, surprise navigation or overlays blocking actions. Audit ad-induced
layout shifts and interaction delay, not only first-party bundle size.

## Prioritized execution order

| Order | Deliverable | Acceptance |
| --- | --- | --- |
| 1 | Security remediation and broken-route repair | Fresh security gate green; explicit authenticated contracts; no fabricated insights. |
| 2 | Mobile/browser release acceptance | 320/375px, desktop, 200% zoom, themes, reduced motion, keyboard/screen reader; image/video/gallery; swipe/scroll/pinch; ads on/off; no wrong-meme actions. |
| 3 | Content baseline and 5–8 observed target-user sessions | Record time to first worthwhile meme, readability, repeats, availability, share/save recovery and user explanations. Small sample is diagnostic, not retention proof. |
| 4 | One evidence-selected content experiment | Change freshness OR diversity OR duplicate suppression, not all together; compare against baseline and retain rollback. |
| 5 | Negative feedback and honest learning | Working undo, clear persistence, real reporting pipeline, no automatic dislike from Next. |
| 6 | Outcome instrumentation and controlled relevance test | Confirmed displays, missing-data states, save/share definitions, guest/signed-in cohorts, D1/D7 with uncertainty and privacy review. |

Proposed targets, **not measurements**: p75 LCP <=2.5s, INP <=200ms, CLS <=0.1;
>=98% available and >=95% readable media in a reviewed pilot; zero wrong-meme
save/share actions; materially fewer visual repeats without sacrificing variety
or safety. Set latency and retention thresholds from representative baselines,
not local fixture timing or arbitrary growth promises.

## Changes and validation in this pass

- Changed only mobile gesture behavior and added regression tests; no feed
  rollout flags, dependencies, schema, credentials or production state changed.
- Frontend: baseline 143 passing; final **148 passing**, zero skipped/failing.
- Backend: **1,298 examples, zero failures, seven pending**, 77.24% coverage
  (5,246/6,792 lines), with isolated Bundler, local test PostgreSQL and disposable
  Redis at port 16379. Existing test DB is intended to be cleaned by the suite;
  no production services were selected.
- Native dependency diagnostics passed with the isolated Ruby 3.2.1 wrapper.
- Vite build passed; existing CJS API deprecation warning remains. Build produced
  no tracked bundle diff because this standalone script is not bundled.
- `node --check` and `git diff --check` passed.
- `npm audit` including development dependencies reported zero vulnerabilities.
  This does not cover Ruby or prove application security.
- Fresh Ruby audit reported vulnerabilities; release security gate remains open.
  Advisory database advanced to `fa22952` during this run. Local raw report:
  `/tmp/meme-product-audit-security.log` (temporary, not a committed artifact).
- Physical-device gestures, browser accessibility, new production measurements,
  exploitability assessment and humor/relevance studies remain unverified.