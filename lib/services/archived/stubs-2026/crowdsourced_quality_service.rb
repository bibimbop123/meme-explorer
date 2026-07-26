# Crowdsourced Quality Service - Phase 2
# Tracks user feedback signals to improve quality scoring
# Created: June 3, 2026

class CrowdsourcedQualityService
  # Signal weights for quality score calculation
  SIGNAL_WEIGHTS = {
    'like' => 1.0,
    'save' => 2.0,
    'share' => 3.0,
    'skip_fast' => -0.5,    # Skipped within 2 seconds
    'report' => -5.0
  }.freeze
  
  class << self
    # Record a user interaction signal
    def record_interaction(meme_url, signal_type, user_id: nil)
      return false unless valid_signal?(signal_type)
      return false unless meme_url
      
      # Store signal in database
      if defined?(DB)
        DB.execute(
          "INSERT INTO meme_quality_signals (meme_url, signal_type, user_id, created_at) 
           VALUES (?, ?, ?, ?)",
          [meme_url, signal_type, user_id, Time.now]
        )
      end
      
      # Update quality score asynchronously
      update_quality_score(meme_url)
      
      true
    rescue => e
      log_error("Record interaction error for #{meme_url}", e)
      false
    end
    
    # Update quality score based on all signals
    def update_quality_score(meme_url)
      signals = get_signals(meme_url)
      return 0.0 if signals.empty?
      
      score = calculate_weighted_score(signals)
      
      # Store in database
      if defined?(DB)
        DB.execute(
          "UPDATE meme_stats SET quality_score = ?, updated_at = ? WHERE url = ?",
          [score, Time.now, meme_url]
        )
      end
      
      # Cache score in Redis for fast access
      if defined?(RedisService)
        RedisService.setex("quality:#{meme_url}", 3600, score.to_s)
      end
      
      score
    rescue => e
      log_error("Update quality score error for #{meme_url}", e)
      0.0
    end
    
    # Get quality score for a meme (cached)
    def get_quality_score(meme_url)
      # Try Redis cache first
      if defined?(RedisService)
        cached = RedisService.get("quality:#{meme_url}")
        return cached.to_f if cached
      end
      
      # Fall back to database
      if defined?(DB)
        result = DB.execute(
          "SELECT quality_score FROM meme_stats WHERE url = ? LIMIT 1",
          [meme_url]
        ).first
        
        return result['quality_score'].to_f if result
      end
      
      50.0  # Default score
    rescue => e
      log_error("Get quality score error for #{meme_url}", e)
      50.0
    end
    
    # Get all signals for a meme
    def get_signals(meme_url)
      return [] unless defined?(DB)
      
      DB.execute(
        "SELECT signal_type, COUNT(*) as count 
         FROM meme_quality_signals 
         WHERE meme_url = ? 
         GROUP BY signal_type",
        [meme_url]
      )
    rescue => e
      log_error("Get signals error for #{meme_url}", e)
      []
    end
    
    # Calculate weighted quality score
    def calculate_weighted_score(signals)
      # Base score
      base = 50.0
      
      # Calculate adjustment from signals
      adjustment = signals.sum do |signal|
        weight = SIGNAL_WEIGHTS[signal['signal_type']] || 0
        count = signal['count'].to_i
        weight * count
      end
      
      # Apply adjustment with diminishing returns
      score = base + (adjustment / (1 + adjustment.abs * 0.01))
      
      # Clamp to 0-100 range
      [[score, 0].max, 100].min
    rescue => e
      log_error("Calculate weighted score error", e)
      50.0
    end
    
    # Get top quality memes
    def top_quality_memes(limit: 20, min_signals: 10)
      return [] unless defined?(DB)
      
      DB.execute(
        "SELECT m.url, m.title, m.subreddit, m.quality_score,
                COUNT(q.id) as signal_count
         FROM meme_stats m
         LEFT JOIN meme_quality_signals q ON m.url = q.meme_url
         GROUP BY m.url, m.title, m.subreddit, m.quality_score
         HAVING COUNT(q.id) >= ?
         ORDER BY m.quality_score DESC, signal_count DESC
         LIMIT ?",
        [min_signals, limit]
      )
    rescue => e
      log_error("Top quality memes error", e)
      []
    end
    
    # Get quality distribution stats
    def quality_distribution
      return {} unless defined?(DB)
      
      {
        excellent: count_by_score_range(80, 100),
        good: count_by_score_range(60, 79),
        average: count_by_score_range(40, 59),
        poor: count_by_score_range(0, 39),
        avg_score: average_quality_score,
        total_signals: total_signal_count
      }
    rescue => e
      log_error("Quality distribution error", e)
      {}
    end
    
    private
    
    def valid_signal?(signal_type)
      SIGNAL_WEIGHTS.key?(signal_type)
    end
    
    def count_by_score_range(min, max)
      return 0 unless defined?(DB)
      
      result = DB.execute(
        "SELECT COUNT(*) as count FROM meme_stats 
         WHERE quality_score BETWEEN ? AND ?",
        [min, max]
      ).first
      
      result ? result['count'].to_i : 0
    rescue
      0
    end
    
    def average_quality_score
      return 0.0 unless defined?(DB)
      
      result = DB.execute(
        "SELECT AVG(quality_score) as avg FROM meme_stats 
         WHERE quality_score > 0"
      ).first
      
      result && result['avg'] ? result['avg'].to_f.round(2) : 0.0
    rescue
      0.0
    end
    
    def total_signal_count
      return 0 unless defined?(DB)
      
      result = DB.execute(
        "SELECT COUNT(*) as count FROM meme_quality_signals"
      ).first
      
      result ? result['count'].to_i : 0
    rescue
      0
    end
    
    # Centralized error logging
    def log_error(context, error)
      message = error.is_a?(String) ? error : error.message
      AppLogger.warn("⚠️  [CrowdsourcedQuality] #{context}: #{message}")
      
      if defined?(Sentry) && error.is_a?(Exception)
        Sentry.capture_exception(error, extra: { context: context })
      end
    end
  end
end
