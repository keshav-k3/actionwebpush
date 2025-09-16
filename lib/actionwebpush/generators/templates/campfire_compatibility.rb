# frozen_string_literal: true

# Compatibility module for transitioning from Campfire's web push to ActionWebPush
# Include this in your existing code during the migration period

module ActionWebPush
  module CampfireCompatibility
    extend ActiveSupport::Concern

    included do
      # Alias old method names to new ones
      alias_method :push_subscriptions, :action_web_push_subscriptions if respond_to?(:action_web_push_subscriptions)
    end

    module ClassMethods
      # Provide backward compatibility for existing Campfire classes
      def setup_campfire_compatibility
        # Map old WebPush module to ActionWebPush
        if defined?(::WebPush::Notification)
          ::WebPush::Notification.class_eval do
            def self.new(*args, **kwargs)
              ActionWebPush::Notification.new(*args, **kwargs)
            end
          end
        end

        # Map old Pool class
        if defined?(::WebPush::Pool)
          ::WebPush::Pool.class_eval do
            def self.new(*args, **kwargs)
              ActionWebPush::Pool.new(*args, **kwargs)
            end
          end
        end
      end
    end

    # Legacy notification pusher that mimics Campfire's Room::MessagePusher
    class LegacyMessagePusher
      attr_reader :room, :message

      def initialize(room:, message:)
        @room, @message = room, message
      end

      def push
        build_payload.tap do |payload|
          push_to_users_involved_in_everything(payload)
          push_to_users_involved_in_mentions(payload)
        end
      end

      private

      def build_payload
        if room.direct?
          build_direct_payload
        else
          build_shared_payload
        end
      end

      def build_direct_payload
        {
          title: message.creator.name,
          body: message.plain_text_body,
          data: { path: room_path }
        }
      end

      def build_shared_payload
        {
          title: room.name,
          body: "#{message.creator.name}: #{message.plain_text_body}",
          data: { path: room_path }
        }
      end

      def push_to_users_involved_in_everything(payload)
        subscriptions = relevant_subscriptions.merge(involved_in_everything_scope)
        ActionWebPush::BatchDelivery.deliver(
          subscriptions.map { |sub| sub.build_notification(**payload) }
        )
      end

      def push_to_users_involved_in_mentions(payload)
        return unless message.mentionees.any?

        subscriptions = relevant_subscriptions
                       .merge(involved_in_mentions_scope)
                       .where(user_id: message.mentionees.ids)

        ActionWebPush::BatchDelivery.deliver(
          subscriptions.map { |sub| sub.build_notification(**payload) }
        )
      end

      def relevant_subscriptions
        ActionWebPush::Subscription
          .joins(user: :memberships)
          .merge(visible_disconnected_scope)
          .where.not(user: message.creator)
      end

      def involved_in_everything_scope
        # This should match your existing Membership.involved_in_everything scope
        # Placeholder implementation:
        Membership.where(involved_in_everything: true)
      end

      def involved_in_mentions_scope
        # This should match your existing Membership.involved_in_mentions scope
        # Placeholder implementation:
        Membership.where(involved_in_mentions: true)
      end

      def visible_disconnected_scope
        # This should match your existing Membership.visible.disconnected.where(room: room) scope
        # Placeholder implementation:
        Membership.where(room: room, visible: true, connected: false)
      end

      def room_path
        # Use your existing route helper
        Rails.application.routes.url_helpers.room_path(room)
      rescue
        "/rooms/#{room.id}"
      end
    end

    # Helper methods for migrating existing code
    module MigrationHelpers
      def migrate_push_subscription_creation(params)
        # Convert old push subscription params to ActionWebPush format
        {
          endpoint: params[:endpoint],
          p256dh_key: params[:p256dh_key] || params[:keys]&.dig(:p256dh),
          auth_key: params[:auth_key] || params[:keys]&.dig(:auth),
          user_agent: params[:user_agent]
        }
      end

      def create_action_web_push_subscription(user, params)
        ActionWebPush::Subscription.find_or_create_subscription(
          user: user,
          **migrate_push_subscription_creation(params)
        )
      end

      # Batch migrate existing Push::Subscription records
      def migrate_legacy_subscriptions!(batch_size: 1000)
        return unless defined?(Push::Subscription)

        Push::Subscription.find_in_batches(batch_size: batch_size) do |batch|
          batch.each do |legacy_subscription|
            ActionWebPush::Subscription.find_or_create_subscription(
              user: legacy_subscription.user,
              endpoint: legacy_subscription.endpoint,
              p256dh_key: legacy_subscription.p256dh_key,
              auth_key: legacy_subscription.auth_key,
              user_agent: legacy_subscription.user_agent
            )
          end
        end
      end
    end
  end
end

# Auto-setup compatibility when this file is loaded
if Rails.env.development? || Rails.env.staging?
  ActionWebPush::CampfireCompatibility.setup_campfire_compatibility
end