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

### Selection pipeline follow-up

Local telemetry-batching implementation: random.json opts into a bounded
fiber-local batch around the existing total measurement. Nested completed stage
samples retain their RPUSH/LTRIM ordering and flush in one pipeline on normal
completion or exception unwinding; standalone callers still record immediately.
At 64 pending samples a chunk flush bounds memory. Telemetry errors remain soft
and batch state clears before final flush. No cache/history/selection policy
change. Stage timings no longer include the former nested telemetry network waits,
so historical benchmark distributions straddle a measurement-boundary change.
selection_pipeline/route_total still include the final flush. Validate runtime
benefit after approval; the local experiment is not production acceptance.
Validation: 1,232 backend examples, zero failures, seven pending, 76.28% coverage,
gates passed, exit 0. Includes nested single-flush ordering, result preservation,
exception cleanup, soft telemetry failure, bounded buffering and simultaneous
thread isolation. No frontend changes; disposable test Redis stopped.
Route-level acceptance additionally confirms one flush containing exactly
pool_manager_lookup, pool_lookup, selection and total, retained Redis samples,
unchanged response state and cleared batch storage. Latest full isolated run:
1,233 examples, zero failures, seven pending; 76.36% coverage, exit 0. Still local,
uncommitted and undeployed.

Local decoding experiment: 5,000 synthetic records, 1,707,781 JSON bytes, three
warm-ups and 20 parses on isolated project Ruby produced min/median/max
2.07/2.62/4.94ms. Excludes real payload shape, network transfer, Redis, concurrent
load and production hardware. Does not establish production parsing cost, but
does not support blaming parsing alone for the observed 450.36ms pool lookup.

Static populated-route trace identifies four separate benchmark recording
pipeline flushes: pool_manager_lookup, pool_lookup, selection and total. Each
already batches its RPUSH/LTRIM pair but flushes independently. Candidate next
experiment: request-scoped batched recording with preserved stage samples,
standalone behavior, nested/exception cleanup and thread isolation. Do not add
an inventory process cache or remove telemetry on this evidence alone.

After operator-reported `4010046` deployment, one public response reported
route_total 923.26ms, selection_pipeline 743.36ms, pool_lookup 450.36ms and
selection_work 119.73ms. The roughly 173ms parent/children difference includes
outer benchmark recording and surrounding overhead; it is not pure telemetry.
The populated pool manager path performs one RedisService.get('meme_pool'),
which decodes the full payload, then returns without expansion. The enclosing
pool helper also records pool_manager_lookup. No redundant pool read was found
to remove. A regression now enforces one populated-pool read and no request-time
fetcher/maintenance lock/batch fetch. No runtime change or process cache added;
payload transfer/decoding and nested telemetry remain investigation candidates.

After operator-reported `1838106` deployment, one response returned route_total
824.18ms, selection_pipeline 654.54ms, response_prepare 167.17ms, history_write
55.05ms and likes_lookup 111.62ms/database_fallback. All expected fields and 200/
no-store checks passed. Lower than earlier individual samples, not a controlled
causal comparison or percentile.

Local timing follow-up exposes pool_lookup and selection_work inside the existing
benchmark blocks, excluding each block's own subsequent benchmark recording call.
Pool lookup still includes nested pool-manager instrumentation; selection_work
includes selector history/preference I/O, not just CPU. Parent-minus-children
contains outer recording calls and surrounding overhead, not exclusively telemetry.
No additional Redis writes or selection-policy changes; timings overlap parents.

After operator-reported `9b0311a` deployment, one public response reported
route_total 965.95ms, selection_pipeline 778.80ms, response_prepare 182.86ms,
history_write 59.06ms, likes_lookup 123.31ms and database_fallback; HTTP 200 and
expected fields. Selection was roughly 81% of handler duration in this sample,
not a field percentile or algorithm-only CPU cost.

Local review found history retrieval prunes then reads in two sequential Redis
calls. Follow-up pipelines those commands in order and returns the resolved read
result. It changes neither history TTL/bounds nor selection-time commit policy;
it is not a transaction or ACK/session concurrency fix. Existing duplicate route
marking and benchmark telemetry remain unchanged. Expected benefit is one fewer
sequential network wait per history read, not a measured production speedup.

History-read pipeline validation: 1,226 backend examples, zero failures, seven
pending; 76.23% coverage, gates passed, exit 0. Ordered/resolved-result and
failure-path tests passed alongside existing real-Redis pruning, recency,
deduplication, capacity and expiry coverage. Disposable Redis stopped; syntax and
whitespace checks passed. Three-file slice remains local and uncommitted.

### Pipeline rollout and likes-cache follow-up

After operator-reported `28b8c6e` deployment, five sequential public random.json
requests in one guest cookie session, spaced two seconds apart, all returned 200,
expected identity fields and database_fallback. Sample ranges/medians (ms):

| Measurement | Min | Median | Max |
| --- | ---: | ---: | ---: |
| Client request elapsed | 1253.38 | 1394.64 | 1416.74 |
| response_prepare | 169.11 | 171.11 | 177.49 |
| history_write | 55.68 | 56.40 | 58.36 |
| likes_lookup | 112.31 | 112.98 | 120.08 |
| impression_issue | 1.92 | 2.47 | 9.21 |

No warm hit occurred, so cache-hit versus fallback latency is unmeasured. Requests
selected content and issued pending impressions but did not ACK visible views;
this is not an ordinary-user content audit or media-ready measurement. Client
elapsed includes transport/client overhead; unmeasured time cannot all be assigned
to application code. Investigate existing pool/selection measurements and
session/middleware/network costs before prioritizing another likes optimization.
Five observations do not establish field p95 or controlled before/after benefit.

Local follow-up adds route_total (handler entry through JSON serialization) and
selection_pipeline (the existing benchmark call, including its Redis recording).
They add monotonic clock reads only. route_total excludes before/after filters,
outer middleware/session persistence and transport. selection_pipeline includes
pool lookup, selection, nested instrumentation and their telemetry writes, not
just algorithm CPU. Parent and child durations overlap; never sum all stages.
Use these to locate the remaining gap before proposing another optimization.

Operator reports deploying `5dd473a`. One public response returned history_write
57.54ms and response_prepare 175.00ms, versus earlier single samples of 235.43ms
and 355.88ms; likes_lookup was 116.94ms. This is encouraging, not a controlled
comparison or percentile. HTTP 200, no-store/private and expected fields passed.

Likes lookup already uses a 300-second cache: GET, database fallback on miss,
SETEX for a successful result. Cold versus warm status was not measured in that
production response. Added real-Redis tests confirming successful zero and
nonzero values survive a second read without another DB query and retain expiry.
No runtime/cache policy change. Full isolated run: 1,221 examples, zero failures,
seven pending, 76.13% coverage, exit 0. Production cold/warm attribution remains
open; do not lengthen TTL or cache outage fallbacks to chase a single sample.

Local attribution follow-up adds X-Likes-Lookup on successful random.json:
cache_hit, database_fallback, unavailable, not_requested or unknown (allowlisted).
The helper records whether its existing fallback ran; no extra cache read/write
or database query is introduced. database_fallback includes a cache miss or Redis
unavailability and does not distinguish them. The value is request-instance state,
captured immediately after lookup, and contains no URL, key or account identifier.
Pair it with likes_lookup duration during ordinary browsing after approved rollout;
do not interpret a slow cache_hit alone as database latency.

Attribution acceptance: consecutive real-Redis route requests report database
fallback then cache hit; a likes DB failure keeps HTTP 200/zero fallback with
unavailable attribution; replacement helpers without diagnostic state report
unknown. Final isolated run: 1,224 examples, zero failures, seven pending,
76.20% coverage, exit 0. No frontend changes in this slice. Still uncommitted and
not deployed; no new production sample collected.

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