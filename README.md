# ActionWebPush

[![Gem Version](https://badge.fury.io/rb/actionwebpush.svg)](https://badge.fury.io/rb/actionwebpush)
[![Build Status](https://github.com/keshav-k3/actionwebpush/workflows/CI/badge.svg)](https://github.com/keshav-k3/actionwebpush/actions)

Rails integration for Web Push notifications with ActionMailer-like interface.

ActionWebPush provides a comprehensive solution for sending Web Push notifications in Rails applications. It offers an ActionMailer-inspired API, background job integration, rate limiting, and sophisticated error handling.

Extracted from the [Campfire](https://github.com/keshav-k3/once-campfire) project and designed for production use.

> **🎉 Version 0.1.0** - Initial stable release with full feature set including ActionMailer-like interface, background jobs, rate limiting, and comprehensive error handling.

## Features

- 🚀 **ActionMailer-like Interface** - Familiar Rails patterns for sending notifications
- 🔧 **Easy Configuration** - Simple setup with VAPID keys
- 🎯 **Background Jobs** - ActiveJob integration for async delivery
- 📊 **Rate Limiting** - Built-in protection against abuse
- 🔄 **Thread Pool Management** - Efficient concurrent delivery
- 📈 **Instrumentation** - ActiveSupport::Notifications integration
- 🛡️ **Error Handling** - Comprehensive error management with cleanup
- 🗄️ **ActiveRecord Integration** - Models and migrations included
- 🧪 **Test Helpers** - Testing utilities for development
- 📝 **Detailed Logging** - Structured logging for debugging

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Basic Notifications](#basic-notifications)
  - [ActionMailer-like Senders](#actionmailer-like-senders)
  - [Background Delivery](#background-delivery)
  - [Batch Operations](#batch-operations)
- [Subscription Management](#subscription-management)
- [Rate Limiting](#rate-limiting)
- [Error Handling](#error-handling)
- [Monitoring](#monitoring)
- [Testing](#testing)
- [Configuration Reference](#configuration-reference)
- [API Documentation](#api-documentation)
- [Contributing](#contributing)
- [Requirements](#requirements)
- [License](#license)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'actionwebpush'
```

And then execute:

```bash
bundle install
```

Run the installation generator:

```bash
rails generate action_web_push:install
```

This will:
- Create configuration file `config/initializers/action_web_push.rb`
- Generate database migrations for subscription management
- Create VAPID keys if not present

Run the migrations:

```bash
rails db:migrate
```

## Configuration

Configure ActionWebPush in `config/initializers/action_web_push.rb`:

```ruby
ActionWebPush.configure do |config|
  # Required: VAPID keys for push service authentication
  config.vapid_public_key = ENV['VAPID_PUBLIC_KEY']
  config.vapid_private_key = ENV['VAPID_PRIVATE_KEY']
  config.vapid_subject = 'mailto:support@yourapp.com'

  # Optional: Performance tuning
  config.pool_size = 10           # Thread pool size
  config.queue_size = 100         # Queue size
  config.connection_pool_size = 5 # HTTP connection pool
  config.batch_size = 100         # Default batch size

  # Optional: Delivery method (default: :web_push)
  config.delivery_method = :web_push
end
```

### Generate VAPID Keys

If you don't have VAPID keys, generate them:

```bash
rails generate action_web_push:vapid_keys
```

This creates a `.env` file with your keys. Add them to your production environment:

```bash
# .env
VAPID_PUBLIC_KEY=your_generated_public_key
VAPID_PRIVATE_KEY=your_generated_private_key
```

## Quick Start

### 1. Set up User Associations

```ruby
class User < ApplicationRecord
  has_many :push_subscriptions,
           class_name: "ActionWebPush::Subscription",
           foreign_key: :user_id,
           dependent: :destroy
end
```

### 2. Create Notification Senders

```ruby
class UserNotifications < ActionWebPush::Base
  def welcome(user)
    web_push(
      title: "Welcome to MyApp!",
      body: "Thanks for joining us",
      to: user.push_subscriptions,
      data: { type: 'welcome', url: '/dashboard' }
    )
  end

  def new_message(user, message)
    web_push(
      title: "New Message",
      body: message.preview,
      to: user.push_subscriptions,
      data: {
        type: 'message',
        message_id: message.id,
        url: message_path(message)
      }
    )
  end
end
```

### 3. Send Notifications

```ruby
# Deliver immediately
UserNotifications.welcome(user).deliver_now

# Deliver via background job (recommended)
UserNotifications.new_message(user, message).deliver_later

# Batch delivery to multiple users
users = User.active.includes(:push_subscriptions)
users.each do |user|
  UserNotifications.welcome(user).deliver_later
end
```

## Usage

### Basic Notifications

Create and send notifications directly:

```ruby
notification = ActionWebPush::Notification.new(
  title: "System Alert",
  body: "Maintenance scheduled for tonight",
  endpoint: subscription.endpoint,
  p256dh_key: subscription.p256dh_key,
  auth_key: subscription.auth_key,
  data: { type: 'maintenance', scheduled_at: '2024-01-01T02:00:00Z' },
  icon: '/system-icon.png',
  badge: '/badge.png',
  urgency: 'high'
)

# Synchronous delivery
notification.deliver_now

# Asynchronous delivery
notification.deliver_later
```

### ActionMailer-like Senders

Create notification classes that inherit from `ActionWebPush::Base`:

```ruby
class SystemNotifications < ActionWebPush::Base
  default data: { app: 'MyApp' }

  def maintenance_notice(users, maintenance)
    web_push(
      title: "Scheduled Maintenance",
      body: "Service will be unavailable #{maintenance.start_time}",
      to: users.flat_map(&:push_subscriptions),
      data: {
        type: 'maintenance',
        start_time: maintenance.start_time.iso8601,
        duration: maintenance.duration_minutes,
        url: maintenance_path(maintenance)
      },
      urgency: 'high'
    )
  end

  def feature_announcement(user, feature)
    web_push(
      title: "New Feature Available!",
      body: feature.description,
      to: user.push_subscriptions,
      data: {
        type: 'feature',
        feature_id: feature.id,
        url: feature_path(feature)
      },
      icon: feature.icon_url
    )
  end
end
```

### Background Delivery

Leverage ActiveJob for asynchronous delivery:

```ruby
# Basic background delivery
notification.deliver_later

# With scheduling
notification.deliver_later(wait: 1.hour)
notification.deliver_later(wait_until: Date.tomorrow.noon)

# Custom queue and priority
notification.deliver_later(
  queue: :critical_notifications,
  priority: 10
)

# ActionMailer-like senders
UserNotifications.welcome(user).deliver_later(wait: 5.minutes)
```

### Batch Operations

Efficiently send to multiple recipients:

```ruby
# Using BatchDelivery for performance
notifications = users.map do |user|
  user.push_subscriptions.map do |subscription|
    subscription.build_notification(
      title: "Weekly Update",
      body: "Check out this week's highlights",
      data: { type: 'weekly_update' }
    )
  end
end.flatten

ActionWebPush::BatchDelivery.deliver(notifications)

# With custom batch size
ActionWebPush::BatchDelivery.new(notifications, batch_size: 50).deliver_all

# Using ActionMailer-like pattern for batches
users.find_each do |user|
  WeeklyNotifications.digest(user).deliver_later
end
```

## Subscription Management

ActionWebPush includes ActiveRecord models for managing subscriptions:

```ruby
# Create subscription from frontend
subscription = ActionWebPush::Subscription.create!(
  endpoint: params[:endpoint],
  p256dh_key: params[:keys][:p256dh],
  auth_key: params[:keys][:auth],
  user: current_user,
  user_agent: request.user_agent
)

# Find subscriptions
user_subscriptions = ActionWebPush::Subscription.for_user(current_user)
active_subscriptions = ActionWebPush::Subscription.active
mobile_subscriptions = ActionWebPush::Subscription.by_user_agent('Mobile')

# Build notifications from subscriptions
notification = subscription.build_notification(
  title: "Hello",
  body: "World",
  data: { url: '/dashboard' }
)

# Cleanup expired subscriptions
ActionWebPush::Subscription.expired.destroy_all
```

### Frontend Integration

Example JavaScript for subscription management:

```javascript
// Register service worker and get subscription
navigator.serviceWorker.register('/sw.js').then(registration => {
  return registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: '<%= ActionWebPush.config.vapid_public_key %>'
  });
}).then(subscription => {
  // Send subscription to your Rails app
  fetch('/push_subscriptions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: JSON.stringify({
      subscription: {
        endpoint: subscription.endpoint,
        keys: {
          p256dh: arrayBufferToBase64(subscription.getKey('p256dh')),
          auth: arrayBufferToBase64(subscription.getKey('auth'))
        }
      }
    })
  });
});
```

## Rate Limiting

Protect your application from abuse with built-in rate limiting:

```ruby
# Configure rate limits
rate_limiter = ActionWebPush::RateLimiter.new(
  limits: {
    endpoint: { max_requests: 100, window: 3600 },    # 100/hour per endpoint
    user: { max_requests: 1000, window: 3600 },       # 1000/hour per user
    subscription: { max_requests: 50, window: 3600 }  # 50/hour per subscription
  }
)

# Check before sending
begin
  rate_limiter.check_rate_limit!(:user, current_user.id)
  notification.deliver_now
rescue ActionWebPush::RateLimitExceeded => e
  render json: { error: "Rate limit exceeded" }, status: 429
end

# Get rate limit information
info = rate_limiter.rate_limit_info(:user, current_user.id)
# => { limit: 1000, remaining: 950, window: 3600, reset_at: Time }
```

## Error Handling

ActionWebPush provides comprehensive error handling:

```ruby
begin
  notification.deliver_now
rescue ActionWebPush::ExpiredSubscriptionError => e
  # Subscription is no longer valid - cleanup
  subscription.destroy
rescue ActionWebPush::RateLimitExceeded => e
  # Rate limit hit - retry later
  notification.deliver_later(wait: 1.hour)
rescue ActionWebPush::DeliveryError => e
  # Delivery failed - log and handle
  Rails.logger.error "Push notification failed: #{e.message}"
rescue ActionWebPush::ConfigurationError => e
  # Configuration issue - check VAPID keys
  Rails.logger.error "Push configuration error: #{e.message}"
end
```

All errors include detailed context and are automatically instrumented for monitoring.

## Monitoring

ActionWebPush integrates with ActiveSupport::Notifications for comprehensive monitoring:

```ruby
# Subscribe to all ActionWebPush events
ActiveSupport::Notifications.subscribe(/^action_web_push\./) do |name, start, finish, id, payload|
  duration = (finish - start) * 1000
  Rails.logger.info "#{name}: #{duration.round(2)}ms #{payload.inspect}"
end

# Monitor specific events
ActiveSupport::Notifications.subscribe("action_web_push.notification_delivery") do |name, start, finish, id, payload|
  if payload[:success]
    Metrics.increment('push.delivery.success')
  else
    Metrics.increment('push.delivery.failure', tags: { code: payload[:response_code] })
  end
end

# Track rate limiting
ActiveSupport::Notifications.subscribe("action_web_push.rate_limit_exceeded") do |name, start, finish, id, payload|
  Metrics.increment('push.rate_limit_exceeded',
    tags: { resource_type: payload[:resource_type] })
end

# Pool overflow monitoring
ActiveSupport::Notifications.subscribe("action_web_push.pool_overflow") do |name, start, finish, id, payload|
  Metrics.gauge('push.pool.overflow_rate', payload[:overflow_rate])
end
```

### Available Events

- `action_web_push.notification_delivery` - Individual notification delivery
- `action_web_push.subscription_expired` - Subscription marked as expired
- `action_web_push.rate_limit_exceeded` - Rate limit threshold hit
- `action_web_push.pool_overflow` - Thread pool queue overflow
- `action_web_push.notification_delivery_failed` - Delivery failure
- `action_web_push.configuration_error` - Configuration validation error
- `action_web_push.unexpected_error` - Unexpected error occurred

## Testing

ActionWebPush includes comprehensive test helpers:

```ruby
# Test mode (add to test environment)
ActionWebPush.configure do |config|
  config.delivery_method = :test
end

# In your tests
require 'action_web_push/test_helper'

class NotificationTest < ActiveSupport::TestCase
  include ActionWebPush::TestHelper

  test "sends welcome notification" do
    user = users(:alice)

    assert_enqueued_push_deliveries 1 do
      UserNotifications.welcome(user).deliver_later
    end

    assert_push_delivered_to user.push_subscriptions.first do |notification|
      assert_equal "Welcome!", notification[:title]
      assert_equal "welcome", notification[:data][:type]
    end
  end

  test "handles expired subscriptions" do
    expired_subscription = push_subscriptions(:expired)

    assert_raises ActionWebPush::ExpiredSubscriptionError do
      notification = expired_subscription.build_notification(
        title: "Test", body: "Test"
      )
      notification.deliver_now
    end
  end
end
```

### Test Helpers

- `assert_push_delivered_to(subscription, &block)` - Assert notification delivered
- `assert_enqueued_push_deliveries(count, &block)` - Assert jobs enqueued
- `assert_no_push_deliveries(&block)` - Assert no deliveries
- `clear_push_deliveries` - Clear test delivery queue

## Configuration Reference

Complete configuration options:

```ruby
ActionWebPush.configure do |config|
  # VAPID Configuration (Required)
  config.vapid_subject = "mailto:admin@example.com"  # or "https://example.com"
  config.vapid_public_key = "your_public_key"
  config.vapid_private_key = "your_private_key"

  # Delivery Method
  config.delivery_method = :web_push  # :web_push, :test, or custom

  # Thread Pool Configuration
  config.pool_size = 10               # Max concurrent deliveries
  config.queue_size = 100             # Queue size before overflow
  config.connection_pool_size = 5     # HTTP connection pool size

  # Batch Processing
  config.batch_size = 100             # Default batch size

  # Rate Limiting (optional - uses sensible defaults)
  config.rate_limits = {
    endpoint: { max_requests: 100, window: 3600 },
    user: { max_requests: 1000, window: 3600 },
    global: { max_requests: 10000, window: 3600 },
    subscription: { max_requests: 50, window: 3600 }
  }

  # Logging
  config.logger = Rails.logger        # Custom logger
end
```

## API Documentation

For detailed API documentation, see [API.md](API.md).

## Requirements

- Ruby 2.6+
- Rails 6.0+
- Redis (optional, for rate limiting)

## Dependencies

- `web-push` - Web Push protocol implementation
- `concurrent-ruby` - Thread pool management
- `activejob` - Background job processing
- `activerecord` - Database integration

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rake test`)
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create a Pull Request

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Roadmap

As this is the initial 0.1.0 release, we're excited to hear from the community! Planned future enhancements include:

- Additional delivery method adapters
- Enhanced monitoring and metrics
- Performance optimizations
- Extended configuration options

## Support

- **GitHub Issues**: [Report bugs and feature requests](https://github.com/keshav-k3/actionwebpush/issues)
- **Documentation**: [API.md](API.md)
- **Examples**: See examples in this README and [API.md](API.md)

We welcome feedback, bug reports, and contributions from the Rails community!