# Local browser acceptance — October 16, 2026

## Scope and setup

- Application base commit: `58ff1c2`, with uncommitted checklist/diagnostic-test changes.
- Origin: `http://127.0.0.1:18080`; RACK_ENV=test, isolated test PostgreSQL and
  disposable Redis on 16379. No workers started; cooldown prevented bootstrap.
- Google Chrome **155.0.8059.82**, headless, separate temporary browser profile.
  Chrome DevTools Protocol driven with Node's built-in WebSocket; no new dependency.
- Desktop default headless viewport and **390 × 844** mobile emulation. This is
  not a physical touch-device or assistive-technology test.
- Bundle: `/dist/bundle.js?v=d8f0bffb3a8e32e8`; Vite build passed before boot.
- Disposable local account, 30 Saved fixtures, 51 Likes, eight local image URLs.
  URL variants use the same local artwork: navigation demonstrates URL identity,
  not unique visual content or live Reddit availability. No provider login tested.

## Executed results

| Scenario | Result | Evidence/limits |
| --- | --- | --- |
| Email login through rendered form | PASS | Local fixture account reaches profile using normal session/CSRF flow |
| Saved case-insensitive search, page 2 | PASS | 30 matches, six cards on page 2 |
| Likes older than newest 50 | PASS | Likes page 3 of 3 reached |
| Open filtered Saved card | PASS | Back href and actual Back-link click preserve query, page 2 and card anchor |
| Remove and Undo | PASS | Remains on detail; follow-up profile navigation verifies removal and restored match |
| No-match versus empty account | PASS | No-match message, not empty-account claim |
| Clear Saved search | PASS | Filter removed, 24 cards displayed |
| Narrow profile layout | PASS | Document width 390 equals viewport width 390; not full visual/focus audit |
| Broken Saved image | PASS | Assigned missing local source; image hidden, recovery displayed |
| Keyboard retry | PASS | Focused retry activated with Enter; repeated missing-source failure re-enables retry |
| Image recovery | PASS | Assigning valid local source displays loaded image; origin recovery via retry not simulated |
| Space five times | PASS | Six successive fixture URLs differ from their immediate predecessors |
| Focused Next then Space | PASS | Both actions advance; exact request count not asserted |
| Previous | PASS | Restores URL selected before last Space navigation |
| `/random.json` privacy/impression | PASS | HTTP 200, `no-store, private`; follow-up compares two distinct nonempty impression IDs |
| Held Space and field typing | PASS | Five auto-repeat keydowns cause no additional navigation; focused input Space does not navigate |
| Browser Back/Forward | PASS | Restores prior/next selected fixture URLs; Like/Save restoration not asserted |
| Profile pager context | PASS | Both pager hrefs preserve the other page; Likes pager retains Saved query |
| JavaScript exceptions in exercised flows | PASS | No Runtime.exceptionThrown events captured; not a full console/network audit |

## NOT RUN — still required

- Rapid/stale operations and history Like/Save state restoration; galleries,
  GIF/video, tall-image scroll and seeking recovery.
- Reduced motion, Save-Data, old service worker, fresh private browser context,
  full offline/slow/reconnect behavior, duplicate mutation/retry request counting.
- Native share/cancel, clipboard denial/focus, fresh-recipient exact identity,
  removed content/catalog outage, crawler fetch/rendering.
- Guest pending Save through wrong/correct login, signup, OAuth/cancel, expired
  sessions and two tabs; account isolation in a browser.
- Saved punctuation/non-Latin/invalid-input cases, persistence after full reload,
  actual paging clicks preserving both sections, staging DB-query failure, unsafe
  source UI, image failure before deferred script, retry success from network stub.
- Physical devices/touch, Safari/Firefox, screen reader announcements, visible focus,
  contrast/zoom, comprehensive visual layout, consent/storage/clipboard denial.
- Production configuration, scheduler/OAuth/shared Redis, hosted CI, secret rotation.

## Artifacts and decision

Local temporary artifacts (not committed, may be removed):
`/tmp/meme-browser-results.json`, `/tmp/meme-browser-viewer-results.json`,
`/tmp/meme-browser-profile.png`, `/tmp/meme-browser-saved-mobile.png`, and
`/tmp/meme-browser-viewer.png`. Temporary CDP drivers are under `/tmp/meme-browser-*.mjs`.
Follow-up assertions: `/tmp/meme-browser-followup-results.json` (nine PASS, no
captured runtime exceptions). An initial driver incorrectly reopened a removed
Saved record before Undo; it was corrected to exercise Undo on the still-open
detail page. That driver error is not counted as an application failure.
Do not publish raw browser/session/server logs without redaction.

**Decision: partial local pass, NOT release acceptance.** No failures observed in
the assertions above; remaining scenarios are NOT RUN, not assumed passing.