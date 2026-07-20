# Meme Explorer Architecture Diagram

## High-Level System Architecture

```mermaid
graph TB
    User[👤 User Browser]
    
    subgraph "Frontend Layer"
        Layout[Layout.erb]
        Random[Random Meme Page]
        Trending[Trending Page]
        Profile[Profile Page]
        JS[JavaScript Modules]
    end
    
    subgraph "Application Layer - Sinatra"
        App[app.rb]
        
        subgraph "Route Handlers"
            RandomRoutes[/random]
            TrendingRoutes[/trending]
            ProfileRoutes[/profile]
            APIRoutes[/api/*]
            AuthRoutes[/auth/*]
        end
        
        subgraph "Middleware Stack"
            Security[Security Headers]
            CSRF[CSRF Protection]
            Session[Session Management]
            RateLimit[Rate Limiting]
            Perf[Performance Monitor]
        end
    end
    
    subgraph "Service Layer"
        MemeService[MemeService]
        DiversityEngine[DiversityEngineService]
        RedditFetcher[RedditFetcherService]
        TurboFetcher[TurbochargedRedditFetcher]
        CacheService[CacheService]
        ViewHistory[ViewingHistoryService]
        TasteProfile[TasteProfileService]
        AuthService[AuthService]
    end
    
    subgraph "Background Workers - Sidekiq"
        PoolRefresh[MemePoolRefreshWorker]
        CachePreload[CachePreloadWorker]
        Cleanup[DatabaseCleanupWorker]
        Health[HealthCheckWorker]
    end
    
    subgraph "Data Layer"
        DB[(PostgreSQL)]
        Redis[(Redis)]
        
        subgraph "Redis Keys"
            MemePool[Meme Pool]
            ViewedMemes[Viewed History]
            Cache[Response Cache]
            Sessions[User Sessions]
        end
    end
    
    subgraph "External APIs"
        RedditAPI[Reddit API]
        ImgurAPI[Imgur API]
    end
    
    User -->|HTTP Request| Layout
    Layout --> Random
    Layout --> Trending
    Layout --> Profile
    
    Random --> RandomRoutes
    Trending --> TrendingRoutes
    Profile --> ProfileRoutes
    
    RandomRoutes --> Middleware Stack
    TrendingRoutes --> Middleware Stack
    ProfileRoutes --> Middleware Stack
    APIRoutes --> Middleware Stack
    
    Security --> App
    CSRF --> Security
    Session --> CSRF
    RateLimit --> Session
    Perf --> RateLimit
    
    App --> MemeService
    App --> DiversityEngine
    App --> AuthService
    
    MemeService --> RedditFetcher
    MemeService --> CacheService
    DiversityEngine --> ViewHistory
    DiversityEngine --> TasteProfile
    
    RedditFetcher --> TurboFetcher
    TurboFetcher -->|Fetch Posts| RedditAPI
    TurboFetcher -->|Parse Media| ImgurAPI
    
    MemeService -->|Read/Write| DB
    CacheService -->|Get/Set| Redis
    ViewHistory -->|Track| Redis
    
    PoolRefresh -->|Populate| Redis
    PoolRefresh -->|Fetch| RedditFetcher
    CachePreload -->|Warm| Cache
    Cleanup -->|Prune| DB
    Health -->|Monitor| Redis
    
    style User fill:#e1f5ff
    style DB fill:#f9f
    style Redis fill:#f66
    style RedditAPI fill:#ff6a00
    style App fill:#90EE90
```

## Data Flow Diagrams

### Random Meme Request Flow

```mermaid
sequenceDiagram
    participant U as User
    participant S as Sinatra App
    participant D as DiversityEngine
    participant V as ViewHistory
    participant R as Redis (Pool)
    participant M as MemeService
    participant DB as PostgreSQL
    
    U->>S: GET /random
    S->>D: get_random_meme(user_id)
    D->>V: get_viewed_meme_ids(user_id)
    V->>R: SMEMBERS viewing_history:user:123
    R-->>V: [id1, id2, id3...]
    V-->>D: [viewed_ids]
    
    D->>R: LRANGE meme_pool:tier_1 0 99
    R-->>D: [meme_candidates]
    
    D->>D: filter_viewed_memes(candidates, viewed_ids)
    D->>D: apply_diversity_scoring()
    D->>D: select_random_weighted()
    
    D->>M: get_full_meme_data(meme_id)
    M->>DB: SELECT * FROM memes WHERE id = ?
    DB-->>M: meme_data
    M-->>D: meme_data
    
    D->>V: track_view(user_id, meme_id)
    V->>R: SADD viewing_history:user:123 meme_id
    
    D-->>S: meme_data
    S-->>U: render random.erb with meme
```

### Background Pool Refresh Flow

```mermaid
sequenceDiagram
    participant W as MemePoolRefreshWorker
    participant R as RedditFetcher
    participant API as Reddit API
    participant DB as PostgreSQL
    participant Redis as Redis Pool
    
    W->>W: scheduled_run()
    W->>R: fetch_fresh_memes(subreddits)
    
    loop For each subreddit
        R->>API: GET /r/subreddit/hot.json
        API-->>R: JSON response
        R->>R: parse_posts()
        R->>R: extract_media_urls()
        R->>R: filter_quality()
    end
    
    R-->>W: [fresh_memes]
    
    W->>DB: INSERT INTO memes ... ON CONFLICT UPDATE
    DB-->>W: inserted_ids
    
    W->>W: categorize_by_tier()
    
    W->>Redis: DEL meme_pool:tier_1
    W->>Redis: RPUSH meme_pool:tier_1 ...high_quality_ids
    W->>Redis: EXPIRE meme_pool:tier_1 3600
    
    W->>Redis: DEL meme_pool:tier_2
    W->>Redis: RPUSH meme_pool:tier_2 ...good_ids
    W->>Redis: EXPIRE meme_pool:tier_2 7200
    
    W->>W: log_pool_stats()
```

## Component Responsibilities

### Frontend Components
- **layout.erb**: Base template, nav, meta tags, AdSense
- **random.erb**: Random meme discovery interface
- **meme-interactions.js**: Like, share, save functionality
- **meme-navigation.js**: Next/previous meme controls

### Service Components
- **MemeService**: Core meme CRUD operations
- **DiversityEngineService**: Anti-repetition algorithm
- **RedditFetcherService**: Reddit API integration
- **CacheService**: Redis caching abstraction
- **ViewingHistoryService**: User view tracking

### Background Workers
- **MemePoolRefreshWorker**: Maintains fresh meme pool
- **CachePreloadWorker**: Warms response caches
- **DatabaseCleanupWorker**: Prunes old data
- **HealthCheckWorker**: System health monitoring

## Technology Stack

- **Web Framework**: Sinatra 3.x
- **Database**: PostgreSQL 14+
- **Cache/Queue**: Redis 7+
- **Background Jobs**: Sidekiq
- **Frontend**: Vanilla JS (ES6+), CSS3
- **Testing**: RSpec, Rack::Test
- **Deployment**: Render.com
