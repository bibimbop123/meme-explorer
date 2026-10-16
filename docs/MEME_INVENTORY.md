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
Publication remains multi-key/non-atomic; simultaneous publishers and Redis memory/
command cost at larger inventory still require monitoring and follow-up.

- Fetcher requests top/week first pages: repeated maintenance overlaps heavily.
  Cursor-based pagination or bounded hot/new/top rotation needs a separate design.
- Source posts may be videos, removed, malformed, unsafe, duplicates or fail quality
  checks. Requesting 100 posts does not yield 100 usable images.
- URL identity does not deduplicate identical art across different CDN URLs.
- Inventory and eligible-unseen counts need an admin dashboard and outcome metrics.

This change has local mocked fetch-budget tests, not a measured production inventory
increase. External Reddit availability and actual worker execution remain unverified.