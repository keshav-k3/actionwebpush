# frozen_string_literal: true

module ActionWebPush
  class StatusChannel < ActionCable::Channel::Base
    def subscribed
      stream_from "action_web_push_status_#{current_user&.id}" if current_user
    end

    def unsubscribed
      # Cleanup when channel is unsubscribed
    end

    private

    def current_user
      # This should be implemented based on your authentication system
      # Example: connection.current_user
      nil
    end
  end
end