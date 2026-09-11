# 📚 Meme Explorer API Documentation

**Version:** 2.0 (P2)  
**Base URL:** `https://your-app.com` or `http://localhost:8080`  
**Date:** May 11, 2026

---

## 🌐 Overview

Meme Explorer provides a RESTful API for meme discovery, user management, and analytics. All endpoints return JSON unless otherwise specified.

## 🔐 Authentication

### Session-Based Authentication
Most endpoints use cookie-based session authentication. After login, a session cookie is automatically set.

```ruby
# Login required for protected routes
# Session cookie: rack.session
```

### Admin Authentication
Admin routes require:
1. Valid session cookie
2. User role: `admin` or `super_admin`

---

## 📋 Response Format

### Success Response
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "timestamp": "2026-05-11T12:00:00Z",
    "version": "2.0"
  }
}
```

### Error Response
```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE",
  "status": 400
}
```

---

## 🎯 Endpoints

### Public Routes

#### GET /
**Description:** Home page (HTML)  
**Authentication:** None  
**Response:** HTML page with featured memes

---

#### GET /random
**Description:** Random meme discovery page (HTML)  
**Authentication:** Optional (tracks user if logged in)  
**Response:** HTML page with random meme

---

#### GET /random.json
**Description:** Get a random meme (JSON API)  
**Authentication:** Optional  
**Parameters:**
- `category` (string, optional) - Filter by category
- `exclude` (array, optional) - Exclude meme IDs

**Response:**
```json
{
  "id": 123,
  "title": "Distracted Boyfriend",
  "url": "https://example.com/meme.jpg",
  "category": "funny",
  "reddit_url": "https://reddit.com/r/memes/...",
  "views": 1543,
  "likes": 234,
  "source": "reddit"
}
```

**Example:**
```bash
curl https://your-app.com/random.json?category=funny
```

---

#### GET /trending
**Description:** Trending memes page  
**Authentication:** Optional  
**Query Parameters:**
- `period` (string) - Time period: `day`, `week`, `month`, `all` (default: `day`)
- `page` (integer) - Page number (default: 1)
- `limit` (integer) - Items per page (default: 20, max: 100)

**Response:** HTML page with trending memes

---

#### GET /trending.json
**Description:** Trending memes API  
**Authentication:** Optional  
**Parameters:** Same as `/trending`

**Response:**
```json
{
  "memes": [
    {
      "id": 456,
      "title": "Success Kid",
      "url": "https://example.com/meme2.jpg",
      "trending_score": 87.5,
      "views_24h": 1250,
      "likes_24h": 145,
      "rank": 1
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 100,
    "per_page": 20
  }
}
```

---

#### GET /search
**Description:** Search memes  
**Authentication:** Optional  
**Query Parameters:**
- `q` (string, required) - Search query
- `category` (string, optional) - Filter by category
- `page` (integer) - Page number (default: 1)

**Response:** HTML page with search results

---

#### GET /search.json
**Description:** Search memes API  
**Authentication:** Optional  
**Parameters:** Same as `/search`

**Response:**
```json
{
  "results": [
    {
      "id": 789,
      "title": "Mocking SpongeBob",
      "url": "https://example.com/meme3.jpg",
      "category": "reaction",
      "relevance_score": 0.95
    }
  ],
  "query": "spongebob",
  "total_results": 42
}
```

---

#### GET /leaderboard
**Description:** User leaderboard  
**Authentication:** Optional  
**Query Parameters:**
- `period` (string) - `daily`, `weekly`, `monthly`, `all_time` (default: `all_time`)
- `limit` (integer) - Number of users (default: 50)

**Response:** HTML page with leaderboard

---

#### GET /leaderboard.json
**Description:** Leaderboard API  
**Authentication:** Optional  
**Parameters:** Same as `/leaderboard`

**Response:**
```json
{
  "leaderboard": [
    {
      "rank": 1,
      "username": "meme_master",
      "score": 15430,
      "badges": ["🏆", "⚡", "🔥"],
      "streak": 45,
      "level": 12
    }
  ],
  "updated_at": "2026-05-11T11:00:00Z"
}
```

---

#### GET /profile/:username
**Description:** Public user profile  
**Authentication:** Optional  
**Response:** HTML page with user stats, saved memes, achievements

---

### Authentication Routes

#### POST /auth/signup
**Description:** Create new user account  
**Authentication:** None  
**Content-Type:** `application/x-www-form-urlencoded` or `application/json`

**Parameters:**
```json
{
  "email": "user@example.com",
  "username": "cool_user",
  "password": "SecurePass123!"
}
```

**Validation Rules:**
- Email: Valid format, unique
- Username: 3-20 chars, alphanumeric + underscore, unique
- Password: 8+ chars, includes uppercase, lowercase, number

**Success Response (200):**
```json
{
  "success": true,
  "message": "Account created successfully",
  "user": {
    "id": 123,
    "username": "cool_user",
    "email": "user@example.com"
  }
}
```

**Error Response (422):**
```json
{
  "success": false,
  "error": "Email already registered",
  "field": "email"
}
```

---

#### POST /auth/login
**Description:** Login to existing account  
**Authentication:** None  
**Content-Type:** `application/x-www-form-urlencoded` or `application/json`

**Parameters:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Login successful",
  "user": {
    "id": 123,
    "username": "cool_user",
    "email": "user@example.com"
  }
}
```

**Error Response (401):**
```json
{
  "success": false,
  "error": "Invalid email or password"
}
```

---

#### POST /auth/logout
**Description:** Logout current user  
**Authentication:** Required  

**Success Response (200):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

### Protected Routes (Authentication Required)

#### GET /profile
**Description:** Current user's profile  
**Authentication:** Required  
**Response:** HTML page with full profile access

---

#### POST /memes/:id/save
**Description:** Save/unsave a meme to favorites  
**Authentication:** Required  
**Parameters:** None (meme ID in URL)

**Success Response (200):**
```json
{
  "success": true,
  "saved": true,
  "message": "Meme saved to favorites"
}
```

---

#### POST /memes/:id/react
**Description:** Add reaction to meme  
**Authentication:** Optional (tracks if logged in)  
**Content-Type:** `application/json`

**Parameters:**
```json
{
  "type": "like"  // Options: like, laugh, fire
}
```

**Success Response (200):**
```json
{
  "success": true,
  "reaction": "like",
  "total_reactions": 456,
  "points_earned": 10
}
```

---

#### POST /memes/:id/view
**Description:** Track meme view (automatic)  
**Authentication:** Optional  
**Response:** No response (fire-and-forget)

---

### Admin Routes

#### GET /admin
**Description:** Admin dashboard  
**Authentication:** Admin required  
**Response:** HTML page with admin controls

---

#### GET /admin/ab-testing
**Description:** A/B testing management interface  
**Authentication:** Admin required  
**Response:** HTML page with experiment list

---

#### GET /admin/ab-testing/experiments.json
**Description:** Get all A/B experiments  
**Authentication:** Admin required  

**Response:**
```json
{
  "experiments": [
    {
      "name": "button_color",
      "description": "Test CTA button colors",
      "active": true,
      "variants": {
        "control": 0.5,
        "red": 0.25,
        "blue": 0.25
      },
      "created_at": "2026-05-01T10:00:00Z",
      "conversions": {
        "control": 145,
        "red": 167,
        "blue": 134
      },
      "samples": {
        "control": 1000,
        "red": 950,
        "blue": 980
      }
    }
  ]
}
```

---

#### POST /admin/ab-testing/experiments
**Description:** Create new A/B experiment  
**Authentication:** Admin required  
**Content-Type:** `application/json`

**Parameters:**
```json
{
  "name": "homepage_layout",
  "description": "Test different homepage layouts",
  "variants": {
    "control": 0.5,
    "grid": 0.5
  },
  "active": true
}
```

**Success Response (201):**
```json
{
  "success": true,
  "experiment": {
    "name": "homepage_layout",
    "active": true,
    "created_at": "2026-05-11T12:00:00Z"
  }
}
```

---

#### GET /admin/ab-testing/experiments/:name/stats.json
**Description:** Get experiment statistics  
**Authentication:** Admin required  

**Response:**
```json
{
  "experiment": "button_color",
  "stats": {
    "control": {
      "samples": 1000,
      "conversions": 145,
      "conversion_rate": 0.145,
      "confidence": 0.95
    },
    "red": {
      "samples": 950,
      "conversions": 167,
      "conversion_rate": 0.176,
      "confidence": 0.98,
      "lift": 21.4,
      "is_winner": true
    }
  },
  "winner": "red",
  "significant": true
}
```

---

#### PUT /admin/ab-testing/experiments/:name
**Description:** Update experiment  
**Authentication:** Admin required  

**Parameters:**
```json
{
  "active": false  // Deactivate experiment
}
```

---

#### GET /metrics
**Description:** Performance metrics dashboard  
**Authentication:** Admin required  
**Response:** HTML page with system metrics

---

#### GET /metrics.json
**Description:** Performance metrics API  
**Authentication:** Admin required  

**Response:**
```json
{
  "performance": {
    "avg_response_time_ms": 156,
    "p95_response_time_ms": 340,
    "p99_response_time_ms": 580,
    "requests_per_minute": 245
  },
  "cache": {
    "hit_rate": 0.84,
    "size_mb": 145,
    "evictions_per_hour": 23
  },
  "database": {
    "active_connections": 12,
    "slow_queries_24h": 3,
    "size_mb": 2048
  },
  "sidekiq": {
    "processed": 12456,
    "failed": 5,
    "busy": 2,
    "enqueued": 8
  }
}
```

---

#### GET /sidekiq
**Description:** Sidekiq monitoring dashboard  
**Authentication:** Admin required  
**Response:** Sidekiq Web UI (HTML)

---

#### GET /health
**Description:** Health check endpoint  
**Authentication:** None  
**Response:**
```json
{
  "status": "ok",
  "timestamp": "2026-05-11T12:00:00Z",
  "services": {
    "database": "ok",
    "redis": "ok",
    "sidekiq": "ok"
  },
  "sidekiq": {
    "processed": 12456,
    "failed": 5,
    "enqueued": 8
  },
  "cache_age_seconds": 120
}
```

---

## 🎮 A/B Testing Integration

### Client-Side Usage

```javascript
// Get assigned variant
fetch('/api/variant?experiment=button_color')
  .then(r => r.json())
  .then(data => {
    const variant = data.variant; // 'control', 'red', or 'blue'
    applyVariant(variant);
  });

// Track conversion
function trackConversion(experiment, variant) {
  fetch('/api/convert', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ experiment, variant })
  });
}
```

---

## 📊 Rate Limiting

**Default Limits:**
- Anonymous: 100 requests/minute
- Authenticated: 300 requests/minute
- Admin: 1000 requests/minute

**Rate Limit Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1683820800
```

**Rate Limit Response (429):**
```json
{
  "error": "Rate limit exceeded",
  "retry_after": 60
}
```

---

## 🐛 Error Codes

| Code | Status | Description |
|------|--------|-------------|
| `VALIDATION_ERROR` | 422 | Invalid input parameters |
| `UNAUTHORIZED` | 401 | Authentication required |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `RATE_LIMITED` | 429 | Too many requests |
| `SERVER_ERROR` | 500 | Internal server error |

---

## 🔧 Response Headers

All responses include:
```
X-Request-ID: uuid-v4
X-Request-Duration: 156ms
Cache-Control: public, max-age=300
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
```

---

## 📝 Examples

### cURL Examples

```bash
# Get random meme
curl https://your-app.com/random.json

# Search memes
curl "https://your-app.com/search.json?q=funny&category=reaction"

# Login
curl -X POST https://your-app.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"SecurePass123!"}'

# Create A/B experiment (admin)
curl -X POST https://your-app.com/admin/ab-testing/experiments \
  -H "Content-Type: application/json" \
  -H "Cookie: rack.session=..." \
  -d '{"name":"test","variants":{"control":0.5,"variant":0.5},"active":true}'
```

### JavaScript Examples

```javascript
// Fetch random meme
async function getRandomMeme() {
  const response = await fetch('/random.json');
  const meme = await response.json();
  return meme;
}

// Save meme
async function saveMeme(memeId) {
  const response = await fetch(`/memes/${memeId}/save`, {
    method: 'POST',
    credentials: 'include'
  });
  return await response.json();
}

// React to meme
async function reactToMeme(memeId, reactionType) {
  const response = await fetch(`/memes/${memeId}/react`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify({ type: reactionType })
  });
  return await response.json();
}
```

---

## 🚀 Versioning

API version is included in response metadata. Breaking changes will increment major version.

**Current Version:** 2.0 (P2 Release)

---

## 📞 Support

- **Issues:** GitHub Issues
- **Documentation:** `/docs`
- **Email:** api@meme-explorer.com

---

**Last Updated:** May 11, 2026  
**Maintained By:** Discovery Partners Institute
