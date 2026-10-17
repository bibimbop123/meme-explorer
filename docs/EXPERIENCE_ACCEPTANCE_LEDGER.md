# Experience acceptance and baseline ledger

## Execution state

Roadmap: [remaining-work execution](REMAINING_WORK_EXECUTION_ROADMAP.md).
Stage 0 is in progress; stage 1 collection is prepared, not completed.
Implementation candidate `72a8fe4`; subsequent searchable-community/unseen-label
changes are local and uncommitted. Do not attribute local changes to production.

Use this ledger for results, not inferred completion. For each new observation
record UTC time, environment, actual revision (or unknown), browser/OS, method,
result, limitation and next action. Never include credentials or account emails.

## Stage 0: acceptance record

| Check | Evidence/result | Status / next action |
| --- | --- | --- |
| Candidate frontend served | Public HTML markers; bundle, viewer CSS and keyboard JS byte-matched `72a8fe4` | Observed; full server SHA unknown |
| Web/worker revision and environment alignment | No operator SHA/config attestation recorded | Operator verifies privately |
| Local build and test gates | Latest full run: 1,215 examples, 0 failures, 7 pending; 76.10% coverage; 141 frontend tests; build passed | Local evidence, not hosted CI |
| Guest Next/Previous and help focus | Real local Rack app in Chrome; exact return image and focus restoration passed | Local scripted acceptance |
| Save -> email login/signup | Actual local forms and full-page exact-meme redirects passed | Local scripted acceptance; disposable users removed |
| Narrow layout | Chrome fixtures at 320/375px: sticky navigation and menu positioning passed | Fixture, not physical-device acceptance |
| Enlarged text | Doubled root font fixture exposed/fixed Previous overflow | True browser zoom still pending |
| Dark navigation | Scoped Chrome computed colors passed | Full-app theme check pending |
| Screen reader | No manual evidence | Pending operator/manual review |
| Real Reddit OAuth | Mocked/server tests only | Pending approved callback and operator-owned account |
| Exact share recipient preview | No current platform-preview evidence recorded here | Pending operator preview check |
| Credential rotation / hosted CI | Not verified | Operator confirms privately / records exact-SHA CI result |

Do not pass stage 0 while a critical wrong-content, authentication, false-save,
hidden-focus or inaccessible-navigation failure remains. See
[release checklist](UX_RELEASE_CANDIDATE.md) for task details and rollback rules.

## Stage 1A: three ordinary supply cycles

One historical production completion is known: 990 fetched/validated candidates,
981 unique candidates, 162 previous unique URLs, 885 candidate new unique URLs,
1,047 published records, publication succeeded, 278.385 seconds job duration.
This is not the required three-cycle observation and is not current inventory.

### Operator-provided inventory read-back

Sample UTC time and deployed SHA were not supplied. The read-only diagnostic
reported 3,640 metadata records and 3,640 unique payload URLs, zero invalid records
under its structural checks, zero duplicate URLs, and refresh age 26 seconds.
Source-age buckets: 441 under one day (12.1%), 3,124 one-to-seven days (85.8%),
75 over seven days (2.1%), zero unknown. No cooldown or maintenance lease existed
at sampling time. Random list count matched 3,640; derived pools overlap and must
not be added together. Fresh-list membership (2,013) is not the under-one-day
source-age count. The report is non-atomic and does not establish media health,
visual uniqueness, humor quality or scheduler consistency. Compared with the
earlier 1,047-record publication, the sampled count is 2,593 higher; this is not
a measured single-cycle yield. Await matching maintenance logs before assigning
this read-back to one of the three observed ordinary cycles.

### Operator collection procedure

1. In the intended worker's logs, observe the next three **ordinary scheduled**
   maintenance attempts. Do not enqueue extra work or run direct maintenance.
2. For each attempt, retain sanitized Starting, Inventory batch outcome,
   Maintenance finished/Success or skip/error lines, and terminal job duration.
3. After each completed attempt, run the existing read-only diagnostic in the
   matching environment:

   ```sh
   bundle exec ruby scripts/check_pool_inventory.rb --content-summary
   ```

   This opt-in reads bounded inventory payload and emits aggregates. It does not
   validate media availability, humor or visual uniqueness. Record its UTC sample
   time and non-atomic nature. Do not share connection URLs or payloads.
4. Record cumulative provider counters as snapshots per fetcher, never sum them.
   If a cycle skips, record why; do not bypass the lease/cooldown to force success.
5. If worker logs stop, use the earlier read-only Sidekiq process/queue check.
   A lease alone does not prove an active job. Preserve inventory and evidence.

| Cycle | UTC / worker SHA | Outcome and duration | Fetched / validated / candidate new unique | Published / read-back count | Source-age buckets / invalid / duplicates | Skip/error/provider explanation |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Pending | Pending | Pending | Pending | Pending | Pending |
| 2 | Pending | Pending | Pending | Pending | Pending | Pending |
| 3 | Pending | Pending | Pending | Pending | Pending | Pending |

Exit: all three attempts accounted for, publication/read-back distinguished from
fetch success, and unexplained losses/no-ops assigned a concrete investigation.

## Stage 1B: 100-selection content audit

Collect ordinary browsing with consent where appropriate, not a scripted fetch
storm. Keep content examples private if needed; do not export session histories.
Use local audit row numbers, not user identifiers. A requested/prefetched meme
must not be counted as visibly viewed.

Record per selection: audit number, guest/returning condition, device class,
visible yes/no, readable yes/no, media available yes/no, source age known/unknown,
age bucket, repeated URL yes/no, repeated artwork yes/no, and broad topic/source
group. Do not assume different URLs mean different artwork or unseen means fresh.

Report aggregates with denominators: visible/requested, readable/visible,
available/visible, known-age/visible, repeated-URL/visible, repeated-artwork/visible,
and source/topic concentration. Keep subjective relevance/humor feedback separate.

Status: **0/100 audit selections recorded in this ledger**. Public startup smoke
checks are not a representative content audit.

## Stage 1C: 5–8 observed users

Recruit with consent; no account email exports. Use anonymous participant labels
and operator-owned staging accounts where account creation is not the task.

Tasks, without coaching:

1. Find a meme worth keeping; describe why.
2. Advance, then recover the previous meme.
3. Save, authenticate if needed, and confirm the same meme is retained.
4. Recover it from favorites and share an exact link.
5. Find a different topic using Search.

Record task success, time/hesitation, errors, device, assistance and a short
consented quote. Distinguish study task completion from production retention.
Stop for privacy/accessibility distress or wrong-account/wrong-content actions.

Status: **0 participants observed in this ledger**; automated browser scripts
are not user research.

## Next intervention decision

### Operator-reported follow-up rollout and timing sample

Operator subsequently reports deploying `f796705`. One fresh public response
contained all sub-stages: response_prepare 355.88ms, history_write 235.43ms,
media_detect 0.03ms, likes_lookup 119.80ms, impression_issue 2.46ms,
serialization 0.02ms; HTTP 200, no-store/private and expected identity fields.
This is one observation, not p50/p95 or a measured before/after comparison.

Local follow-up pipelines the four history-write commands in existing order,
preserving pruning, deduplication, bounds and TTL with no reply dependencies.
Pipelining reduces sequential network waits; it is not a transaction and does not
fix ACK/session races or change selection-time history semantics. No production
improvement is claimed until ordinary-session timings are compared after approval.

Pipeline follow-up validation: 1,219 backend examples, zero failures, seven pending;
76.18% coverage, gates passed, exit 0. Added ordered-command/failure tests and a
real-Redis regression that directly reads the sorted set after mark_seen, proving
write-time expired-score pruning and renewal of a short TTL without allowing the
read helper's pruning to mask errors. Existing deduplication and capacity tests
also passed. Disposable Redis stopped. Implementation remains uncommitted.

Operator reports merging/deploying `120b70a`. A public random.json request returned
200, no-store/private, expected response identity fields, and timings:
response_prepare 347.03ms, impression_issue 2.62ms, serialization 0.02ms. A fresh
HTML response showed the searchable community; an earlier request still returned
old markup. Exact deployed revision/transition cause were not independently
verified. One sample is not a percentile or stable bottleneck estimate.

Local follow-up adds history_write, media_detect and likes_lookup sub-stages
inside response_prepare. They overlap the parent duration and must not be added
to it. No extra network telemetry, history-policy or caching changes are included.

Interpretation after rollout: history_write measures the route's legacy history
write (currently four sequential Redis commands), media_detect measures local
type detection, and likes_lookup measures the cache/DB fallback helper. Large
history time suggests investigating Redis round trips; large likes time suggests
cache misses/DB/network work. These are hypotheses until sampled. Do not remove
history writes or change ACK semantics as a performance shortcut. A controlled
delayed-lookup regression verifies attribution to likes_lookup and its parent;
it is not a production benchmark.

### Local post-selection measurement slice

`/random.json` now has local, uncommitted Server-Timing stages: response_prepare
(history/session field preparation, response building and initial likes lookup),
impression_issue (pending state, engagement lookup and catalog registration), and
serialization. These use monotonic clocks and add no Redis telemetry writes.
The existing SelectionBenchmark total still means pool/selection work, not the
entire HTTP request. New headers exclude session middleware persistence, network
delivery and media-ready/render time. No production timings collected yet.
After approved rollout, collect a bounded ordinary-session sample in browser
Network tools, record sample size and stage p50/p95, and compare with full request
and media-ready timing. Do not infer a bottleneck or improvement before measuring.

Code review also identified duplicate like-count lookups in each random/similar
JSON response: response building fetched the count, then impression issuance
fetched it again. Local follow-up reuses that server-built count within the same
response, preserving fallback lookup for callers without a supplied count and
coercing the output to integer. This proves one fewer helper lookup per tested
JSON response, not a measured production latency improvement.

Review checkpoint: zero-count reuse and missing-count helper fallback are covered.
An initial new HTML-route expectation failed because that route separately calls
engagement lookup twice; the test was corrected to exercise the helper fallback
directly, not to claim homepage deduplication. Final isolated full rerun passed:
1,215 examples, zero failures, seven pending, 76.10% coverage, exit 0. No homepage
deduplication, ACK migration, fetch-policy or production-setting change is included.

### Bounded release grouping

- Metadata quick wins: searchable initial community, unseen-not-fresh wording,
  related template/frontend tests and rebuilt bundle.
- Measurement/lookup slice: aggregate post-selection Server-Timing and one
  server like-count lookup per random/similar JSON response, with regressions.
- Documentation: roadmap, acceptance ledger and operator-reported release evidence.

All three groups remain local/uncommitted. Review and obtain explicit commit,
push and deployment approvals. After approved rollout, verify actual deployed
revision, guest and signed-in response state, no-store behavior and timing header.
Collect ordinary usage timings rather than generating a production benchmark
storm. Preserve the previous known-good revision and rollback if correctness or
request failures regress. None of this completes the three-cycle/user-study gates.

Not selected until evidence is available. Rank at most three findings by impact,
frequency, confidence, effort and dependencies; choose one reversible intervention.
If concurrency corrupts legitimate ACK/history state, prioritize reproduction and
correctness over ranking experiments. If latency dominates, measure server stages
and media-ready time separately before optimizing.

| Finding | Evidence / denominator | Impact / confidence | Proposed bounded fix | Success rule / rollback |
| --- | --- | --- | --- | --- |
| Awaiting baseline | Not yet collected | Unknown | Not selected | Define before implementation |