# Meme Explorer experience roadmap

Status: proposed UX execution plan. Nothing below is marked shipped by this document.

## Product promise

**Open Meme Explorer, find something that makes you laugh, and send it to someone.**

Returning users should be able to recover a favorite and steer their next discovery.
The interface should be a calm frame around expressive content, not compete with it.
Optimize worthwhile moments and voluntary return—not time trapped in the app.

## How this fits the engineering roadmap

This is the experience workstream of the
[release-gated product roadmap](PRODUCT_ROADMAP_2026_10_15.md), not a replacement
for its security, privacy, coverage and operational requirements. Prototype and
research work can proceed in parallel; public rollout must satisfy those gates.

Already implemented in the working tree, but not equivalent to browser acceptance:
visible Next, AJAX/history ordering guards, page-local Like/Save restoration,
impression acknowledgments, gallery event ownership, menu/theme fixes, search form
and validation feedback, and real-session interaction regressions.

Latest full-suite engineering evidence: 1010 backend examples, zero failures, seven pending;
117 frontend tests pass; 73.70% backend coverage passes both overall 70% and per-file
30% gates. Full backend command exits 0 using isolated project-local dependencies
without RUBYLIB (see RUBY_ENVIRONMENT.md). Shared RVM gems remain contaminated;
second fresh dependency-directory reproduction passes on the same machine.
Cross-platform/CI reproduction remains open. No production rollout
or fresh score is implied. See the engineering execution log for current evidence.

Subsequent lock-helper contract tests pass with 100% targeted file coverage;
11 isolated real-Redis service ownership checks pass. Full-suite coverage above
remains the last full measurement, not the smaller targeted-run percentage.

## Three journeys that determine priorities

1. **Discover and send:** “Find something you would send to a friend.”
2. **Recover:** “You skipped something good. Get it back and keep it.”
3. **Steer:** “You are tired of this topic. Change what comes next.”

Every release must improve one of these without degrading another.

## Experience architecture

- **Discover:** one meme, Previous/Next, Like/Save/Share, source, overflow actions.
- **Search:** intentional topic/community discovery leading to the exact content.
- **Saved:** a dependable place to recover favorites and optionally organize them.
- **Meme detail:** stable recipient-friendly landing page for one content identity.
- **Preferences:** simple feed controls and reset; not a mandatory onboarding quiz.

Keep account access and secondary links out of the core content hierarchy. Browsing,
viewing a shared meme and trying a mood never require signup.

## Phase 0 — Baseline and prototype

**Deliverable:** a small validated design brief, not a visual rewrite.
**Accountability:** product/design with engineering support.

- [ ] Record current guest and signed-in versions of all three journeys.
- [ ] Audit content fit: tall images, small text, galleries, video, unavailable media.
- [ ] Prototype a focused viewing screen at narrow mobile and desktop widths.
- [ ] Recruit 5–8 target users; observe unaided tasks and record hesitation, mistakes,
  success, device and quotes. Do not treat a small study as statistical growth proof.
- [ ] Establish baseline task completion and time-to-first-usable-media measurements.

**Exit:** documented top five observed obstacles, a screen hierarchy, and a ranked
backlog tied to actual journey failures. No fabricated satisfaction/retention lift.

## Phase 1 — Focused discovery and dependable recovery

Navigation-announcement follow-up adds a polite atomic status region describing
new/restored selected content with bounded title text. It does not announce a
successful media load or prove an impression. Stale operations cannot update it;
screen-reader announcement quality/repetition still requires real-browser testing.

Source-attribution follow-up restores the original-post link after AJAX navigation
and validates initial/JSON/client Reddit post destinations. Foreign/lookalike hosts,
malformed paths and unsafe attributes are omitted. Attribution is not a rights or
moderation clearance; source coverage still depends on ingestion metadata.

Title-disclosure follow-up wires initial/AJAX buttons through one delegated handler
with visible Show/Hide labels and aria-controls/expanded state. T uses the same state
transition. Each newly rendered meme starts with title visible; no persistence or
cross-device preference is promised. Real-browser layout/accessibility acceptance remains.

Feedback-semantics correction removes automatic negative preference feedback from
Next, including after liking/saving. Advancing is navigation only. Existing server
feedback API remains compatible; explicit Not my thing/Undo UI is not implemented
by this change and historical preference scores are not rewritten.

Gallery-observation follow-up switches visibility observation when the active slide
changes before qualification. A bounded 200-ID local qualification set avoids
restarting completed gallery impressions; server deduplication remains authoritative.
This does not prove browser visibility timing or guarantee delivery after exhausted
retries. Existing retry budget is unchanged.

Recently viewed focus follow-up restores the same meme's button after list updates
or reordering, without scrolling or taking outside focus. If that item was evicted,
focus moves to Clear. URL attributes are escaped; no selector interpolation of
stored URLs is used. Browser/screen-reader acceptance remains open.

Initial-gallery ownership follow-up removes duplicate script emission from the
display partial; shared layout owns initialization, with a per-gallery duplicate
guard. Rendered-page regression verifies one initializer. Actual click/swipe
single-action behavior still needs browser acceptance.

Ingestion follow-up preserves source gallery dimensions through the unified Reddit
fetcher and primary image. Preview dimensions are used only for exact matching
source URLs, not a thumbnail/different rendition. Malformed metadata is ignored;
older cached content and unmatched sources still may lack dimensions.

Source-dimension follow-up validates available width/height, preserves them in JSON,
and emits attributes on initial/AJAX images and galleries. AJAX uses supplied ratio
before image load; missing/invalid metadata is not guessed. Existing sources without
dimensions still need enrichment, and actual layout shift must be measured.

Tall-media follow-up removes viewer container height caps/hidden overflow and the
global forced 16:9 image aspect ratio within this display. Images use natural ratio
at available width and page scrolling; videos retain a 75vh maximum. This may increase
loading layout shift until true source dimensions are reserved. Actual tall/wide/
gallery rendering, CLS and mobile readability must be measured in-browser.

Mobile-controls follow-up replaces legacy four-slot assumptions with viewer-scoped
six-column placement: Previous/Next row, Like/Save/Share row, secondary Download row.
Readable labels, 48px primary targets and safe-area padding are specified. Expanded
controls remain in document flow instead of covering content with a tall sticky bar.
Static CSS contract checks do not establish computed layout at 320px/zoom or device
usability; those measurements remain required before choosing a persistent toolbar.

Data-saving follow-up respects navigator.connection.saveData for speculative
selection and image preloading while retaining explicit Next requests. Unsupported
browsers keep current behavior; already-started requests are not retroactively
aborted. This is not a user-visible data-saver setting or a total bandwidth budget.

Prefetch-state follow-up keeps confirmed page-session Like/Save/count changes from
being overwritten by older selection responses. Merge is repeated after animation
wait to cover a late interaction completion. Server state remains the default for
content without a local override; cross-tab/device freshness is still not guaranteed.

Initial interaction-state follow-up now reads persisted account likes/saves and guest
session likes for HTML/JSON viewer responses, including initial history data and real
like count. This fixes hardcoded zero counts and absent flags; it does not provide
live cross-tab synchronization. Four new state regressions pass in the full suite.

Primary-controls follow-up adds visible Like text, stable accessible names,
explicit button types, initial Like/Save aria-pressed state and minimum 44px target
styling with focus outlines/disabled affordance. Two template-semantic regressions
pass; computed layout, contrast and screen-reader interaction need browser evidence.

Reduced-motion follow-up skips the viewer's JavaScript animation wait and entrance/
exit classes when the system requests reduced motion; matching CSS suppresses those
animations too. This does not certify motion behavior of every third-party or legacy
component. Current working-tree validation: 62 frontend tests pass; browser acceptance
and release gates remain open.

Media recovery focus follow-up keeps Retry status explicit and updates repeated
failure text without duplicating buttons. On success, focus moves to the display
without scrolling only when the disappearing notice contained keyboard focus.
Other focus is preserved. Automated focus/status regressions pass; screen-reader
announcement quality and visible focus still require real-browser acceptance.

### Implementation slice: visible Previous

Initial-media recovery follow-up opts initial images/video/gallery into the same
controller as AJAX and detects failures completed before bundle initialization.
The legacy image listener skips opted-in media and the initial inline placeholder
handler is removed. Broader lazy-load/third-party handlers and browser acceptance
still need verification; this is not an app-wide fallback rewrite.

AJAX media recovery follow-up replaces silent image placeholder substitution with
an explicit failure notice, Try again and Show another meme. Retry keeps the
original source/identity; successful load clears the notice. Failed media is not
eligible at the final impression dwell check. Initial server-page fallback remains
a separate owner and must be unified/validated before claiming all media recovery.

Recent recovery synchronization follow-up keeps already-viewed entries updated as
gallery position, playback time, reading offset and confirmed Like/Save state change.
Updating state does not add prefetched content or repopulate a cleared tray.
Reopening pushes a recoverable history entry while retaining its reading offset.
Page-memory scope and real-browser acceptance requirements remain unchanged.

Recently viewed working-tree slice adds a collapsed tray with up to 20 unique
memes after client visibility eligibility, safe title buttons, reopen and Clear.
It is page-memory-only and explicitly resets on reload; no account/device-local
persistence promise. Reopening retains impression identity and latest page-local
interaction flags. Server acknowledgment may still fail despite client eligibility.
Validation: 55 frontend tests and 26 targeted backend examples pass; backend partial
coverage gate remains unsuccessful. Browser usability acceptance is still open.

Delayed-layout follow-up retries history scroll restoration on media load/metadata
and display resize for up to three seconds. It stops when the offset is reached,
on new navigation, detached display, page departure or reader input, avoiding a
late jump after the user takes control. Slow media beyond the window may still
prevent exact recovery; real-browser/device validation remains required.

Scroll recovery follow-up saves page-session reading offsets with coalesced history
updates. Back/Previous restores saved offset without animation; fresh content starts
at top. Stale navigation callbacks cannot write or restore offsets. Delayed media
resizing can still clamp the initial restoration and needs browser validation;
this is not a persistent cross-session reading-position guarantee.

Video recovery follow-up stores page-session playback position on seek/pause and
coalesced time updates, restores after metadata without calling play, and ignores
superseded metadata callbacks. Position may lag by roughly two seconds during
continuous playback; unseekable sources retain native controls. Physical-device
validation, scroll recovery and persistent recent history remain open.

Follow-up working-tree slice preserves gallery position in the current history
entry for initial and AJAX galleries. Restoring history clamps the index to valid
slides and retains the existing impression ID and interaction state. This does not
yet preserve video playback/scroll position or replace physical-device acceptance.

Working-tree implementation adds a visible Previous control, disabled on initial
entry and while loading. Session history positions enable it only after successful
in-app navigation and restore position on Back/Forward. ArrowLeft outside galleries
uses the same guard rather than blindly leaving the first meme. Reload starts a
new recovery boundary; no cross-session Recently viewed promise is made.

Validation: 44 frontend tests pass; 19 targeted home/random backend examples have
zero failures, but the partial run exits 2 on enforced coverage (30.68%). Production
bundle, ERB syntax and source/deploy parity verified. Real-device acceptance and
unaided usability study remain required; this does not complete Phase 1.

**Outcome:** users understand what to do immediately and cannot easily lose content.
**Dependency:** existing core-loop fixes; verify them rather than duplicating handlers.

- [ ] Make content primary; Next is the main action and Previous is visibly available.
- [ ] Keep Like, Save and Share legible; move download/report/preference detail into
  secondary UI where appropriate. No reliance on unexplained icon-only controls.
- [ ] Fit full meme content without cropping punchlines; allow tall media to scroll.
- [ ] Preserve scroll/gallery position and video state where practical on return;
  define explicit behavior when exact media playback restoration is unavailable.
- [ ] Offer a bounded Recently viewed tray based on acknowledged views, not prefetch.
  Provide clear-history and disclose local/device scope before account synchronization.
- [ ] Show recoverable errors: “This one isn't loading. Try again · Show another.”
- [ ] Reserve media space; controls must not jump under a finger or cover captions.
- [ ] Respect reduced motion and data-saving preferences. No forced full-screen flash.
- [ ] Remove inert ad space and validate that consent/ad surfaces cannot obscure actions.

**Acceptance:** guest and signed-in users each navigate 20 memes; recover an accidental
skip; traverse galleries; retry after disconnect; use Back/Forward without wrong-meme
actions. Keyboard/screen-reader labels, focus, loading and errors are understandable.
Test iOS Safari, Android Chrome and desktop, including 320px width and zoom.

**Initial targets, not observed achievements:** primary touch targets at least
44×44 CSS px, no unintended horizontal page overflow, full punchline visibility,
no exact repeats before eligible pool exhaustion, no competing gesture actions.

## Phase 2 — Share the exact moment

New permalink snapshots retain crosspost origin; nested parents preserve the
deepest resolved community and direct GIFs retain animation type. Targeted route
checks verify escaped origin rendering. Existing snapshots are not rewritten.

Website-link previews and crossposted parent images/galleries now resolve through
shared validated metadata selection in both fetchers, retaining outer attribution.
No arbitrary site scraping or immutable catalog rewriting; existing pools need
normal refresh. Crossposted videos and remote availability remain separate work.

Direct media extraction now rejects unsafe primary/preview candidates and tolerates
malformed gallery shapes with safe preview fallback. Targeted media regressions
pass; remote media availability and crawler acceptance remain separate checks.

Ad-policy boundary regressions cover invalid recipient links and ordinary desktop
browsing, confirming the exclusion is scoped. Full backend after content-first
changes: 802 examples, zero failures, seven pending; 60.42% coverage, exit 2.

Recipient /meme/ pages now exclude server ad slots and the independent Monetag
loader, including unavailable routes. Added a post-viewer Find your next favorite
link. This intentionally suppresses recipient-page monetization; actual browser
layout/ad-network acceptance remains open. Subsequent full-page /random browsing
retains its existing ad policy.

Manual-copy recovery checks the displayed exact path before reopening after an
asynchronous failure, avoiding stale focus theft after navigation. Keyboard handlers
already exclude input fields. Deferred clipboard-denial regression passes; real
keyboard/device focus acceptance remains open.

Clipboard failure/unsupported APIs now reveal a labeled read-only exact-link field,
focus/select its value and provide manual copy instructions. Navigation hides prior
recovery fields. No arbitrary page URL fallback is used. Keyboard/device acceptance
of focus and selection remains open despite simulated regression coverage.

Navigation regressions now verify exact paths survive stored/restored history,
rendering replaces the share identity, and unregistered content clears it. Existing
implementation passes; actual browser-history/native sharing acceptance stays open.

Deferred native-share regressions cover success, clipboard fallback and cancellation
while navigating: duplicate taps are suppressed, the original payload stays stable,
and the next attempt can share newly displayed content. No application fix needed;
these simulated API checks do not replace actual native-device acceptance.

Native Share now reads the displayed title as bounded text rather than document
title. Clipboard/unsupported-browser feedback no longer recommends copying a
potentially stale page address. Frontend regression covers clean exact URLs with
stale document title and Search query context; native device acceptance remains open.

Share now refuses missing/invalid exact paths instead of falling back to the page
address, which can identify an earlier meme after viewer navigation. Clear error
feedback replaces misleading sharing. This supersedes earlier page-URL fallback
notes; catalog failure now makes exact Share unavailable rather than approximate.

Outage-to-retry regression confirms the same registered meme recovers with normal
metadata and no stale error headers/message. Full suite after shared-layout and
unavailable-page changes: 799 examples, zero failures, seven pending; coverage
60.42%, enforced exit 2. Browser/crawler behavior remains unverified.

Unavailable recipient pages now suppress canonical/social metadata, use an error
title and noindex/nofollow headers/meta. Catalog outages provide Retry-After: 60
and a same-meme retry link; missing/removed content retains 404 without retry.
These are server response checks, not crawler acceptance.

Generic pages now use summary cards without image tags: removed SVG placeholders
and unverified image type/dimension claims. Exact-meme raster previews remain on
recipient pages. This supersedes earlier generic-SVG follow-up notes; a verified
brand raster preview and real platform rendering checks remain optional/open.

Shared-layout generic social/canonical URLs now also use PUBLIC_ORIGIN and omit
request-derived values when production configuration is absent. Generic SVG
preview quality and fixed image dimensions are unchanged and remain follow-ups.

Production-mode recipient route regressions confirm missing/invalid PUBLIC_ORIGIN
omits canonical/social URL/image tags without breaking the viewer. Full regression
after Search recovery and preview/origin changes: 796 examples, zero failures,
seven pending; enforced coverage exit 2 at 60.39%. Real deployment/crawler checks
and production configuration remain required; no release gate is marked complete.

Recipient canonical/social metadata now uses validated PUBLIC_ORIGIN when set.
Production without a valid HTTPS origin omits URL/image metadata rather than
trusting forwarded request hosts. Configure the real public origin before rollout;
development/test alone can fall back to the request origin. Other pages' origin
handling and real crawler previews remain open.

Social-preview edge checks now cover absolute local raster URLs, escaped query
strings and first-gallery-image selection. Candidate parsing fails closed on
malformed URI sources instead of raising during metadata selection. Raster
extensions are hints, not verified MIME types or availability. Trusted production
origin configuration and real crawler acceptance remain open.

Search detail links now carry bounded query/page/result context. Recipient pages
offer a fixed local Back to search results link targeting the selected card anchor;
share paths and social URLs omit that context. This is anchor-based recovery, not
pixel-perfect scroll persistence or a snapshot of changing search results. Browser
focus/scroll acceptance remains open. Targeted search/permalink: 26 examples pass.

HTML Search now renders/registers at most 24 results per page, with query-preserving
Previous/Next links and total counts. Oversized pages clamp to the last page;
nonpositive pages return validation feedback. JSON contracts are unchanged. This
bounds catalog writes/rendering, not upstream search computation or result storage.
Search scroll restoration and actual browser acceptance remain open.

Search-to-detail slice registers server-known HTML results and routes View Meme to
their exact app pages. Registration failure retains validated media links instead
of failing Search. Search JSON shape is unchanged. Result scroll restoration,
large-result registration budgets and crawler/device acceptance remain open.

Social-metadata slice gives valid recipient pages exact escaped title/URL tags and
validated raster image candidates, omitting conflicting generic SVG/dimension tags.
Video-only content has a summary card without falsely labeling its video an image.
External media availability, platform preview support, image sizing and crawler
fetches remain unverified; this is server markup, not proof of rendered social cards.

Recipient-route working-tree slice now registers selected server-known snapshots,
returns share_path for AJAX, renders it on initial pages and resolves /meme/:id
without the sender session. Unknown/removed IDs return 404; lookup outages return
503. Viewer Share prefers a validated stable path; navigation/history retains it.
Catalog registration failure preserves browsing but makes exact Share unavailable;
page-address fallback has been removed. Catalog migration is required before
rollout. Social-card metadata and crawler/browser acceptance are not complete.

Identity foundation working-tree slice adds deterministic URL-v1 IDs and a durable
server-known snapshot registry with removed-content filtering and bounded payloads.
Existing engagement URL keys are unchanged. This is not CDN-independent/perceptual
deduplication; detail routes, registration wiring, previews and Share destinations
are not implemented by this slice. Apply add_meme_catalog.sql before enabling it.

Preliminary share-feedback slice handles native cancellation silently, attempts
clipboard fallback on other native failures, explains denial/unsupported APIs and
avoids simultaneous duplicate share flows. Native success means handoff, not receipt.
**Exact-meme destinations remain unimplemented**: current handler still uses the
page URL. This slice does not complete or substitute for Phase 2's identity work.

**Outcome:** the recipient sees exactly what the sender intended.
**Critical dependency:** canonical content identity independent of delivery URL.

- [ ] Define canonical IDs, legacy URL mapping, migrations and rollback before links.
- [ ] Add a stable per-meme route with server-rendered metadata, attribution and a
  useful removed/unavailable-content state. Do not accept arbitrary fetch URLs.
- [ ] Generate accurate raster social previews; test actual crawler-visible responses.
- [ ] Route Share and search-result View actions to this destination.
- [ ] Native share first; accessible copy-link fallback with real error recovery.
- [ ] Cancellation produces no success toast and no completed-share event.
- [ ] Recipient page leads with the meme and a low-pressure “Find your next favorite.”
  No signup wall, redirect to a random meme, or intrusive ad before content.

**Acceptance:** share from initial/AJAX/gallery/video views; open in a fresh browser
without cookies; verify exact identity, correct preview and source. Test clipboard
denial, unavailable native share, cancellation, removed content and malformed IDs.

**Measurement:** separate share intent, successful handoff, copy success and recipient
open. Native API resolution is a handoff signal, not proof a friend received a message.

## Phase 3 — Saving means “you won't lose this”

### Current implementation status

- Account Saved supports semantic detail links, 24-item account-scoped pages,
  stable ordering, total counts and truthful query-error/retry states.
- Detail Back returns to the originating page/card anchor. Offset changes and
  pixel/focus restoration still require browser acceptance.
- Detail removal offers page-lifetime Undo with retry. Restore uses Save, can
  change ordering and engagement effects, and is not transactional rollback.
- Guest Save explains account value and retains one expiring catalog ID through
  email login/signup and validated Reddit OAuth session rotation. The user must
  press Save after return; no automatic saving or device-local favorites promised.
- Existing-save retries/insertion conflicts do not repeat reward/preference effects.
- Likes failures are distinct from empty lists; count is honestly capped at 50.
  Saved detail media and attribute values are validated/escaped.

### Remaining work

1. Execute [browser acceptance](BROWSER_ACCEPTANCE.md), including auth return,
   two-tab behavior, expired sessions, keyboard focus and Undo failure recovery.
2. Decide guest device-local persistence before offering reload/offline retention.
3. Saved detail now has broken-image status, explicit retry and browse/Back recovery;
   unsafe sources cannot retry. Browser/network/focus acceptance remains open.
   Saved now has account-scoped title/community
   text search, literal case-insensitive matching, filtered pagination, clear/no-match
   states and detail-return query context. Browser acceptance remains open.
   Likes now has 24-item pages,
   stable timestamp/ID ordering, account-wide totals, validated/clamped page inputs
   and retryable errors; browser/keyboard acceptance remains open.
4. Decide whether Undo must preserve ordering and avoid all save engagement effects.
5. Add collections only after basic retrieval has passed acceptance.

These are implementation results, not phase acceptance. Historical slice evidence
is retained in the engineering execution log; old intermediate test counts are
not the current baseline.

**Outcome:** favorites are easy to keep and recover without interrupting discovery.
**Dependency:** canonical IDs and Phase 1 recovery behavior.

- [ ] One-tap save with immediate, truthful confirmation and undo.
- [ ] Decide and implement guest persistence before promising it: bounded device-local
  saves with clear scope, graceful storage restrictions and a clear-data control.
- [ ] Explain account value at the moment of saving: keep favorites across devices.
  Browsing remains open; do not require a collection modal on each save.
- [ ] Preserve the pending save through signup/login and define duplicate-safe merging.
- [ ] Build a useful Saved screen with empty state, removal, recent order and search.
- [ ] Add optional collections only after basic retrieval works; default “All saved.”
- [ ] Preserve browsing context when opening and returning from a saved meme.

**Acceptance:** save as guest, reload, find it, sign in, verify merge without duplicates,
return to browsing, unsave and undo. Test quota/storage errors, expired sessions,
deleted media, reload and two tabs. Cross-device state must come from the server.

## Phase 4 — Steer the vibe without an onboarding burden

**Outcome:** users feel agency and see meaningful responses to explicit feedback.
**Dependency:** sufficient classified inventory and trustworthy impression events.

- [ ] Add optional session chips: Surprise me plus a small number of genuinely
  supported moods/topics. Validate labels against the corpus before shipping.
- [ ] Keep “Change the vibe” available; show the active filter and easy reset.
- [ ] Add “More like this,” “Not my thing,” “Already seen it” and report/broken-media
  actions without expanding the primary reaction bar.
- [ ] Distinguish topic/style feedback from content safety reports and broken media.
- [ ] Feedback has specific confirmation, Undo, and clear account-versus-session scope.
- [ ] Stop treating every Next as negative preference; preserve diversity/exploration.
- [ ] Avoid unsupported explanations such as “because you love cats” without evidence.

**Acceptance:** users can change an unwanted topic without instructions; observe the
selected filter actually influencing eligible content; undo/reset restores behavior.
Sparse pools offer an honest alternative, not silent repetition or ignored filters.

**Measurement:** explicit feedback and reversal rates, filter exhaustion, topic diversity,
and task success. Recommendation uplift requires a predeclared controlled comparison.

## Phase 5 — Intentional discovery and trustworthy return

**Outcome:** users can find a known idea and return with confidence.

- [ ] Add useful topic/community query examples and suggestions grounded in inventory.
- [ ] Preserve search query/results/scroll when opening a detail page and returning.
- [ ] Handle long titles, punctuation, multilingual text, no-results and unavailable
  content honestly. Do not promise semantic search until tested against real queries.
- [ ] Make attribution, reporting, preferences and clear/reset controls easy to find.
- [ ] Make non-essential consent explicit and revocable; review privacy obligations
  with qualified guidance rather than guessing jurisdiction from timezone.
- [ ] Repeat the three core usability journeys after each major change.

**Acceptance:** search → exact meme → back to same result context; report and reset
are discoverable; keyboard/screen-reader journeys work; no preference/consent promise
exceeds implemented behavior.

## Release verification matrix

Every phase needs relevant automated tests plus real-browser evidence:

| Context | Required checks |
| --- | --- |
| Guest/account | Start, save, authenticate, logout, expire, retry without losing context |
| Media | Tall/wide image, tiny text, gallery, video, missing/broken source |
| Navigation | Next/Previous, Back/Forward, rapid actions, reload, recipient deep link |
| Network | Slow/cold/warm, offline transition, reconnect, timeout, duplicate retry |
| Input/accessibility | Touch, keyboard, screen reader, zoom, reduced motion, contrast |
| Privacy/storage | Denied storage/clipboard, revoked consent, clear/reset, multiple tabs |

Each release records a short screen recording, findings, owner, automated regressions,
known limitations and rollback. Prototype findings do not substitute for production
security review, migrations, CI or operational readiness.

## Success dashboard

Establish a clean baseline first; all proposed improvements remain hypotheses.

- **Task completion:** can users discover/send, recover/save, and steer unaided?
- **Time to usable content:** action to displayed media, by network/device/cache state.
- **Value proxy:** saves and share handoffs per 100 acknowledged impressions.
- **Recovery:** success finding a recently viewed/saved meme, not just number saved.
- **Trust guardrails:** wrong-content actions, broken media, duplicate content,
  undo/failure rates, intrusive-ad complaints and consent failures.
- **Return:** mature D1/D7 cohorts, guests/accounts separately with privacy-respecting
  identity rules. Do not mix old request-count views with acknowledged impressions.
- **Performance targets:** browser p75 LCP ≤2.5s, INP ≤200ms, CLS ≤0.1; investigate
  device segments and tail failures rather than reporting one favorable average.

## Suggested first four delivery slices

1. **Research and frame:** baseline three journeys, prototype focused viewer, visible
   Previous, real-device acceptance checklist. Separate release blockers explicitly.
2. **Exact-meme sharing:** canonical IDs → detail route → previews → share fallback.
   This is a vertical slice, not four disconnected infrastructure projects.
3. **Keep and recover:** recent history → reliable guest/account save → retrieval.
4. **User agency:** supported mood chips → explicit feedback → undo/reset and evaluation.

Use capacity-based estimates after discovery; these are dependency order, not promised
calendar dates. Search suggestions and polish may proceed when they don't delay a
critical safety/reliability fix. Finish and validate a slice before starting another.

## Not building yet

XP/streak economies, leaderboards, mandatory quizzes, push-growth mechanics, oversized
reaction bars, autoplay feeds, native apps or a framework rewrite. No claim that an
algorithm understands a user without evidence. No signup wall before content value.

## Definition of the experience we want

**A new user finds and sends the exact meme without instructions. A returning user
recovers a favorite and steers what comes next. Neither has to fight the interface.**