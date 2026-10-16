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

## Follow-up evidence and remaining acceptance

### Additional exact-share / email-auth pass

Executed against application commit `beedd53` plus quality-validation commit
`0b08e73` (current working tree clean at start), using a separate temporary Chrome
profile and local fixture account. Same Chrome/build/origin/test infrastructure;
one local artwork fixture with a distinct URL and registered content identity.

| Scenario | Result | Limits |
| --- | --- | --- |
| Clipboard denial recovery | PASS | navigator.share disabled and clipboard.writeText rejection simulated in real page; exact-link input visible, focused and selected |
| Guest Save | PASS | Sign-in link focused; “Not saved yet” message shown |
| Wrong then correct email password | PASS | Wrong stays on login; correct returns to pending exact meme and save_after_login context |
| No automatic Save UI | PASS | Save control remains unselected after login; database absence before explicit Save not queried in this run |
| Explicit Save | PASS | Profile search returns exactly one matching favorite after explicit Save |
| Recipient without sender cookies | PASS | Cookies cleared; same media/title at exact route, no signup wall; not a separate browser context |
| Unknown content identity | PASS | No random media substitution; HTTP 404 status not asserted in browser driver |
| Runtime exceptions | PASS | None captured in this run |

Artifacts: `/tmp/meme-browser-auth-results.json`, driver
`/tmp/meme-browser-auth.mjs`. Synthetic clipboard denial does not verify the native
browser permission prompt. No native share sheet, OAuth or social crawler exercised.

### Remaining unexecuted scenarios

### Offline removal/Undo follow-up — one failure

Local Chrome/test fixtures on commit `beedd53`: offline Remove stays truthful and
retryable (PASS); reconnect Remove succeeds (PASS); offline Undo retains Undo and
reports failure (PASS); reconnect Undo succeeds (PASS). A subsequent profile search
confirms one restored favorite (PASS). Missing recipient fetch returns HTTP 404,
noindex/nofollow and no random display (PASS). No runtime exceptions captured.

**Historical failure, now fixed/retested: original Saved detail URL after Undo.** Removal deletes the
old saved_memes row; Undo recreates a favorite with a different ID, while the page
retains the old `/saved/:id` address. Reload therefore cannot display the restored
favorite. The fix returns the restored account-owned saved_id, replaces the detail
history URL and updates the Back anchor while preserving query/page context.
The same Chrome offline/reconnect driver was rerun: all six assertions PASS,
including full detail reload; no captured runtime exceptions. Backend regression
checks account-owned ID and new detail access; frontend regression checks query/
page/anchor preservation. Other unexecuted acceptance cases remain open.

The first seed attempt assumed an account still existed after backend tests; that
setup failure was corrected by idempotent account creation, not counted as an app
failure. Network offline was Chrome CDP emulation, not a physical connection test.
Artifacts: `/tmp/meme-browser-offline-results.json`,
`/tmp/meme-browser-offline-persistence.json`, `/tmp/meme-browser-offline.mjs`.

Signup/recipient follow-up on commit `beedd53` with documentation-only working-tree
changes: four assertions PASS, no runtime exceptions captured in the sender page.
Guest Save → rendered signup form → exact pending meme succeeded; profile search
showed zero matching favorites before explicit Save and one afterward. A separately
created Chrome browser context rendered the exact fixture media/title without the
sender's Profile UI. Recipient exceptions were not monitored in this driver.
This checks local identity/rendering, not social-platform previews or provider auth.
Artifacts: `/tmp/meme-browser-signup-results.json` and
`/tmp/meme-browser-signup.mjs`. A disposable signup account remains in the isolated
test database; no real email delivery or email ownership verification was tested.

- Rapid/stale operations and history Like/Save state restoration; galleries,
  GIF/video, tall-image scroll and seeking recovery.
- Reduced motion, Save-Data, old service worker, fresh private browser context,
  full offline/slow/reconnect behavior, duplicate mutation/retry request counting.
- Native share/cancel, actual clipboard permission denial,
  removed content/catalog outage, crawler fetch/rendering.
- Guest pending Save through OAuth/cancel, expired
  sessions and two tabs; account isolation in a browser.
- Saved punctuation/non-Latin/invalid-input cases, corrected Undo full-reload behavior,
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

**Decision: partial local acceptance; Undo/reload failure fixed and locally retested,
NOT release acceptance.** Remaining NOT RUN scenarios must not be assumed passing.