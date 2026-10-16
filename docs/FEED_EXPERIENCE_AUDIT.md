# Feed experience audit and user observation

Status: ready to execute; **no production audit or user study performed**.
Use with the current delivery slices in PRODUCT_ROADMAP_2026_10_15.md.

## Audit setup

Record the owner, date, deployed commit, environment, audience, device/browser,
guest/account scope, cold/warm state, sampling window and selection method before
collecting results. Do not include credentials, cookies, email addresses or user IDs.
Use a disposable account; do not purge pools or force refreshes to improve the sample.

Sample 100 consecutive feed selections, or every available selection if fewer.
Report attempts and acknowledged views separately. Count failed loads even if the
user skips them. Record how many sessions contributed; do not cherry-pick highlights.
Sample real source content for quality assessment, not repeated local artwork fixtures.

## Per-selection worksheet

Create one row per attempt in a private, access-controlled worksheet:

| Field | Recording rule |
| --- | --- |
| Sequence/session label | Local pseudonymous sequence, not a tracking identifier |
| Content reference | Existing nonsecret content ID when available; no full browsing history export |
| Source/topic | Community/topic as displayed; unknown remains unknown |
| Load outcome | Usable / broken / timeout / unsupported; include observation time |
| Time to usable | Same start/end definition for every observation; unknown if not measured |
| Readability | Full punchline visible; cropped; too small; needs zoom; other |
| Repeat | Same URL; same art/different URL; same template/different punchline; none; uncertain |
| Age | Source creation time if known, not ingestion timestamp; note time-sensitive mismatch |
| Safety/attribution | Flag review needs without copying sensitive media; source link available? |
| User judgment | Optional funny/would-send/not-for-me and reason; never infer from Next alone |

Visual matching is human review here, not a new automated identity rule. Keep
different caption edits distinct; uncertain duplicates stay uncertain. Do not
download/republish source media unnecessarily. Set access, retention and deletion
dates before collecting anything; obtain consent for recordings and quotes.

## Three observed tasks (5–8 target users)

1. “Find something you would send to a friend.” Stop before actually messaging
   anyone unless the participant chooses to. A share-sheet handoff is not delivery.
2. “You skipped something good. Find it again and keep it.” Observe Previous,
   Recently viewed, Save/auth and retrieval without coaching.
3. “You are tired of this topic. Change what comes next.” Record whether current
   controls meet the task; do not imply unimplemented preferences exist.

For each task record completion without help / with help / not completed, elapsed
time if measured, hesitation, wrong-content actions, recovery paths and voluntary
comments. Ask what prevented success, not leading questions about proposed features.
Include guest/account and narrow/desktop contexts across the study. Small samples
identify problems; they do not establish population humor ratings or retention lift.

## Report and next experiment

- Report usable / attempted, broken / attempted, repeat URLs / acknowledged views,
  visually repeated art / acknowledged views, source mix and unknown values.
- Report task outcomes with raw denominators and separate guest/account contexts.
  Summarize humor disagreement rather than average it into a fabricated certainty.
- Rank five problems by user harm, frequency and confidence. Critical wrong-meme,
  account-data or favorite-loss incidents stop the scoped release immediately.
- Select one reversible improvement. Write the hypothesis, eligible audience,
  baseline, primary outcome, guardrails, observation period/sample adequacy and
  stop/rollback rule **before** launch. Assign an owner and approval requirements.
- Rerun the same sampling/tasks. Report inconclusive results honestly. Do not
  update website/meme scores solely because code shipped or URL inventory increased.

This worksheet does not substitute for moderation ownership, actual device/provider
acceptance, accessibility review, hosted CI or operational/security release gates.