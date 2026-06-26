# frozen_string_literal: true
# QualityFilterService - Extracted from ApiCacheService
# Single Responsibility: Content quality scoring and filtering
# Part of Phase 1 God Object Refactoring

require_relative '../../config/tuning_parameters'

class QualityFilterService
  include TuningParameters

  # Filter memes by quality threshold
  # @param memes [Array<Hash>] Memes to filter
  # @param threshold [Float] Quality threshold (0.0 - 1.0)
  # @return [Array<Hash>] Filtered memes
  def filter(memes, threshold: QUALITY_THRESHOLD)
    memes.select { |meme| quality_score(meme) >= threshold }
  end

  # Calculate quality score for a meme
  # @param meme [Hash] Meme data
  # @return [Float] Quality score (0.0 - 1.0)
  def quality_score(meme)
    return 0.0 unless meme.is_a?(Hash)

    scores = [
      engagement_score(meme),
      recency_score(meme),
      format_score(meme),
      source_score(meme)
    ]

    scores.compact.sum / scores.compact.size.to_f
  end

  # Balance diversity in meme set
  # @param memes [Array<Hash>] Memes to balance
  # @param max_per_subreddit [Integer] Max memes per subreddit
  # @return [Array<Hash>] Balanced memes
  def balance_diversity(memes, max_per_subreddit: 5)
    subreddit_counts = Hash.new(0)
    
    memes.select do |meme|
      subreddit = meme[:subreddit] || 'unknown'
      if subreddit_counts[subreddit] < max_per_subreddit
        subreddit_counts[subreddit] += 1
        true
      else
        false
      end
    end
  end

  # Remove low quality memes
  # @param memes [Array<Hash>] Memes to filter
  # @return [Array<Hash>] High quality memes
  def remove_low_quality(memes)
    filter(memes, threshold: MINIMUM_QUALITY_SCORE)
  end

  # Get top quality memes
  # @param memes [Array<Hash>] Memes to rank
  # @param limit [Integer] Number of top memes
  # @return [Array<Hash>] Top quality memes
  def top_quality(memes, limit: 10)
    memes.sort_by { |m| -quality_score(m) }.take(limit)
  end

  private

  def engagement_score(meme)
    ups = meme[:ups].to_i
    comments = meme[:num_comments].to_i
    
    return 0.0 if ups <= 0
    
    # Normalize engagement (log scale)
    engagement = Math.log10(ups + 1) + Math.log10(comments + 1)
    [engagement / 10.0, 1.0].min
  end

  def recency_score(meme)
    created_at = meme[:created_utc].to_i
    return 0.0 if created_at <= 0
    
    hours_old = (Time.now.to_i - created_at) / 3600.0
    
    # Decay over 72 hours
    [(72.0 - hours_old) / 72.0, 0.0].max
  end

  def format_score(meme)
    # Prefer images and videos over text
    case meme[:post_hint]
    when 'image' then 1.0
    when 'hosted:video', 'rich:video' then 0.9
    when 'link' then 0.7
    else 0.5
    end
  end

  def source_score(meme)
    # Prefer quality subreddits (can be configured)
    quality_subreddits = %w[memes dankmemes wholesomememes funny]
    subreddit = meme[:subreddit]&.downcase
    
    quality_subreddits.include?(subreddit) ? 1.0 : 0.8
  end
end
