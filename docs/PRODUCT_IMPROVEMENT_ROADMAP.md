# Product improvement roadmap: 66 → 90

Status: execution started 2026-10-17. Scores are provisional judgments, not
measured satisfaction. Targets require acceptance evidence, not completed tickets.
This is the product prioritization index; the execution roadmap, feed contracts,
security diagnosis and acceptance ledger retain their technical/release authority.

## Scorecard

| Dimension | Baseline | Target | Evidence required |
| --- | ---: | ---: | --- |
| Content quality, freshness, discovery | 13/25 | 22/25 | Reviewed novelty/readability, sustainable supply, worthwhile discoveries |
| Viewing UX/accessibility | 15/20 | 18/20 | Real-device, keyboard, zoom and screen-reader journeys |
| Personalization/user control | 7/15 | 13/15 | Reversible steering and improved rated relevance without diversity collapse |
| Sharing/saving/return | 11/15 | 14/15 | Exact-content journeys, useful previews and observed recovery/return |
| Reliability/architecture/delivery | 13/15 | 14/15 | Deployed correctness, resource budgets, rollback and reproducible artifacts |
| Security/privacy/measurement | 7/10 | 9/10 | Fresh security gate, privacy review and honest outcome denominators |
| **Total** | **66/100** | **90/100** | **No automatic score increases** |

## Delivery sequence

Effort estimates are focused engineering time, not calendar promises. Recruitment,
provider approvals, observation and security compatibility add elapsed time.

| Phase | Indicative effort | Deliverable / exit gate |
| --- | --- | --- |
| 1. Trustworthy baseline | 1–2 weeks; research in parallel | Dependency remediation, private credential assessment, broken-route repair, metric dictionary; 100 visible selections, 5–8 observed users, three ordinary supply cycles |
| 2. Effortless viewing | 1–2 weeks | Audit-selected readability/recovery fixes; 320/375px, desktop, true 200% zoom, themes, reduced motion, screen reader, native touch/media and ads on/off pass |
| 3. Better content supply | 2–4 weeks across separate experiments | One baseline-selected freshness, duplicate or diversity intervention at a time; reviewed benefit, guardrails and rollback |
| 4. Agency before opaque learning | 2–3 weeks plus evaluation | One explicit preference control with Undo/reset and persistence disclosure; sound like/unlike signals; real reporting workflow; controlled relevance comparison |
| 5. Share/save/return loop | 1–2 weeks plus preview checks | Received links useful without signup; exact save/auth/recovery; honest sharing outcomes; collections/digests only if research supports demand |
| 6. Boring delivery, credible measurement | Throughout | Feed migration operational acceptance, critical-path browser checks, deployed revisions, resource budgets, stricter CSP rollout and privacy-reviewed cohorts |

### Phase 1: current batch

- [x] Replace `/saved`'s missing service/template with authenticated `/profile` redirect.
- [x] Explicitly retire unsupported taste insights with authenticated HTTP 410 and useful alternatives.
- [x] Add route contracts, including guest/JSON authorization and favorites continuity.
- [x] Correct README: Render web blueprint already builds frontend assets; actual dashboard settings still need verification.
- [x] Add private research worksheet and participant task script, reusing the existing offline summary tool.
- [x] Extend offline summary with joint session/device coverage, unknown judgments
  and explicit manual-review requirements; row count alone is not acceptance.
- [ ] Complete reviewed dependency batches and fresh hosted test/security gates.
  Local Puma 7.2.1 scan now reports zero findings; transport checks pass. Hosted
  gates and actual-app/platform shutdown acceptance remain open. See
  [Puma acceptance](PUMA_7_ACCEPTANCE.md).
  Follow-up: 12 actual-app local middleware/drain checks now pass with direct
  Puma; Render Rackup/platform, hosted gates and browser acceptance remain open.
- [ ] Privately assess/rotate exposed credentials and tracked artifacts with operator involvement.
- [ ] Collect real content/user/supply baseline; do not fabricate observations.
- [ ] Ratify measurement definitions and operational rollout/stop thresholds.

### Phase 2: proposed acceptance

Local [browser image-fixture acceptance](BROWSER_UX_ACCEPTANCE_2026_10_17.md)
now passes 42 checks across widths, keyboard, theme and emulated touch. True zoom,
screen reader, physical devices, video/gallery, ads and real-content review remain
open. No score increase or full phase completion implied.

Media follow-up extends this to 50 checks and fixes reproduced vertical-gallery
gesture capture and nested-video-source error recovery. Successful video decoding,
physical devices, ads, actual zoom, assistive technology and real content remain open.

Latest follow-up: 60 browser checks now include successful synthetic silent WebM
playback/seek/position recovery and dynamic-gallery touch/position recovery.
Cross-codec/browser/device, ads, true zoom and assistive technology remain open.

Accessibility follow-up: 66 browser checks; fixed inactive server slides exposed
in AX tree, non-keyboard indicators, missing slide-status semantics and gallery
reduced-motion transitions. Real zoom/screen-reader/device acceptance remains open.

Keyboard follow-up: 78 browser checks; skip-to-content now focuses main without
triggering fragment/popstate meme navigation, and Tab continues into viewer controls.
All action-focus/sticky-obscuration, true zoom and screen-reader acceptance remain open.

Action-group follow-up: 126 browser checks, including visible focus, bounds and
center hit for four actions in both themes across three widths. No new defect;
all-state/overlay/tall-media/zoom/screen-reader acceptance remains open. Next prioritize
real content/user baseline and manual/platform gates, not assertion-count growth.

Preserve artwork and punchlines; add full-size viewing if observation demonstrates
need. Separate gallery from feed controls. No audible autoplay, blocked native zoom,
stranded focus, wrong-meme mutation or navigation caused by page scrolling.

Pilot targets: >=98% usable media and >=95% normally readable media in reviewed
selections, reporting raw denominators/unknowns. Deterministic fixtures must have
zero clipped punchlines or blocked core controls. Targets are not production SLAs.

### Phase 3: experiment order selected by baseline

1. If freshness/supply novelty dominates, test replacing about 10% of the existing
   listing budget with newest listings. No increased request budget; preserve
   throttling, retained inventory and weekly-top rollback. Review safety and quality.
2. If artwork repeats dominate, label exact/near duplicates offline, measure false
   matches on caption variants/crops/galleries, then consider bounded background
   analysis. Never hash/download every image synchronously on Next.
3. If source concentration dominates, test a bounded diversity constraint with
   honest scarcity/reset. Optional topic entries must reflect available inventory.

Predeclare audience, baseline, window, success, stop conditions and rollback. A
candidate repeat target is 25% relative reduction when baseline repeats >=10%;
retain media/readability/diversity/safety guardrails. Small samples are diagnostic.

### Phase 4: control and learning contracts

Signal-integrity slice: sequential re-likes of the same user/media now reuse
existing liked_at evidence instead of repeatedly increasing community preference.
Real-route regression cycles unlike/re-like and verifies a different meme still
contributes. This preserves the existing historical-positive interpretation, not
current-active-like preference semantics. No historical score repair, retry-safe
toggle API, concurrency guarantee or relevance benefit claimed. Account write
atomicity and idempotent desired-state client/API remain separate work.

Follow-up implementation: `/like` accepts optional boolean `liked`; bundled client
sends desired state, legacy missing-state requests still toggle. Signed-in membership
and engagement writes run under one PostgreSQL transaction locked on the media stats
row; repeated desired states return unchanged without extra engagement writes.
Guest desired states are session-based, not a multi-tab/session race guarantee.
No optimistic concurrency/version ordering: conflicting intents serialize in DB
arrival order. Existing internal direct track_like callers are outside this boundary.
Test/acceptance results are recorded in the ledger; no automatic rollout/score claim.

Actual-stack HTTP follow-up passes repeated true/false desired-state and CSRF/input
boundaries (19 total app-server checks). Additional backend regression injects a
swallowed SQL error after writes begin and requires membership/count/preferences
to roll back. Browser-button mutation acceptance remains distinct and open.

Guest browser follow-up now covers DOM button listeners, lost successful response
retry without double count, explicit unlike, late-response isolation and Previous
state recovery (132 total browser checks). Signed-in browser, concurrent guests,
physical-pointer and broader failure schedules remain separate acceptance work.

Signed-in browser follow-up: opt-in disposable signup/session, Like listener,
profile continuity, unlike cleanup and logout protection pass (138 total checks).
Not real form typing, exact-meme reload, multi-tab or cross-device acceptance.

Choose “less from this community” OR “more of this topic” first. Provide Undo,
reset, visible constraints, session/account scope and explicit exhaustion; never
silently bypass exclusions. Next is not dislike. Cap boosts and retain exploration.
Review like/unlike accumulation and atomicity before extending preference scoring.

A report control requires taxonomy, storage, abuse protection, privacy handling,
moderation responsibility and a review queue. No cosmetic success toast. Initial
steering usability target: >=4/5 unaided participants, reporting all actual counts.
A larger relevance comparison must improve rated worth without diversity collapse.

### Phase 5: exact distribution and return

Test selected messaging/social previews; unavailable media remains useful and
honest. Share initiation is not completed delivery; cancellation is not success.
Verify discover→share→reopen and save→login/signup→recover with failure/retry,
refresh and removed content. Define account recovery before expanding return loops.
Notifications/digests must be opt-in with easy withdrawal and proven user value.

### Phase 6: security, delivery and measurement

Coordinate ACK/confirmed-view integration with existing contracts. Local fixtures
do not approve rollout. Agree resource/error/latency budgets, rollback and canary
scope first. Keep `feed.legacy_pending_store` unchanged until operational acceptance.
Prevent frontend drift, inventory script ownership, replace removed-service pending
tests and add browser critical paths incrementally. No framework rewrite needed.

Stage CSP after reports and inline-handler cleanup; review third-party ad trust.
Keep security gates enforced. Define data purposes/retention/deletion and consent;
do not fingerprint guests to obtain retention numbers.

| Outcome | Definition / caution |
| --- | --- |
| Worthwhile-content rate | Explicit worthwhile ratings / rated displayed content; not all impressions |
| Time to first worthwhile meme | Consented observed task time; report failures/timeouts |
| Visual-repeat rate | Repeated artwork / reviewed displayed selections; separate exact/near and within/cross-session |
| Available/readable media | Usable/readable reviewed selections, with unknowns and raw counts |
| Supply novelty | Eligible/new/published/retained counts per ordinary cycle; URL novelty is not artwork novelty |
| Saves | Persisted saves / valid displayed-content denominator; separate guests/account flow |
| Share intent | Initiation, copy success, cancellation and failures separately; do not claim delivery |
| Return | D1/D7 with cohort eligibility/observable identity and uncertainty; signed-in != all users |
| Browser performance | p75 LCP <=2.5s, INP <=200ms, CLS <=0.1; usable-media time separate from route latency |

Performance values are proposed targets, not current field measurements.

## Evidence and ownership

For each slice assign an engineering owner, product/research reviewer and release
operator (one person may fill multiple roles, but record them). Keep current status
as implemented / browser accepted / user validated / sustained, with candidate
revision, evidence, uncertainty and rollback. Re-score only at evidence reviews.

- Technical order: [execution roadmap](REMAINING_WORK_EXECUTION_ROADMAP.md)
- Content experiments: [quality roadmap](MEME_CONTENT_QUALITY_ROADMAP.md)
- Collection: [audit runbook](CONTENT_AUDIT_RUNBOOK.md), [research worksheet](CONTENT_BASELINE_WORKSHEET.md)
- Evidence: [acceptance ledger](EXPERIENCE_ACCEPTANCE_LEDGER.md)
- Findings: [2026-10-17 audit](PRODUCT_CODE_AUDIT_2026_10_17.md)
- Security: [remediation diagnosis](SECURITY_AUDIT_2026_10_16.md)

Defer new game modes, decorative gamification, complex ML, forced onboarding and
source expansion without review. Optimize worthwhile discovery, not trapped time.