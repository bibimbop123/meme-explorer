# Feed protocol migration and replay contract

Status: **proposed design for review, not implemented or rollout approval**.
Companion: [implemented prerequisites](FEED_RESERVATION_PROTOCOL.md).

Implementation note: unused FeedAcknowledgementEnvelope now classifies parsed
legacy/v2 request shapes with no partial-v2 fallback and offers a bounded JSON body
reader. No route uses it; content-type/stream handling, status mapping, session authorization and protocol dispatch remain integration
work. Its existence does not implement this proposal or approve the switch.

## Scope and invariants

Change homepage/random/similar selection and their selection-time marks together.
Keep exact recipient and Saved recovery addressable regardless of feed eligibility.
Preserve existing filtering, personalization, share identity and media/gallery
payloads. FeedTraversal now copies bounded allowlisted gallery/video/source metadata,
but that is not full media validation or proof every rendering field is preserved.
Verify exact identity/full payload mapping through existing media resolvers and
renderer integration tests before rendering a migrated response.

No client URL/title/user value authorizes an impression. Never clear history at
exhaustion or migrate speculative legacy marks into acknowledged history. Initial
repeat continuity can reset once; disclose and test that transition. Redis loss,
lease expiry, late displays and cross-store lag limit repeat protection.

## Switch and acknowledgement coexistence

Proposed setting: FEED_ACKNOWLEDGED_SELECTION_ENABLED, default false, read by a
single selection/issuance dispatcher. This setting does not exist yet. Enable only
after all entry-point and transition tests pass and review approves the limits.

- Switch off: retain current selection and issuance semantics.
- Switch on: coordinated entry points use versioned acknowledged selection;
  recipient/recovery paths use credential-only issuance, not unseen admission.
- Proposed response fields: impression_protocol: 2, impression_id, ack_token.
  Initial HTML carries the same fields. Do not put credentials in URLs or logs.
- ACK dispatch is independent of the selection switch. Presence of any new-protocol
  field requires the complete valid v2 envelope; malformed/unknown version never
  falls back to legacy pending IDs. Requests with only impression_id retain the
  legacy path for pages issued before transition.
- Turning selection off must not disable v2 ACK processing while credentials remain
  valid. Keep both handlers through their original 30-minute lifetimes; never renew
  a credential to extend rollback support. Do not deploy old code incapable of v2
  ACK during that window without an explicitly accepted loss/degraded-mode plan.
- No v2 selection-time marks. Legacy pages/requests may continue writing only the
  legacy namespace; v2 ACK writes only the acknowledged namespace.

## Exhaustion and replay admission

Replay is not implemented. Do not use lease-only acquire as an unguarded bypass.
Proposed bounded policy:

1. Build a bounded immutable eligible snapshot with the normal media/filter and
   preference rules. New supply or filter/auth changes invalidate the pass.
2. Traverse unseen candidates with existing budgets. Incomplete/capacity/outage and
   reservation conflicts are not exhaustion. Stop at a reviewed overall request
   budget; do not loop all chunks synchronously without a latency bound.
3. Only after a complete pass without unresolved conflicts, refresh acknowledged
   recency and recheck the inventory generation. If changed, restart within budget
   or return incomplete; never silently replay past newly eligible unseen items.
4. Replay the least recently acknowledged eligible identity, excluding current
   content when another item exists. Break timestamp ties deterministically by
   identity. Use a dedicated atomic replay-admission operation that rechecks the
   candidate's expected history score and lease ownership/capacity before leasing;
   stale scores/history loss must restart unseen selection, not authorize replay.
5. Admission cannot prove global exhaustion against unversioned inventory. Inventory
   generation/recheck semantics and a concurrent ACK/admission race test are design
   prerequisites, not guarantees provided by today's snapshot object.
6. Replay issuance does not update history. Qualified replay ACK uses a new ID;
   its original DB recorded time advances recency once. Duplicate retries do not.
7. Single-item supply retains current media and displays the existing honest
   no-different-content message; no duplicate prefetch/refetch loop.

For the first migration, returning honest exhaustion without automatic replay is a
possible scoped alternative, but requires explicit product review; do not silently
remove the existing oldest-selected replay behavior.

## Response and client behavior

| Outcome | Required behavior |
| --- | --- |
| Issued unseen | Render exact returned identity; retain bound credential with history entry |
| Issued replay | Explicit exhaustion/replay notice; never claim fresh supply |
| Temporarily reserved | Retain current media; bounded user retry, not automatic exhaustion |
| Incomplete scan | Retain current; server-owned progress only; no raw client offset authority |
| Pending/receipt capacity | Retain current; explicit wait/retry; never evict repair credentials |
| Redis unavailable | Disclose repeat protection unavailable; no IP fallback or false empty pool |
| Invalid credential | Terminal ACK rejection, no protocol fallback or client-driven fresh ID |
| DB/history unavailable | Retry same ID/token within original deadline, bounded backoff |

### Proposed HTTP mapping (not implemented or approved)

Selection JSON must be parsed as a discriminated outcome before media rendering.
Proposed non-success body: `{ "outcome": "temporarily_reserved" }` with no fabricated
media or credential. Existing fetchMeme rejects non-OK responses and requires media;
it MUST change in the coordinated patch, not be paired with these mappings as-is.

| Selection outcome | Proposed HTTP | Automatic selection retry |
| --- | --- | --- |
| Issued unseen/replay | 200, full media + v2 envelope | None for same-current replay; retain existing single-item guard |
| Empty/exhausted without approved replay | 409, distinct outcome | None; retain current + Search/return-later |
| Temporarily reserved | 409 | None; explicit user retry |
| Traversal incomplete | 409 | None; reviewed server continuation orchestration only |
| Pending/receipt capacity | 429, distinct outcome | None; explicit wait/retry |
| Infrastructure unavailable | 503 | None in foreground selection; preserve current |
| Invalid server candidate/context | 503, generic unavailable | None; aggregate diagnostics, no raw input reflection |

Do not invent a precise Retry-After from the 120-second lease or 30-minute ACK TTL:
oldest outstanding expiry and early completion can differ. Add a header only when
server computes a valid bound; keep countdowns advisory, not an unseen guarantee.
Prefetch must not render outcome responses, store them as memes, or retry them in
a loop. Capacity/outage outcomes must not be interpreted as negative preference.

| ACK outcome | Proposed HTTP/body | Client treatment |
| --- | --- | --- |
| Acknowledged new/duplicate | 200, success:true and recorded boolean | Complete local ACK work; duplicate is success |
| Invalid/expired/mismatched token | 404, generic invalid credential | Terminal, no legacy fallback/fresh-ID retry |
| Malformed envelope/JSON | 400 | Terminal |
| Unsupported explicit protocol | 400 | Terminal; retain current media |
| Store/DB/history unavailable | 503, generic retryable error | Same ID/token, bounded retry within original deadline |

Do not expose database/history stage details or a rollback claim in public errors.
The server may already have committed even when returning 503 or losing response;
idempotency depends on unchanged ID/token. Internal aggregate stage counters must
exclude URLs, IDs, credentials and user identity. Rate limiting, if added, may use
429; it must not masquerade as successful recording.

Current ACK loop is three attempts, five-second request deadlines and 500/1000ms
backoff, retrying network/5xx/429. Proposed v2 retains those upper bounds initially,
with a deadline supplied at issuance (never renewed), and must stop when that
deadline is reached. Do not add nested server retries. Retry exhaustion can leave
history lagging; durable background repair is not implemented. No indefinite
client persistence/replay of credentials is authorized by this document.

Current visibility observer marks an ID qualified before ACK and does not reobserve
it after retry exhaustion. Migration must distinguish qualified, pending, confirmed
and terminal/expired ACK states; preserve loaded/visible qualification independently
of network success. Back/Forward must reuse, not duplicate, bounded pending work.

Client qualification remains loaded media + visibility + one second. Carry the
credential through prefetch and Back/Forward restoration without reissuing a
selection on restore. An abandoned prefetch is not an ACK. Auth rotation preserves
feed identity; exposure requires issued user to match current authenticated user.
Logout invalidates session association. Exact-page Save/auth return must still
recover the same media and cannot depend on active feed lease validation.

## Required integration matrix

- Default-off behavior unchanged across home/random/random.json/similar and exact
  recipient paths; all v2 paths issue credentials without speculative marks.
- Old HTML/new assets, new HTML/old assets, pending prefetch at switch, switch off
  with outstanding v2 ACK, invalid v2 + valid legacy ID (no fallback).
- Two simultaneous tabs, first-session persistence race, auth login/signup/OAuth
  rotation, logout and account switch; no cross-session or wrong-user attribution.
- Abandonment, media failure, delayed ACK beyond lease, lost ACK response, DB
  rollback, DB-success/Redis-failure repair, expired credential, successor lease.
- Full immutable media/gallery mapping, exact sharing, Saved detail/Back and Save
  through auth. Crawler metadata and actual provider acceptance remain separate.
- Unseen/new supply during exhaustion, oldest replay, score changes during admission,
  active conflict, single-item pool, both token caps, byte/traversal bounds.
- Build JS before backend boot; full suites; physical mobile, second desktop browser,
  keyboard/screen reader and slow/offline browser matrix. No deployment implied.
- Selection 409/429/503 outcomes bypass media validation/refetch loops; prefetch
  caches only issued media. ACK 400/404 stops, ACK 503/lost response retries the
  unchanged envelope, duplicate 200 succeeds, and qualification is not lost when
  the first ACK attempt fails. Test request deadlines and retry exhaustion.

## Decisions still requiring review

Inventory generation/atomic replay contract, request-wide latency/continuation
storage, complete payload mapping, approval of proposed HTTP/retry mapping, capped wait UX and measured
capacity/privacy remain open. Do not turn this proposal into an enabled route patch
by assuming these decisions are approved. Security remediation, credential rotation,
exact-SHA hosted CI, deployed config verification and release approval remain gates.