# Execute the content baseline

This is human observation, not a scripted feed-fetch exercise. No supply/ranking
change is enabled. Follow the [quality roadmap](MEME_CONTENT_QUALITY_ROADMAP.md).

## Record observations privately

Keep the audit file outside the repository. Use a separate private cover sheet for
revision, UTC windows, browser/device, sampling method and reviewer agreement.
Do not include account emails, session IDs, URLs, titles or credentials in input.
Record 100 actually visible selections across two time windows, guest/returning
conditions and mobile/desktop. Double-review 20 observations. Do not label
prefetch as viewed or infer enjoyment from Next. Do not accelerate production
requests for this audit. Stop on wrong-content actions or privacy concerns.

Create a JSON array. Each observation has exactly these fields:

```json
[
  {
    "id": 1,
    "session": "guest",
    "device": "mobile",
    "visible": "yes",
    "available": "unknown",
    "readable": "unknown",
    "repeated_url": "unknown",
    "repeated_artwork": "unknown",
    "source_age": "unknown"
  }
]
```

This example is schema only, not a recorded observation. Use unique positive
integer row numbers. session is guest/returning; device is mobile/desktop.
visible is yes/no; other judgments are yes/no/unknown. Source age is under_day,
one_to_seven_days, over_seven_days or unknown. For invisible selections all
judgments/age must be unknown. Judge availability by usable media, not HTTP 200;
judge repeated artwork separately from repeated URLs and caption variants.
If age cannot be verified, retain unknown. Do not put subjective humor ratings
into these objective categories; collect consented feedback separately.

## Summarize offline

From the repository root, with isolated project dependencies:

```sh
ruby scripts/isolated_bundle.rb exec ruby scripts/summarize_content_audit.rb /absolute/private/path/audit.json
```

No app boot, Redis access, provider calls or account mutations occur. Input is
bounded to 256 KiB/1,000 rows; errors omit values and paths. Output includes counts,
explicit denominators, unknowns, source-age distribution and guest/returning and
mobile/desktop sample mix. Review both mixes before claiming baseline coverage.
Unknowns stay in visible denominators; zero denominators yield null percentages.
target_met means 100 visible observations only, not research/quality acceptance.
Output intentionally omits raw row identifiers and free text. Review aggregates
for small-sample privacy before sharing. Do not commit private input/output.

## Decision meeting

Pair results with three maintenance outcomes and 5–8 user observations. Source/
topic concentration, within-session repeat boundaries, usable-media timing,
recovery attempts and subjective worth require the separate reviewer cover sheet;
this first tool does not compute them. Rank three findings, choose one pilot,
define success/stop conditions before coding, and record limitations in the
[acceptance ledger](EXPERIENCE_ACCEPTANCE_LEDGER.md). No automatic score increase
or automatic newest-post rollout follows from this report.