# Feed reservations and acknowledged-history protocol

Status: partially implemented prerequisites; **not integrated or approved for rollout**.
Identity prerequisite implemented locally: shared validated random feed_session_id
used by homepage/random/similar and initialized for recipient impressions. Preserved
through successful email/signup/validated OAuth session rotation; cleared on logout.
Reservation/acknowledgement prerequisites below are unused by routes. Legacy histories
are not migrated, so upgrade can reset recent-selection continuity once. Initial
parallel requests before session persistence and session-store races remain open.
Builds on ANTI_REPEAT_EXECUTION_PLAN.md Phase 2. Existing anti-repeat selection
remains active; do not remove selection marking until all migrated paths are tested.

Active-reservation primitive is now implemented locally as FeedReservationService,
but unused by app routes. Atomic acquire/release uses Redis server time, 120-second
expiry, 20-active cap, hashed content/session key namespace, and token ownership.
The lease-only acquire does not write history or validate ACK credentials.
The newer acquire_unseen atomically checks acknowledged-history recency; the
coordinators below bind credentials and reconcile history, still unused by routes.
Returned token is stored as owner metadata in Redis (not hashed there); no raw media
payloads are stored. Two keys share a hash tag; real Cluster deployment not tested.

Nine real-Redis examples cover ownership, capacity, expiry/successor protection,
session isolation, unchanged history, key TTLs, invalid input, errors/unavailability
and two independent connections racing on one content identity. Full backend:
1070 examples, zero failures, seven pending, 62.26s; 74.28% (4623/6224), gates pass,
exit 0; 121 frontend tests pass. Initial error-stub teardown failure was corrected;
final full run is green. No live route behavior change or rollout approval.

## Current implementation map and next migration review

Concrete proposed transition/replay rules and acceptance matrix are in
[Feed migration contract](FEED_MIGRATION_CONTRACT.md). This is a review proposal,
not implemented route behavior or permission to enable a switch.

The checkpoint notes below are reverse-chronological engineering evidence, not a
single cumulative statement of current gaps. Older "unimplemented" statements are
historical. Current local prerequisites:

| Component | Implemented responsibility | Still not provided |
| --- | --- | --- |
| FeedReservationService | Lease ownership/expiry; atomic unseen admission | Inventory-wide eligibility/replay proof |
| FeedAcknowledgementStore | Bound credential/context/owner; bounded snapshots; pending/receipt caps; history repair | PostgreSQL provenance verification by itself |
| FeedAcknowledgementService | Commit/verify DB binding; counters once per ID; duplicate history repair | Cross-store transaction or background durable repair |
| FeedIssuanceService | Acquire unseen lease then issue credential; owned failure cleanup | Atomic acquisition plus issuance; crash-free cleanup |
| FeedCandidateService | Caller-ranked traversal; per-call work budgets; server offset and conflict observations | Snapshot-bound continuation/aggregation, replay, personalization/media filtering |
| FeedTraversal | Process-local copied/deduplicated snapshot, private offset, cross-chunk conflict aggregation, serialized advance | Durable/client continuation, full media snapshot, replay/current-inventory proof |

**Live path remains legacy:** homepage/random/similar select and mark selection;
exact recipient pages also issue session pending IDs; /api/impressions consumes
session pending metadata. Browser sends impression_id only, not the unused store's
credential. No new service is connected to those entry points. Do not remove marks
or change only one entry point.

Before a coordinated migration patch:

1. Review a stable server-owned snapshot/continuation contract, cross-chunk conflict
   aggregation/dedup, pool changes and oldest-acknowledged replay admission. A bare
   offset or suffix_complete cannot authorize replay/exhaustion.
2. Preserve existing personalization/media eligibility and exact-page/Saved identity.
   Decide whether exact recipient views require leases or credential-only issuance;
   do not block exact recovery merely because feed eligibility rejects a repeat.
3. Specify a default-off reviewed switch and old-page protocol coexistence. Dispatch
   ACK by explicit version/credential presence without fallback on invalid new tokens;
   legacy pending IDs must remain usable for their original lifetime. Define rollback
   while new credentials are outstanding; do not erase either history namespace.
4. Carry issued credentials through initial HTML, random/similar JSON, prefetch,
   Back/Forward restoration and ACK retries. Bind attribution from server state,
   never request-body user/title metadata. Preserve auth continuity/logout isolation.
5. Handle capacity, temporary contention, incomplete scans and outage separately;
   retain current media, avoid nested retry loops, and disclose exhausted replay.
   Provisional bounds and total-cap wait UX require capacity/privacy review.
6. Test every entry point and protocol transition together, then build JS before
   backend boot, full backend/frontend gates, browser two-tab/offline/media failure,
   exact sharing/Saved/auth recovery. Production acceptance/security/exact-SHA CI
   and deployment authorization remain independent blockers.

Latest validated code: 1182 backend examples, zero failures, seven pending;
75.54% (4938/6537), gates pass, exit 0; 121 frontend tests pass. No route,
configuration or production changes.

## Checkpoint evidence (newest first)

Aggregate media-budget regressions: two additional cases verify byte/node budgets
are shared across unique candidates, exact boundaries accepted, duplicate identities
not double-charged, and aggregate overflow rejected before issuance with partial
snapshot released. No implementation change or measured capacity approval.
Full backend 1182 examples, zero failures, seven pending, 66.00s; 75.54%
(4938/6537), gates pass, exit 0; 17 targeted snapshot cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged.

Snapshot-to-JSON-builder regression: real issuance then existing build_meme_json
preserves gallery slides/count, video file/type, dimensions and Reddit permalink,
with no speculative history or DB impressions. Not browser rendering/live-media
or all resolver-field acceptance. Full backend 1180 examples, zero failures, seven
pending, 65.65s; 75.54% (4938/6537), gates pass, exit 0; 15 targeted snapshot tests
pass (partial coverage exit 2); 121 frontend tests pass; syntax/whitespace pass.
No route migration or rollout enabled; release gates remain open.

Snapshot media preservation: allowlisted file/type/dimensions/gallery/source fields
now recursively copied/frozen, excluding credentials/viewer state. Separate 1 MiB
payload-string and 20000-node aggregate budgets plus depth 6, alongside original
metadata/count caps. Invalid types/nonfinite floats/colliding normalized nested keys
reject before issuance. Not URL safety/media semantic validation or full renderer
acceptance. Two regressions cover immutable media and malformed/budget rejection.
Full backend 1179 examples, zero failures, seven pending, 66.66s; 75.45%
(4932/6537), gates pass, exit 0; 14 targeted snapshot tests pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged.

Parsed expired-credential boundary: new real Redis/DB regression verifies a shaped
v2 envelope can still be unauthorized after deadline expiry, without starting DB
transaction, writing history/counters or deleting a successor lease. Score-driven
expiry simulation, not wall-clock/provider acceptance. Full backend 1177 examples,
zero failures, seven pending, 66.11s; 75.32% (4902/6508), gates pass, exit 0;
29 targeted coordinator/envelope cases pass (partial coverage exit 2); 121 frontend
tests pass; syntax/whitespace pass. Routes unchanged; release gates remain open.

Parsed envelope/coordinator integration: two real Redis/PostgreSQL regressions feed
strict v2 JSON into coordinator, verify duplicate counters once and issued metadata
instead of forged body attribution, and reject syntactically valid credentials in
another session. Parser shape is not authorization. Full backend 1176 examples,
zero failures, seven pending, 66.16s; 75.37% (4905/6508), gates pass, exit 0;
28 targeted coordinator/envelope cases pass (partial coverage exit 2); 121 frontend
tests pass; syntax/whitespace pass. No routes connected or rollout enabled.

ACK raw JSON duplicate-key rejection uses installed JSON allow_duplicate_key:false.
One matrix regression covers repeated IDs/protocol/token, escaped-equivalent keys
and nested duplicates. Already-parsed Hash cannot recover lost duplicate provenance.
Initial custom object insertion approaches failed because parser collapses keys;
removed in favor of supported strict option. Final full backend 1174 examples, zero
failures, seven pending, 66.04s; 75.37% (4905/6508), gates pass, exit 0; nine targeted
envelope tests pass (partial coverage exit 2); 121 frontend tests pass; syntax/
whitespace pass. No routes changed or rollout enabled.

Unused ACK body reader: reads at most 1025 bytes for a 1 KiB cap, bounds JSON nesting,
then uses the no-fallback envelope classifier. Caller owns stream position/content
type; no Content-Length trust or route integration. Three tests cover valid legacy/
v2, byte boundary/oversize sentinel, malformed/deep/unreadable body. Full backend
1173 examples, zero failures, seven pending, 65.56s; 75.40% (4907/6508), gates pass,
exit 0; eight targeted envelope cases pass (partial coverage exit 2); 121 frontend
tests pass; syntax/whitespace pass. Release gates unchanged.

Envelope ownership follow-up: valid legacy/v2 parse results and copied identifier
strings are frozen; request strings remain mutable without altering validated
results. One mutation regression; still no route use or authorization claim.
Full backend 1170 examples, zero failures, seven pending, 66.07s; 75.34%
(4898/6501), gates pass, exit 0; five targeted envelope cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Release gates unchanged.

Unused FeedAcknowledgementEnvelope validates parsed JSON shape and classifies
legacy-only IDs or complete integer-version-2 ID/token envelopes. Presence of any
new field prevents legacy fallback; malformed/mixed keys rejected, client attribution
excluded from result. Shape only, not ownership/expiry/DB authorization; routes
still unchanged. Four regression cases. Full backend 1169 examples, zero failures,
seven pending, 65.55s; 75.34% (4898/6501), gates pass, exit 0; four targeted envelope
cases pass (partial coverage exit 2); 121 frontend tests pass; syntax/whitespace pass.

Real snapshot conflict aggregation: Redis/PostgreSQL regression holds a prefix
lease, acknowledges remaining candidates, preserves conflict across chunk boundary
even after simulated lease expiry, then verifies a fresh pass rechecks/issues that
now-eligible prefix item. Snapshot completion is observational, not replay/global
exhaustion proof. Full backend 1165 examples, zero failures, seven pending, 65.77s;
75.30% (4886/6489), gates pass, exit 0; 12 targeted snapshot cases pass (partial
coverage exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged.

Process-local snapshot cancellation: cancel serializes with advance, closes an
incomplete pass and releases copied refs without Redis calls. Repeated cancellation
returns closed; invalid construction remains invalid. If issuance finishes before
cancel obtains lock, issued credential/lease are not revoked. Not request/network
abort or Redis reservation cancellation. Two mocked concurrency/lifecycle tests.
Full backend 1164 examples, zero failures, seven pending, 65.16s; 75.28%
(4885/6489), gates pass, exit 0; 11 targeted snapshot cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged.

Snapshot reference release: invalid partial construction and terminal/exception
passes drop internal candidate/session/user references. Returned issued candidate
remains usable; incomplete passes retain state. Makes references GC-eligible, not
immediate RSS reclamation or secure erasure. One internal-retention regression;
real lifecycle still passes. Full backend 1162 examples, zero failures, seven
pending, 65.36s; 75.30% (4881/6482), gates pass, exit 0; nine targeted snapshot
cases pass (partial coverage exit 2); 121 frontend tests pass; syntax/whitespace
pass. Routes unchanged; release gates remain open.

Snapshot aggregate byte budget: constructor caps copied unique URL/title/subreddit
string bytes at 1 MiB, in addition to 5000 input entries. Rejects before issuance,
clears partial copied candidates on overflow; duplicates not charged twice. Not
Ruby heap/RSS measurement or capacity approval. One boundary/multientry regression;
initial conflicting mock expectation corrected. Full backend 1161 examples, zero
failures, seven pending, 65.12s; 75.27% (4872/6473), gates pass, exit 0; eight
targeted snapshot cases pass (partial coverage exit 2); 121 frontend tests pass;
syntax/whitespace pass. Routes unchanged; release gates remain open.

Real snapshot lifecycle: unmocked Redis/PostgreSQL regression verifies copied URL/
title survive caller mutation, no speculative history/counters, original metadata
on ACK, duplicate counter dedupe and later acknowledged snapshot completion. Local
service evidence, not route/browser or replay acceptance. Full backend 1160
examples, zero failures, seven pending, 64.91s; 75.21% (4863/6466), gates pass,
exit 0; seven targeted snapshot cases pass (partial coverage exit 2); 121 frontend
tests pass; syntax/whitespace pass. Routes unchanged; release gates remain open.

Snapshot exception boundary: unexpected StandardError from candidate traversal now
closes the single-pass object and returns unavailable/stage:traversal without error
details. It cannot implicitly rerun partial work; pre-existing side effects remain
subject to TTL/retry rules, not rollback. One mocked fault regression added.
Full backend 1159 examples, zero failures, seven pending, 65.34s; 75.21%
(4863/6466), gates pass, exit 0; six targeted snapshot cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged.

Shared snapshot concurrency regression: two synchronized callers advance one
process-local traversal; mocked issuance executes once, one receives issued and
the other closed. Does not establish cross-process coordination or network-fault
acceptance. Full backend 1158 examples, zero failures, seven pending, 67.69s;
75.20% (4861/6464), gates pass, exit 0; five targeted snapshot tests pass (partial
coverage exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged.

Unused FeedTraversal now owns a bounded (5000 input entries) copied/deduplicated
URL/title/subreddit snapshot, validates it before issuance, retains private offset
and reservation observations, serializes advance calls, and closes on terminal
outcome. Completion reports snapshot_complete, not global exhaustion/replay proof.
No original media/gallery payload transport, durable state/client cursor or cross-
process coordination. Snapshot allocation bound is provisional, not memory approval.
Four mocked-issuance tests cover copying/dedup, aggregation, validation and closure.
Full backend 1157 examples, zero failures, seven pending, 65.02s; 75.19%
(4860/6464), gates pass, exit 0; four targeted snapshot cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged.

History-loss recovery: two real DB/Redis regressions verify completed credentials
can repair deleted history with original DB timestamp without renewed deadline,
pending membership or duplicate counters, but DB rows alone cannot authorize repair
after credentials are also deleted. Requires retained valid token and client retry;
not full Redis-loss recovery/background repair. Full backend 1153 examples, zero
failures, seven pending, 65.07s; 75.07% (4821/6422), gates pass, exit 0; 17 targeted
coordinator cases pass (partial coverage exit 2); 121 frontend tests pass; syntax/
whitespace pass. Routes unchanged; release gates remain open.

Traversal identity preflight: shared issuance-context validator checks server user
identity before scanning, including empty pools and end offsets. Invalid IDs cannot
produce misleading empty/suffix outcomes. One malformed-ID matrix regression.
Full backend 1151 examples, zero failures, seven pending, 64.82s; 75.10%
(4823/6422), gates pass, exit 0; 19 targeted candidate cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged;
snapshot/replay/migration/capacity/privacy acceptance remain open.

Persisted DB timestamp preflight: coordinator checks finite/positive/recent/nonfuture
created_at against PostgreSQL clock_timestamp inside transaction before counter
updates. Null/infinite/epoch/future/expired rows report database-stage unavailable;
correction permits same-token duplicate repair without inventing absent counters.
One real PostgreSQL regression covers matrix/recovery. Redis independently checks
timestamp bounds; cross-server clock skew remains an operational acceptance item.
Full backend 1150 examples, zero failures, seven pending, 65.19s; 75.10%
(4822/6421), gates pass, exit 0; 15 targeted coordinator cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged;
snapshot/replay/migration/capacity/privacy acceptance remain open.

Lease input consistency: reservation content validator now checks valid encoding
before strip/Redis, matching acknowledgement content validation. Regression covers
non-string/blank/oversized/invalid UTF-8 across acquire, acquire_unseen, validate and
release, confirming no Redis calls for malformed content. Routes unchanged.
Full backend 1149 examples, zero failures, seven pending, 65.00s; 75.05%
(4817/6418), gates pass, exit 0; 18 targeted reservation cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Snapshot/replay/migration/
capacity/privacy acceptance remain open.

Lease-only schema preflight: acquire/release now validate expiry/owner key types
before mutations. Wrong-type expiry cannot make release delete owner metadata
before failing; acquire schema failure preserves expiry pruning state. Two new
real-Redis fault/recovery tests. Predictable WRONGTYPE protection only, not general
Lua rollback safety. Existing unseen admission retains its three-key preflight.
Full backend 1148 examples, zero failures, seven pending, 65.11s; 75.09%
(4819/6418), gates pass, exit 0; 28 targeted reservation/issuance cases pass
(partial coverage exit 2); 121 frontend tests pass; syntax/whitespace pass.
Routes unchanged; snapshot/replay/migration/capacity/privacy acceptance remain open.

Issuance attribution preflight: shared store context validator now runs before lease
acquisition, preventing malformed title/subreddit/user metadata from creating
avoidable reservations that depend on cleanup. Store issuance still validates it
independently. One regression checks malformed values never acquire/release leases
or issue credentials, with unchanged history/DB. Routes unchanged.
Full backend 1146 examples, zero failures, seven pending, 64.81s; 75.09%
(4819/6418), gates pass, exit 0; 38 targeted issuance/store tests pass (partial
coverage exit 2); 121 frontend tests pass; syntax/whitespace pass. Snapshot/replay/
migration/capacity/privacy acceptance remain open.

Real continuation lifecycle: new unmocked Redis/PostgreSQL test acknowledges 100
prefix items, reaches later unseen item through next_offset, preserves prior
history/timestamps through speculative issuance, then commits only new ACK. Final
suffix remains suffix_complete, not whole-pool exhaustion. Local service evidence,
not snapshot binding, browser acceptance or performance benchmark.
Full backend 1145 examples, zero failures, seven pending, 71.42s; 75.12%
(4818/6414), gates pass, exit 0; 18 targeted candidate cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged;
snapshot/replay/migration/capacity/privacy acceptance remain open.

Continuation conflict follow-up: both budget exits now include reserved observation
for the visited chunk, allowing future coordinator aggregation without losing prefix
contention. Regression covers reserved prefix followed by acknowledged-only suffix;
existing budget assertions cover true/false observations. No aggregation or snapshot
binding implemented; suffix remains incapable of authorizing whole-pool exhaustion.
Full backend 1144 examples, zero failures, seven pending, 64.30s; 75.04%
(4813/6414), gates pass, exit 0; 17 targeted candidate tests pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged;
snapshot/replay/migration/capacity/privacy acceptance remain open.

Server-only continuation prerequisite: traversal accepts a validated integer offset
and returns next_offset on traversal_incomplete without slicing the candidate array.
Offsets apply only to the same stable ordered snapshot, not a client credential.
Resumed suffix completion returns suffix_complete with suffix reservation indicator,
never whole-pool exhaustion. Snapshot binding and aggregation of earlier conflicts/
dedup across chunks remain coordinator integration work; changing inventory cannot
reuse offsets as proof of exhaustion. Three new progress/validation tests pass.
Full backend 1143 examples, zero failures, seven pending, 64.27s; 75.07%
(4815/6414), gates pass, exit 0; 16 targeted candidate tests pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged;
snapshot/replay/migration/capacity/privacy acceptance remain open.

Traversal work bound: unused candidate service now caps issuance attempts at 100
and inspected entries (including duplicates) at 1000 per call. If more candidates
remain beyond either budget, returns traversal_incomplete, never false exhaustion.
Exact-budget complete traversal may report exhausted. Limits are provisional,
not production latency evidence. No continuation token/reranking policy yet;
repeating an unchanged prefix can starve later candidates, so integration MUST
define progress before rollout. Three regressions cover both bounds and boundary.
Full backend 1140 examples, zero failures, seven pending, 64.55s; 75.06%
(4813/6412), gates pass, exit 0; 13 targeted candidate tests pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged;
continuation/replay/migration/capacity/privacy acceptance remain open.

Ambiguous issuance follow-up: saved Redis issuance followed by simulated lost
response leaves pending orphan credentials, bounded by 20 pending and original
30-minute deadlines; no history/DB acknowledgement is invented. Owner cleanup
releases attempted lease, expired credential pruning restores capacity. Simulated
cleanup failure retains a lease only until original expiry. Two new tests use real
Redis state with response/cleanup fault injection and score-driven expiry, not a
real network partition or wall-clock expiry acceptance test.
Full backend 1137 examples, zero failures, seven pending, 64.18s; 75.02%
(4807/6408), gates pass, exit 0; 10 targeted issuance cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged; capacity/
privacy, wait UX, replay and migration gates remain open.

Traversal capacity follow-up: real pending-cap and total-receipt-cap tests verify
credential preservation and cleanup of newly attempted speculative leases. Pending
case leaves history/DB empty. Receipt fixture calls trusted Redis reconciliation
directly to populate capacity, so it tests accounting, not DB provenance. Both
limits still provisional; total-cap wait UX/privacy/capacity approval remain open.
Full backend 1135 examples, zero failures, seven pending, 64.06s; 75.02%
(4807/6408), gates pass, exit 0; 10 targeted candidate tests pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged.

Traversal failure/recovery follow-up: two real-service regressions cover injected
DB rollback retaining contention and same-token retry, and real Redis wrong-type
history after DB commit followed by repair. Original ACK repairs history using DB
timestamp, increments counters once and preserves a successor lease. Explicit
limitation demonstrated: during DB-success/Redis-lag, lease expiry can permit
reissuance before repair. This is eventual reconciliation, not cross-store exactly-
once selection. New successor impression IDs are separate ACKs, not deduplicated
against older IDs. No live routes or release gates changed.
Full backend 1133 examples, zero failures, seven pending, 64.13s; 75.02%
(4807/6408), gates pass, exit 0; eight targeted candidate tests pass (partial
coverage exit 2); 121 frontend tests pass; syntax/whitespace pass. Replay/migration/
capacity/privacy acceptance remain open.

Real traversal follow-up: two new Redis/PostgreSQL service tests verify abandoned
reservations remain unseen, simulated lease expiry permits recovery, ACK writes
history/counters, and subsequent traversal reports exhaustion. Simultaneous
traversals of the same ordered pool issue distinct identities/impression IDs and
leave history empty until ACK. No mocks of issuance in these two cases. Local
service evidence only, not browser/multi-tab, sustained-load or route acceptance.
Full backend 1131 examples, zero failures, seven pending, 64.16s; 75.05%
(4809/6408), gates pass, exit 0; six targeted candidate cases pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. No routes changed;
replay/migration/capacity/privacy acceptance remain open.

Unused candidate traversal: FeedCandidateService accepts server-filtered candidates
in caller-supplied ranking order, deduplicates URL/file identity, attempts issuance
once per identity, skips only already_acknowledged/already_reserved and stops at
capacity/error. Returns empty, exhausted (all acknowledged), or temporarily_reserved
(any reservation conflict) distinctly. Exhaustion is an observed traversal result,
not an atomic inventory-wide snapshot; no replay authorization or novelty guarantee
across content arriving later. Does not replace personalization/media filtering.
Four mocked-issuance orchestration tests pass; no real traversal-concurrency/route
acceptance claimed. Full backend 1129 examples, zero failures, seven pending,
64.08s; 75.05% (4809/6408), gates pass, exit 0; 121 frontend tests pass;
targeted four cases pass (partial coverage exit 2), syntax/whitespace pass. No
routes changed; replay/migration/capacity/privacy gates remain open.

Acknowledged-history snapshot prerequisite: store.history returns available entries
oldest-first with committed timestamps, or invalid/unavailable (never treating Redis
outage as empty). Redis-time age pruning and 5000-entry cap are atomic with read;
reads do not renew key expiry. Response shape/content/finite positive scores checked.
Snapshot is advisory only: admission still needs atomic eligibility/lease check;
it does not authorize exhausted replay. No selector/routes use reader yet.
Three added tests cover ordering/age/non-renewal, cap and empty/error/malformed
results. Full backend 1125 examples, zero failures, seven pending, 64.05s; 74.96%
(4788/6387), gates pass, exit 0; 27 targeted store tests pass (partial coverage
exit 2); 121 frontend tests pass; syntax/whitespace pass. Replay/migration/capacity/
privacy acceptance remain open; no production changes or score increase.

Stored timestamp validation follow-up: lookup rejects present acknowledged_at unless
it is a bounded positive finite decimal string, before coordinator DB work. One
regression exercises null/boolean/array/object/numeric/nonfinite/negative/zero and
oversized malformed values, then restores metadata and verifies normal duplicate
ACK. This validates shape, not proof of DB existence or timestamp provenance.
Full backend 1122 examples, zero failures, seven pending, 63.93s; 74.85%
(4771/6374), gates pass, exit 0; 38 targeted acknowledgement cases pass (partial
coverage exit 2); 121 frontend tests pass; syntax/whitespace pass. Routes unchanged;
replay/migration/capacity/privacy acceptance remain open.

Unseen-admission concurrency follow-up: independent Redis connections race the new
ACQUIRE_UNSEEN script; exactly one wins and admission writes no history. Repeated
acknowledged rejection preserves score/history expiry; invalid input and Redis
unavailability stay distinct. Three regressions added; no live behavior change.
Full backend 1121 examples, zero failures, seven pending, 63.97s; 74.86%
(4768/6369), gates pass, exit 0; 23 targeted reservation/issuance cases pass
(partial coverage exit 2); all 121 frontend tests pass; syntax/whitespace pass.
This is local service evidence only; inventory replay/route migration/capacity and
privacy acceptance remain open. No deployment or production score increase.

Atomic unseen admission prerequisite: FeedReservationService.acquire_unseen checks
versioned acknowledged-history recency and acquires the lease in one Redis script,
with key-type preflight. FeedIssuanceService now uses it; recently acknowledged
candidates report already_acknowledged before credential issuance. Aged history is
ignored without resetting/deleting history; legacy selection history untouched.
This is candidate admission only, not inventory traversal/exhaustion/replay or
atomic credential issuance. Existing acquire remains lease-only. No routes changed.
Three regressions cover stale-candidate ACK, age-out and corrupt history fail-closed.
Full backend 1118 examples, zero failures, seven pending, 64.08s; 74.86%
(4768/6369), gates pass, exit 0; 20 targeted issuance/reservation cases pass (partial
coverage exit 2); 121 frontend tests pass; syntax/whitespace pass. Capacity/privacy,
replay design and coordinated route/client migration still block rollout.

Unused issuance orchestration: FeedIssuanceService acquires a reservation, creates
an impression ID, issues a bound acknowledgement credential, and returns only ACK
token/impression ID. Credential failure/capacity triggers owner-safe cleanup; existing
reservation conflicts never trigger cleanup. Unexpected issuance errors return no
private details. Cleanup cannot delete successor leases. This is NOT atomic
selection/history eligibility or reservation+issuance: crash/ambiguous responses
may leave lease/credential state until original TTL. Cleanup failure uses lease TTL.
No speculative history/DB counters are written by issuance. No routes use it.
Five cases cover issuance-to-ACK, collision, both capacity/failure outcomes,
unexpected exception and successor cleanup. Full backend 1115 examples, zero
failures, seven pending, 65.37s; 74.83% (4755/6354), gates pass, exit 0; five
targeted issuance cases pass (partial coverage exit 2); 121 frontend tests pass;
syntax/whitespace pass. Capacity/privacy approval, total-cap UX, atomic eligibility
and coordinated route/client migration remain open; no rollout approval implied.

Issuance-bound reservation follow-up: credential metadata now includes an optional
validated reservation token from trusted server issuance. Reconciliation derives
release ownership from stored metadata, not ACK arguments; supplied token must
match before coordinator DB writes. Lua rechecks stored association before writes.
No-bound-lease credentials can acknowledge but cannot release a lease. No active
lease is required at ACK time, preserving late repair; issuance does not atomically
acquire/validate a reservation, which remains an integration responsibility.
Two coordinator regressions verify successor substitution rejection before DB and
release from stored owner without ACK-supplied token. Updated existing ownership
cases bind issued token. Full backend 1110 examples, zero failures, seven pending,
64.06s; 74.77% (4739/6338), gates pass, exit 0; 37 targeted acknowledgement cases
pass (partial coverage exit 2); 121 frontend tests pass; syntax/whitespace pass.
Routes remain unchanged; provisional capacity/privacy approval and wait UX open.

Redis schema-failure follow-up: issuance and reconciliation now check all mutation
key types before writing, returning unavailable on wrong-type keys. Regression
tests inject wrong-type reservation ownership and pending-index keys; history,
credential metadata and expiry pruning remain untouched until recovery, then retry
succeeds. This prevents predictable WRONGTYPE partial writes, not general Lua
rollback safety (OOM/runtime/connection failures still require retry reconciliation).
Full backend 1108 examples, zero failures, seven pending, 63.63s; 74.68%
(4730/6334), gates pass, exit 0; 35 targeted acknowledgement cases pass (partial
coverage exit 2); all 121 frontend tests pass; syntax/whitespace pass. Routes remain
unchanged; capacity/privacy approval, total-cap wait UX and rollout review open.

PostgreSQL concurrency follow-up: synchronized duplicate coordinator calls use two
verified distinct pg_backend_pid connections, both inside transactions before
INSERT. Exactly one reports recorded:true; views/exposure/activity increment once;
Redis history matches persisted original timestamp and pending membership clears.
This is a local service test, not route/multi-tab or production load acceptance.
Full backend 1106 examples, zero failures, seven pending, 65.18s; 74.71%
(4732/6334), gates pass, exit 0; 33 targeted acknowledgement cases pass (partial
coverage exit 2); all 121 frontend tests pass; syntax/whitespace pass. No routes
changed, provisional capacity/privacy approval and total-cap UX remain open.

Capacity concurrency follow-up: two additional real-Redis independent-connection
tests verify only one admission at the final total-cap slot and duplicate concurrent
reconciliation freeing exactly one pending slot. Retained receipts remain valid;
duplicate reconciliation preserves original expiry/history score. No production
capacity, Cluster, sustained-load or concurrent route acceptance implied.
Full backend 1105 examples, zero failures, seven pending, 63.32s; 74.74%
(4734/6334), gates pass, exit 0; 32 targeted acknowledgement cases pass (partial
coverage exit 2); 121 frontend tests pass; syntax/whitespace pass. Limits remain
provisional and routes unchanged. Capacity/privacy and total-cap wait UX still open.

Latest capacity prerequisite (unused, limits NOT approved for rollout): 20 pending
credentials plus a 200-total cap covering pending and completed retry receipts.
Successful reconciliation removes only pending membership as its last mutation;
credential metadata and original deadline remain intact for duplicate DB/history
repair. Failed reconciliation does not free a slot. Issuance atomically prunes
expired credentials/pending membership, checks both caps, and never evicts an
unexpired credential. Pending capacity reports limit_reached; total receipt capacity
reports receipt_limit_reached. This still can pause browsing at the total cap; it
is bounded admission, not unlimited throughput or production capacity evidence.
New pending index shares session hash tag; unused pre-index records are not migrated.
No live routes use these keys. Integration must handle both capacity outcomes,
retain current media, and release only a newly acquired owned speculative lease.
Capacity/privacy approval and concurrent completed-receipt race acceptance remain
open; no rollout switch or route migration. No raw credentials in logs.

Three added cases cover more than 20 sequential acknowledgements with retained retry,
200-total non-eviction/expiry recovery, and failed reconciliation pending-slot
retention. Existing independent pending-cap race test updated for new index.
Full backend 1103 examples, zero failures, seven pending, 63.86s; 74.71%
(4732/6334), gates pass, exit 0. All 30 targeted acknowledgement cases pass
(partial coverage exit 2); all 121 frontend tests pass; syntax/whitespace pass.

Latest attribution slice: credentials now require validated issuance context
(title/subreddit nullable bounded strings, user_id nullable positive PostgreSQL
integer). Missing/corrupt context fails closed. Coordinator no longer accepts
title/subreddit/user attribution arguments: it reads issued metadata and counts
authenticated exposure only when issued user matches current server-authenticated
user. Anonymous issuance is not retroactively attributed after login; switched
accounts cannot inherit old-page exposure. Routes remain unchanged. There are no
live legacy credentials from this unused component; no metadata migration added.

Full backend 1100 examples, zero failures, seven pending, 63.29s; 74.69%
(4728/6330), gates pass, exit 0. All 27 targeted acknowledgement cases pass
(partial coverage exit 2), 121 frontend tests pass. Initial fixture IDs returned
as strings were normalized to match integer auth-helper contract; final runs green.

Earlier cap proposal (superseded by unused pending/receipt split above): keep 20 unexpired credentials intact;
at capacity retain displayed content and return an explicit capacity/retry response,
release only a newly acquired owned speculative lease, and do not mark history or
retry selection automatically. This can block browsing for up to 30 minutes, so it
is NOT a ship-ready UX. Before route migration, review separate bounded completed
receipts/capacity accounting with retry preservation, or approve an explicit user
visible wait policy. Never silently evict credentials needed for DB-success repair.

Latest slice: FeedAcknowledgementService now coordinates PostgreSQL commit and
Redis reconciliation, unused by routes. It validates the credential before DB work,
verifies persisted session/content binding even on conflict, and derives history
time from the original DB created_at. Duplicate inserts skip counters but never
skip history repair. DB failure rolls back counters; post-commit history failure
reports the committed recorded result separately. Nested transactions are refused
because DB's reentrant wrapper would otherwise reconcile before outer commit.
Trusted title/subreddit/user identity must come from server state; integration must
bind this context at issuance, not accept ACK-body attribution. Existing routes
still use their original transaction. No capacity recycling or rollout switch.

Eight real-DB/Redis cases cover post-commit Redis failure/duplicate repair, rollback,
DB binding conflicts, unavailable/malformed credentials, successor ownership, lost
response, expiry between stages and outer transaction refusal. Full backend 1096
examples, zero failures, seven pending, 62.39s; 74.68% (4720/6320), gates pass,
exit 0. Eight targeted coordinator examples pass (partial coverage exit 2), all 121
frontend tests pass; syntax/whitespace checks pass. Redis is disposable and stopped
after validation. No deployment or production acceptance evidence.

Reconciliation final review: credential deadline is unchanged by reconciliation;
history TTL is bounded by recorded time; expired acknowledgement credentials cannot
write history. Two boundary regressions added. Final backend 1088 examples, zero
failures, seven pending, 62.18s; 74.57% (4691/6291), gates pass, exit 0. Fifteen
targeted store cases pass (partial coverage exit 2); 121 frontend tests pass;
syntax/whitespace pass. This earlier store-only checkpoint had no coordinator or route use.

Redis reconciliation prerequisite implemented locally, unused by routes: validates
token/impression/content binding, records trusted caller-supplied committed timestamp
in a separate feed:acknowledged:v1 history, and releases only matching active owner.
Retries preserve first timestamp, do not overwrite newer history, and TTL derives
from recorded time rather than indefinite retry renewal. Timestamp metadata uses a
decimal string to avoid Redis cjson precision loss found in the first full run.

Caller MUST verify/commit the DB impression and supply its original timestamp;
this primitive does not query PostgreSQL or prove that happened. Atomicity here is
Redis script execution, not cross-store transaction/rollback safety. Keys share the
session digest hash tag. Tokens still expire after 30 minutes; no route migration,
capacity-slot recycling or live feature switch. The coordinator described above now
supplies DB verification, but remains unused by routes.

Five added Redis cases cover retries, successor ownership, late older ACK, invalid
time/binding and Redis failure recovery. Final full backend: 1086 examples, zero
failures, seven pending, 62.64s; 74.50% (4687/6291), gates pass, exit 0; 121 frontend
tests pass; 13 targeted cases pass (partial coverage exit 2), syntax/whitespace pass.

Latest prerequisite: acknowledgement issuance now requires a syntactically valid
server-supplied impression_id, persists that association and returns it on lookup.
An optional expected impression ID must match; mismatches are invalid, corrupt
stored bindings are unavailable. This binds supplied metadata; it does not verify
that the impression exists in PostgreSQL or make issuance atomic with DB writes.
Routes remain unchanged; history reconciliation and active-lease binding are open.
No migration of existing unbound metadata: unused-store records lacking the field
are rejected as unavailable until expiry. No live clients use this store yet.

Eight targeted store tests pass (partial coverage exit 2). Latest full backend:
1081 examples, zero failures, seven pending, 61.79s; 74.53% (4677/6275), gates pass,
exit 0; 121 frontend tests pass; syntax/whitespace pass. Earlier measurements below
are historical evidence, not current integration status.

Acknowledgement-store review adds stored-payload size/shape/content validation and
an independent-two-connection last-capacity-slot race test. Six targeted store
examples pass (partial coverage exit 2). Final full backend: 1079 examples, zero
failures, seven pending, 62.24s; 74.50% (4674/6274), gates pass, exit 0; 121 frontend
tests pass, syntax/whitespace pass. No route use or reconciliation implemented.

Longer-lived metadata prerequisite implemented locally as unused
FeedAcknowledgementStore: opaque token issuance, session-scoped digest keys,
Redis server-time 30-minute expiry, atomic 20-token cap/pruning and non-renewing
lookup. Stores bounded content URL metadata, not title/account data. Invalid and
unavailable results differ. Now tied to supplied impression IDs as described above,
but not active owner tokens, DB dedupe or history; no routes migrated.
Oldest unexpired tokens are not evicted
to admit new tokens, so limit-reached needs an explicit integration policy.

Four Redis tests pass; full backend 1077 examples, zero failures, seven pending,
62.26s, 74.50% (4672/6271), gates pass, exit 0; 121 frontend tests pass. Syntax/
whitespace pass. Concurrent cap tests and malformed stored-data tests remain review
follow-ups. This component does not by itself make prefetch acknowledgement-safe.

Active lease validation now atomically checks server-time expiry and exact session/
content/token ownership without renewal. Status distinguishes active, invalid and
unavailable. It is unused by routes and must NOT substitute for the proposed
30-minute acknowledgement token: an expired 120-second lease does not prove that
a late otherwise-valid displayed impression is invalid. At this historical
checkpoint durable ACK metadata/history reconciliation were not yet implemented;
see the current implementation map above for their now-unused implementations.

Three validation regressions cover association, no renewal, expiry, successors and
unavailability. Full backend: 1073 examples, zero failures, seven pending, 62.12s;
74.35% (4635/6234), gates pass, exit 0; 121 frontend tests pass; 12 targeted lease
tests pass (partial coverage exit 2); syntax/whitespace pass. No live behavior switch.

- SimpleMemeSelector.select marks selection in ViewingHistoryService; random/similar
  routes also mark it. Homepage now uses the selector. A prefetch therefore counts
  as selected, though not necessarily displayed.
- RandomMeme#issue_impression creates a 30-minute session-bound ID with pending
  URL metadata, bounded to 20 entries. Concurrent session writes can overwrite this
  pending map; it must not become the authoritative multi-tab reservation store.
- POST /api/impressions commits an idempotent PostgreSQL impression and view/exposure
  counters. Client qualification requires loaded media, visibility and one second.
- PostgreSQL and Redis cannot be committed atomically by the present architecture.
  This protocol must document recovery, not claim exactly-once distributed state.

## Proposed bounded constants (require capacity/privacy review)

| Concern | Proposed starting bound | Rationale/limit |
| --- | --- | --- |
| Reservation TTL | 120 seconds | Short speculative protection; slow/abandoned prefetch eventually eligible |
| Active reservations/session | 20 | Same order as existing pending map; cap checked atomically |
| Commit retries/server request | 1 Redis attempt | Client already retries acknowledgements; avoid nested retry storms |
| Candidate traversal work | 100 issuance attempts / 1,000 inspected entries per call | Provisional implemented bounds; incomplete scans return server offset, not exhaustion |
| ACK pending / total credentials | 20 pending / 200 total | Completed receipts retain original deadline; neither cap silently evicts unexpired credentials |
| Acknowledgement validity | Existing 30 minutes | Reservation expiry is not permission to reject an otherwise valid displayed impression |
| Acknowledged history | 5,000 entries / seven-day age window | Current local policy; memory approval still required |

Do not treat these starting values as measured production thresholds. Reservation
expiry can permit the same content in two tabs if one displays it late; explicitly
accept that bound rather than promise permanent uniqueness.

## Session identity and keys

Create an opaque random feed-session identity in the server session, shared by
homepage, /random, /random.json, /similar.json and exact recipient impressions.
Never fall back to IP identity. Do not key guest history to user_id or introduce
cross-device tracking. Decide guest → authenticated continuity in the existing
session-rotation helper: allowlist only this opaque identity when appropriate;
logout must not silently carry private account state into a new guest identity.
Define/test rotation and retention explicitly before enabling this migration.

Redis owns authoritative reservations and token metadata with per-session keys:
active token sorted set by expiry, content-to-token lookup and token metadata.
Opaque tokens bind session, content URL/identity and expiry. Hash tokens for key
names where practical; never log tokens, raw session identities or content URLs.
Keys must share a deliberate hash tag if Redis Cluster support is introduced;
current deployment compatibility must be checked, not assumed.

## Selection/reservation transaction

1. Fetch the bounded current candidate pool without changing supply scheduling.
2. Read/prune recent acknowledged history and active reservations. Rank eligible
   unseen candidates using existing selection policy; reserve only the chosen item.
3. Lua/atomic Redis operation rechecks candidate eligibility, prunes expired entries,
   enforces the active limit and installs session-bound token + expiry together.
   On conflict choose another candidate within three local attempts.
4. Return reserved content and opaque token with its impression ID. Prefetch creates
   a reservation only. No selection-time acknowledged-history write remains in a
   migrated path. Remove duplicate route marks in the same implementation slice.
5. Exhaustion distinguishes **temporarily reserved** from **all recently viewed**:
   do not replay an active reservation merely because unseen candidates are reserved.
   Offer retry shortly for temporary contention; replay least-recent acknowledged
   content only under the explicit exhausted/replay policy and with the same reserve
   rules. Single-item supply keeps the current meme and shows honest guidance.

Avoid token leakage into canonical/share URLs or persisted meme snapshots. Saved
and catalog identities must remain unchanged. Do not hold a Redis connection while
fetching Reddit/media, and do not create unbounded scripts proportional to inventory.

## Acknowledgement and partial failure

1. Validate token/session/content association and the existing valid impression ID.
   Redis token metadata replaces reliance on a race-prone session pending map for
   migrated requests; provide a bounded transition policy for older open pages.
2. Commit existing PostgreSQL impression/view/exposure transaction idempotently.
3. Atomically write/prune acknowledged Redis history and remove the matching active
   reservation. A retry must perform this reconciliation even when DB insertion is
   already deduplicated; `recorded: false` must not skip Redis repair.
4. If DB fails, return retryable 503; do not claim a recorded impression. Reservation
   stays until retry/expiry. If DB succeeds and Redis commit fails, return a retryable
   outcome without pretending DB rolled back. Retry uses the same ID/token and must
   not increment DB counters again. If retries are exhausted, history may lag; log
   aggregate stage failures and use expiry, not permanent exclusion.
5. Late valid acknowledgement may mark history after reservation expiry, but must
   never delete a successor token's reservation. Ownership compare-and-delete is
   mandatory. Repeated acknowledged tokens must not refresh history forever; history
   timestamp derives from the recorded acknowledgement, not retry arrival time.

No client URL field alone may create history entries or acknowledge arbitrary media.
Session/token mismatch is terminal; infrastructure failures are retryable. Keep
response bodies free of secret details and private/no-store.

## Abandonment, history navigation and outages

- Navigation away needs no guaranteed unload mutation: TTL handles abandoned
  reservations. Optional explicit release must be session/token-owned and idempotent.
- Failed media does not become viewed. Deliberately advancing may release its owned
  reservation, but does not declare the meme unsafe or disliked.
- Back/Forward/Recently viewed can restore the exact content independent of feed
  eligibility. Do not issue an unrelated selection or count duplicate acknowledgements.
- Redis unavailable: define a separate degraded response, not a global IP bucket or
  implicit “unseen” guarantee. Prefer retained current media with retry/Search. If a
  fallback is allowed, label repeat protection unavailable and bound its traffic.
- Cap evictions do not erase acknowledged history; old tokens expire. Sessions with
  20 active reservations must receive an honest retry response, not silently reset.

## Implementation tickets and acceptance

Identity validation: six new helper/auth regressions plus updated homepage tests;
19 targeted identity/auth/home cases pass (partial coverage exit 2). Full backend
1061 examples, zero failures, seven pending, 61.83s; 74.22% coverage (4595/6191),
gates pass, exit 0; 121 frontend tests pass. Provider auth mocked, no actual OAuth
acceptance or concurrency guarantee. No history marks removed or rollout enabled.

1. **Identity contract:** tests for all selection/recipient entry points, login/signup/
   OAuth rotation, logout, two tabs and old-page transition. No behavior switch yet.
2. **Reservation service:** atomic tests with two independent Redis connections,
   collisions, limits, expiry, ownership and malformed input; deterministic clock.
3. **Acknowledgement reconciliation:** DB failure, Redis-after-DB failure, lost response,
   duplicate/late ACK and successor ownership. No duplicate view/exposure counters.
4. **Route migration:** selector plus all route marks change together behind a reviewed
   rollout switch. Test prefetch abandonment and newly arrived content; retain current
   algorithm until route coverage is complete. Do not mix old/new history semantics
   without namespacing/versioned transition and rollback rules.
5. **Browser/operational acceptance:** two tabs, slow/offline/reconnected network,
   gallery/video failures, Back/Forward, Save/auth return and exhausted UI. Measure
   Redis memory, script latency, conflict/expiry rates and acknowledgement repair.

Exit: abandoned prefetch is not acknowledged history; healthy concurrent requests
reserve distinct eligible items within the lease; late retries cannot delete successor
state; existing share/Saved behavior and PostgreSQL dedupe remain intact. Rollout
still requires security remediation, exact-SHA CI, privacy/capacity approval and
explicit deployment authorization. No claim of unique artwork or new content supply.