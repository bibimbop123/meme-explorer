# Local browser UX acceptance — 2026-10-17

## Result

### Signed-in browser continuity: 138 checks with opt-in account

Complete script passes **138 checks** when server and Node both receive matching
`BROWSER_FIXTURE_ACCOUNT=browser-<24 lowercase hex characters>@example.test`.
Default account-free run remains 132 checks. Fixture refuses an existing account
and registers at-exit deletion for only that random account and its user activity.
Never use an actual account. Unexpected hard kill may require private cleanup.

Six new checks: signup through browser fetch/real CSRF/session rotation; actual
DOM Like listener confirms state/count; profile contains liked media after full-page
navigation; explicit unlike restores baseline; browser logout; protected profile
redirect after logout. Browser signup uses fetch, not real form typing/submission.
Unlike cleanup also uses browser fetch. Profile evidence is image presence, not
exact-link/like-button state after reloading that exact meme. No cross-device or
multi-tab auth acceptance claimed. Existing 132 checks run first unchanged.

No app defect or product-code change. 153 Node tests, syntax/diff checks pass;
backend not rerun for test/harness/docs-only additions. After fixture shutdown an
independent local query found zero matching disposable browser users. Count delta
restored before logout; residual ordinary viewer metadata remains test data.

### Guest like-button retry and navigation: 132 checks

Complete script passes **132 checks**. Test-only fetch wrapper delegates real
HTTP/CSRF/session persistence, then deliberately drops one successful response or
holds another after the server replies. DOM button activation exercises bundled
interaction listeners; this is not physical pointer/touch input. Lost success
rolls UI back; retry repeats desired true without double count. Explicit unlike
restores count. Late success does not repaint another meme; Previous restores
the original meme's confirmed liked state/count. Final unlike restores test delta.

No new product defect or implementation change. 153 frontend tests, JS syntax
and diff checks pass; backend not rerun for test/docs-only slice. Guest session is
fresh disposable Chrome profile; actual test DB metadata may be written. Wrapper
exists only in that browser page and vanishes on navigation/process exit.
No concurrent guest-tab, signed-in browser, server-outage, physical-pointer or
all stale-response schedules claimed. Signed-in real HTTP acceptance is separate.

### Viewer action focus follow-up: 126 checks

Current suite passes **126 browser checks**. Added 48 assertions: Like, Save,
Share and Download each have focus-visible outline >=2px, remain entirely within
viewport, and pass center-point hit testing at 320/375/1280px in light/dark themes.
Like is focused to enter the action group; native Tab reaches Save→Share→Download.
No actions are activated by this test and no defect reproduced. 152 Node tests,
JS syntax and diff checks pass. Test/docs-only change; no backend suite rerun.

These are fixture-image action-group checks, not complete page Tab-order, contrast,
edge occlusion, all scroll positions, tall media, ads/consent overlays, disabled/error
states, zoom or screen-reader acceptance. A passing center hit alone does not prove
the whole focus indicator is unobscured. Remaining manual gates stay open.

Do not substitute rising assertion counts for product outcome evidence. Next
high-value work is actual-content/user baseline, true zoom and screen-reader/device
acceptance, plus approved platform termination validation. No score increase.

### Skip-to-content follow-up: 78 checks

Current browser script passes **78 checks**. Skip activation initially failed to
focus main; adding tabindex alone exposed a second interaction: fragment navigation
reaches the viewer's popstate path and can reload/replace content. Main now has
tabindex=-1 and the skip handler prevents fragment history, focuses main and scrolls
to it. No permanent extra Tab stop. Four checks per viewport confirm focused skip
visibility, main focus, identity/URL preservation and subsequent Tab into viewer
navigation. Tested at 320/375/1280px. Native anchor remains the no-JS fallback.

Two additional Node regressions cover landmark markup and skip handler behavior;
disclosure mock updated for the new selector. Browser menu test now waits briefly
after focus-induced scrolling before opening, because menu intentionally closes on
scroll. 152 frontend tests pass. Rebuilt bundle: 56.89 kB / 16.73 kB gzip.

This slice does not close all action-focus/sticky-obscuration checks; no true
browser zoom or screen-reader listening acceptance. Keep those manual gates open.

### Gallery accessibility follow-up: 66 checks

Current complete script passes **66 checks**. Chrome's accessibility tree initially
exposed inactive server gallery images, confirming a product defect. Server slides
now use hidden/display state consistently; indicators are labeled native buttons
with aria-pressed; position counter is a polite atomic status. Visible keyboard
focus and reduced-motion transition suppression are styled in viewer controls.

Browser checks confirm exactly one gallery image exposed, live-status markup,
indicator semantics, Enter activation/selected state, visible focus outline and
zero-duration transition under reduced motion. The Enter test required CDP text/
virtual-key metadata to synthesize native activation correctly; its initial failure
was harness input, not an additional application defect. Existing route regression
asserts initial hidden slide and indicator/status semantics. Gesture mocks updated
for real slide properties. 150 frontend tests and build/syntax/diff checks pass.

This is accessibility-tree/keyboard evidence, **not a screen-reader listening test**.
No true desktop 200% browser zoom accepted; CDP viewport/text enlargement is not
equivalent. Remaining checks include real zoom, screen readers, physical devices,
contrast across all states, ads-enabled layouts and real-content audit.

### Successful playback and dynamic-gallery follow-up: 60 checks

Current complete script passes **60 checks** in local Chrome. It generates an
original two-second silent canvas recording with Chrome MediaRecorder/VP8, keeps
bytes in memory and serves them through CDP interception with byte-range responses.
No downloaded media, binary dependency or production fixture added. Controlled
random.json responses exercise the normal dynamic renderer without exposing debug
app globals or changing the backend selector.

New checks cover decoded dynamic gallery, single-step button navigation, vertical
touch preserving slide, horizontal touch changing slide but not feed, and exact
gallery/slide recovery after Next→Previous. Video checks cover decoding, native
controls, advancing playback time, paused seek to 0.8s with muted state, and position
recovery after Next→Previous. Original-media generation is also asserted.

Initial failures were harness issues: global JS variable redeclaration and missing
range metadata causing an unseekable fixture response. Both corrected; no new
application defect confirmed in this slice. 150 Node frontend tests, script syntax
and diff checks pass. No full backend rerun for this test/documentation-only slice.

This establishes one synthetic WebM/VP8 path in headless Chrome, not MP4/H.264,
audio, streaming/CDN performance, Safari/iOS, native control accessibility, all
gallery types or physical-device acceptance. Previous invalid-video checks remain.
Fixture services are stopped after validation; no production/flag/deploy changes.

### Media follow-up: 50 checks and two reproduced fixes

The extended script now passes 50 checks. Server gallery buttons/ArrowRight change
one slide without changing feed identity; vertical-dominant touch leaves the slide
unchanged. Invalid-video fixture exposes native controls/muted state, retry preserves
identity and Show another meme loads a decoded local image.

Two failures reproduced before fixes:

1. Server gallery treated any >50px horizontal drift as a swipe, even during a
   predominantly vertical gesture. Fixed server and dynamic gallery controllers
   with direction dominance, multi-touch invalidation, cancel reset and interactive
   control exclusions. Two Node regressions execute both controllers' gesture logic.
2. Chrome emitted nested `<source>` failure without a recoverable `<video>` error.
   Recovery now maps source error to its parent video. Existing recovery unit test
   includes nested-source regression; browser retry/escape passed afterward.

Rebuilt committed JS bundle (56.64 kB / 16.66 kB gzip); 150 Node tests pass. Existing
132-byte MP4 assets are invalid playback fixtures: these checks prove controls and
failure recovery only, not successful video playback, seeking or codec support.
Browser fixture mode is request-local/thread-reset and exists only in test harness;
no runtime app parameter or feed flag added. Dynamic gallery gestures have Node
coverage; new browser gallery tests exercise server-rendered galleries specifically.

42 checks passed in local headless Google Chrome through DevTools Protocol.
Uses actual config.ru/app/middleware with local image supply, test PostgreSQL and
disposable Redis. No app defect reproduced; no production/UI code changed in this
slice. Scripted actions are not human usability findings or a WCAG certification.

At 320/375/1280px (36 checks): no horizontal document overflow; decoded image within
viewer; light/dark state consistency; menu within viewport; Escape/focus restoration;
shortcuts dialog opening/focus containment/dismissal; Space advances decoded image;
Previous restores exact identity; doubled root text does not cause page overflow.

Six additional checks: reduced-motion preference reaches browser; vertical emulated
touch preserves meme; horizontal touch advances; About has no swipe overlay; swipe
on About does not redirect; no uncaught Runtime exceptions during these journeys.

## Repeatable harness

Files: `tests/browser_fixture.ru`, `tests/browser_ux.mjs`. Node 22's built-in
WebSocket/fetch and Chrome CDP; no new libraries. Requires pre-existing test schema.
Use only disposable/local test data. Fixture guard refuses remote/non-test DB and
Redis outside loopback port 16379. No account creation or DB truncation, but sessions,
selection/impression/catalog metadata may be written. It is not read-only.

From the repository root, start a disposable Redis yourself and run:

```sh
RACK_ENV=test DATABASE_URL=postgresql://localhost/meme_explorer_ack_browser_test \
REDIS_URL=redis://127.0.0.1:16379/0 \
ruby scripts/isolated_bundle.rb exec puma -C - -b tcp://127.0.0.1:19292 \
  -t 1:2 tests/browser_fixture.ru
```

In a separate terminal, start Chrome with a fresh disposable profile:

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port=19293 --user-data-dir="$(mktemp -d /tmp/meme-ux-chrome.XXXXXX)" \
  --no-first-run --no-default-browser-check --disable-background-networking about:blank
```

Then `node tests/browser_ux.mjs`. Server fixture skips dotenv, blocks outbound Ruby
HTTP, fakes Sidekiq and supplies local images without changing feed flags. CDP
intercepts page requests and allows only fixture-origin/data URLs. Chrome background
network disabling is not an OS network sandbox. Use a clean process environment;
the fixture clears selected integrations but is not a general environment scrubber.
Do not run with production credentials. Stop fixture Puma/Chrome and disposable Redis
afterward; do not terminate unrelated services. Remote debugging must remain local.

## Evidence limits / remaining acceptance

- Root text enlargement is **not actual 200% browser zoom**.
- Emulated touch is not physical iOS/Android, pinch/assistive gestures or browser
  back-edge acceptance. Three local images are not a content quality sample.
- Theme assertions test state, not all color contrast combinations.
- Reduced-motion assertion tests media-query delivery, not animation suppression.
- Keyboard checks cover specific dialogs/actions, not every Tab stop or screen-reader
  announcement. No automated accessibility library or assistive technology used.
- Ads disabled; video/gallery, removed media, offline transitions, true zoom,
  screen reader, Safari/Firefox and real social previews remain open.
- No visual screenshot review or field performance/retention claim.
- Existing Node frontend suite remains separate from this opt-in browser script.

Use this harness for incremental image-viewer regressions, not automatic release
or score approval. Raw local output `/tmp/meme-ux-results.log` is temporary.