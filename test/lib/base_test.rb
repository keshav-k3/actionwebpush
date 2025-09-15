# frozen_string_literal: true

require "test_helper"

class BaseTest < Minitest::Test
  include ActionWebPush::TestHelper

  def setup
    setup_action_web_push
    @user = MockUser.new(1)
    @subscription = create_subscription
  end

  def test_push_delivers_notification
    pusher_class = Class.new(ActionWebPush::Base) do
      def initialize(title:, body:, **options)
        super(title: title, body: body, **options)
      end
    end

    pusher = pusher_class.new(title: "Test Push", body: "Test message")
    pusher.push([@subscription])

    assert_push_delivered_to @subscription, title: "Test Push", body: "Test message"
  end

  def test_class_method_push
    pusher_class = Class.new(ActionWebPush::Base)

    pusher_class.push([@subscription], title: "Class Push", body: "From class method")

    assert_push_delivered_to @subscription, title: "Class Push", body: "From class method"
  end

  def test_default_params
    pusher_class = Class.new(ActionWebPush::Base) do
      default title: "Default Title", icon: "/default-icon.png"
    end

    pusher = pusher_class.new(body: "Test body")
    pusher.push([@subscription])

    delivery = last_push_delivery
    assert_equal "Default Title", delivery[:title]
    assert_equal "Test body", delivery[:body]
    assert_equal "/default-icon.png", delivery[:options][:icon]
  end

  def test_deliver_now
    pusher_class = Class.new(ActionWebPush::Base)
    pusher = pusher_class.new(title: "Immediate", body: "Delivered now")

    pusher.deliver_now([@subscription])

    assert_push_delivered_to @subscription, title: "Immediate"
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