# Meme content quality: variety, readability and relevance

## Objective and evidence boundary

Improve three experience dimensions: variety/freshness (provisional 20/35),
readability/availability (17/25), and relevance/user control (14/25). These are
editorial judgments, not measured satisfaction or validated numerical baselines.
Do not increase scores because inventory or test counts rise.

Known evidence: one inventory sample contained 3,660 distinct URLs, 442 source
posts under one day old, 3,125 aged one-to-seven days and 93 older posts. One
completed maintenance batch fetched 1,134 unique URLs but zero new unique URLs.
Distinct URLs do not establish distinct artwork, and source age is not artwork age.
Current fetches use weekly-top listings with bounded pagination. Browsing history
still marks selection/prefetch rather than only confirmed views.

This document owns the content-improvement experiment order. The
[execution roadmap](REMAINING_WORK_EXECUTION_ROADMAP.md) owns operational,
security, ACK-migration and release dependencies. Record results in the
[acceptance ledger](EXPERIENCE_ACCEPTANCE_LEDGER.md).

## 1. Establish a small, reproducible baseline

Execution instructions and offline aggregate tool:
[content audit runbook](CONTENT_AUDIT_RUNBOOK.md).

**Effort:** 2–3 focused days plus participant recruitment. Start now, alongside
worker recovery verification; do not wait for another infrastructure project.

### Content review: 100 actually visible selections

Distribute the sample across at least two time windows, fresh guest sessions,
returning sessions and mobile/desktop. Record exact sample composition and app
revision; do not treat this convenience sample as representative population data.
Review images, videos and galleries present in ordinary supply. Record categories
separately; if a media type is absent, arrange a separate labeled fixture check.

Use anonymous audit row numbers and private content references where necessary.
For each visible selection record:

- Media type, availability, load/recovery outcome and time to usable media.
- Source-post age bucket or unknown; broad source/topic category.
- Same URL versus previously seen artwork; distinguish exact visual duplicates
  from near-duplicate formats, changed captions and intentional variants.
- Text readable at normal mobile viewing size, punchline fully accessible,
  gallery understandable and video controllable.
- Reviewer relevance/humor notes, explicitly labeled subjective.

Count prefetched/requested but never visible items separately. Do not use legacy
selection-history counts as a confirmed-view denominator. Double-review 20 rows
and reconcile disagreement before classifying the rest.

### User review: 5–8 target users

With consent, observe unaided tasks: find something worth sending, recover it,
save/share it and change topic. Ask what felt repetitive, unreadable or irrelevant.
Collect task completion and brief feedback, not private browsing/account exports.
Record guest/returning state and broad self-described interests without inferring
sensitive traits. Small studies reveal friction, not statistical retention gains.

### Metric dictionary

| Outcome | Definition | Important limit |
| --- | --- | --- |
| Visual repeat rate | Visible selections repeating earlier artwork / reviewed visible selections | Report exact/near duplicates and within-session/cross-session separately |
| Fresh exposure | Visible posts under 24h and under 7d / visible posts; unknown reported separately | Source age, not creative originality or humor |
| Source/topic concentration | Largest source share and distinct sources/topics per sample | More sources are not automatically more relevant |
| Supply novelty yield | New eligible unique candidate URLs / eligible unique candidate URLs per completed batch | Report retained additions separately; URLs are not artwork |
| Available-media rate | Reviewed selections with usable media / reviewed visible selections | HTTP 200 alone is insufficient |
| Mobile readability | Selections readable without losing text/punchline / reviewed mobile selections | Assess zoom access separately; normal-size readability is subjective |
| Recovery success | Failed-media attempts with successful retry/alternative / observed failed attempts | Report small denominator; do not manufacture production failures |
| Worthwhile-content rate | Explicitly worthwhile selections / selections rated by that participant | Consent, burden and self-selection affect results |
| Steering success | Users reaching a requested different topic without assistance / users attempting task | Next is not dislike; a view is not enjoyment |

**Deliverable:** baseline report ranking the top three failures by impact,
frequency, confidence and effort. Choose one intervention, not all candidates.

## 2. Variety and freshness: diversify supply without diluting it

**First experiment candidate:** bounded newest-post allocation, only after worker
cycle accounting and sample content review. Effort: 2–4 engineering days plus
an observation window; no delivery-date promise.

1. Review three ordinary maintenance attempts with fetched -> eligible -> new
   unique -> published -> retained counts. Explain failures/no-ops first.
2. Implement a default-off listing policy that replaces a small portion of the
   existing weekly-top request budget with newest listings. Starting hypothesis:
   10% of listing requests; freeze the exact allocation, communities and page
   budget in the experiment record before enabling.
3. Keep total request/page caps, throttles, auth, rate-limit stop, cooldowns,
   source timestamps, validation and publication conflict handling. No extra
   requests to compensate for low yield. Never delete retained inventory merely
   because a batch contains duplicates.
4. Review a private candidate sample before canary rollout. Newest content may
   have worse readability, moderation or media reliability; basic structural
   filtering is not editorial acceptance. Retain weekly-top-only rollback.
5. Compare source age, URL novelty yield, visual repeats, source balance and
   user-rated worth—not just pool size. Observe ordinary cycles across multiple
   time windows; match traffic/provider conditions as far as practical.

**Second experiment, only if visual repeats dominate:** evaluate perceptual
duplicate detection offline on labeled examples. Exact-image checks can precede
near-duplicate scoring. Measure false matches on caption variants, templates,
galleries and crops. Do not hash/fetch every image synchronously on Next. Review
image-processing dependencies, download limits, permitted sources, SSRF protection,
memory budget, retention and privacy before implementation. A labeled duplicate
cluster may inform ranking; do not irreversibly delete content on an unvalidated
threshold. Maintain original URL identity for saves/shares.

**Third experiment, only if source concentration dominates:** add a bounded,
reversible source-diversity constraint with scarcity fallback and an explanation.
Do not simultaneously alter recency weighting and personalization.

**Proposed pilot decision rules, to ratify after baseline:** improve visual-repeat
rate by at least 25% relative when baseline is at least 10%, or improve source-age
exposure and new-supply yield when repeats are already low. Report percentage
points and raw counts. Reject if available-media/readability falls by more than
2 percentage points in a sufficiently sized comparable audit, or if review finds
a critical safety failure. Small samples trigger further review, not a statistical
claim. No requirement to reach 5,000 records or make every meme less than 24h old.

## 3. Readability and availability: remove unusable selections first

**Effort:** 2–4 days for one audit-selected issue, then repeat the checks.

Prioritize by observed failure count:

1. **Broken media:** verify actual display, distinguish transient load failures
   from removed content, offer retry/another meme and preserve exact action
   identity. Test slow network, redirects, offline, cancellation and galleries.
   A single client error must not globally retire a source URL.
2. **Unreadable text:** provide an explicit fit/full-size or zoom affordance if
   observation demonstrates a need. Preserve complete artwork; do not crop to
   fill. Keep navigation reachable, allow horizontal detail inspection without
   accidental feed swipes, and support keyboard dismissal/focus restoration.
3. **Gallery/video confusion:** make image count and gallery/feed navigation
   distinct; preserve return position. Keep accessible playback controls and
   respect reduced motion/data saving. Never introduce audible autoplay.
4. **Layout instability:** reserve trustworthy dimensions without stretching or
   clipping content; test tall images and controls against ads/consent overlays.

Use deterministic local fixtures for regressions and ordinary real-media review
for acceptance. No provider/network probing on every request; background health
work needs bounded budgets and retained-state safeguards.

**Proposed acceptance targets:** at least 98% available media and 95% normally
readable content in the reviewed sample, with zero hidden punchlines or blocked
core controls in deterministic fixtures. Report sample counts and uncertainty;
these are pilot targets, not production SLAs or existing measurements. Repeat
at 320/375px, desktop, true 200% zoom, keyboard and screen reader, in both themes.
Track usable-media time separately from fast server handler time.

## 4. Relevance and user control: agency before opaque personalization

**Effort:** 3–5 days for one reversible control, after baseline selection.

### First: make intentional discovery work

- Verify Search retrieves meaningful title/community matches and handles no
  results honestly. Observe whether users can steer without guidance.
- If topic discovery is the primary friction, prototype a few optional topic
  entry points using existing inventory. Do not add mandatory preference quizzes
  or promise unseen content when the chosen topic has insufficient supply.

### Next: one explicit control

Choose either “less from this community” or “show more of this topic,” according
to research—not both plus a new ranking system. Specify session-only versus
account persistence in UI. Make the choice reversible, provide Undo/reset, and
show active constraints. Never silently reintroduce excluded content on scarcity;
explain exhaustion and offer widening/reset. Do not infer dislike from Next.

### Then: evaluate preference weighting

Use explicit likes/saves/controls, normalize against exposure, and cap boosts to
retain exploration. Separate community preference from creative quality. Do not
infer sensitive personal attributes or make every interaction a permanent signal.
Keep guest behavior usable and disclose account persistence. Validate aggregate
preference benefit with participant feedback; sparse signals are not grounds for
claims of accurate personalization. Coordinate anything relying on confirmed views
with the default-off ACK migration rather than treating prefetch as exposure.

**Proposed acceptance:** 4/5 or more participants can steer and undo without
assistance in an initial usability check; test with all recruited users and report
actual counts. A later, appropriately sized comparison should improve explicitly
rated worthwhile content without collapsing source diversity. No claim of causal
retention lift from a 5–8-person study, saves alone or increased time-on-site.

## Delivery sequence and responsibilities

| Slice | Driver | Output / dependency |
| --- | --- | --- |
| A. Baseline and worker acceptance | Product reviewer + operator + engineering | 100 visible selections, three accounted-for cycles, recruitment; can run in parallel |
| B. Highest-impact usability/media defect | Engineering + reviewer | One regression-backed fix; start immediately if a critical defect is already confirmed |
| C. One supply OR steering pilot | Engineering + product | Baseline hypothesis, default-off implementation, reviewed sample and approved canary |
| D. Repeat audit and tasks | Product reviewer | Compare original definitions, device mix, time windows and denominators |
| E. Retain/revert, then select next pilot | Product + operator | Written decision; expand only after evidence and safety gates pass |

Do not run supply/ranking/personalization changes together: attribution becomes
impossible. Prefer a non-overlapping baseline/pilot comparison with recorded
seasonality limits; use a properly designed concurrent comparison only when
traffic, consent, isolation and sample size support it.

## Experiment record and release gates

Before coding a pilot, record: revision/environment, hypothesis, target users,
single changed variable, request/resource budget, primary metric, safety metrics,
sample size/observation window, operator, stop rules and rollback flag. Avoid
peeking/stopping merely because an early number looks good. Separate release
acceptance from research consent and statistical claims.

Every implementation requires regression tests, build before backend boot, full
isolated non-overlapping suites, privacy/security review and browser acceptance.
Commit, push, deploy and enablement need explicit approvals. Stop on wrong-content
save/share, unauthorized mutations, accessibility blockers, provider-pressure
increase or inventory loss. Preserve leases/cooldowns and original inventory.

## Score reassessment

Reassess only after repeating the audit and observed tasks. Use evidence across
the same three dimensions; keep confidence/limitations beside each score. A
planning aspiration is roughly 28/35 variety, 22/25 readability and 20/25 relevance,
not a promised outcome or formula derived from the pilot thresholds. Explain
tradeoffs; freshness that makes the feed less funny/readable is not improvement.

## Immediate next actions

1. Operator supplies post-deployment worker completion and inventory read-back;
   privately verifies low-latency routing and exposed-credential rotation.
2. Product reviewer starts the 100-selection audit and recruits 5–8 target users.
3. Rank observed failures; choose the first media fix or bounded supply/steering
   pilot. Do not implement newest listings, image hashing or more personalization
   merely because those ideas appear in this plan.