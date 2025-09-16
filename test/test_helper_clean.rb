# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "actionwebpush"
require "minitest/autorun"
require "minitest/mock"

class Minitest::Test
  def setup
    # Reset configuration for each test
    ActionWebPush.configuration = nil
    # Clear test deliveries if available
    if defined?(ActionWebPush::DeliveryMethods::Test)
      ActionWebPush::DeliveryMethods::Test.clear_deliveries!
    end
  end

  def teardown
    # Clean up after tests
    ActionWebPush.configuration = nil
  end
end