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

1. Confirm a live Sidekiq worker consumes default jobs and the maintenance schedule
   actually runs. Web startup saying 'pool ready' does not prove maintenance runs.
2. Check maintenance logs: current pool count, fetched count, filtered count, stored
   count, errors and cooldowns. Compare distinct media URLs, not requested limits.
3. Verify OAuth succeeds; unauthenticated Reddit access may be heavily rate-limited.
4. Confirm the web and worker share the intended Redis database/configuration.
5. Wait for normal maintenance and observe unique inventory growth. Do not purge
   the working pool, disable cooldowns or spawn parallel Reddit fetch storms.

## Remaining supply constraints

The hidden 300-item tier cap is now replaced by TARGET_POOL_SIZE. Maintenance
merges new unique URLs with retained pool entries, bounded at that target; new
snapshots win duplicate URLs. Count metadata now reflects unique random-pool
inventory rather than the sum of overlapping tiers. No cache purge is needed.
Publication now queues prepared JSON, lists, media fields and metadata in one Redis
MULTI/EXEC, so list clearing/rebuilding is not visible between commands. Empty tiers
are cleared; missing fallback IDs use stable SHA-256 URL digests. Failed/missing EXEC
results do not report success. This is not rollback safety: Redis execution-time
errors can leave partial writes, and a connection loss during EXEC has an ambiguous
outcome. Separate reader commands can straddle snapshots. Concurrent publishers can
still overwrite newer inventory with stale snapshots; media hash retention and Redis
memory/command cost at larger inventory require follow-up. No old IDs are purged.

- Maintenance now follows at most two top/week pages per community, using Reddit's
  validated after cursor and URL deduplication. Default/bootstrap fetching stays
  single-page. Missing/repeated cursors or HTTP errors stop pagination. Each run
  still starts at page one; cross-run cursor persistence/source rotation stay open.
- A 429 marks the shared fetcher rate-limited, stops later maintenance tiers and
  sets the existing cooldown even if partial content was stored. Subsequent calls
  on that fetcher make no HTTP requests; later jobs create fresh fetchers after
  normal cooldown checks. Separate workers still need publication coordination.
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