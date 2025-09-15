# frozen_string_literal: true

require "test_helper"

class SubscriptionTest < Minitest::Test
  include ActionWebPush::TestHelper

  def setup
    setup_action_web_push
    @user = MockUser.new(1)
  end

  def test_validates_required_fields
    subscription = ActionWebPush::Subscription.new
    refute subscription.valid?
    assert_includes subscription.errors[:endpoint], "can't be blank"
    assert_includes subscription.errors[:p256dh_key], "can't be blank"
    assert_includes subscription.errors[:auth_key], "can't be blank"
  end

  def test_build_notification
    subscription = create_subscription
    notification = subscription.build_notification(
      title: "Test",
      body: "Test message"
    )

    assert_equal "Test", notification.title
    assert_equal "Test message", notification.body
    assert_equal subscription.endpoint, notification.endpoint
    assert_equal subscription.p256dh_key, notification.p256dh_key
    assert_equal subscription.auth_key, notification.auth_key
  end

  def test_find_or_create_subscription_creates_new
    params = {
      user: @user,
      endpoint: "https://example.com/push",
      p256dh_key: "test_p256dh",
      auth_key: "test_auth"
    }

    subscription = ActionWebPush::Subscription.find_or_create_subscription(**params)

    assert subscription.persisted?
    assert_equal @user, subscription.user
    assert_equal params[:endpoint], subscription.endpoint
  end

  def test_find_or_create_subscription_updates_existing
    subscription = create_subscription
    original_updated_at = subscription.updated_at

    # Sleep to ensure different timestamp
    sleep 0.01

    found_subscription = ActionWebPush::Subscription.find_or_create_subscription(
      user: @user,
      endpoint: subscription.endpoint,
      p256dh_key: subscription.p256dh_key,
      auth_key: subscription.auth_key
    )

    assert_equal subscription.id, found_subscription.id
    assert found_subscription.updated_at > original_updated_at
  end

  def test_test_delivery_success
    subscription = create_subscription

    assert subscription.test_delivery!
    assert_push_delivered_to subscription, title: "Test Notification"
  end

  private

  def create_subscription
    ActionWebPush::Subscription.create!(
      user: @user,
      endpoint: "https://example.com/push",
      p256dh_key: "test_p256dh_key",
      auth_key: "test_auth_key"
    )
  end

  class MockUser
    attr_reader :id

    def initialize(id)
      @id = id
    end

    def ==(other)
      other.is_a?(MockUser) && other.id == id
    end
  end
end