# ActionWebPush

Rails integration for Web Push notifications with ActionMailer-like interface.

## Status: Phase 1 Complete ✅

This gem has been extracted from the Campfire project and provides a Rails-integrated solution for Web Push notifications.

### What's Been Implemented

- ✅ **Basic gem structure** with proper Rails integration
- ✅ **Configuration system** similar to ActionMailer
- ✅ **Core classes extracted** from Campfire:
  - `ActionWebPush::Notification` - Individual push notifications
  - `ActionWebPush::Pool` - Thread pool management for efficient delivery
  - `ActionWebPush::Base` - ActionMailer-like interface
  - `ActionWebPush::Subscription` - ActiveRecord model for subscriptions
- ✅ **Rails integration** via Railtie and Engine
- ✅ **Database migration** for subscription storage
- ✅ **RESTful controller** for subscription management
- ✅ **Generator** for easy installation

### Installation (Once Published)

Add this line to your application's Gemfile:

```ruby
gem 'actionwebpush'
```

And then execute:

```bash
bundle install
rails generate action_web_push:install
rails db:migrate
```

### Basic Usage

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/actionwebpush. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/actionwebpush/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Actionwebpush project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/actionwebpush/blob/main/CODE_OF_CONDUCT.md).
