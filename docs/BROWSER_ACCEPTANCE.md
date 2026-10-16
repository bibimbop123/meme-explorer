# Viewer and Saved browser acceptance

Status: **not executed**. Automated tests and this checklist do not establish
browser, device, accessibility or OAuth-provider acceptance.

## Record before testing

- Deployed commit, URL, timestamp, browser/version, device/viewport.
- Versioned bundle URL from page source; no credentials in screenshots/logs.
- Use a disposable test account and owned test data. Do not fault-inject into
  production databases, purge shared caches, or expose OAuth tokens/cookies.
- Confirm viewer migrations and PUBLIC_ORIGIN configuration separately.

Run desktop keyboard and narrow mobile/touch passes. Include a fresh private
session and an existing session with an older service worker.

## Discover and recover

| Action | Pass condition |
| --- | --- |
| Open viewer; press Space five times, allowing transitions to finish | Different URL-backed content advances; no reload or unsolicited skip feedback |
| Click Next, then press Space | One navigation per press, including focused Next |
| Hold Space; type spaces in a field | No repeat storm; typing never navigates |
| Previous and browser Back/Forward | Correct meme and Like/Save state; no stale response overwrites |
| Gallery arrows, tall-image scroll, video seek, then return | Correct content; practical position recovery; controls remain reachable |
| Reduced motion and Save-Data | No forced transition motion; no speculative preload under Save-Data |
| Broken image/network failure in local staging | Retry/Show another works; old content remains usable; no endless loading |

Inspect /random.json: private/no-store, media URL not an HTML page, distinct
impression IDs. First Next may consume prefetch without issuing a click-time
request. Capture Network Initiator and first Console exception on failure.

## Share and recipient

- Share initial and AJAX image, GIF and gallery; URL identifies displayed content.
- Native cancel: no success claim. Denied clipboard: exact-link field is labeled,
  focused/selectable; navigating away suppresses stale recovery prompts.
- Open link without sender cookies: exact media/title/source, no signup wall or
  intrusive recipient ads. Website preview/crosspost resolves corresponding image.
- Missing/removed content: 404, not random substitution. Staging catalog outage:
  503 with retry; retry recovers exact content.
- Check actual social-platform crawler rendering separately; metadata markup alone
  does not prove image fetch, dimensions, MIME compatibility or platform support.

## Guest Save through authentication

1. In fresh guest session, Save a registered meme: no saved-success claim; sign-in
   action receives keyboard focus and explains pending return.
2. Try wrong credentials, then correct email login: same meme returns, explicit
   Save instruction appears, and account contains nothing until Save is pressed.
3. Repeat with signup and Reddit OAuth using a permitted test account.
4. Cancel OAuth/retry; do not lose browsing or claim successful persistence.
5. Staging expired/missing/removed/outage context: no false return promise and no
   arbitrary redirect. Removed recipient content stays unavailable.
6. After explicit Save, reload profile: exactly one favorite with correct metadata.

## Saved retrieval and removal

- Open a favorite from page 2; Back returns to that page/card anchor.
- Remove: stays on detail with Undo. Undo restores metadata; failure stays retryable.
- Double click during request: one mutation. Reload profile verifies persisted state.
- Empty list, staging query outage and unavailable media have distinct truthful UI.
- Tab/Enter reaches cards, Back, Remove/Undo and retry controls; visible focus is
  not obscured. Screen reader announces status without repeatedly stealing focus.

Undo lasts only for the current page, can change saved ordering and is not a
transactional rollback. URL-v1 identity cannot detect identical art at different URLs.

## Evidence and release decision

For each failed row record: expected/actual, steps, media URL (nonsecret), Console
error, request status/timing and screenshot. Mark every scenario PASS/FAIL/NOT RUN.
Do not mark a phase accepted while critical scenarios remain NOT RUN. Keep hosted
CI, secrets rotation, provider acceptance and deployment approval separate.