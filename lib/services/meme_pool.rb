# frozen_string_literal: true

require_relative '../app_logger'

# Unified meme pool management service
# Single source of truth for meme pool retrieval
# Hierarchy: Redis → Bootstrap → Local Files
class MemePool
  class << self
    # Get meme pool with fallback hierarchy
    def get
      # 1. Try Redis/MemePoolManager (authoritative)
      pool = from_pool_manager
      return pool if pool&.any?
      
      # 2. Fallback to bootstrap
      AppLogger.warn("Pool empty, attempting bootstrap...")
      pool = bootstrap_pool
      return pool if pool&.any?
      
      # 3. Emergency: local static memes
      AppLogger.error("Bootstrap failed, using local memes")
      from_local_files
      
      private
      
      def from_pool_manager
        return nil unless defined?(MemeExplorer::MemePoolManager)
        
        result = MemeExplorer::MemePoolManager.get_pool
        if result[:success] && result[:memes]&.any?
          AppLogger.debug("Loaded #{result[:memes].size} memes from MemePoolManager")
          return result[:memes]
        end
        
        nil
      rescue => e
        AppLogger.error("MemePoolManager error", error: e.message)
        nil
      end
      
      def bootstrap_pool
        return nil unless defined?(MemeExplorer::MemePoolManager)
        
        result = MemeExplorer::MemePoolManager.bootstrap_pool
        if result[:success] && result[:memes]&.any?
          AppLogger.info("Bootstrapped #{result[:memes].size} memes")
          return result[:memes]
        end
        
        nil
      rescue => e
        AppLogger.error("Bootstrap error", error: e.message)
        nil
      end
      
      def from_local_files
        memes = if defined?(MEMES)
          case MEMES
          when Hash
            MEMES.values.flatten.compact
          when Array
            MEMES
          else
            []
          end
        else
          []
        end
        
        AppLogger.info("Loaded #{memes.size} memes from local files")
        memes
      rescue => e
        AppLogger.error("Local memes load error", error: e.message)
        []
      end
    end
  end
end