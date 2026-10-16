# Meme inventory: diagnosis and expansion

The 5,000 target is an aspiration, not a fetched-content guarantee. A pool near
167 can be the deliberately small cold-start bootstrap; maintenance is responsible
for background growth. Increasing TARGET_POOL_SIZE alone does not add content.

## Implemented budget correction

Tier maintenance previously divided its request budget across all communities,
then the OAuth fetcher sampled at most 25. Large tiers therefore requested far
less than intended. Maintenance now selects at most 25 unique communities first,
rotates that selection each batch, divides with ceiling and caps listings at 100.
It retains sequential requests, shared OAuth fetcher, cooldowns and quality filters.
Larger response bodies can increase processing time; monitor duration and rate limits.

## Operator checks (no secrets in logs)

With `REDIS_URL` already supplied by the deployment environment, run the read-only
`scripts/check_pool_inventory.rb` using the application's bundled Ruby. Locally:

```sh
ruby scripts/isolated_bundle.rb exec ruby scripts/check_pool_inventory.rb
```

Do not paste credentials into shell commands or reports. The script reads only
fixed metadata keys, TTLs and list lengths; it does not boot the app, scan Redis,
read media/lock-owner payloads, mutate keys or contact Reddit. Missing metadata is
null, not a fabricated zero. TTL -2 means absent and -1 means no expiry. Output is
a non-atomic sample, not verified unique inventory, scheduler/OAuth health, or proof
that two processes share Redis. Compare web/worker samples and deployment config
privately; matching counts alone do not establish shared Redis. Failures exit 1
with generic text and omit exception/connection details.

1. Confirm a live Sidekiq worker consumes default jobs and the maintenance schedule
   actually runs. Web startup saying 'pool ready' does not prove maintenance runs.
2. Check maintenance logs: current pool count, fetched count, filtered count, stored
   count, errors and cooldowns. Compare distinct media URLs, not requested limits.
3. Verify OAuth succeeds; unauthenticated Reddit access may be heavily rate-limited.
4. Confirm the web and worker share the intended Redis database/configuration.
5. Wait for normal maintenance and observe unique inventory growth. Do not purge
   the working pool, disable cooldowns or spawn parallel Reddit fetch storms.

Maintenance emits `[PoolManager] Inventory batch outcome` with numeric/boolean
fields only: `fetched`, `fetched_unique`, `validated`, `validated_unique`,
`previous_unique`, `candidate_new_unique`, `planned_unique`, `stored`, `replaced`,
`publication_succeeded`, and `rate_limited`. No URLs/tokens/credentials are included.
Candidate additions are before target truncation and publication; planned size is
not a read-back measurement. `stored` is total published inventory, not additions.
Publication success is the transaction response, not proof of later retention or
absence of a concurrent overwrite. Compare subsequent observed pool counts before
claiming growth; ambiguous EXEC disconnects and partial runtime errors remain open.

## Remaining supply constraints

Maintenance quality evaluation errors now reject new candidates rather than
returning the unfiltered batch; existing inventory is retained. The optional
pipeline's absence checks hash shape, browser-safe URL and nonblank title/community
text; bootstrap shares this cheap predicate but bypasses the optional pipeline.
Existing retained content is not
purged. “Validated” does not certify availability, moderation, readability or humor. Use
FEED_EXPERIENCE_AUDIT.md for the planned real-feed/user evaluation; none performed.

The hidden 300-item tier cap is now replaced by TARGET_POOL_SIZE. Maintenance
merges new unique URLs with retained pool entries, bounded at that target; new
snapshots win duplicate URLs. Count metadata now reflects unique random-pool
inventory rather than the sum of overlapping tiers. No cache purge is needed.
Bootstrap also merges its validated batch with inventory present immediately before
publication, so a late small bootstrap does not simply replace an already-grown
pool. It returns only its newly fetched usable batch to the caller; retained items
do not inflate bootstrap's fetched/usable count. Empty validated batches do not
republish the pool. Read/merge/publication is still not fenced against concurrent
writes after that read; this is not a full concurrency fix.
Publication now queues prepared JSON, lists, media fields and metadata in one Redis
MULTI/EXEC, so list clearing/rebuilding is not visible between commands. Empty tiers
are cleared; missing fallback IDs use stable SHA-256 URL digests. Failed/missing EXEC
results do not report success. This is not rollback safety: Redis execution-time
errors can leave partial writes, and a connection loss during EXEC has an ambiguous
outcome. Separate reader commands can straddle snapshots. Concurrent publishers can
still overwrite newer inventory with stale snapshots; media hash retention and Redis
memory/command cost at larger inventory require follow-up. No old IDs are purged.

Scheduled maintenance now takes an ownership-token Redis lease before fetching.
Duplicate jobs (or jobs unable to acquire Redis) skip; cooldown is checked again
after acquisition and the lease is released on success, failure and early return.
The lease expires after two hours to cover long sequential fetch batches; a killed
worker can therefore delay maintenance until expiry. Release cannot delete a
successor's lease. This is not publication fencing: bootstrap/other writers and a
job running past lease expiry can still race. Monitor job duration and lock TTL;
do not manually delete a live owner's lease to force inventory expansion.

- Maintenance now follows at most two top/week pages per community, using Reddit's
  validated after cursor and URL deduplication. Default/bootstrap fetching stays
  single-page. Missing/repeated cursors or HTTP errors stop pagination. Each run
  still starts at page one; cross-run cursor persistence/source rotation stay open.
- A 429 marks the shared fetcher rate-limited, stops later maintenance tiers and
  sets the existing cooldown even if partial content was stored. Subsequent calls
  on that fetcher make no HTTP requests; later jobs create fresh fetchers after
  normal cooldown checks. Separate workers still need publication coordination.
- Bootstrap also preserves cooldown after partial 429 success, including failed
  Redis publication, and deduplicates overlapping probe/fetch URLs before reporting
  usable inventory. Partial usable content remains available to the current caller.
- Stale refresh keeps existing items until quality-filtered replacements arrive.
  Only genuinely new URLs retire stale entries, at most one per new unique URL;
  duplicate snapshots update metadata without reducing unique inventory. Empty or
  rejected batches do not publish. Redis write failures/overlapping publishers
  remain subject to the multi-key/non-atomic publication limitation above.
- Two-page expansion can double request count and job duration; monitor worker
  backlog, rate limits and lease duration before enabling large production batches.
- Source posts may be videos, removed, malformed, unsafe, duplicates or fail quality
  checks. Requesting 100 posts does not yield 100 usable images.
- URL identity does not deduplicate identical art across different CDN URLs.
- Inventory and eligible-unseen counts need an admin dashboard and outcome metrics.

This change has local mocked fetch-budget tests, not a measured production inventory
increase. External Reddit availability and actual worker execution remain unverified.