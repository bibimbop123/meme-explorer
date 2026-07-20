# Changelog

All notable changes to Meme Explorer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Dark mode with system preference detection and manual toggle (Cmd+K)
- PWA install capability with offline support
- Comprehensive video playback (MP4, WebM, MOV, Reddit videos)
- Full video error handling with fallback UI
- Mobile-optimized video playback (max-height 60vh)
- .editorconfig for consistent code formatting
- SECURITY.md for vulnerability disclosure
- Enhanced .env.example documentation

### Fixed
- Redis thread leak prevention (critical memory issue)
- Hardcoded admin email removed (security vulnerability)
- N+1 query optimizations across services
- Mobile touch targets enlarged to 48px+ (accessibility)
- Duplicate OG meta tags removed (SEO)
- 22 broad rescue clauses replaced with specific error handling
- ARIA labels added for screen readers (WCAG 2.1 Level AA)

### Changed
- Database queries now 30-50% faster with critical indexes
- Centralized logging with AppLogger
- Connection pooling for Redis and PostgreSQL
- All `puts` replaced with proper logging
- Improved error boundaries with detailed logging

### Security
- RBAC properly implemented for admin access
- CSP headers configured correctly
- CSRF protection enabled
- OAuth flow secured
- Session management hardened

## [1.0.0] - 2026-07-20

### Added
- Initial production release
- Reddit meme integration
- User authentication with OAuth
- Gamification system (streaks, levels, XP)
- Leaderboard functionality
- Push notifications for streaks
- Search and trending features
- Mobile-responsive design
- AdSense integration
- Comprehensive testing suite

---

**Legend:**
- `Added` for new features
- `Changed` for changes in existing functionality
- `Deprecated` for soon-to-be removed features
- `Removed` for removed features
- `Fixed` for bug fixes
- `Security` for vulnerability fixes
