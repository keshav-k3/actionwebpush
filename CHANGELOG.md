# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial preparation for public release
- Comprehensive test suite improvements
- Documentation enhancements

### Fixed
- Thread safety improvements
- Rate limiting optimizations

## [0.1.0] - 2025-09-22

### Added
- Initial release of ActionWebPush gem
- ActionMailer-like interface for Web Push notifications
- Thread pool management with concurrent-ruby
- Rate limiting with Redis and memory stores
- Multiple delivery methods (WebPush, Test)
- Rails engine integration with generators and migrations
- ActiveRecord model for subscription management
- VAPID key management and configuration
- Background job integration with ActiveJob
- Comprehensive error handling and retry logic
- Sentry integration for error reporting
- Analytics and metrics collection
- Status broadcasting via ActionCable
- Tenant configuration support
- Campfire migration support

### Security
- VAPID key validation and management
- Rate limiting to prevent abuse
- Secure subscription handling
- Input validation and sanitization

### Performance
- Thread pool optimization for concurrent delivery
- Connection pooling with Net::HTTP::Persistent
- Efficient batch delivery mechanisms
- Memory and Redis-based rate limiting stores

### Documentation
- Basic README with usage examples
- Generator-based installation process
- Configuration examples and best practices

[Unreleased]: https://github.com/keshav-k3/actionwebpush/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/keshav-k3/actionwebpush/releases/tag/v0.1.0