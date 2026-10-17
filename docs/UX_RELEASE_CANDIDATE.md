# UX release candidate

Implementation candidate: `72a8fe4eb3f080b9e2cbf0584aaf791bec84c470`.
Status: committed locally; assistant has not pushed or deployed this candidate.
This checklist update is separate from the implementation commit.

## Operator-reported deployment and public smoke check

The operator reports the candidate deployed. An initial public Chrome request
still returned old markup; a subsequent cache-busting HTTP request returned 200
with the new viewer navigation, favorites label and notification-status element.
A fresh Chrome profile then confirmed new navigation, modal semantics, a rendered
meme image and populated Recently viewed. This confirms candidate UI markers and
guest initialization, not an independently verified deployed SHA or cause of the
earlier old response. No production test account, save or OAuth action was used.
Opening the live feed can invoke its normal prefetch/impression tracking.
The live page's versioned bundle, viewer-controls stylesheet and keyboard-navigation
script were fetched separately and matched the bytes in implementation commit
`72a8fe4`. This verifies those three assets, not the full deployed server revision.

## Scope

- Separate sticky Previous/Next controls from secondary feed actions. Preserve
  loading disablement and initial Previous unavailability.
- Promote Search, wrap mobile navigation, and override conflicting legacy styles.
- Clarify favorites versus downloads; replace the generic personalization claim.
- Remove the dead password-recovery link. Password recovery is not implemented.
- Complete a server-held, unexpired exact-content save intent after successful
  email login, signup, or validated Reddit OAuth. Recheck catalog availability,
  retain session rotation, and show persisted saved state on return. Save failure
  must not fail login. Never mutate from the return-page query parameter.
- Keep bounded, tab-scoped recently viewed history. Persist only URL, title and
  validated local permalink; exclude account state and impression/ACK tokens.
  Refresh-restored entries load the server permalink to refresh availability and
  engagement state. Galleries and entries without exact links remain page-only.
- Improve keyboard-help focus containment/restoration and loading announcements.
- Position the disclosure menu below the measured header, constrain its viewport
  height/width, and keep it above viewer controls. Close on resize/page scroll,
  restoring focus when it would otherwise remain in a hidden menu. Behavioral
  tests pass. Chrome fixtures at 320px/375px confirmed the open menu begins
  eight pixels below the wrapped header, remains within viewport width/height,
  and has a higher stacking level than viewer controls.
- Replace unsolicited notification prompts with an explicit settings action;
  distinguish permission, subscription persistence, denial and retry outcomes.
- Label the metrics account count as all-time registered accounts.

## Validation already completed

- Production Vite build passed.
- 140 frontend tests passed (latest granted-permission retry follow-up).
- Isolated backend run: 1,209 examples, zero failures, seven pending;
  75.77% line coverage, exit 0 (latest full release-candidate rerun).
- Syntax and whitespace checks passed.
- Headless Chrome fixture using the actual stylesheets, at 320px and 375px:
  navigation top remained 0 after scrolling 800px, no horizontal page overflow,
  intended Next colors and wrapping header confirmed. This is a fixture check,
  not an end-to-end application or screen-reader audit.
- Real Rack app guest-startup smoke check in headless Chrome, using the isolated
  test database, disposable local Redis, bundled image fixtures, no Sidekiq
  consumer and outbound HTTP blocked: homepage HTTP 200, local media rendered,
  Next enabled, Previous initially disabled, keyboard dialog initialized with
  modal semantics, and Recently viewed populated. This did not exercise login,
  OAuth, actual permission dialogs or screen-reader behavior.
- Real-app guest interaction smoke check in Chrome with the same isolation:
  Next changed the bundled image, Previous became enabled and returned to the
  original image; keyboard-help opening focused its close button, Escape closed
  it, and focus returned to Next. A temporary local-only response wrapper injected
  the test actions; no production code or services were modified by the harness.
- Real-app Chrome Save -> signup smoke check: guest Save displayed sign-in
  recovery; browser fetch submitted the real signup form's CSRF token using a
  disposable test account; signup returned the exact selected permalink; fetching
  that destination in the authenticated browser returned HTTP 200, saved=true
  button semantics and the saved confirmation. This checks browser sessions,
  CSRF and server state, not manual form typing/submission or a full-page redirect.
  The disposable account was deleted afterward; local app/Redis were stopped.
- Real-app Chrome Save -> email login -> full-page redirect passed: guest Save
  preserved the exact target, a temporary harness filled the real login form and
  invoked requestSubmit (exercising its actual submit handler), and Chrome
  navigated to that exact permalink with saved button state and confirmation.
  This is scripted browser interaction, not a human usability test.
- Follow-up real-app Chrome Save -> signup -> full-page redirect passed using
  the actual signup form's requestSubmit/submit handler, password confirmation,
  browser session and CSRF handling. The destination matched the original meme
  and showed saved state and confirmation. No real email delivery was involved.
- Added explicit scoped dark colors for sticky viewer navigation. Chrome's
  computed-style fixture confirmed dark background rgb(30,30,30), Previous text
  rgb(245,245,245), and matching button background at a 500px viewport. This is
  not a full-app dark-theme or zoom audit; those checks remain outstanding.
- Doubled root text size (32px) in Chrome fixtures at 320px/375px exposed a
  six-pixel Previous-label overflow at 320px. Added overflow-wrap to navigation
  buttons; rerun confirmed no button-content or page-width overflow at either
  width. Text enlargement is not equivalent to browser zoom or a WCAG audit.

## Required pre-release browser checks

Use disposable test accounts and isolated development/staging services. Do not
create fake production accounts or enqueue production fetches for this checklist.

1. At 320px, 375px, tablet and desktop widths, browse tall images, video and
   galleries. Verify sticky controls, Search access, menu placement, no obscured
   media/actions and no horizontal overflow. Repeat with ads enabled/disabled.
2. Repeat in light/dark themes, 200% zoom and reduced-motion mode.
3. Use only the keyboard: Next, Previous, Search, menu, shortcuts dialog,
   Shift+Tab, Escape and focus restoration. Check announcements with a screen reader.
4. Guest Save -> email login, signup and Reddit OAuth: verify the exact favorite
   once, correct return content and confirmed state. Repeat with already-saved,
   expired and removed content, failed credentials and unavailable save storage.
5. Rapid Next/Previous and slow/offline media: no incorrect action target,
   duplicate navigation, stranded disabled controls or lost current content.
6. Refresh recently viewed, reopen an entry, clear the list, and refresh again.
   Repeat after authentication changes and with browser storage blocked.
7. Notification settings: dismissal, denial, granted permission with server
   failure, retry success, and rapid repeated clicks. No unsolicited prompt.

## Release and observation

- The implementation was committed with operator approval. Push and deployment
  still require separate approval. Record deployed web/worker SHAs; do not infer
  deployment from a local commit or a service-live banner.
- Before staging, confirm its database, Redis and OAuth callback are isolated
  from production, use disposable accounts, and record the previous web SHA.
- Release blockers: wrong meme saved/shared, misleading saved confirmation,
  unusable navigation at zoom/mobile sizes, keyboard focus stranded in hidden
  UI, or authentication/session-rotation regressions. Stop rollout and preserve
  evidence if any occurs; passing unit tests does not override browser failures.
- Record each manual check with candidate SHA, browser/OS, viewport or zoom,
  observed result and pass/fail. Real Reddit OAuth requires a controlled callback
  and operator-owned test account; never paste codes, tokens or credentials.
- Do not clear Redis, delete maintenance leases or enqueue extra supply jobs.
- After deployment, smoke-test the core browse/save/share journey and monitor
  navigation failures, ACK rejection reasons and maintenance publication outcomes.
- Observe 5–8 people browsing and recovering favorites; audit 100 selections for
  repeat content, broken media, source age and relevance before rating UX again.
- If this patch regresses navigation or saving, revert implementation commit
  `72a8fe4` or redeploy the recorded previous known-good web version, with
  operator approval. Preserve data and rebuild assets for the selected version.

## Remaining separate work

Password reset needs a confirmed delivery provider, hashed single-use expiring
tokens, rate limiting, non-enumerating responses and end-to-end delivery testing.
The deferred feed reservation/ACK integration is not part of this UX patch.