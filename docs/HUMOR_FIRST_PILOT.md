# Humor-first editorial pilot

Owner brief: quick, visually engaging humor with payoff; less political/news
commentary and low-payoff long text. This is editorial direction, not participant
research. Current small live review is incomplete and does not establish uplift.

## Candidate

`ENABLE_HUMOR_FIRST_MIX=true` multiplies existing selection weights by 2.0 for
the expanded `HUMOR_FIRST_SOURCES` list (38 visual/punchline humor communities)
and 0.15 for `COMMENTARY_SOURCES` (41 political, text-wall, Q&A and dating-screenshot
communities) in
`SimpleMemeSelector`. Other sources stay neutral; unset/other flag values retain
baseline behavior. Lists are case-insensitive editorial proxies, not automated
political/humor classification. They do not classify individual posts, remove
politics entirely, detect long text or guarantee visual humor.

No additional fetches, inventory deletion, source-list change or new service.
Existing unseen-first, scarcity, engagement, explicit preferences and exclusions
remain in force. Consequently the pilot changes ordering/probability, not the
composition of an entire inventory exhausted over a long session. Strong existing
engagement/preference weights can outweigh this bounded multiplier.

The shared selector serves Random/home/Similar and potentially other callers;
this is not an isolated topic lane or cohort canary. A same-source Similar pool
gets the same multiplier on all candidates, so its relative weights are unchanged.
Exact links and Search are not directly filtered by this pilot.

## Acceptance before enablement

- Run backend selection and route regressions, then browser candidate checks.
- Keep flag off in production pending review. Deploying code is not enabling it.
- Record web revision, flag, audience and window; compare ordinary displayed
  selections against baseline. Do not combine this with a freshness-fetch change.
- Compare owner/editorial worthwhile ratings, reading effort with payoff,
  unwanted political commentary and first-worthwhile selection count/time.
- Record source/format mix, repetition, media readability/availability and unknowns.
  Do not present a source-weight test as measured humor or satisfaction gain.
- Stop on wrong-content/safety regressions, worsened readability or unacceptable
  repetition; disable flag consistently across web processes to restore baseline.
- No provider budget increase or forced maintenance needed. Real-user preference
  differences remain relevant even though the owner defines the product direction.

Status: local candidate only, not enabled/deployed; live review still incomplete.