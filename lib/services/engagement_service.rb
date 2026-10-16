# EngagementService
# Comprehensive service for handling all engagement actions (likes, saves, shares)
# Integrates with gamification, leaderboards, metrics, and activity tracking
# Created: June 3, 2026

class EngagementService
  class << self
    # Track a like action with full integration
    # @param user_id [Integer] User performing the action
    # @param meme_url [String] URL of meme being liked
    # @param liked_now [Boolean] Whether this is a like (true) or unlike (false)
    # @param session [Hash] Session data
    # @param db [SQLite3::Database] Database connection
    # @return [Hash] Result with likes count and XP awarded
    def track_like(user_id:, meme_url:, liked_now:, session: {}, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return { error: 'Database not available', likes: 0 } unless db && meme_url
      
      result = {
        success: false,
        liked: liked_now,
        likes: 0,
        xp_awarded: 0,
        level_up: false
      }
      
      begin
        # 1. Update meme_stats table
        ensure_meme_stats_exists(meme_url, db)
        
        if liked_now
          db.execute("UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [meme_url])
          AppLogger.info("✅ [ENGAGEMENT] Like recorded for: #{meme_url[0..50]}...")
        else
          db.execute("UPDATE meme_stats SET likes = CASE WHEN likes > 0 THEN likes - 1 ELSE 0 END, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [meme_url])
          AppLogger.info("✅ [ENGAGEMENT] Unlike recorded for: #{meme_url[0..50]}...")
        end
        
        result[:likes] = get_likes_count(meme_url, db)
        
        # 1b. ROADMAP.md Phase 1 ("Feed real per-user signal ... back into
        # MemePoolManager's tier-distributed pool selection weighting") -
        # see bump_subreddit_preference's own comment below for the full
        # story on why this wasn't happening before. Only on real likes,
        # not unlikes: an unlike shouldn't erase or count against a prior
        # preference signal, and there's no decrement path here by design.
        if liked_now && user_id
          subreddit_row = db.execute("SELECT subreddit FROM meme_stats WHERE url = ?", [meme_url]).first
          subreddit = subreddit_row && (subreddit_row['subreddit'] || subreddit_row[:subreddit])
          bump_subreddit_preference(user_id, subreddit, db, increment: 0.2)
        end
        
        # 2. Log activity for metrics (time-based tracking)
        log_activity(user_id, meme_url, liked_now ? 'like' : 'unlike', session, db)
        
        # 3. Update user_meme_stats (user-specific tracking)
        update_user_meme_stats(user_id, meme_url, liked_now, db) if user_id
        
        # 4. Award XP and update gamification (only for likes, not unlikes)
        if liked_now && user_id
          xp_result = award_xp(user_id, :like_meme, db)
          if xp_result
            result[:xp_awarded] = xp_result[:xp_gained] || 0
            result[:level_up] = xp_result[:leveled_up] || false
            result[:new_level] = xp_result[:level] if xp_result[:leveled_up]
          end
        end
        
        # 5. Update weekly leaderboard
        update_weekly_leaderboard(user_id, 'like', db) if user_id
        
        # 6. Record in ActivityTrackerService (Redis for real-time stats)
        # ActivityTrackerService removed during Elon audit
        # ActivityTrackerService.record_action('like', user_id) if user_id && liked_now
        
        result[:success] = true
        result
      rescue => e
        AppLogger.error("❌ [ENGAGEMENT] Error tracking like: #{e.message}")
        AppLogger.error("backtrace", lines: (e.backtrace.first(3))&.join("\n"))
        result[:error] = e.message
        result
      end
    end
    
    # Track a save action with full integration
    # @param user_id [Integer] User performing the action
    # @param meme_url [String] URL of meme being saved
    # @param title [String] Meme title
    # @param subreddit [String] Meme subreddit
    # @param saved_now [Boolean] Whether this is a save (true) or unsave (false)
    # @param session [Hash] Session data
    # @param db [SQLite3::Database] Database connection
    # @return [Hash] Result with save status and XP awarded
    def track_save(user_id:, meme_url:, title: 'Unknown', subreddit: 'unknown', saved_now: true, session: {}, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return { error: 'Database not available', saved: false } unless db && meme_url && user_id
      
      result = {
        success: false,
        saved: saved_now,
        xp_awarded: 0,
        level_up: false
      }
      
      begin
        # 1. Update saved_memes table
        if saved_now
          # Check if already saved
          existing = db.execute(
            "SELECT id FROM saved_memes WHERE user_id = ? AND meme_url = ?",
            [user_id, meme_url]
          ).first
          return result.merge(success: true, unchanged: true) if existing
          
          unless existing
            # BUG FIX: `saved_memes`' real column is `saved_at` (see
            # db/postgres_schema.sql), not `created_at` - this INSERT
            # raised PG::UndefinedColumn on every single call, meaning
            # every real "save meme" action (POST /api/save-meme, the
            # only caller of track_save) has silently failed since this
            # was written. The route itself made this invisible: it
            # built its `saved: true` response unconditionally instead
            # of checking `result[:success]`, so users saw a success
            # message while nothing was actually saved.
            inserted = db.execute(
              "INSERT INTO saved_memes (user_id, meme_url, meme_title, meme_subreddit, saved_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP) ON CONFLICT(user_id, meme_url) DO NOTHING RETURNING id",
              [user_id, meme_url, title, subreddit]
            )
            return result.merge(success: true, unchanged: true) if inserted.empty?
            AppLogger.info("✅ [ENGAGEMENT] Save recorded for user #{user_id}")
          end

          # ROADMAP.md Phase 1: a save is a stronger intent signal than a
          # like (deliberate, not incidental while scrolling), so it's
          # weighted higher (+0.3 vs. a like's +0.2) - a genuine design
          # choice, not an arbitrary number; revisit with real usage data
          # once there's enough traffic to tell if it's well-calibrated.
          # Unlike track_like above, `subreddit` is already a real
          # parameter here (not looked up from meme_stats), so this is a
          # direct call.
          bump_subreddit_preference(user_id, subreddit, db, increment: 0.3)
        else
          # Unsave
          db.execute(
            "DELETE FROM saved_memes WHERE user_id = ? AND meme_url = ?",
            [user_id, meme_url]
          )
          AppLogger.info("✅ [ENGAGEMENT] Unsave recorded for user #{user_id}")
        end
        
        # 2. Log activity for metrics
        log_activity(user_id, meme_url, saved_now ? 'save' : 'unsave', session, db)
        
        # 3. Award XP for saves (only for saves, not unsaves)
        if saved_now
          xp_result = award_xp(user_id, :save_meme, db)
          if xp_result
            result[:xp_awarded] = xp_result[:xp_gained] || 0
            result[:level_up] = xp_result[:leveled_up] || false
            result[:new_level] = xp_result[:level] if xp_result[:leveled_up]
          end
        end
        
        # 4. Update weekly leaderboard
        update_weekly_leaderboard(user_id, 'save', db) if saved_now
        
        # 5. Record in ActivityTrackerService (Redis)
        # ActivityTrackerService removed during Elon audit
        # ActivityTrackerService.record_action('save', user_id) if saved_now
        
        # 6. Check collection progress (badges/achievements)
        check_collections(user_id, db) if saved_now
        
        result[:success] = true
        result
      rescue => e
        AppLogger.error("❌ [ENGAGEMENT] Error tracking save: #{e.message}")
        AppLogger.error("backtrace", lines: (e.backtrace.first(3))&.join("\n"))
        result[:error] = e.message
        result
      end
    end
    
    # Check if user has liked a meme
    # @param user_id [Integer] User ID
    # @param meme_url [String] Meme URL
    # @param db [SQLite3::Database] Database connection
    # @return [Boolean] Whether user has liked this meme
    def user_liked?(user_id:, meme_url:, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return false unless db && user_id && meme_url
      
      result = db.execute(
        "SELECT id FROM user_liked_memes WHERE user_id = ? AND meme_url = ?",
        [user_id, meme_url]
      ).first
      
      !result.nil?
    rescue => e
      false
    end
    
    # Check if user has saved a meme
    # @param user_id [Integer] User ID
    # @param meme_url [String] Meme URL
    # @param db [SQLite3::Database] Database connection
    # @return [Boolean] Whether user has saved this meme
    def user_saved?(user_id:, meme_url:, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return false unless db && user_id && meme_url
      
      result = db.execute(
        "SELECT id FROM saved_memes WHERE user_id = ? AND meme_url = ?",
        [user_id, meme_url]
      ).first
      
      !result.nil?
    rescue => e
      false
    end
    
    # Track a skip (user navigated past a meme without liking/saving it).
    #
    # ROADMAP.md Phase 1: "Feed real per-user signal (saves, skips, dwell
    # time) back into ... pool selection weighting" - likes and saves
    # were wired in earlier this session (see bump_subreddit_preference),
    # but a skip carries real signal too and had no path into
    # user_subreddit_preferences at all. Unlike likes/saves, this is a
    # genuinely new capability (no prior method anywhere in the codebase
    # even attempted to record skips), not a "found it disconnected,
    # reconnected it" fix like the rest of this session's personalization
    # work.
    #
    # Deliberately small penalty (-0.05, vs. a like's +0.2/save's +0.3):
    # scrolling past one meme in a subreddit a user otherwise likes is
    # weak, noisy signal (could be "not in the mood right now", not "I
    # dislike this subreddit") - a harsh penalty would make one skip undo
    # several likes' worth of signal, which isn't the right calibration
    # for a click a user makes far more often than a like. Floored at 0.1
    # by bump_subreddit_preference (never zero/negative). This is a
    # genuine, stated design choice pending real usage data, exactly like
    # the like/save weights above - not a proven-optimal number.
    # @param user_id [Integer] User performing the action (no-op if nil -
    #   skip signal for anonymous sessions isn't tracked, same as likes)
    # @param subreddit [String] Subreddit of the skipped meme
    # @param db [SQLite3::Database] Database connection
    # @return [Hash] Result with success status
    def track_skip(user_id:, subreddit:, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return { success: false, error: 'Database not available' } unless db
      return { success: true, skipped: false } unless user_id && subreddit

      bump_subreddit_preference(user_id, subreddit, db, increment: -0.05)
      { success: true, skipped: true }
    rescue => e
      AppLogger.error("❌ [ENGAGEMENT] Error tracking skip: #{e.message}")
      { success: false, error: e.message }
    end

    # Get comprehensive engagement stats for a user
    # @param user_id [Integer] User ID
    # @param db [SQLite3::Database] Database connection
    # @return [Hash] User engagement statistics
    def user_stats(user_id:, db: nil)
      db ||= defined?(DB) ? ::DB : nil
      return {} unless db && user_id
      
      {
        total_likes: count_user_likes(user_id, db),
        total_saves: count_user_saves(user_id, db),
        total_xp: get_user_xp(user_id, db),
        level: get_user_level(user_id, db),
        weekly_rank: get_weekly_rank(user_id, db),
        current_streak: get_current_streak(user_id, db)
      }
    rescue => e
      AppLogger.error("❌ [ENGAGEMENT] Error getting user stats: #{e.message}")
      {}
    end
    
    private

    # ROADMAP.md Phase 1 ("Feed real per-user signal ... back into
    # MemePoolManager's tier-distributed pool selection weighting"): the
    # mechanism that's supposed to increment
    # user_subreddit_preferences.preference_score (which
    # apply_user_preferences in lib/helpers/meme_pool_helpers.rb reads on
    # every /random pool build to boost a user's preferred subreddits)
    # was `update_user_preference` in lib/helpers/meme_navigation_helpers.rb
    # - but that's defined as an instance method inside `module
    # MemeNavigationHelpers`, only reachable via Sinatra's `helpers
    # MemeNavigationHelpers` mixin inside a route's `self` context.
    # EngagementService is a plain Ruby class, not a Sinatra route
    # context, so it can't call that method directly (confirmed:
    # `MemeNavigationHelpers.instance_methods(false)` includes it,
    # `Object.private_instance_methods(false)` does not) - and it was
    # never called from any actual route either way, so every like/save,
    # ever, went through this class without ever touching that table.
    # This is the same upsert (same SQL, same ON CONFLICT semantics
    # already fixed for PostgreSQL's ambiguous-column requirement in a
    # prior session), just defined where it's actually reachable from
    # both track_like and track_save.
    #
    # `increment` may be negative (see EngagementService.track_skip below,
    # ROADMAP.md Phase 1's "skips" signal) - GREATEST(..., 0.1) floors the
    # result so preference_score can never hit zero or go negative, which
    # would invert SimpleMemeSelector#weighted_sample's multiplier (a
    # negative weight breaks the cumulative-sum sampling logic entirely,
    # not just "penalize too hard"). `times_liked` only increments on a
    # positive bump (an actual like/save) - a skip is a real signal but
    # isn't a "like", so it doesn't inflate that count.
    def bump_subreddit_preference(user_id, subreddit, db, increment:)
      return unless user_id && subreddit && subreddit != 'unknown'

      # NOTE on the INSERT branch: a brand-new (user_id, subreddit) row
      # always starts at literal 1.0, regardless of `increment`'s sign -
      # this preserves the pre-existing, already-tested behavior from
      # before `increment:` became a parameter at all (a first-ever like
      # set the baseline rather than contributing its own +0.2). Only
      # the UPDATE branch (an existing row, i.e. a second+ signal for
      # that subreddit) actually applies `increment`. This means a
      # user's very first skip for a subreddit they have no prior signal
      # for lands at neutral 1.0, not 0.95 - consistent with a first
      # like/save also landing at neutral 1.0, not 1.2/1.3.
      times_liked_delta = increment.positive? ? 1 : 0
      db.execute(
        "INSERT INTO user_subreddit_preferences (user_id, subreddit, preference_score, times_liked) VALUES (?, ?, 1.0, ?) ON CONFLICT(user_id, subreddit) DO UPDATE SET preference_score = GREATEST(user_subreddit_preferences.preference_score + ?, 0.1), times_liked = user_subreddit_preferences.times_liked + ?, last_updated = CURRENT_TIMESTAMP",
        [user_id, subreddit.downcase, times_liked_delta, increment, times_liked_delta]
      )
    rescue => e
      AppLogger.warn("⚠️ [ENGAGEMENT] subreddit preference upsert failed: #{e.message}")
    end

    # Ensure meme_stats record exists (PostgreSQL compatible)
    def ensure_meme_stats_exists(meme_url, db)
      db.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views) 
         VALUES (?, ?, ?, 0, 0) 
         ON CONFLICT (url) DO NOTHING",
        [meme_url, 'Unknown', 'unknown']
      )
    end
    
    # Get current likes count
    def get_likes_count(meme_url, db)
      result = db.execute("SELECT likes FROM meme_stats WHERE url = ?", [meme_url]).first
      result ? result['likes'].to_i : 0
    end
    
    # Log activity to meme_activity_log
    def log_activity(user_id, meme_url, activity_type, session, db)
      session_id = begin
        session[:visitor_id] || session[:user_id]
      rescue => e
        AppLogger.warn("log_activity: session read failed", error: e.message)
        nil
      end
      
      db.execute(
        "INSERT INTO meme_activity_log (meme_url, activity_type, user_id, session_id, created_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)",
        [meme_url, activity_type, user_id, session_id]
      )
    rescue PG::UndefinedTable, StandardError => e
      # Table might not exist yet - fail gracefully
      AppLogger.warn("⚠️ [ENGAGEMENT] Activity log insert skipped: #{e.message}") unless e.message =~ /does not exist|no such table/
    end
    
    # Update user_meme_stats table
    def update_user_meme_stats(user_id, meme_url, liked_now, db)
      if liked_now
        db.execute(
          "INSERT INTO user_meme_stats (user_id, meme_url, liked, liked_at, updated_at) 
           VALUES (?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
           ON CONFLICT(user_id, meme_url) DO UPDATE SET 
           liked = 1, liked_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP",
          [user_id, meme_url]
        )
      else
        db.execute(
          "UPDATE user_meme_stats SET liked = 0, unliked_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP 
           WHERE user_id = ? AND meme_url = ?",
          [user_id, meme_url]
        )
      end
    rescue PG::UndefinedTable, StandardError => e
      # Table might not exist yet
      AppLogger.warn("⚠️ [ENGAGEMENT] user_meme_stats update skipped: #{e.message}") unless e.message =~ /does not exist|no such table/
    end
    
    # Award XP using GamificationHelpers
    def award_xp(user_id, activity_type, db)
      return nil unless defined?(GamificationHelpers)
      
      # Use a helper object that includes GamificationHelpers
      helper = Object.new
      helper.extend(GamificationHelpers)
      
      # Temporarily set DB constant if not set
      original_db = defined?(::DB) ? ::DB : nil
      Object.const_set(:DB, db) unless defined?(::DB)
      
      result = helper.add_xp(user_id, activity_type)
      
      # Restore original DB constant
      Object.const_set(:DB, original_db) if original_db && !defined?(::DB)
      
      result
    rescue => e
      AppLogger.error("⚠️ [ENGAGEMENT] XP award failed: #{e.message}")
      nil
    end
    
    # Update weekly leaderboard
    def update_weekly_leaderboard(user_id, action_type, db)
      week_num = Date.today.strftime("%Y%U").to_i
      
      # Increment metric value based on action type
      increment = case action_type
                  when 'like' then 1
                  when 'save' then 2  # Saves worth more
                  when 'share' then 3  # Shares worth most
                  else 1
                  end
      
      db.execute(
        "INSERT INTO weekly_leaderboard (week_number, user_id, metric_value, updated_at)
         VALUES (?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT (week_number, user_id)
         DO UPDATE SET metric_value = metric_value + ?, updated_at = CURRENT_TIMESTAMP",
        [week_num, user_id, increment, increment]
      )
      
      # Update ranks (could be done async in production)
      update_leaderboard_ranks(week_num, db)
    rescue PG::UndefinedTable, StandardError => e
      AppLogger.warn("⚠️ [ENGAGEMENT] Leaderboard update skipped: #{e.message}") unless e.message =~ /does not exist|no such table/
    end
    
    # Update leaderboard ranks
    def update_leaderboard_ranks(week_num, db)
      # Get all users sorted by metric_value
      users = db.execute(
        "SELECT id, metric_value FROM weekly_leaderboard 
         WHERE week_number = ? 
         ORDER BY metric_value DESC",
        [week_num]
      )
      
      # Update ranks
      users.each_with_index do |user, index|
        db.execute(
          "UPDATE weekly_leaderboard SET rank = ? WHERE id = ?",
          [index + 1, user['id']]
        )
      end
    rescue => e
      AppLogger.error("⚠️ [ENGAGEMENT] Rank update failed: #{e.message}")
    end
    
    # Check collection progress after save
    def check_collections(user_id, db)
      return unless defined?(GamificationHelpers)
      
      helper = Object.new
      helper.extend(GamificationHelpers)
      
      # Temporarily set DB if needed
      original_db = defined?(::DB) ? ::DB : nil
      Object.const_set(:DB, db) unless defined?(::DB)
      
      helper.check_collection_progress(user_id)
      
      Object.const_set(:DB, original_db) if original_db && !defined?(::DB)
    rescue => e
      AppLogger.error("⚠️ [ENGAGEMENT] Collection check failed: #{e.message}")
    end
    
    # Count user's total likes
    def count_user_likes(user_id, db)
      result = db.execute(
        "SELECT COUNT(*) as count FROM user_liked_memes WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['count'].to_i : 0
    rescue => e
      0
    end
    
    # Count user's total saves
    def count_user_saves(user_id, db)
      result = db.execute(
        "SELECT COUNT(*) as count FROM saved_memes WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['count'].to_i : 0
    rescue => e
      0
    end
    
    # Get user's total XP
    def get_user_xp(user_id, db)
      result = db.execute(
        "SELECT total_xp FROM user_levels WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['total_xp'].to_i : 0
    rescue => e
      0
    end
    
    # Get user's level
    def get_user_level(user_id, db)
      result = db.execute(
        "SELECT level FROM user_levels WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['level'].to_i : 1
    rescue => e
      1
    end
    
    # Get user's weekly rank
    def get_weekly_rank(user_id, db)
      week_num = Date.today.strftime("%Y%U").to_i
      result = db.execute(
        "SELECT rank FROM weekly_leaderboard WHERE week_number = ? AND user_id = ?",
        [week_num, user_id]
      ).first
      result ? result['rank'].to_i : nil
    rescue => e
      nil
    end
    
    # Get user's current streak
    def get_current_streak(user_id, db)
      result = db.execute(
        "SELECT current_streak FROM user_streaks WHERE user_id = ?",
        [user_id]
      ).first
      result ? result['current_streak'].to_i : 0
    rescue => e
      0
    end
  end
end
