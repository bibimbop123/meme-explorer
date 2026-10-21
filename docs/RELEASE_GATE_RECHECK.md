# Release and measurement recheck

Saved-state boundary follow-up: never-saved Unsave returns unchanged success
with zero activity; Save/Save/Unsave/Unsave/Save/Save yields two saves, one unsave,
one current saved row. Real DB service tests added. **1,372 backend examples,
zero failures, seven pending**, 78.07% coverage; **170 frontend pass**, syntax/diff
pass. No runtime changes in this step. Sequential semantics only, not concurrency
or historical repair. Changes uncommitted; temporary Redis stopped.

Unsave retry correction: DELETE RETURNING distinguishes actual removal from no-op;
already-unsaved requests still succeed but no longer emit false unsave activity.
Extended real-route reconciliation repeats Unsave and retains exactly one event.
Full backend **1,370 examples, zero failures, seven pending**, 78.03% coverage,
exit 0; syntax/diff pass. No concurrent save/unsave transaction guarantee or
historical data repair claimed. Changes uncommitted/undeployed, Redis stopped.

Controlled interaction reconciliation: authenticated view, repeated desired-state
like/unlike and duplicate save followed by unsave produce one event per tested
transition. Final current likes/saves are zero while rolling gross like actions
remain one; chart sum matches report. **1,370 backend examples, zero failures,
seven pending**, 78.10% coverage, exit 0. This covers sequential requests only;
concurrent toggles and repeated unsave requests are not established idempotent.
No runtime change in this step, syntax/diff pass. Temporary Redis stopped.

Controlled server view reconciliation: two AJAX selections leave rolling view
counts unchanged; two acknowledgments of one issued ID add one activity view.
Rolling report total, summed chart and authenticated metrics JSON reconcile.
Real route/DB regression added; **1,369 backend examples, zero failures, seven
pending**, 78.11% coverage, exit 0. This is a simulated acknowledgment, not proof
of human visibility; historical production data, automated traffic and like/save
event sequences still need independent reconciliation. Syntax/diff pass; temporary
Redis stopped. Changes uncommitted/undeployed.

Latest authenticated browser follow-up: disposable signup and metrics page checks
pass in the **213-check Chrome suite**. Actual metrics DOM exposes recorded-activity
limitations and account-day span exclusions, removes D1 wording, and fits 375/1280px
document widths. This is rendered DOM/layout evidence, not screenshot review of
populated/empty/unavailable states or actual chart rendering. No controlled
event-to-report reconciliation yet. Temporary account cleanup registered in fixture;
app/Chrome/Redis stopped. JS syntax/diff pass; no backend changes in this step.

Local candidate: `34d42d8`. User reports deployment; running hosted revision,
flag values and hosted CI have not been independently verified.

## Executed local gates

### Demo ad obstruction correction (local follow-up)

Demo ad slots now require `AD_PLACEHOLDER_PREVIEW=true` outside production;
production ignores preview opt-in. Random sidebar wrappers are absent without
preview; footer slot emits no empty overlay. Preview footer uses normal document
flow at desktop/mobile widths. Independent Monetag loader is unchanged; this is
not network removal, consent repair or a new revenue-generating integration.
Two new policy examples; existing premium tests explicitly opt into preview.
Full backend **1,368 examples / zero failures / seven pending**, 78.04% coverage;
**170 frontend tests pass**, syntax/diff pass. Ad-enabled browser fixture/overlap
acceptance still NOT RUN; no claim of physical-device or third-party ad acceptance.
Changes uncommitted/undeployed; temporary Redis stopped.

Preview browser follow-up: guarded fixture accepts `BROWSER_FIXTURE_AD_PREVIEW=true`
to render inert slots. External browser traffic remains intercepted/blocked by
the existing acceptance harness. **221 Chrome checks pass**, including footer
normal-flow position, no media/action rectangle overlap and no document overflow
at 320/375/1280px in both themes. These final checks use the fixture image after
Reset; not all media/scroll states, real creatives or physical-device acceptance.
Syntax/diff checks pass. Temporary app/Chrome/Redis stopped. Metrics visual check
and controlled event reconciliation remain outstanding.

- 170 frontend tests pass; Vite build, diff and tracked-artifact checks pass.
- Humor-first flag enabled: 1,361 backend examples, zero failures, seven existing
  pending; 78.04% coverage, exit 0.
- Humor-first plus discovery enabled fixture: 203 Chrome checks pass, exit 0.
- Initial backend attempts were invalid: disposable test databases were absent,
  then newly created databases lacked schema. Loaded checked-in PostgreSQL schema
  into isolated test databases and reran successfully. No production DB changes.
- Backend/browser ran sequentially. Temporary app, Chrome and Redis stopped.

## NOT completed

Real two-tab browser journeys, physical devices, actual zoom, screen-reader
announcements, native sharing handoff, live ad obstruction fix, hosted CI,
credential rotation, platform drain and rollback acceptance. Existing deterministic
session concurrency tests do not replace real two-tab acceptance. No overall
release approval or engagement/retention uplift follows these local gates.

## Measurement findings from source inspection

`RetentionService.daily_return_rate` aggregates logged-in account activity on
adjacent calendar dates; it is not new-user cohort retention. Its overall ratio
weights account-days, not distinct participants across the entire window.

Before interpreting as engagement:

1. Yesterday's denominator currently includes returns during today, whose return
   day is incomplete. Use only fully observed return days or label partial rows.
2. `DATE(created_at)` and `CURRENT_DATE` use database timezone, while other metrics
   explicitly use UTC. Define a single timezone/captured cutoff and exclude future
   events consistently.
3. Retention currently accepts any activity type. Define eligible intentional
   actions/confirmed views and audit actual instrumentation for speculative
   selection, bots, retries, account/test traffic and missing events. Do not
   retroactively call historical selection logs confirmed viewing.
4. Account-day first-to-last activity span excludes single-event days and includes
   idle gaps. It is neither active time nor session duration; show its denominator
   and exclusions and remove claims that longer span proves a better experience.
5. Separate unavailable source data from no observed returns; expose raw eligible
   and returned counts with observation window, identity coverage and limitations.

Next implementation slice: ratify definitions, add deterministic timestamp/event
boundary tests, correct queries/labels, and verify controlled event-to-report
reconciliation. Production engagement remains unassessed; owner's humor direction
is an editorial brief, not participant evidence or a validated retention signal.

## Measurement correction follow-up

Implemented explicit UTC boundaries and bound SQL parameters, recognized activity
types, complete next-day observation (latest cohort two days ago), future-event
exclusion and raw eligible/returned account-day counts. Window bounded 1–365 days.
Dashboard labels describe recorded account returns, remove arbitrary 20% success
color and distinguish query-unavailable from no eligible return data. Account-day
span now uses UTC and excludes future/unsupported events; still excludes
single-event days and includes idle gaps, explicitly disclosed.

Backend: **1,362 examples, zero failures, seven existing pending**, 78.07% coverage,
exit 0. Fixed-time UTC boundary regression added. No production event reconciliation,
identity/bot/test-traffic audit, new-user cohort metric or confirmed-attention
claim. Browser metrics presentation not rerun in this slice. Changes uncommitted;
temporary Redis stopped. Earlier findings describe pre-correction behavior.

Boundary regression follow-up: real SQL retains UTC cohort dates under an
America/Los_Angeles connection timezone; future/unsupported events do not inflate
account-day spans; unavailable return queries differ from available empty data.
Real metrics HTML route verifies limitations and distinct empty/unavailable text.
Full backend **1,366 examples, zero failures, seven pending**, 78.10% coverage,
exit 0; syntax/diff pass. This is rendered-route evidence, not visual browser or
production reconciliation. Temporary Redis stopped; changes remain uncommitted.