# frozen_string_literal: true

module WebPush
  class ResponseError < StandardError; end
  class ExpiredSubscription < ResponseError; end
  class InvalidSubscription < ResponseError; end

  def self.payload_send(message:, endpoint:, p256dh:, auth:, vapid:, **options)
    # Mock successful response
    MockResponse.new(200, "OK")
  end

  def self.generate_key
    {
      public_key: "mock_public_key_#{SecureRandom.hex(32)}",
      private_key: "mock_private_key_#{SecureRandom.hex(32)}"
    }
  end

  class MockResponse
    attr_reader :code, :body

    def initialize(code, body)
      @code = code
      @body = body
    end

    def success?
      code == 200
    end
  end
end