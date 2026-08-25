# Meme Pool Manager - Phase 2
# Intelligent 5,000-meme pool management with tier-based distribution
# Created: June 3, 2026

require 'concurrent'
require_relative 'reddit_fetcher_service'
# require_relative 'turbocharged_reddit_fetcher'  # Deleted during service cleanup - use reddit_fetcher_service instead
# require_relative 'quality_pipeline_service'  # Removed during Elon audit - file not found
require_relative 'redis_service'
require 'yaml'

class MemePoolManager
  TARGET_POOL_SIZE = 5000
  MIN_POOL_SIZE = 1000
  BOOTSTRAP_COOLDOWN_KEY = "meme_pool:bootstrap_cooldown"
  BOOTSTRAP_COOLDOWN_TTL = 300 # 5 minutes - avoid hammering Reddit while rate-limited
  BOOTSTRAP_LOCK_KEY = "lock:meme_pool:bootstrap"

  # BUG FIX (Aug 25, 2026, round 6): The entire pool architecture above
  # (get_current_pool, store_in_pool, the bootstrap lock/cooldown) is built
  # entirely on Redis. RedisService.acquire_lock/get/set/delete all
  # early-return a default value whenever redis_available? is false - so
  # when Redis is genuinely unreachable (confirmed via /health showing
  # "redis: available: false"), RedisService.acquire_lock(BOOTSTRAP_LOCK_KEY)
  # ALWAYS returns false. That means no request could ever become "the"
  # bootstrapper, no background bootstrap thread was ever spawned, and the
  # app was permanently stuck serving only the 10-meme local fallback pool
  # with zero visible errors (the log message "Another request is
  # bootstrapping" was misleading - nobody was actually bootstrapping).
  #
  # Fix: keep an in-process (thread-safe) fallback lock/pool so bootstrap
  # can still happen entirely within a single Puma worker's memory even
  # when Redis is completely down. This is a degraded mode (each worker
  # process bootstraps and caches its own copy rather than sharing one
  # pool via Redis), but it means real Reddit content can still load
  # instead of being permanently stuck on local placeholders.
  @in_process_pool = []
  @in_process_bootstrap_mutex = Mutex.new
  @in_process_bootstrapping = false
  @in_process_cooldown_until = nil

  class << self
    attr_accessor :in_process_pool

    def in_process_pool_available?
      @in_process_bootstrap_mutex.synchronize { !@in_process_pool.empty? }
    end

    def in_process_cooling_down?
      @in_process_bootstrap_mutex.synchronize do
        !!(@in_process_cooldown_until && Time.now < @in_process_cooldown_until)
      end
    end

    # Returns true if this call became the bootstrapper (caller must ensure
    # `finish_in_process_bootstrap!` runs afterwards, even on error).
    def try_start_in_process_bootstrap!
      @in_process_bootstrap_mutex.synchronize do
        return false if @in_process_bootstrapping
        @in_process_bootstrapping = true
        true
      end
    end

    def finish_in_process_bootstrap!(memes: nil, cooldown_ttl: nil)
      @in_process_bootstrap_mutex.synchronize do
        @in_process_pool = memes if memes
        @in_process_cooldown_until = Time.now + cooldown_ttl if cooldown_ttl
        @in_process_bootstrapping = false
      end
    end

    # Test/ops helper to reset state between specs or after manual recovery.
    def reset_in_process_state!
      @in_process_bootstrap_mutex.synchronize do
        @in_process_pool = []
        @in_process_bootstrapping = false
        @in_process_cooldown_until = nil
      end
    end
  end
  # BUG FIX (Aug 25, 2026): this was 45s, but the on-demand bootstrap fetched
  # from up to 80 subreddits sequentially with a 1s throttle between each
  # (see RedditFetcherService::THROTTLE_DELAY) - realistically 80-120+
  # seconds. The lock kept expiring mid-fetch (Redis EX doesn't know the code
  # is still running), letting new requests acquire it and start a SECOND
  # concurrent bootstrap - recreating the exact stampede this lock exists to
  # prevent. Combined with BOOTSTRAP_WAIT_RETRIES/INTERVAL below being far
  # too short to ever catch a ~100s bootstrap, EVERY request always timed
  # out and fell back to the 10-meme local pool, even when Reddit was fully
  # responsive. Fixed by (a) shrinking the on-demand bootstrap's subreddit
  # count (see BOOTSTRAP_QUICK_TIER_LIMITS below) so it can realistically
  # finish within a web request, and (b) raising this TTL to a safe margin
  # above that new expected duration.
  # BUG FIX (Aug 25, 2026, round 2): 30s was still nowhere near enough.
  # bootstrap_pool makes up to 15 sequential Reddit requests (3 for the
  # rate-limit probe + 12 for the real fetch), each with up to a 15s
  # HTTP timeout plus a throttle sleep between requests - worst case
  # ~240s, and even a "normal" case with real-world latency (especially
  # on a shared/throttled Render free-tier CPU) routinely exceeds 30s.
  # When the lock expired mid-fetch, a brand-new request would see no
  # lock, acquire it, and spawn ANOTHER overlapping background bootstrap
  # thread - multiple concurrent threads hammering Reddit's OAuth +
  # subreddit endpoints at once, none of them ever finishing cleanly,
  # recreating the exact thundering-herd this lock exists to prevent.
  # Production logs showed this exact symptom: an endless stream of
  # "Another request is bootstrapping..." with no bootstrap ever actually
  # completing. Raised to a generous ceiling; bootstrap_pool also no
  # longer pays for two separate OAuth round-trips (see create_fetcher
  # reuse below), which was needlessly adding to the real duration.
  BOOTSTRAP_LOCK_TTL = 120 # seconds - real safety margin for worst-case sequential fetch time
  # UX FIX (Aug 25, 2026): This used to be 15 retries x 1.0s (a full 15s of
  # blocked wait per follower request). Since bootstrap realistically takes
  # 15-30s, EVERY follower request always burned its full wait budget before
  # timing out and falling back anyway - production logs showed every single
  # page load taking ~15.1s, and with a fixed 32-thread Puma pool that's
  # enough concurrent 15s-blocked requests to exhaust all worker threads
  # under even light traffic. Waiting at all trades a guaranteed-fast local
  # fallback for a coin flip on catching someone else's in-flight fetch, and
  # for an already-instant local fallback that trade is never worth it.
  # Now we do one cheap immediate re-check and bail straight to the fast
  # local fallback if the pool still isn't there - the bootstrapping
  # request's fetch keeps running in the background regardless and will
  # populate Redis for the *next* request.
  BOOTSTRAP_WAIT_RETRIES = 1 # a single quick re-check, not a long blocking poll
  BOOTSTRAP_WAIT_INTERVAL = 0.2 # seconds - just enough to catch an already-almost-done bootstrap

  # Subreddit counts per tier for the on-demand (synchronous, request-time)
  # bootstrap - deliberately much smaller than the full pool build performed
  # by the scheduled MemePoolMaintenanceWorker, so it can complete within a
  # reasonable web request timeout (~12 subreddits x 1s throttle + the
  # 3-subreddit fail-fast test ≈ 15s worst case) instead of blocking on 80
  # sequential Reddit requests (~100s).
  BOOTSTRAP_QUICK_TIER_LIMITS = { tier_1: 5, tier_2: 3, tier_3: 2, tier_4: 1, tier_5: 1 }.freeze
  
  # Tier distribution for balanced variety
  TIER_DISTRIBUTION = {
    tier_1: 0.60,  # 3,000 memes - Peak Humor & Relationships
    tier_2: 0.20,  # 1,000 memes - Viral Humor
    tier_3: 0.10,  # 500 memes - Specific Niches
    tier_4: 0.05,  # 250 memes - Visual Comedy
    tier_5: 0.05   # 250 memes - Wholesome
  }.freeze
  
  class << self
    # Main entry point - maintains pool at target size
    def maintain_pool!
      AppLogger.info("🔄 [PoolManager] Starting pool maintenance...")

      # Respect the same rate-limit cooldown used by bootstrap_pool. This runs
      # on a schedule (every 5 min), so if Reddit was confirmed rate-limited
      # very recently there's no point re-attempting a large fetch yet.
      if RedisService.get(BOOTSTRAP_COOLDOWN_KEY)
        AppLogger.warn("⏳ [PoolManager] Maintenance skipped - still cooling down after recent rate limit")
        return { success: false, error: "Cooling down after recent rate limit", pool_size: get_pool_size }
      end

      current_size = get_pool_size
      
      if current_size < MIN_POOL_SIZE
        AppLogger.warn("⚠️  [PoolManager] Pool below minimum (#{current_size} < #{MIN_POOL_SIZE})")
        fetch_batch(size: 1000, priority: :high)
      elsif current_size < TARGET_POOL_SIZE
        needed = TARGET_POOL_SIZE - current_size
        AppLogger.info("📊 [PoolManager] Pool at #{current_size}/#{TARGET_POOL_SIZE}, fetching #{needed} memes")
        fetch_batch(size: needed)
      else
        AppLogger.info("✅ [PoolManager] Pool at target size (#{current_size}), replacing stale content")
        replace_stale(percentage: 0.2)
      end
      
      final_size = get_pool_size
      AppLogger.info("✅ [PoolManager] Maintenance complete: #{final_size} memes in pool")
      { success: true, pool_size: final_size }
    rescue => e
      log_error("Pool maintenance error", e)
      { success: false, error: e.message }
    end
    
    # Get current pool (main entry point for app.rb)
    def get_pool
      pool = get_current_pool
      size = pool.size
      
      # If pool exists, return it
      if size > 0
        return {
          success: true,
          memes: pool,
          pool_size: size,
          error: nil
        }
      end

      # BUG FIX (Aug 25, 2026, round 6): if Redis is genuinely unreachable,
      # every RedisService call below (acquire_lock/get/set/delete) would
      # otherwise silently no-op, meaning acquire_lock ALWAYS returns false
      # and no request could ever become the bootstrapper - the app stays
      # permanently stuck on the 10-meme local fallback with zero errors.
      # When Redis is down, fall through entirely to an in-process (single
      # worker memory) bootstrap/lock/pool instead, so real Reddit content
      # can still load in degraded mode.
      unless RedisService.redis_available?
        return get_pool_via_in_process_fallback
      end
      
      # Pool empty - check cooldown before hammering Reddit again.
      # If we recently confirmed Reddit is rate-limiting us, skip straight to
      # local fallback instead of re-attempting bootstrap on every single request.
      if RedisService.get(BOOTSTRAP_COOLDOWN_KEY)
        AppLogger.warn("⏳ [PoolManager] Bootstrap cooling down (recent rate limit) - using local fallback")
        return {
          success: false,
          memes: [],
          pool_size: 0,
          error: "Bootstrap cooling down after recent rate limit"
        }
      end

      # Pool empty - try to become the single request that bootstraps it.
      # Without this lock, every concurrent request that sees an empty pool
      # independently launches its own ~30s Reddit fetch (a thundering herd),
      # each burning a full OAuth token + dozens of subreddit requests for
      # the same outcome. Only the request that acquires the lock actually
      # bootstraps; everyone else gets a quick single re-check and, if the
      # pool still isn't ready, falls straight back to the fast local pool
      # instead of blocking the request thread.
      unless RedisService.acquire_lock(BOOTSTRAP_LOCK_KEY, ttl: BOOTSTRAP_LOCK_TTL)
        waited = wait_for_pool(BOOTSTRAP_WAIT_RETRIES, BOOTSTRAP_WAIT_INTERVAL)
        return waited if waited

        AppLogger.info("⏳ [PoolManager] Another request is bootstrapping - using local fallback for now")
        return {
          success: false,
          memes: [],
          pool_size: 0,
          error: "Bootstrap in progress - using local fallback"
        }
      end

      # UX FIX (Aug 25, 2026): Bootstrapping synchronously here used to make
      # the *first* unlucky visitor after a cold cache eat the entire 15-30s
      # Reddit fetch themselves, on top of every follower request separately
      # blocking on wait_for_pool above. Nobody should ever wait tens of
      # seconds for a page load. Instead, kick the real fetch off in a
      # background thread (same pattern already used for the config.ru
      # startup cache warm) and let this request return the fast local
      # fallback immediately - the pool will be populated in Redis for the
      # *next* request by the time the fetch finishes.
      Thread.new do
        Thread.current.name = 'meme-pool-bootstrap'
        Thread.current.abort_on_exception = false

        begin
          AppLogger.warn("⚠️  [PoolManager] Pool empty, bootstrapping with quick fetch (background)...")
          bootstrap_result = bootstrap_pool

          if bootstrap_result[:success]
            AppLogger.info("✅ [PoolManager] Background bootstrap complete: #{bootstrap_result[:size]} memes")
            # Trigger background expansion to 5K (non-blocking)
            trigger_background_expansion
          else
            AppLogger.error("⚠️  [PoolManager] Background bootstrap failed: #{bootstrap_result[:error]}")
          end
        rescue => e
          log_error("Background bootstrap error", e)
        ensure
          RedisService.delete(BOOTSTRAP_LOCK_KEY)
        end
      end

      {
        success: false,
        memes: [],
        pool_size: 0,
        error: "Bootstrap started in background - using local fallback"
      }
    rescue => e
      log_error("Get pool error", e)
      { success: false, memes: [], pool_size: 0, error: e.message }
    end

    # Degraded-mode pool retrieval used only when Redis is confirmed
    # unreachable (see get_pool). Mirrors the same "one bootstrapper,
    # background thread, fast local fallback for everyone else" shape as
    # the Redis-backed path above, but coordinated entirely via in-process
    # memory (Mutex-protected class state) instead of Redis keys - this
    # pool is per-worker-process rather than shared across the fleet, but
    # it's the only way to ever load real Reddit content while Redis is
    # down instead of being permanently stuck on local placeholders.
    def get_pool_via_in_process_fallback
      if in_process_pool_available?
        pool = in_process_pool
        return { success: true, memes: pool, pool_size: pool.size, error: nil }
      end

      if in_process_cooling_down?
        AppLogger.warn("⏳ [PoolManager] In-process bootstrap cooling down (Redis unavailable, recent rate limit) - using local fallback")
        return { success: false, memes: [], pool_size: 0, error: "In-process bootstrap cooling down after recent rate limit" }
      end

      unless try_start_in_process_bootstrap!
        AppLogger.info("⏳ [PoolManager] Another in-process bootstrap already running (Redis unavailable) - using local fallback for now")
        return { success: false, memes: [], pool_size: 0, error: "In-process bootstrap in progress - using local fallback" }
      end

      Thread.new do
        Thread.current.name = 'meme-pool-bootstrap-in-process'
        Thread.current.abort_on_exception = false

        begin
          AppLogger.warn("⚠️  [PoolManager] Pool empty, bootstrapping in-process (Redis unavailable)...")
          bootstrap_result = bootstrap_pool

          if bootstrap_result[:success]
            AppLogger.info("✅ [PoolManager] In-process background bootstrap complete: #{bootstrap_result[:size]} memes")
            finish_in_process_bootstrap!(memes: bootstrap_result[:memes])
          else
            AppLogger.error("⚠️  [PoolManager] In-process background bootstrap failed: #{bootstrap_result[:error]}")
            finish_in_process_bootstrap!(cooldown_ttl: BOOTSTRAP_COOLDOWN_TTL)
          end
        rescue => e
          log_error("In-process background bootstrap error", e)
          finish_in_process_bootstrap!(cooldown_ttl: BOOTSTRAP_COOLDOWN_TTL)
        end
      end

      { success: false, memes: [], pool_size: 0, error: "In-process bootstrap started in background - using local fallback" }
    end
    
    # Bootstrap pool with quick 500-meme fetch (20-30 seconds)
    def bootstrap_pool
      AppLogger.info("🚀 [Bootstrap] Attempting bootstrap (will fail fast if rate-limited)...")

      # BUG FIX (Aug 25, 2026, round 2): create_fetcher was being called
      # TWICE per bootstrap - once for the rate-limit probe, once for the
      # real fetch - and each call performs its own full OAuth
      # client-credentials round-trip to Reddit. That's a second,
      # unnecessary network round-trip (plus a second short-lived token)
      # added to every single bootstrap, on top of already being tight
      # against BOOTSTRAP_LOCK_TTL. Create the fetcher once and reuse it
      # for both the probe and the real fetch.
      fetcher = create_fetcher

      # CRITICAL: Fail fast if Reddit is completely rate-limited
      # Try just 3 subreddits first to check if we're getting 429s
      test_subs = load_tier_subreddits(:tier_1).first(3)
      test_memes = fetcher.fetch_memes(test_subs, limit: 5)

      # If we got ZERO memes from 3 attempts, Reddit is rate-limited
      # Don't waste 25 seconds trying 80 more subreddits
      if test_memes.empty?
        AppLogger.warn("⚠️  [Bootstrap] Reddit rate-limited - skipping full bootstrap, using local fallback")
        # Set cooldown so subsequent requests don't re-hammer Reddit (and re-request
        # OAuth tokens) until the cooldown expires. Without this, every incoming
        # request independently re-triggers bootstrap_pool, multiplying 429s.
        RedisService.set(BOOTSTRAP_COOLDOWN_KEY, "true", ttl: BOOTSTRAP_COOLDOWN_TTL)
        return { success: false, size: 0, memes: [], error: "Reddit rate limited (429)" }
      end

      AppLogger.info("🚀 [Bootstrap] Reddit responsive - proceeding with quick fetch...")

      # Quick, request-time-friendly fetch: a small number of subreddits per
      # tier so this can realistically finish inside a web request instead of
      # the ~80-subreddit / ~100s full build (that full build is handled by the
      # scheduled MemePoolMaintenanceWorker via fetch_batch/build_pool!, which
      # isn't time-constrained the way an inline request is).
      #
      # NOTE: tier_1's first 3 subreddits were already fetched above by the
      # rate-limit probe (test_subs) - skip re-fetching them here so we
      # don't hit the same 3 subreddits twice in one bootstrap.
      remaining_tier_limits = BOOTSTRAP_QUICK_TIER_LIMITS.merge(tier_1: BOOTSTRAP_QUICK_TIER_LIMITS[:tier_1] - test_subs.size)
      remaining_subs = remaining_tier_limits.flat_map do |tier, count|
        next [] if count <= 0
        subs = load_tier_subreddits(tier)
        subs = subs.drop(test_subs.size) if tier == :tier_1
        subs.first(count)
      end

      remaining_memes = remaining_subs.empty? ? [] : fetcher.fetch_memes(remaining_subs, limit: 20)
      memes = test_memes + remaining_memes

      # SKIP quality filter on bootstrap for speed (basic validation only)
      validated = memes.select { |m| m["url"] && m["title"] && m["subreddit"] }
      stored = store_in_pool(validated)

      AppLogger.info("📊 [Bootstrap] Fetched: #{memes.size}, Validated: #{validated.size}, Stored: #{stored}")

      # Bootstrap succeeded - clear any prior rate-limit cooldown
      RedisService.delete(BOOTSTRAP_COOLDOWN_KEY) if stored > 0

      # BUG FIX (Aug 25, 2026, round 6): success used to be defined as
      # `stored > 0` - i.e. it depended on RedisService.set succeeding
      # inside store_in_pool. When Redis is genuinely unreachable,
      # RedisService.set always silently returns false, so `stored` was
      # always 0 EVEN WHEN we had genuinely fetched and validated real
      # memes from Reddit - bootstrap_pool always reported failure despite
      # having good data in `validated`, and callers like
      # get_pool_via_in_process_fallback (which read `validated`/`memes`
      # from this return value, not from Redis) had no way to succeed.
      # Success should reflect whether we actually have usable memes, not
      # whether the (optional, best-effort) Redis cache write succeeded.
      { success: validated.any?, size: validated.size, memes: validated, error: validated.empty? ? "No memes passed validation" : nil }
    rescue => e
      log_error("Bootstrap error", e)
      { success: false, size: 0, memes: [], error: e.message }
    end
    
    # Trigger background expansion to full 5K pool
    #
    # IMPORTANT: This is a best-effort, fire-and-forget side effect called
    # right after a successful bootstrap (see get_pool above). It must NEVER
    # raise — if it does, the exception propagates up through get_pool's
    # rescue and discards the memes we just successfully fetched from Reddit,
    # silently degrading every request to the 10-meme local fallback even
    # though bootstrap actually worked. (This happened in production when
    # Sidekiq's Redis `namespace:` option broke perform_async - see
    # config/initializers/sidekiq.rb.)
    def trigger_background_expansion
      if defined?(MemePoolMaintenanceWorker)
        # BUG FIX (Aug 25, 2026, round 11): this used to enqueue the full
        # expansion job immediately (perform_async), stacking a large
        # 1000-meme fetch right on top of the quick bootstrap that had
        # just completed seconds earlier - doubling Reddit API pressure in
        # a short window and increasing the odds of tripping a rate-limit
        # cooldown that then blocks ALL bootstrap attempts (including
        # future safe on-demand ones) for 5 minutes. A short delay lets
        # Reddit "breathe" between the two fetches; the scheduled 5-minute
        # cron (config/sidekiq.yml) would eventually pick this up anyway,
        # so this is purely about spacing out the immediate case.
        if MemePoolMaintenanceWorker.respond_to?(:perform_in)
          MemePoolMaintenanceWorker.perform_in(60)
        else
          MemePoolMaintenanceWorker.perform_async
        end
        AppLogger.info("✅ [PoolManager] Scheduled background expansion to 5,000 memes")
      else
        AppLogger.debug("ℹ️  [PoolManager] Sidekiq unavailable, pool will stay at bootstrap size")
      end
    rescue => e
      log_error("Trigger background expansion error (non-fatal, ignoring)", e)
    end
    
    # Build pool from scratch
    def build_pool!
      AppLogger.info("🔨 [PoolManager] Building pool from scratch...")
      fetch_batch(size: TARGET_POOL_SIZE, priority: :high)
    end
    
    # Fetch a batch of memes with tier-based distribution
    #
    # BUG FIX (Aug 25, 2026, round 11): this used to launch 5 concurrent
    # Concurrent::Future tasks (one per tier), and fetch_from_tier called
    # create_fetcher independently in each - meaning every single
    # fetch_batch call (triggered on a schedule every 5 minutes via
    # MemePoolMaintenanceWorker, AND immediately after every successful
    # on-demand bootstrap via trigger_background_expansion) fired 5
    # simultaneous OAuth token requests plus 5 concurrent waves of
    # subreddit fetches at Reddit. That's a self-inflicted thundering herd
    # far more aggressive than the careful, sequential, single-fetcher
    # on-demand bootstrap path (see bootstrap_pool). When Reddit rate-
    # limited this burst, it tripped BOOTSTRAP_COOLDOWN_KEY for 5 minutes -
    # blocking ALL subsequent bootstrap attempts (including the safe
    # on-demand ones) - and with the pool's 6-hour Redis TTL, once it went
    # empty there was nothing to reliably refill it, explaining the
    # observed "pool works great, then goes to 0 for a while, then
    # sporadically recovers" pattern in production.
    #
    # Fix: create ONE shared fetcher (one OAuth token) and reuse it
    # sequentially across tiers, matching bootstrap_pool's approach.
    def fetch_batch(size:, priority: :normal)
      AppLogger.info("📥 [PoolManager] Fetching batch of #{size} memes (priority: #{priority})")
      
      # Calculate tier distribution
      tier_counts = TIER_DISTRIBUTION.map do |tier, percentage|
        [tier, (size * percentage).to_i]
      end.to_h

      fetcher = create_fetcher

      all_memes = tier_counts.flat_map do |tier, count|
        fetch_from_tier(tier, count, fetcher: fetcher)
      end
      AppLogger.info("📦 [PoolManager] Fetched #{all_memes.size} memes total")
      
      # Apply quality pipeline
      validated_memes = quality_filter(all_memes)
      AppLogger.info("✅ [PoolManager] #{validated_memes.size} memes passed quality filter")
      
      # Store in pool
      stored_count = store_in_pool(validated_memes)
      AppLogger.info("💾 [PoolManager] Stored #{stored_count} memes in pool")

      if stored_count > 0
        # Successful fetch - clear any prior rate-limit cooldown
        RedisService.delete(BOOTSTRAP_COOLDOWN_KEY)
      elsif all_memes.empty?
        # Nothing came back from ANY tier - likely rate-limited across the board.
        # Set cooldown so the next scheduled/on-demand attempt doesn't immediately retry.
        AppLogger.warn("⚠️  [PoolManager] Fetch batch returned 0 memes across all tiers - assuming rate limit")
        RedisService.set(BOOTSTRAP_COOLDOWN_KEY, "true", ttl: BOOTSTRAP_COOLDOWN_TTL)
      end
      
      { fetched: all_memes.size, validated: validated_memes.size, stored: stored_count }
    rescue => e
      log_error("Fetch batch error", e)
      { fetched: 0, validated: 0, stored: 0, error: e.message }
    end
    
    # Replace stale memes with fresh content
    def replace_stale(percentage: 0.2)
      current_pool = get_current_pool
      stale_count = (current_pool.size * percentage).to_i
      
      AppLogger.info("🔄 [PoolManager] Replacing #{stale_count} stale memes (#{(percentage * 100).to_i}%)")
      
      # Find oldest memes
      stale_urls = find_stale_memes(current_pool, stale_count)
      
      # Remove stale memes
      remove_from_pool(stale_urls)
      
      # Fetch fresh replacements
      fetch_batch(size: stale_count)
      
      { replaced: stale_count }
    rescue => e
      log_error("Replace stale error", e)
      { replaced: 0, error: e.message }
    end

    # Poll for a pool becoming available while another request holds the
    # bootstrap lock. Returns the get_pool-shaped success hash as soon as the
    # pool is populated, or nil if it times out (caller should fall back).
    #
    # Also bails out early (instead of burning the full wait window) if the
    # in-progress bootstrap already confirmed a Reddit rate limit and set the
    # cooldown flag - no point waiting the rest of the timeout for a pool that
    # we already know isn't coming.
    def wait_for_pool(retries, interval)
      retries.times do
        sleep interval

        if RedisService.get(BOOTSTRAP_COOLDOWN_KEY)
          AppLogger.info("⏳ [PoolManager] Concurrent bootstrap hit rate limit - stopping wait early")
          return nil
        end

        pool = get_current_pool
        next if pool.empty?

        AppLogger.info("✅ [PoolManager] Concurrent bootstrap finished - reusing #{pool.size} memes")
        return { success: true, memes: pool, pool_size: pool.size, error: nil }
      end
      nil
    rescue => e
      log_error("Wait for pool error", e)
      nil
    end

    # Get current pool size (public - used by /health and other diagnostics).
    #
    # BUG FIX (Aug 25, 2026, round 10): this was accidentally defined below
    # the `private` marker further down in this file, even though it's a
    # legitimate public API used by routes/health.rb's meme_pool check
    # (which previously had no way to see MemePoolManager's real pool size
    # at all, and instead reported on a wholly separate, largely-unused
    # legacy cache - see the matching fix in routes/health.rb).
    def get_pool_size
      cached_count = RedisService.get('meme_pool:count')
      return cached_count.to_i if cached_count
      
      pool = get_current_pool
      pool.size
    rescue => e
      log_error("Get pool size error", e)
      0
    end
    
    private
    
    # Fetch memes from a specific tier.
    #
    # Accepts an optional pre-built `fetcher:` so callers doing multiple
    # tier fetches in one batch (see fetch_batch) can share a single OAuth
    # token instead of each tier independently authenticating with Reddit.
    def fetch_from_tier(tier, count, fetcher: nil)
      AppLogger.info("  📍 [PoolManager] Fetching #{count} memes from #{tier}")
      
      subreddits = load_tier_subreddits(tier)
      return [] if subreddits.empty?
      
      # Calculate memes per subreddit
      memes_per_sub = [count / subreddits.size, 1].max
      
      # Use Reddit Fetcher Service
      fetcher ||= create_fetcher
      memes = fetcher.fetch_memes(subreddits, limit: memes_per_sub)
      
      AppLogger.info("  ✅ [PoolManager] Got #{memes.size} memes from #{tier}")
      memes
    rescue => e
      log_error("Fetch from tier #{tier} error", e)
      []
    end
    
    # Apply quality pipeline to filter memes
    def quality_filter(memes)
      return [] if memes.empty?
      
      if defined?(QualityPipelineService)
        memes.select { |meme| QualityPipelineService.passes_all_gates?(meme) }
      else
        # Basic filtering if pipeline not available
        memes.select do |meme|
          meme["url"] && meme["title"] && meme["subreddit"]
        end
      end
    rescue => e
      log_error("Quality filter error", e)
      memes # Return unfiltered on error
    end
    
# Categorize memes by their subreddit tier - FIXED July 13: NOW CREATES ALL 5 POOLS
def categorize_by_tier(memes)
  return { fresh: [], trending: [], surprise: [], diverse: [], random: [] } if memes.empty?
  
  categorized = { fresh: [], trending: [], surprise: [], diverse: [], random: [] }
  tier_map = load_subreddit_tier_map
  
  memes.each do |meme|
    subreddit = meme["subreddit"]&.downcase
    next unless subreddit
    
    tier = tier_map[subreddit] || 5
    likes = meme['likes'].to_i
    upvote_ratio = meme['upvote_ratio'].to_f || 0.5
    
    # Fresh: Tier 1 (Peak humor, relationships)
    if tier == 1
      categorized[:fresh] << meme
    end
    
    # Trending: High engagement from any tier
    if likes >= 50 || upvote_ratio >= 0.8
      categorized[:trending] << meme
    end
    
    # Surprise: Tier 2-3 (Viral + Niche)
    if [2, 3].include?(tier)
      categorized[:surprise] << meme
    end
    
    # Diverse: Tier 4-5 (Visual + Wholesome)
    if [4, 5].include?(tier)
      categorized[:diverse] << meme
    end
    
    # Random: Everything
    categorized[:random] << meme
  end
  
  AppLogger.info("📊 [PoolManager] Categorized: fresh=#{categorized[:fresh].size}, trending=#{categorized[:trending].size}, surprise=#{categorized[:surprise].size}, diverse=#{categorized[:diverse].size}, random=#{categorized[:random].size}")
  categorized
end

# Load subreddit → tier mapping from YAML
def load_subreddit_tier_map
  return @tier_map if @tier_map
  
  yaml_path = File.join(__dir__, '../../data/subreddits.yml')
  data = YAML.load_file(yaml_path)
  
  @tier_map = {}
  data['tier_1']&.each { |sub| @tier_map[sub.downcase] = 1 }
  data['tier_2']&.each { |sub| @tier_map[sub.downcase] = 2 }
  data['tier_3']&.each { |sub| @tier_map[sub.downcase] = 3 }
  data['tier_4']&.each { |sub| @tier_map[sub.downcase] = 4 }
  data['tier_5']&.each { |sub| @tier_map[sub.downcase] = 5 }
  
  AppLogger.info("📚 [PoolManager] Loaded tier map: #{@tier_map.size} subreddits")
  @tier_map
rescue => e
  AppLogger.error("⚠️  [PoolManager] Failed to load tier map: #{e.message}")
  {}
end

# Get memes from a specific tier pool (July 13, 2026 - Redis Lists)
def get_tier_pool(pool_name)
  list_key = "meme_pool:#{pool_name}_ids"
  meme_ids = RedisService.lrange(list_key, 0, -1)
  return [] if meme_ids.empty?
  
  # Fetch full meme data for each ID
  memes = meme_ids.map do |meme_id|
    json = RedisService.hget("meme:data", meme_id)
    JSON.parse(json) if json
  end.compact
  
  memes
rescue => e
  AppLogger.error("⚠️  Failed to get tier pool '#{pool_name}': #{e.message}")
  []
end

    # Store memes using DUAL FORMAT (July 13, 2026 - Comprehensive Fix)
    # Stores both JSON blobs (backward compat) and Redis Lists (new arch)
    def store_in_pool(memes)
      return 0 if memes.empty?
      
      # Categorize memes by tier (now returns 5 pools!)
      categorized = categorize_by_tier(memes)
      
      # Deduplicate and limit each pool
      categorized.each do |pool, pool_memes|
        categorized[pool] = pool_memes.uniq { |m| m['url'] }.take(300)
      end
      
      total_stored = 0
      categorized.each do |pool_name, pool_memes|
        next if pool_memes.empty?
        
        # DUAL FORMAT: Store in BOTH JSON and Lists
        
        # Format 1: JSON blob (for legacy DiversityEngine v1 code)
        json_key = "meme_pool:#{pool_name}"
        RedisService.set(json_key, pool_memes.to_json, ttl: 21600) # 6 hours
        
        # Format 2: Redis Lists (for new architecture)
        list_key = "meme_pool:#{pool_name}_ids"
        RedisService.delete(list_key)  # Clear old
        
        pool_memes.each do |meme|
          # Generate consistent ID
          meme_id = meme['id'] || "#{meme['subreddit']}_#{meme['url'].hash.abs}"
          meme['id'] = meme_id
          
          # Store full meme data in hash
          RedisService.hset("meme:data", meme_id, meme.to_json)
          
          # Add ID to list
          RedisService.rpush(list_key, meme_id)
        end
        
        RedisService.expire(list_key, 21600)  # 6 hour TTL
        
        AppLogger.info("   ✅ Stored #{pool_memes.size} memes in '#{pool_name}' pool (JSON + Lists)")
        total_stored += pool_memes.size
      end
      
      # Update metadata with extended TTL
      RedisService.set("meme_pool:count", total_stored, ttl: 21600)
      RedisService.set("meme_pool:initialized", "true", ttl: 21600)
      RedisService.set("meme_pool:last_refresh", Time.now.to_i, ttl: 21600)
      
      # Store complete pool for legacy code (backward compatibility)
      all_memes = categorized.values.flatten.uniq { |m| m['url'] }
      RedisService.set("meme_pool", all_memes.to_json, ttl: 21600)
      
      total_stored
    rescue => e
      log_error("Store in pool error", e)
      0
    end
    
    # Get current pool from Redis
    #
    # BUG FIX (Aug 25, 2026, round 12): this used to call JSON.parse(cached)
    # on the result of RedisService.get('meme_pool') - but RedisService#get
    # already parses JSON internally via its private parse_value helper
    # before returning (see redis_service.rb), so `cached` here is already
    # a plain Ruby Array, not a JSON string. Calling JSON.parse on an Array
    # raises "no implicit conversion of Array into String" - and since this
    # is the ONLY way get_pool ever reads a populated pool back out of
    # Redis, this meant that as soon as store_in_pool successfully wrote a
    # real pool (confirmed by the "✅ Stored N memes" log lines), every
    # subsequent get_current_pool call blew up, size fell back to 0, and
    # get_pool treated the pool as perpetually empty - triggering another
    # bootstrap attempt on every single request, which then hit "another
    # request is bootstrapping" or the on-demand cooldown, and fell all
    # the way back to the 10-meme local pool. The real pool was being
    # written successfully the whole time; it could just never be read
    # back.
    def get_current_pool
      cached = RedisService.get('meme_pool')
      return cached if cached.is_a?(Array)
      return JSON.parse(cached) if cached.is_a?(String)
      
      []
    rescue => e
      log_error("Get current pool error", e)
      []
    end
    
    # Find stale memes (oldest by timestamp)
    def find_stale_memes(pool, count)
      return [] if pool.empty?
      
      # Sort by created_at or fetched_at (oldest first)
      sorted = pool.sort_by do |meme|
        timestamp = meme["fetched_at"] || meme["created_at"] || Time.now.to_s
        Time.parse(timestamp) rescue Time.now
      end
      
      # Take oldest N memes
      sorted.first(count).map { |m| m["url"] }
    rescue => e
      log_error("Find stale memes error", e)
      []
    end
    
    # Remove memes from pool by URL
    def remove_from_pool(urls)
      return 0 if urls.empty?
      
      pool = get_current_pool
      original_size = pool.size
      
      # Filter out URLs to remove
      updated_pool = pool.reject { |m| urls.include?(m["url"]) }
      
      # Update Redis
      RedisService.set('meme_pool', updated_pool.to_json)
      RedisService.set('meme_pool:count', updated_pool.size)
      
      original_size - updated_pool.size
    rescue => e
      log_error("Remove from pool error", e)
      0
    end
    
    # Load subreddits for a specific tier
    def load_tier_subreddits(tier)
      data = YAML.load_file('data/subreddits.yml', aliases: true)
      data[tier.to_s] || []
    rescue => e
      log_error("Load tier subreddits error for #{tier}", e)
      []
    end
    
    # Create Reddit fetcher with appropriate auth
    # Using standard RedditFetcherService (TurbochargedRedditFetcher deleted during cleanup)
    def create_fetcher(use_turbo: false)
      client_id = ENV['REDDIT_CLIENT_ID'].to_s.strip
      client_secret = ENV['REDDIT_CLIENT_SECRET'].to_s.strip
      
      fetcher_class = RedditFetcherService  # Always use standard fetcher

      # BUG FIX (Aug 25, 2026): render.yaml previously set these via
      # `value: ${REDDIT_CLIENT_ID}`, which a Render Blueprint does NOT
      # shell-interpolate - it stores the literal placeholder string. That
      # made ENV['REDDIT_CLIENT_ID'] non-empty but garbage, so this method
      # believed OAuth was configured, attempted (and always failed) a
      # token request, and silently fell back to the aggressively
      # rate-limited unauthenticated endpoint - the app then only ever
      # served the 10-meme local fallback pool with API memes never
      # rendering. Detect this specific misconfiguration shape explicitly
      # so it surfaces as a clear, actionable log line instead of a vague
      # downstream "0 memes" symptom. (Fixed properly at the source in
      # render.yaml via `sync: false`, but this guard protects against the
      # same class of copy/paste mistake in any environment.)
      if client_id.match?(/\A\$\{.*\}\z/) || client_secret.match?(/\A\$\{.*\}\z/)
        AppLogger.error(
          "⚠️  [PoolManager] REDDIT_CLIENT_ID/SECRET look like unresolved " \
          "placeholder strings (e.g. \"\#{REDDIT_CLIENT_ID}\") rather than real " \
          "credentials - check your deployment platform's env var config " \
          "(Render Blueprints require `sync: false` for secrets, not " \
          "`value: \#{VAR}` shell interpolation, which isn't supported)."
        )
        client_id = ''
        client_secret = ''
      end
      
      if !client_id.empty? && !client_secret.empty?
        require 'oauth2'
        
        client = OAuth2::Client.new(
          client_id,
          client_secret,
          site: "https://www.reddit.com",
          authorize_url: "/api/v1/authorize",
          token_url: "/api/v1/access_token"
        )
        
        token = client.client_credentials.get_token(scope: "read")
        fetcher_class.new(auth_strategy: :oauth, access_token: token.token)
      else
        fetcher_class.new(auth_strategy: :static)
      end
    rescue => e
      log_error("Create fetcher error", e)
      fetcher_class.new(auth_strategy: :static)
    end
    
    # Centralized error logging
    def log_error(context, error)
      message = error.is_a?(String) ? error : error.message
      AppLogger.warn("⚠️  [PoolManager] #{context}: #{message}")
      
      if defined?(Sentry) && error.is_a?(Exception)
        Sentry.capture_exception(error, extra: { context: context })
      end
    end
  end
end
