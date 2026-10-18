# Exact-meme Tweet audit and acceptance

## Consolidated sharing panel and desktop image clipboard

Local receiving-composer follow-up: opt-in clipboard suite **182 checks passes**.
After actual PNG copy/readback, CDP keyboard Paste command delivers nonempty
image/png File in paste event to a temporary local contenteditable composer;
receiver records MIME/size and suppresses insertion, then is removed. This is
native clipboard-to-page evidence, not X composer or OS/manual acceptance. 161
frontend tests/syntax/diff pass. No product code changed in this slice.

Real Chrome clipboard follow-up: opt-in `BROWSER_CLIPBOARD_TEST=true` grants
clipboard read/write only to local fixture origin and activates Copy image with
Enter. Readback yields nonempty decodable PNG matching displayed natural dimensions.
Complete suite **181 checks passes** with option (default remains 180). Clipboard
permission/readback moved focus in first run; test refocuses summary before Escape
journey. No product change needed. 161 frontend tests/syntax/diff pass.
Run only in disposable browser context: clipboard test can replace system clipboard
on some hosts. No live X paste, Safari/Firefox or mobile native share acceptance.

Browser reset follow-up: complete account-free suite 180 checks passes, with native
sharing disabled locally to exercise gallery fallback links. Old slide links/status
are removed after slide change; retry resolves the active image. 161 frontend tests
pass. This updates prior observer-only evidence; not actual OS/X acceptance.

Latest reset hardening clears prepared-image state and old fallback links when
viewer identity/active gallery media changes. Pending old preparation/native-share
results cannot restore stale UI. 161 frontend tests/build pass; observer reset has
Node regression, not fresh physical-device/browser handoff acceptance.

Follow-up: direct Download image action now available without first trying native
sharing. Panel guidance distinguishes image handoff from link-only composers.
Border-box sizing/wrapping verified at 320/375/1280px; 177 account-free Chrome
checks and 160 frontend tests pass. Build regenerated. Download confirmation says
requested, not completed; target is resolved on click. No real X paste/attachment
or OS file-save acceptance claimed. Latest changes frontend-only, backend not rerun.

Primary Share now opens one native details disclosure containing image share,
Copy image for X, WhatsApp link, Tweet link and exact-link copy. Summary is
keyboard-operable; Escape/Close restore primary trigger focus. It is a nonmodal
disclosure, not a focus-trapped dialog. Existing Download control remains for
compatibility; this is not a complete viewer action redesign.

Desktop copy initiates clipboard.write with promised PNG bytes during gesture,
converting non-PNG raster files through canvas. Animated inputs copy one still
frame, disclosed in confirmation. Unsupported/denied clipboard directs to image
download/manual attachment; no automatic X post/attachment promise. Native image
sharing retains prepare→second-click flow and active-gallery selection.

Validation: 160 frontend tests, production build and syntax/diff checks pass;
174 account-free Chrome checks include primary opening/focus and Escape restoration
at three widths plus prior exact Tweet identity/card checks. Clipboard write API
unit-tested, not live X paste or real-device share-sheet acceptance. Product changes
frontend-only this slice; backend suite not rerun. Local fixture services stopped.

## Actual-image sharing (device share sheet / download fallback)

Added Share image beside explicitly labeled Tweet link. First click fetches selected
image as a File, second click opens native file sharing under fresh user activation.
Choose X if installed/available; target apps determine attachment handling. Actual
File plus exact-link text handed to share sheet, not an automatic post or guaranteed
X attachment. Native cancellation is not success. Unsupported/failed sharing offers
explicit selected-image download and text/link composer with manual-attachment help.

Active gallery image selected; videos/posters not substituted. Preparation verifies
current identity before offering share; another click after navigation re-resolves
media. Raster MIME allowlist, nonempty <=10 MiB file; no SVG/HTML as shared image.
Remote fetch uses existing same-origin download proxy, now HTTPS/standard-port/
no-credentials only and redirects disabled. Allowlist unchanged; upstream download
still buffers response (no new streaming byte cap or MIME sniffing claim).

Validation: 158 Node frontend tests, build/syntax/diff pass; full backend 1,335
examples, zero failures, seven pending. Tests cover active image selection, disallowed
sources, MIME rejection, actual File payload/two-click flow and cancellation;
proxy tests cover unsafe schemes/credentials/ports and redirect refusal. No real
device/X share-sheet acceptance performed. Manual mobile test and deployment remain
required. Existing Tweet Chrome checks predate this new image action.

## Root causes and implementation

1. Old share bar captured document title/homepage URL when mounted, not current
   viewer identity after AJAX Next/Previous.
2. Inline onclick arguments were pre-encoded, then encodeURIComponent applied
   again in Twitter intent builder: percent escapes became visible tweet text.
3. Replaced inline HTML handlers/global sharing functions with DOM listeners.
   Tweet/WhatsApp/Copy resolve current stable `/meme/<64 hex>` identity and current
   title at click time. URLSearchParams encodes once. No generic hashtag/page-title
   fallback. Missing exact identity fails honestly. Nonviewer cards need explicit
   data-share-path; raw media/card homepage fallback is intentionally removed.
4. Exact recipient page already supplies server-rendered Twitter/OG metadata for
   image/gallery-first-image candidates. Catalog snapshots now preserve video
   thumbnail_url; validated raster thumbnail may supply poster preview. No video
   player card or automatic image upload to X is claimed. Older catalog snapshots
   without thumbnails are not backfilled.

## Production preview blocker

Read-only public sample: exact recipient page fetched as Twitterbot returned 200
but summary card only, no twitter:url/image. Consistent with missing/invalid
PUBLIC_ORIGIN; actual dashboard value not inspected. Runtime requires approved
HTTPS origin for canonical/social URLs rather than trusting request headers.

Operator must verify/set `PUBLIC_ORIGIN=https://meme-explorer.onrender.com` if that
is the approved canonical host, redeploy updated bundle/backend, then inspect an
exact image permalink as Twitterbot. Expected one twitter:url for that permalink,
summary_large_image and absolute twitter:image pointing to its artwork. Confirm
image URL publicly loads with suitable content type/size and no login requirement.
Do not paste tokens into validation tools. X may cache cards or decline rendering;
intent URLs cannot force a preview or attach media. No actual tweet published here.

## Regression evidence

Chrome follow-up: complete account-free suite **168 checks pass**. Twelve new
assertions across 320/375/1280px activate actual Tweet DOM listeners while capturing
window.open locally: exact initial identity/readable title, updated identity after
Next, missing-identity refusal, and fetched recipient HTML containing large-image
card/exact absolute URL/current artwork image. No X popup opened or tweet posted.
Local test environment may derive origin; this does not resolve production's
PUBLIC_ORIGIN blocker. 155 frontend tests/syntax/diff checks pass. Backend latest
remains 1,333/zero failures/seven pending; not rerun for browser/docs additions.

Two Node tests exercise exact-current identity, title/emoji/quotes/percent handling,
single URL decoding, no homepage/private-query/hashtag fallback, changed identity,
invalid links and actual Tweet listener after navigation. Backend tests request
exact image as Twitterbot without sender session and video-thumbnail metadata.
Production bundle rebuilt. Frontend 155 tests pass. Full backend outcome recorded
in acceptance ledger. Public preview configuration remains operator-dependent;
no deployment, production config change or live X preview acceptance claimed.