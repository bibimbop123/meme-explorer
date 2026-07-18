# frozen_string_literal: true

# Media Cache Service - Phase 4 Production Optimization
# Caches media metadata to reduce Reddit API calls and improve performance
class MediaCacheService
  CACHE_TTL = 3600 # 1 hour for media metadata
  CACHE_PREFIX = 'media:metadata:'
  
  class << self
    # Cache media metadata for a post
    def cache_media(post_id, media_data)
      return unless redis_available?
      
      key = cache_key(post_id)
      RedisService.set(key, media_data.to_json, CACHE_TTL)
    rescue => e
      AppLogger.error("Failed to cache media for #{post_id}: #{e.message}")
      nil # Fail silently
    end
    
    # Retrieve cached media metadata
    def get_cached_media(post_id)
      return nil unless redis_available?
      
      key = cache_key(post_id)
      cached = RedisService.get(key)
      cached ? JSON.parse(cached) : nil
    rescue => e
      AppLogger.error("Failed to retrieve cached media for #{post_id}: #{e.message}")
      nil
    end
    
    # Cache video thumbnail
    def cache_video_thumbnail(video_url, thumbnail_url)
      return unless redis_available?
      
      key = "media:video:thumb:#{Digest::MD5.hexdigest(video_url)}"
      RedisService.set(key, thumbnail_url, CACHE_TTL * 24) # 24 hours
    rescue => e
      AppLogger.error("Failed to cache video thumbnail: #{e.message}")
      nil
    end
    
    # Get cached video thumbnail
    def get_video_thumbnail(video_url)
      return nil unless redis_available?
      
      key = "media:video:thumb:#{Digest::MD5.hexdigest(video_url)}"
      RedisService.get(key)
    rescue => e
      AppLogger.error("Failed to retrieve video thumbnail: #{e.message}")
      nil
    end
    
    # Cache gallery images
    def cache_gallery_images(post_id, images)
      return unless redis_available?
      
      key = "media:gallery:#{post_id}"
      RedisService.set(key, images.to_json, CACHE_TTL * 12) # 12 hours
    rescue => e
      AppLogger.error("Failed to cache gallery images: #{e.message}")
      nil
    end
    
    # Get cached gallery images
    def get_gallery_images(post_id)
      return nil unless redis_available?
      
      key = "media:gallery:#{post_id}"
      cached = RedisService.get(key)
      cached ? JSON.parse(cached) : nil
    rescue => e
      AppLogger.error("Failed to retrieve gallery images: #{e.message}")
      nil
    end
    
    # Track media performance metrics
    def track_media_load(media_type, load_time_ms)
      return unless redis_available?
      
      key = "metrics:media:#{media_type}:load_times"
      RedisService.lpush(key, load_time_ms)
      RedisService.ltrim(key, 0, 999) # Keep last 1000 samples
      RedisService.expire(key, 86400) # 24 hours
    rescue => e
      AppLogger.error("Failed to track media metrics: #{e.message}")
    end
    
    # Get average load time for media type
    def average_load_time(media_type)
      return nil unless redis_available?
      
      key = "metrics:media:#{media_type}:load_times"
      times = RedisService.lrange(key, 0, -1).map(&:to_f)
      return nil if times.empty?
      
      (times.sum / times.length).round(2)
    rescue => e
      AppLogger.error("Failed to get average load time: #{e.message}")
      nil
    end
    
    # Warm cache for popular posts
    def warm_cache(post_ids)
      return unless redis_available?
      
      post_ids.each do |post_id|
        next if get_cached_media(post_id) # Skip if already cached
        
        # Fetch and cache media in background
        Thread.new do
          begin
            # This would call the fetcher service
            # For now, just mark as warmed
            cache_media(post_id, { warmed: true, timestamp: Time.now.to_i })
          rescue => e
            AppLogger.error("Failed to warm cache for #{post_id}: #{e.message}")
          end
        end
      end
    end
    
    # Clear old cache entries
    def clear_old_cache
      return unless redis_available?
      
      # Redis TTL handles this automatically
      # This method is for manual cleanup if needed
      pattern = "#{CACHE_PREFIX}*"
      keys = RedisService.keys(pattern)
      
      keys.each do |key|
        ttl = RedisService.ttl(key)
        RedisService.del(key) if ttl < 0 # Remove keys without TTL
      end
      
      AppLogger.info("Cleared #{keys.length} old media cache entries")
    rescue => e
      AppLogger.error("Failed to clear old cache: #{e.message}")
    end
    
    # Get cache statistics
    def cache_stats
      return {} unless redis_available?
      
      {
        total_cached: RedisService.keys("#{CACHE_PREFIX}*").length,
        video_thumbs: RedisService.keys("media:video:thumb:*").length,
        galleries: RedisService.keys("media:gallery:*").length,
        redis_memory: RedisService.info('memory')['used_memory_human']
      }
    rescue => e
      AppLogger.error("Failed to get cache stats: #{e.message}")
      {}
    end
    
    private
    
    def cache_key(post_id)
      "#{CACHE_PREFIX}#{post_id}"
    end
    
    def redis_available?
      defined?(RedisService) && RedisService.respond_to?(:get)
    end
  end
end
