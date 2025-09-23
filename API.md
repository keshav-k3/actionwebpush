# ActionWebPush API Documentation

## Table of Contents

- [Configuration](#configuration)
- [Notification](#notification)
- [Batch Delivery](#batch-delivery)
- [Base Classes](#base-classes)
- [Rate Limiting](#rate-limiting)
- [Error Handling](#error-handling)
- [Instrumentation](#instrumentation)
- [ActiveRecord Models](#activerecord-models)
- [Background Jobs](#background-jobs)

## Configuration

### ActionWebPush.configure

Configure the gem with VAPID keys and delivery settings.

```ruby
ActionWebPush.configure do |config|
  config.vapid_subject = "mailto:admin@example.com"
  config.vapid_public_key = "your_vapid_public_key"
  config.vapid_private_key = "your_vapid_private_key"
  config.delivery_method = :web_push
  config.pool_size = 10
  config.queue_size = 100
  config.connection_pool_size = 5
  config.batch_size = 100
end
```

#### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `vapid_subject` | String | nil | VAPID subject (mailto: or https:) |
| `vapid_public_key` | String | nil | VAPID public key |
| `vapid_private_key` | String | nil | VAPID private key |
| `delivery_method` | Symbol | :web_push | Delivery method (:web_push, :test) |
| `pool_size` | Integer | 10 | Thread pool size for async delivery |
| `queue_size` | Integer | 100 | Queue size for thread pool |
| `connection_pool_size` | Integer | 5 | HTTP connection pool size |
| `batch_size` | Integer | 100 | Default batch size for bulk operations |

### ActionWebPush.config

Access current configuration:

```ruby
config = ActionWebPush.config
puts config.vapid_subject
```

## Notification

### Creating Notifications

```ruby
notification = ActionWebPush::Notification.new(
  title: "Hello World",
  body: "This is a push notification",
  endpoint: "https://fcm.googleapis.com/fcm/send/...",
  p256dh_key: "BNbN3OiAT...",
  auth_key: "k2i6t8hBmF...",
  data: { url: "/messages/123" },
  icon: "/icon.png",
  badge: "/badge.png",
  urgency: "high"
)
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | String | Yes | Notification title |
| `body` | String | Yes | Notification body |
| `endpoint` | String | Yes | Push service endpoint |
| `p256dh_key` | String | Yes | P256DH public key from subscription |
| `auth_key` | String | Yes | Auth secret from subscription |
| `data` | Hash | No | Custom data payload |
| `icon` | String | No | Notification icon URL |
| `badge` | String | No | Badge icon URL |
| `urgency` | String | No | Urgency level (very-low, low, normal, high) |

### Delivery Methods

#### Synchronous Delivery

```ruby
# Deliver immediately
notification.deliver_now

# Alias for deliver_now
notification.deliver
```

#### Asynchronous Delivery

```ruby
# Deliver via background job
notification.deliver_later

# With options
notification.deliver_later(
  wait: 5.minutes,
  wait_until: 1.hour.from_now,
  queue: :push_notifications,
  priority: 10
)
```

### Notification Methods

#### Instance Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `deliver(connection: nil)` | Boolean | Deliver notification synchronously |
| `deliver_now(connection: nil)` | Boolean | Alias for deliver |
| `deliver_later(options = {})` | Job | Deliver via background job |
| `to_params` | Hash | Convert to parameter hash |
| `to_json(*args)` | String | Convert to JSON |

#### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `title` | String | Notification title |
| `body` | String | Notification body |
| `data` | Hash | Custom data |
| `endpoint` | String | Push endpoint |
| `p256dh_key` | String | P256DH key |
| `auth_key` | String | Auth key |
| `options` | Hash | Additional options |

## Batch Delivery

### ActionWebPush::BatchDelivery

Efficiently deliver multiple notifications.

```ruby
notifications = [notification1, notification2, notification3]

# Basic batch delivery
ActionWebPush::BatchDelivery.deliver(notifications)

# With custom pool and batch size
batch = ActionWebPush::BatchDelivery.new(
  notifications,
  pool: custom_pool,
  batch_size: 50
)
batch.deliver_all
```

#### Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `new(notifications, pool: nil, batch_size: nil)` | Array, Pool, Integer | BatchDelivery | Create new batch |
| `deliver_all` | None | Void | Deliver all notifications |
| `self.deliver(notifications, **options)` | Array, Hash | Void | Class method for quick delivery |

## Base Classes

### ActionWebPush::Base

Base class for notification senders with ActionMailer-like interface.

```ruby
class NotificationSender < ActionWebPush::Base
  default from_subscription: -> { current_subscription }

  def welcome(user)
    web_push(
      title: "Welcome!",
      body: "Thanks for joining",
      to: user.push_subscriptions
    )
  end
end

# Usage
NotificationSender.welcome(user).deliver_later
```

#### Class Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `default(params)` | Hash | Void | Set default parameters |
| `web_push(params)` | Hash | Notification | Create notification |

#### Instance Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `web_push(params)` | Hash | Notification | Create notification |

## Rate Limiting

### ActionWebPush::RateLimiter

Prevent abuse with configurable rate limits.

```ruby
rate_limiter = ActionWebPush::RateLimiter.new(
  limits: {
    endpoint: { max_requests: 100, window: 3600 },
    user: { max_requests: 1000, window: 3600 }
  }
)

# Check rate limit
begin
  rate_limiter.check_rate_limit!(:endpoint, endpoint_url, user_id)
rescue ActionWebPush::RateLimitExceeded => e
  # Handle rate limit exceeded
end

# Check without raising
if rate_limiter.within_rate_limit?(:endpoint, endpoint_url, user_id)
  # Proceed with notification
end

# Get rate limit info
info = rate_limiter.rate_limit_info(:endpoint, endpoint_url, user_id)
# => { limit: 100, remaining: 95, window: 3600, reset_at: Time }
```

#### Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `check_rate_limit!(type, id, user_id)` | Symbol, String, String | Boolean | Check rate limit, raise if exceeded |
| `within_rate_limit?(type, id, user_id)` | Symbol, String, String | Boolean | Check rate limit, return boolean |
| `rate_limit_info(type, id, user_id)` | Symbol, String, String | Hash | Get rate limit information |

#### Rate Limit Types

| Type | Default Limit | Description |
|------|---------------|-------------|
| `:endpoint` | 100/hour | Per endpoint URL |
| `:user` | 1000/hour | Per user |
| `:global` | 10000/hour | Global limit |
| `:subscription` | 50/hour | Per subscription |

## Error Handling

### Exception Hierarchy

```
ActionWebPush::Error
├── ActionWebPush::DeliveryError
├── ActionWebPush::ExpiredSubscriptionError
├── ActionWebPush::ConfigurationError
└── ActionWebPush::RateLimitExceeded
```

### ActionWebPush::ErrorHandler

Centralized error handling with instrumentation.

```ruby
begin
  notification.deliver
rescue ActionWebPush::ExpiredSubscriptionError => e
  # Automatically handles cleanup and instrumentation
rescue ActionWebPush::RateLimitExceeded => e
  # Automatically handles rate limit logging and instrumentation
end
```

#### Handler Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `handle_delivery_error(error, context)` | Error, Hash | Route error to appropriate handler |
| `handle_expired_subscription_error(error, context)` | Error, Hash | Handle expired subscriptions |
| `handle_rate_limit_error(error, context)` | Error, Hash | Handle rate limit exceeded |
| `handle_delivery_failure(error, context)` | Error, Hash | Handle delivery failures |
| `handle_configuration_error(error, context)` | Error, Hash | Handle configuration errors |
| `handle_unexpected_error(error, context)` | Error, Hash | Handle unexpected errors |

## Instrumentation

### ActionWebPush::Instrumentation

Integrated with ActiveSupport::Notifications for monitoring.

```ruby
# Subscribe to all ActionWebPush events
ActiveSupport::Notifications.subscribe(/^action_web_push\./) do |name, start, finish, id, payload|
  duration = finish - start
  Rails.logger.info "#{name}: #{duration}ms #{payload.inspect}"
end

# Subscribe to specific events
ActiveSupport::Notifications.subscribe("action_web_push.notification_delivery") do |name, start, finish, id, payload|
  # payload includes: endpoint, title, urgency, success, response_code
end
```

#### Events

| Event | Payload | Description |
|-------|---------|-------------|
| `notification_delivery` | endpoint, title, urgency, success, response_code | Notification delivery attempt |
| `subscription_expired` | endpoint, error, subscription_id | Subscription expired |
| `rate_limit_exceeded` | resource_type, resource_id, current_count | Rate limit hit |
| `pool_overflow` | overflow_count, total_queued, overflow_rate | Pool queue overflow |
| `notification_delivery_failed` | endpoint, title, error, error_class | Delivery failed |
| `configuration_error` | error, context | Configuration error |
| `unexpected_error` | error, error_class, backtrace, context | Unexpected error |

## ActiveRecord Models

### ActionWebPush::Subscription

Manage push subscriptions in your database.

```ruby
# Find subscriptions
subscriptions = ActionWebPush::Subscription.active
user_subscriptions = ActionWebPush::Subscription.for_user(user)

# Create subscription
subscription = ActionWebPush::Subscription.create!(
  endpoint: "https://fcm.googleapis.com/fcm/send/...",
  p256dh_key: "BNbN3OiAT...",
  auth_key: "k2i6t8hBmF...",
  user: current_user
)

# Build notification
notification = subscription.build_notification(
  title: "Hello",
  body: "World",
  data: { url: "/path" }
)
```

#### Scopes

| Scope | Parameters | Description |
|-------|------------|-------------|
| `active` | None | Non-expired subscriptions |
| `expired` | None | Expired subscriptions |
| `for_user(user)` | User | Subscriptions for specific user |
| `by_endpoint(endpoint)` | String | Find by endpoint |
| `by_user_agent(agent)` | String | Find by user agent pattern |

#### Instance Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `build_notification(params)` | Hash | Notification | Build notification for subscription |
| `expired?` | None | Boolean | Check if subscription is expired |
| `mark_as_expired!` | None | Boolean | Mark subscription as expired |

## Background Jobs

### ActionWebPush::DeliveryJob

ActiveJob for asynchronous delivery.

```ruby
# Enqueue job directly
ActionWebPush::DeliveryJob.perform_later(notification_params)

# Via notification (recommended)
notification.deliver_later
```

#### Job Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `perform(notification_params)` | Hash | Deliver notification from parameters |

## Thread Pool Management

### ActionWebPush::Pool

Manage concurrent deliveries with thread pooling.

```ruby
# Create custom pool
pool = ActionWebPush::Pool.new(
  invalid_subscription_handler: ->(subscription_id) {
    ActionWebPush::Subscription.find(subscription_id)&.destroy
  }
)

# Queue notifications
pool.queue(notification)
pool.queue(notifications_array)

# Get metrics
metrics = pool.metrics
# => { total_queued: 1000, overflow_count: 5, overflow_rate: 0.5, ... }

# Shutdown gracefully
pool.shutdown
```

#### Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `queue(notifications, subscriptions)` | Mixed, Array | Void | Queue for delivery |
| `metrics` | None | Hash | Get pool metrics |
| `shutdown` | None | Void | Graceful shutdown |

## Examples

### Basic Usage

```ruby
# Configure
ActionWebPush.configure do |config|
  config.vapid_subject = "mailto:admin@example.com"
  config.vapid_public_key = ENV['VAPID_PUBLIC_KEY']
  config.vapid_private_key = ENV['VAPID_PRIVATE_KEY']
end

# Send notification
notification = ActionWebPush::Notification.new(
  title: "New Message",
  body: "You have a new message",
  endpoint: subscription.endpoint,
  p256dh_key: subscription.p256dh_key,
  auth_key: subscription.auth_key,
  data: { message_id: 123 }
)

notification.deliver_later
```

### ActionMailer-like Senders

```ruby
class UserNotifications < ActionWebPush::Base
  def welcome(user)
    web_push(
      title: "Welcome!",
      body: "Thanks for joining our app",
      to: user.push_subscriptions,
      data: { type: 'welcome' }
    )
  end

  def message_received(user, message)
    web_push(
      title: "New Message",
      body: message.preview,
      to: user.push_subscriptions,
      data: {
        type: 'message',
        message_id: message.id,
        url: message_url(message)
      }
    )
  end
end

# Usage
UserNotifications.welcome(user).deliver_later
UserNotifications.message_received(user, message).deliver_now
```

### Batch Operations

```ruby
# Send to multiple users
users = User.where(notifications_enabled: true)
notifications = users.map do |user|
  user.push_subscriptions.map do |subscription|
    subscription.build_notification(
      title: "System Maintenance",
      body: "Scheduled maintenance tonight",
      data: { type: 'announcement' }
    )
  end
end.flatten

ActionWebPush::BatchDelivery.deliver(notifications)
```

### Error Handling

```ruby
begin
  notification.deliver
rescue ActionWebPush::ExpiredSubscriptionError
  # Remove expired subscription
  subscription.destroy
rescue ActionWebPush::RateLimitExceeded => e
  # Retry later or queue for later delivery
  notification.deliver_later(wait: 1.hour)
rescue ActionWebPush::DeliveryError => e
  # Log and handle delivery failure
  Rails.logger.error "Push delivery failed: #{e.message}"
end
```

### Monitoring

```ruby
# Subscribe to all push notifications events
ActiveSupport::Notifications.subscribe("action_web_push.notification_delivery") do |name, start, finish, id, payload|
  duration = (finish - start) * 1000

  if payload[:success]
    Rails.logger.info "Push delivered in #{duration.round(2)}ms to #{payload[:endpoint]}"
  else
    Rails.logger.warn "Push failed to #{payload[:endpoint]}: #{payload[:response_code]}"
  end
end

# Custom metrics collection
ActiveSupport::Notifications.subscribe("action_web_push.rate_limit_exceeded") do |name, start, finish, id, payload|
  Metrics.increment("push.rate_limit_exceeded",
    tags: { resource_type: payload[:resource_type] }
  )
end
```