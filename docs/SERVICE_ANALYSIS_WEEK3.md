# Service Analysis - Week 3
**Date:** July 26, 2026  
**Current Services:** 91  
**Target Services:** 30  
**Reduction Needed:** 61 services (-67.0%)

## Current Services Inventory

- `ab_testing_service.rb`
- `activity_tracker_service.rb`
- `adaptive_rate_limiter.rb`
- `alert_service.rb`
- `algorithm_config_service.rb`
- `analytics_service.rb`
- `api_cache_service.rb`
- `auth_service.rb`
- `business_metrics_service.rb`
- `cache_fetcher_service.rb`
- `cache_warming_service.rb`
- `cdn_service.rb`
- `circuit_breaker.rb`
- `collaborative_filtering_service.rb`
- `contextual_scoring_service.rb`
- `crowdsourced_quality_service.rb`
- `curation_signals_service.rb`
- `curator_notes_service.rb`
- `daily_challenge_service.rb`
- `daily_digest_service.rb`
- `diversity_engine_service.rb`
- `edge_cache_service.rb`
- `engagement_service.rb`
- `geolocation_service.rb`
- `health_check_service.rb`
- `http_connection_pool.rb`
- `humor_optimizer_service.rb`
- `image_fallback_service.rb`
- `image_health_service.rb`
- `image_optimization_service.rb`
- `inline_reddit_fetcher.rb`
- `leaderboard_service.rb`
- `media_cache_service.rb`
- `media_handling_service.rb`
- `meme_pool.rb`
- `meme_pool_manager.rb`
- `meme_remix_service.rb`
- `meme_selection_service.rb`
- `meme_service.rb`
- `metrics_tracker_service.rb`
- `milestone_service.rb`
- `ml_quality_predictor.rb`
- `ml_recommendation_service.rb`
- `ml_user_clustering_service.rb`
- `near_miss_service.rb`
- `oauth_token_service.rb`
- `performance_budget_service.rb`
- `performance_tracker.rb`
- `personalization_service.rb`
- `placeholder_image_service.rb`
- `premium_service.rb`
- `push_notification_service.rb`
- `quality_control_service.rb`
- `quality_filter_service.rb`
- `quality_pipeline_service.rb`
- `reactions_service.rb`
- `realtime_events_service.rb`
- `reddit_fetcher_service.rb`
- `redis_service.rb`
- `redis_service_cluster_patch.rb`
- `region_router_service.rb`
- `retention_service.rb`
- `revenue_tracker.rb`
- `rum_service.rb`
- `search_service.rb`
- `seasonal_content_service.rb`
- `seo_service.rb`
- `session_learning_service.rb`
- `session_tracker_service.rb`
- `similar_meme_cache.rb`
- `similar_meme_service.rb`
- `simple_meme_selector.rb`
- `slo_monitor_service.rb`
- `smart_media_renderer_service.rb`
- `stories_share_service.rb`
- `subreddit_discovery_service.rb`
- `surprise_mechanics_service.rb`
- `surprise_rewards_service.rb`
- `taste_profile_service.rb`
- `thread_safe_metrics.rb`
- `token_bucket_limiter.rb`
- `traffic_analysis_service.rb`
- `trending_service.rb`
- `turbocharged_reddit_fetcher.rb`
- `two_factor_auth_service.rb`
- `user_collections_service.rb`
- `user_preference_service.rb`
- `user_service.rb`
- `view_tracker_service.rb`
- `viewing_history_service.rb`
- `websocket_server.rb`

## Consolidation Opportunities

### Category 1: Meme-Related Services (Merge to 3)
**Current:** 8-10 services  
**Target:** 3 services

**Merge Into:**
1. **`meme_service.rb`** - Core meme operations
   - Consolidate: `meme_selection_service.rb`, `simple_meme_selector.rb`
   - Purpose: Fetching, selection, basic operations

2. **`meme_pool_manager.rb`** - Pool & caching
   - Keep existing, already consolidated
   - Purpose: Pool management, refresh workers

3. **`quality_pipeline_service.rb`** - Quality & filtering
   - Consolidate: `quality_control_service.rb`, `crowdsourced_quality_service.rb`
   - Purpose: Quality scoring, filtering

### Category 2: User Services (Merge to 2)
**Current:** 5-6 services  
**Target:** 2 services

**Merge Into:**
1. **`auth_service.rb`** - Authentication
   - Keep as-is (recently refactored)
   - Purpose: Login, signup, sessions

2. **`user_service.rb`** - User data & interactions
   - Consolidate: `personalization_service.rb`, `taste_profile_service.rb`
   - Purpose: Profiles, preferences, interactions

### Category 3: Engagement Services (Merge to 2)
**Current:** 6-8 services  
**Target:** 2 services

**Merge Into:**
1. **`engagement_service.rb`** - Interactions
   - Keep existing, add minor features from others
   - Purpose: Likes, saves, shares, views

2. **`gamification_service.rb`** (NEW)
   - Consolidate: `milestone_service.rb`, `surprise_rewards_service.rb`, `surprise_mechanics_service.rb`, `near_miss_service.rb`
   - Purpose: All gamification features

### Category 4: Analytics Services (Merge to 2)
**Current:** 5-6 services  
**Target:** 2 services

**Merge Into:**
1. **`analytics_service.rb`** - Tracking & metrics
   - Consolidate: `metrics_tracker_service.rb`, `activity_tracker_service.rb`, `session_tracker_service.rb`
   - Purpose: All analytics tracking

2. **`performance_tracker.rb`** - Performance monitoring
   - Keep as-is
   - Purpose: Performance metrics, health checks

### Category 5: Cache & External Services (Merge to 3)
**Current:** 8-10 services  
**Target:** 3 services

**Merge Into:**
1. **`redis_service.rb`** - Redis operations
   - Keep existing (core infrastructure)
   - Purpose: Redis connections, operations

2. **`turbocharged_reddit_fetcher.rb`** - Reddit API
   - Consolidate: `reddit_fetcher_service.rb`, `subreddit_discovery_service.rb`
   - Purpose: All Reddit operations

3. **`media_handling_service.rb`** - Media processing
   - Consolidate: `image_fallback_service.rb`, `placeholder_image_service.rb`, `smart_media_renderer_service.rb`
   - Purpose: All media/image handling

### Category 6: Specialized Services (Keep 5)
**Current:** 6-8 services  
**Target:** 5 services

**Keep:**
1. `trending_service.rb` - Trending algorithm
2. `diversity_engine_service.rb` - Diversity algorithms
3. `contextual_scoring_service.rb` - Scoring logic
4. `seo_service.rb` - SEO optimization
5. `health_check_service.rb` - System health

**Remove/Inline:**
- `collaborative_filtering_service.rb` - Merge into `diversity_engine_service.rb`
- `session_learning_service.rb` - Merge into `analytics_service.rb`
- `humor_optimizer_service.rb` - Remove (over-engineered)
- `retention_service.rb` - Merge into `analytics_service.rb`

### Category 7: Utility Services (Keep 3)
**Current:** 4-5 services  
**Target:** 3 services

**Keep:**
1. `view_tracker_service.rb` - View tracking
2. `leaderboard_service.rb` - Leaderboards
3. `similar_meme_service.rb` - Similar meme suggestions

**Remove:**
- `similar_meme_cache.rb` - Merge into `similar_meme_service.rb`

## Action Plan

### Phase 1: Low-Risk Merges (Monday-Tuesday)
- Merge gamification services
- Merge analytics services
- Merge media services

### Phase 2: Medium-Risk Merges (Wednesday)
- Merge meme selection services
- Merge user/personalization services

### Phase 3: Cleanup (Thursday-Friday)
- Remove merged services
- Update references
- Test functionality

## Expected Results

| Category | Before | After | Reduction |
|----------|--------|-------|-----------|
| Meme Services | 10 | 3 | -70% |
| User Services | 6 | 2 | -67% |
| Engagement | 8 | 2 | -75% |
| Analytics | 6 | 2 | -67% |
| Cache/External | 10 | 3 | -70% |
| Specialized | 8 | 5 | -38% |
| Utility | 5 | 3 | -40% |
| **TOTAL** | **53** | **20** | **-62%** |

> Note: Target was 30, but analysis shows we can get to 20 safely!

---
**Last Updated:** July 26, 2026
