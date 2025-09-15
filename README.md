# ActionWebPush

Rails integration for Web Push notifications with ActionMailer-like interface.

This gem has been extracted from the Campfire project and provides a Rails-integrated solution for Web Push notifications.

### WIP ^-^

```ruby
gem 'actionwebpush'
```

```bash
bundle install
rails generate action_web_push:install
rails db:migrate
```

```ruby
# Configure in config/initializers/action_web_push.rb
ActionWebPush.configure do |config|
  config.vapid_public_key = ENV['VAPID_PUBLIC_KEY']
  config.vapid_private_key = ENV['VAPID_PRIVATE_KEY']
  config.vapid_subject = 'mailto:support@example.com'
end

# In your User model
class User < ApplicationRecord
  has_many :push_subscriptions, class_name: "ActionWebPush::Subscription"
end

# Create a notification class
class NotificationPusher < ActionWebPush::Base
  def new_message(user, message)
    push(
      user.push_subscriptions,
      title: "New Message",
      body: message.content,
      data: { url: message_path(message) }
    )
  end
end

# Send notifications
NotificationPusher.new_message(user, message).deliver_now
```