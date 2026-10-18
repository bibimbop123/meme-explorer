# Private content and usability baseline worksheet

Template only: **no observations have been collected by this document**. Copy into
approved private storage outside Git. Never record credentials, raw session IDs,
emails or account exports. Use consented participant codes, not inferred identities.
Use the [audit runbook](CONTENT_AUDIT_RUNBOOK.md) for the existing strict JSON schema
and offline summary; do not add worksheet fields to that tool's input.

## Study cover sheet

- Engineering/research/release owners:
- App revision and verified web/worker revisions, if deployed:
- Environment and permitted test accounts:
- Discovery-control flag state (default off); keep fixed within comparison windows:
- UTC windows, browser/OS, viewport, theme, ad state, network conditions:
- Sampling method and limitations:
- Consent procedure, storage access, retention/deletion date:
- Reviewers and agreement/reconciliation for 20 double-reviewed selections:

## 100-visible-selection sampling plan

Suggested balanced convenience sample, not representative population sampling:

| Window | Guest mobile | Guest desktop | Returning mobile | Returning desktop |
| --- | ---: | ---: | ---: | ---: |
| A | 13 | 12 | 13 | 12 |
| B | 12 | 13 | 12 | 13 |

Record actual mix and departures. Explain what returning means (existing browsing
history/account), not simply the second request. Invisible prefetches do not count
toward 100. Include ordinary images/video/galleries; absent types need separately
labeled fixtures, not fabricated ordinary exposure. Do not accelerate production
requests, force refreshes or clear Redis/history to manufacture supply.

Use audit row numbers to pair the strict JSON observations with this private
worksheet. If exact content references are necessary, restrict them separately;
never publish them or feed them into telemetry.

| Row | Window | Media type | Broad source/topic | Usable-media time | Readability/recovery issue | Exact/near repeat and within/cross-session | Subjective worthwhile rating (yes/no/unsure/not asked) |
| --- | --- | --- | --- | --- | --- | --- | --- |

Record source age as unknown unless verifiable. Distinguish source-post age from
artwork age, and changed captions from repeated artwork. HTTP 200 is not usable
media. Define the same timing start/end for all observations and document it.

## 5–8 participant sessions

Recruit intended users with consent. Explain that the product, not the participant,
is being tested. Allow stopping/skipping tasks. Do not ask for passwords, private
messages, or proof of sending. Use isolated disposable accounts for auth tasks.

Unaided task script:

1. “Find a meme you think is worth keeping or sending.” Record time to first
   worthwhile selection, or a predeclared five-minute timeout; do not coach.
2. “Show how you would share it.” Opening a sheet is intent, not proof of delivery.
   Do not require contacting anyone. Record cancellation/fallback honestly.
3. “Go to another meme, then find the one you chose again.”
4. “Save that meme and find where you would return to it.” Test the account
   continuation only with an approved disposable account.
5. “Find something about a different topic you enjoy.”
6. Only in an approved candidate with discovery controls enabled: “Hide a community
   you do not want, then change that preference back.” Record unaided use of
   Restore/Undo/Reset and ask whether the participant expects account or browser
   persistence. Skip and label unavailable when controls are disabled; do not
   enable the flag solely to fill a research task or compare unlike conditions.

For each task record participant code, guest/account state, broad interests
volunteered by the participant, device, completed/partial/failed/skipped, time,
hesitation, assistance and short consented feedback. Do not infer sensitive traits.

Ask afterward: What felt repetitive? Was anything unreadable? What would make you
return? Which meme, if any, was worth the effort? Avoid leading “Was this fun?”
questions. A small study identifies friction; it cannot prove retention lift.

## Three ordinary supply cycles

| UTC window | Worker revision | Fetched | Eligible | New unique URLs | Published | Retained additions | Failure/no-op reason | Budget/rate-limit state |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |

Use approved diagnostics, not forced jobs. Distinguish retained total from additions.
Zero yield is a finding, not permission to increase provider requests.

## Decision record

Select one intervention from the dominant observed disappointment:

| Finding | First candidate | Evidence before implementation |
| --- | --- | --- |
| Broken/unreadable media | Eligibility or presentation fix | Reproducible displayed failure, by media/device |
| Exact URL repeats | Recent-view suppression correction | Visible repeat counts and within-session boundaries |
| Repeated artwork under new URLs | Offline duplicate grouping | Reviewed matches including caption variants/false positives |
| Source concentration | Soft recent-source diversity | Source mix paired with subjective relevance, not counts alone |
| Low freshness/new supply | Replace about 10% of listing budget with newer listings | Three ordinary cycle yields and verified age/novelty findings |
| Usable/varied but irrelevant | One explicit positive steering experiment | Consented task failures and relevance feedback |

Do not run all candidates together. Keep provider request budget unchanged for a
freshness pilot. Source age alone is not success. Predeclare worthwhile-discovery
and repetition comparisons alongside media/readability/safety guardrails; report
raw counts, unknowns, timeouts and sample limitations. No automatic rollout.

Before deciding, inspect the summary's `collection_checks`: all four joint
session/device counts, unknowns and required manual reviews. A 100-row sample or
empty warning list is not a quality verdict. Record missing cells, unknown reasons
and deviations from the sampling plan rather than silently filling assumptions.

- Actual sample composition, unknowns, incomplete tasks and missing evidence:
- Top three problems ranked by frequency, severity, confidence and effort:
- Chosen single intervention and why alternatives are deferred:
- Hypothesis, audience, comparison, observation window and approved owner:
- Success criterion, media/safety/diversity/privacy guardrails:
- Stop conditions and rollback:
- Next review date and evidence location (private references only):

Stop immediately on wrong-content saves/shares, credential exposure, unsafe
navigation or serious safety findings. Preserve minimal private evidence and notify
the responsible owner. No automatic rollout or score increase follows collection.