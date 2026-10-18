# Exact-meme Tweet audit and acceptance

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