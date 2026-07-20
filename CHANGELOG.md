# Changelog

All notable changes to Meme Explorer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive code audit completed (Weeks 1-5)
- Integration tests for critical user flows
- Architecture diagrams and documentation
- RBAC authorization system
- Redis connection pooling
- Performance monitoring middleware

### Fixed
- RedisService thread leak (memory exhaustion prevention)
- Duplicate OG meta tags (SEO improvement)
- Invalid HTML structure (W3C validation)
- ARIA accessibility labels (WCAG 2.1 Level AA)
- CSP compliance (extracted inline scripts)
- Database performance (7 new indexes)

### Changed
- Centralized logging using AppLogger
- Improved error handling with boundaries
- Enhanced test coverage with RSpec improvements
- Updated OpenAPI 3.0 specification

### Security
- Fixed hardcoded admin email (proper RBAC)
- Thread-safe Redis operations
- Enhanced input validation
- Improved CSRF protection

## [2.5.0] - 2026-07-15

### Added
- Random algorithm improvements
- Diversity engine refactoring
- Mobile UX enhancements

### Fixed
- Reddit OAuth session handling
- Pool categorization bugs
- Empty Redis pools issue

## [2.0.0] - 2026-06-01

### Added
- User collections feature
- Quality scoring system
- Trending algorithm improvements

### Changed
- Migrated from SQLite to PostgreSQL
- Redis architecture improvements

## [1.0.0] - 2026-01-01

### Added
- Initial release
- Basic meme discovery
- Reddit integration
- User authentication
